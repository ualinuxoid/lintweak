#!/usr/bin/env bash
#
# glscr.sh
#
# Randomly switches the active WireGuard client "server" on a GL.iNet router 
# Prerequisites: curl, jq, openssl, md5sum.
#
# Config file (gl.conf), placed next to this script, e.g.:
#   ~/.glscrpt/gl-wg-random-switch.sh
#   ~/.glscrpt/gl.conf
#
#   Contents of gl.conf:
#     ip=192.168.8.1
#     password=admin-password
#
# Usage:
#   ./gl-wg-random-switch.sh          # normal run, logs to /tmp/glscr/log.txt
#   ./gl-wg-random-switch.sh -q       # quiet run, no log file is written at all
#
# ---------------------------------------------------------------------

set -Eeuo pipefail

# ======================================================================
# DEFAULTS (do not touch if you don't know what are you doing)
# ======================================================================

ROUTER_HOST="${ROUTER_HOST:-}"
RPC_URL="${RPC_URL:-}"
ROUTER_USER="${ROUTER_USER:-root}"
ROUTER_PASSWORD="${ROUTER_PASSWORD:-}"

# NOTE: SIDs expire after 5 minutes of inactivity).
GLINET_SID="${GLINET_SID:-}"

# Only consider provider groups whose "group_type" is in this
# space-separated list (1 = preconfigured, 2 = manually added,
# 3 = added by app). Leave empty to consider every type.
ALLOWED_GROUP_TYPES="${ALLOWED_GROUP_TYPES:-}"

# Space-separated group_id / peer_id values to always skip.
EXCLUDED_GROUP_IDS="${EXCLUDED_GROUP_IDS:-}"
EXCLUDED_PEER_IDS="${EXCLUDED_PEER_IDS:-}"

# When 1, the script avoids reselecting the server that is currently
# active (as reported by wg-client/get_status), provided at least one
# other candidate exists.
AVOID_CURRENT_SERVER="${AVOID_CURRENT_SERVER:-1}"

# When 1, call wg-client/stop before wg-client/start. Recommended,
# since starting a new peer while another is running can return the
# "vpn conflict" error.
STOP_BEFORE_SWITCH="${STOP_BEFORE_SWITCH:-1}"

# Log file and its directory. Do NOT point to /dev/null, use
# -q flag instead
LOG_DIR="/tmp/glscr"
LOG_FILE="${LOG_DIR}/log.txt"

# Lock file, used to prevent two instances (e.g. overlapping hotkey
# presses or cron runs) from switching servers at the same time
# DO NOT TOUCH
LOCK_FILE="${LOG_DIR}/lock"

# curl timeouts, in seconds
CURL_CONNECT_TIMEOUT="${CURL_CONNECT_TIMEOUT:-5}"
CURL_MAX_TIME="${CURL_MAX_TIME:-15}"

# How many times to retry a failed RPC call before giving up
RPC_RETRIES="${RPC_RETRIES:-2}"

# When 1, do everything (login, selection, logging) except actually
# call stop/start. Useful for testing filters
DRY_RUN="${DRY_RUN:-0}"

# Quiet mode. You can set it to 1 by the or use -q flag to disable logging
QUIET=0

# ======================================================================
# END OF DEFAULTS
# ======================================================================

SCRIPT_NAME="$(basename "$0")"

resolve_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [[ -h "$source" ]]; do
        local dir
        dir="$(cd -P "$(dirname "$source")" >/dev/null 2>&1 && pwd)"
        source="$(readlink "$source")"
        [[ "$source" != /* ]] && source="$dir/$source"
    done
    cd -P "$(dirname "$source")" >/dev/null 2>&1 && pwd
}

SCRIPT_DIR="$(resolve_script_dir)"
CONFIG_FILE="$SCRIPT_DIR/gl.conf"

while getopts ":q" opt; do
    case "$opt" in
        q) QUIET=1 ;;
        \?) echo "$SCRIPT_NAME: unknown option -$OPTARG" >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

log() {
    [[ "$QUIET" == "1" ]] && return 0
    local level="$1"; shift
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '%s [%s] %s\n' "$ts" "$level" "$*" >>"$LOG_FILE"
}

die() {
    log "ERROR" "$*"
    echo "$SCRIPT_NAME: $*" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "required command '$1' not found in PATH"
}

require_cmd curl
require_cmd jq
require_cmd openssl
require_cmd md5sum
require_cmd flock

if [[ "$QUIET" != "1" ]]; then
    mkdir -p "$LOG_DIR" 2>/dev/null || true
fi
mkdir -p "$(dirname "$LOCK_FILE")" 2>/dev/null || true

load_config() {
    [[ -f "$CONFIG_FILE" ]] || die "config file not found: $CONFIG_FILE"
    [[ -r "$CONFIG_FILE" ]] || die "config file is not readable: $CONFIG_FILE"

    local ip_val pass_val
    ip_val="$(grep -E '^[[:space:]]*ip[[:space:]]*=' "$CONFIG_FILE" | tail -n1 | cut -d'=' -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    pass_val="$(grep -E '^[[:space:]]*password[[:space:]]*=' "$CONFIG_FILE" | tail -n1 | cut -d'=' -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

    [[ -n "$ip_val" ]] || die "'ip' is not set in $CONFIG_FILE"
    [[ -n "$pass_val" ]] || die "'password' is not set in $CONFIG_FILE"

    ROUTER_HOST="$ip_val"
    RPC_URL="http://${ROUTER_HOST}/rpc"
    ROUTER_PASSWORD="$pass_val"
}

if [[ -z "$GLINET_SID" ]]; then
    load_config
fi

exec 9>"$LOCK_FILE"
flock -n 9 || die "another instance is already running (lock: $LOCK_FILE)"

http_post_json() {
    local body="$1"
    local attempt=0 response
    while :; do
        attempt=$((attempt + 1))
        if response="$(curl -sS \
            --connect-timeout "$CURL_CONNECT_TIMEOUT" \
            --max-time "$CURL_MAX_TIME" \
            -H 'Content-Type: application/json' \
            -d "$body" \
            "$RPC_URL")"; then
            echo "$response"
            return 0
        fi
        if (( attempt > RPC_RETRIES )); then
            die "HTTP request to $RPC_URL failed after $attempt attempt(s)"
        fi
        log "WARN" "HTTP request failed, retrying ($attempt/$RPC_RETRIES)"
        sleep 1
    done
}

login() {
    local password="$ROUTER_PASSWORD"
    [[ -n "$password" ]] || die "no router password configured (check 'password=' in $CONFIG_FILE), or provide GLINET_SID directly"

    local challenge_body challenge_resp alg salt nonce
    challenge_body="$(jq -n --arg u "$ROUTER_USER" \
        '{jsonrpc:"2.0",method:"challenge",params:{username:$u},id:0}')"
    challenge_resp="$(http_post_json "$challenge_body")"

    alg="$(jq -r '.result.alg // empty' <<<"$challenge_resp")"
    salt="$(jq -r '.result.salt // empty' <<<"$challenge_resp")"
    nonce="$(jq -r '.result.nonce // empty' <<<"$challenge_resp")"
    [[ -n "$alg" && -n "$salt" && -n "$nonce" ]] || die "challenge step failed (unexpected response: $challenge_resp)"

    local cipher_password
    case "$alg" in
        1|5|6) ;;
        *) die "unsupported hashing algorithm returned by challenge: $alg" ;;
    esac
    cipher_password="$(openssl passwd "-$alg" -salt "$salt" "$password")"

    local hash
    hash="$(printf '%s:%s:%s' "$ROUTER_USER" "$cipher_password" "$nonce" | md5sum | cut -d' ' -f1)"

    local login_body login_resp sid
    login_body="$(jq -n --arg u "$ROUTER_USER" --arg h "$hash" \
        '{jsonrpc:"2.0",method:"login",params:{username:$u,hash:$h},id:0}')"
    login_resp="$(http_post_json "$login_body")"

    sid="$(jq -r '.result.sid // empty' <<<"$login_resp")"
    [[ -n "$sid" ]] || die "login failed (unexpected response: $login_resp)"

    echo "$sid"
}

rpc_call() {
    local object="$1" method="$2" params="$3"
    local payload
    payload="$(jq -n \
        --arg sid "$GLINET_SID" \
        --arg object "$object" \
        --arg method "$method" \
        --argjson params "$params" \
        '{jsonrpc:"2.0",method:"call",params:[$sid,$object,$method,$params],id:1}')"
    http_post_json "$payload"
}

check_rpc_error() {
    local response="$1" context="$2"
    local err_code err_msg
    err_code="$(jq -r '.result.err_code // empty' <<<"$response")"
    if [[ -n "$err_code" ]]; then
        err_msg="$(jq -r '.result.err_msg // "unknown error"' <<<"$response")"
        die "$context failed (err_code=$err_code): $err_msg"
    fi
}

fetch_allowed_groups() {
    local response
    response="$(rpc_call "wg-client" "get_group_list" '{}')"
    check_rpc_error "$response" "get_group_list"

    jq -c --arg allowed_types "$ALLOWED_GROUP_TYPES" \
          --arg excluded_ids "$EXCLUDED_GROUP_IDS" '
        ( $allowed_types | split(" ") | map(select(length > 0) | tonumber) ) as $atypes
        | ( $excluded_ids  | split(" ") | map(select(length > 0) | tonumber) ) as $eids
        | [ .result.groups[]?
            | select(($atypes | length) == 0 or (.group_type as $t | $atypes | index($t) != null))
            | select(($eids | index(.group_id)) == null)
          ]
    ' <<<"$response"
}

fetch_candidate_peers() {
    local allowed_groups_json="$1"
    local response
    response="$(rpc_call "wg-client" "get_all_config_list" '{}')"
    check_rpc_error "$response" "get_all_config_list"

    jq -c --argjson allowed "$allowed_groups_json" \
          --arg excluded_peers "$EXCLUDED_PEER_IDS" '
        ( $allowed | map(.group_id) ) as $agids
        | ( $excluded_peers | split(" ") | map(select(length > 0) | tonumber) ) as $epids
        | [ .result.config_list[]?
            | select(.group_id as $g | $agids | index($g) != null)
            | . as $grp
            | .peers[]?
              | select(($epids | index(.peer_id)) == null)
              | {
                  group_id:   $grp.group_id,
                  group_name: $grp.group_name,
                  peer_id:    .peer_id,
                  name:       .name,
                  location:   (.location // "")
                }
          ]
    ' <<<"$response"
}

fetch_current_server() {
    local response
    response="$(rpc_call "wg-client" "get_status" '{}')"
    check_rpc_error "$response" "get_status"

    jq -c '
        if (.result.status // 0) > 0 then
            { group_id: .result.group_id, peer_id: .result.peer_id }
        else
            null
        end
    ' <<<"$response"
}

pick_random_peer() {
    local candidates_json="$1" current_json="$2"
    local count
    count="$(jq 'length' <<<"$candidates_json")"
    (( count > 0 )) || die "no eligible WireGuard servers found (check filters)"

    if [[ "$AVOID_CURRENT_SERVER" == "1" && "$current_json" != "null" ]]; then
        local narrowed
        narrowed="$(jq -c --argjson cur "$current_json" \
            '[ .[] | select(.group_id != $cur.group_id or .peer_id != $cur.peer_id) ]' \
            <<<"$candidates_json")"
        local narrowed_count
        narrowed_count="$(jq 'length' <<<"$narrowed")"
        if (( narrowed_count > 0 )); then
            candidates_json="$narrowed"
            count="$narrowed_count"
        fi
    fi

    local index=$(( RANDOM % count ))
    jq -c ".[$index]" <<<"$candidates_json"
}

switch_to_peer() {
    local group_id="$1" peer_id="$2"

    if [[ "$DRY_RUN" == "1" ]]; then
        log "INFO" "[dry-run] would stop current client and start group_id=$group_id peer_id=$peer_id"
        return 0
    fi

    if [[ "$STOP_BEFORE_SWITCH" == "1" ]]; then
        local stop_resp
        stop_resp="$(rpc_call "wg-client" "stop" '{}')"
        check_rpc_error "$stop_resp" "stop"
    fi

    local params start_resp
    params="$(jq -n --argjson group_id "$group_id" --argjson peer_id "$peer_id" \
        '{group_id:$group_id, peer_id:$peer_id}')"
    start_resp="$(rpc_call "wg-client" "start" "$params")"
    check_rpc_error "$start_resp" "start (group_id=$group_id peer_id=$peer_id)"
}

main() {
    log "INFO" "starting random VPN server switch"

    if [[ -z "$GLINET_SID" ]]; then
        GLINET_SID="$(login)"
        log "INFO" "logged in, obtained session"
    else
        log "INFO" "using pre-supplied GLINET_SID"
    fi

    local allowed_groups candidates current chosen
    local group_id peer_id label

    allowed_groups="$(fetch_allowed_groups)"
    candidates="$(fetch_candidate_peers "$allowed_groups")"
    current="$(fetch_current_server)"
    chosen="$(pick_random_peer "$candidates" "$current")"

    group_id="$(jq -r '.group_id' <<<"$chosen")"
    peer_id="$(jq -r '.peer_id' <<<"$chosen")"
    label="$(jq -r '"\(.group_name) / \(.name)" + (if .location != "" then " [\(.location)]" else "" end)' <<<"$chosen")"

    log "INFO" "selected group_id=$group_id peer_id=$peer_id ($label)"

    switch_to_peer "$group_id" "$peer_id"

    log "INFO" "successfully switched to $label (group_id=$group_id, peer_id=$peer_id)"
    echo "Switched active VPN server to: $label (group_id=$group_id, peer_id=$peer_id)"
}

main "$@"
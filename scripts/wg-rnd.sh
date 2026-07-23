#!/bin/bash
#
# wg-rnd.sh
#
# NOTE: wg-quick (util from script) needs root, so it uses pkexec (PolicyKit) to ask for password graphically 

set -euo pipefail

# ==== CHANGE THIS: ====
CONFIG_DIR="/path/to/your/wireguard/configs"
# ======================

SCRIPT_PATH="$(readlink -f "$0")"

if [[ "${1:-}" == "--apply" ]]; then
    NEW_CONF="$2"
    [[ -f "$NEW_CONF" && "$NEW_CONF" == *.conf ]] || exit 1

    for conf in "$CONFIG_DIR"/*.conf; do
        iface="$(basename "$conf" .conf)"
        ip link show "$iface" &>/dev/null && wg-quick down "$conf" || true
    done

    wg-quick up "$NEW_CONF"
    exit 0
fi

[[ -d "$CONFIG_DIR" ]] || {
    notify-send -i dialog-error "WireGuard" "Config folder not found: $CONFIG_DIR"
    exit 1
}

mapfile -t PROFILES < <(find "$CONFIG_DIR" -maxdepth 1 -name '*.conf' -printf '%f\n' | sort)
[[ ${#PROFILES[@]} -gt 0 ]] || {
    notify-send -i dialog-error "WireGuard" "No .conf profiles found in $CONFIG_DIR"
    exit 1
}

CURRENT_IFACE="$(ip -o link show type wireguard 2>/dev/null | awk -F': ' '{print $2}' | head -n1 || true)"

CANDIDATES=()
for p in "${PROFILES[@]}"; do
    [[ "${p%.conf}" == "$CURRENT_IFACE" ]] || CANDIDATES+=("$p")
done
[[ ${#CANDIDATES[@]} -gt 0 ]] || CANDIDATES=("${PROFILES[@]}")

PICKED="${CANDIDATES[$RANDOM % ${#CANDIDATES[@]}]}"
NAME="${PICKED%.conf}"

if pkexec "$SCRIPT_PATH" --apply "$CONFIG_DIR/$PICKED"; then
    notify-send -i network-vpn "WireGuard switched" "$NAME"
else
    notify-send -i dialog-error "WireGuard switch failed" "$NAME"
fi
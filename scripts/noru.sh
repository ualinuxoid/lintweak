#!/usr/bin/env bash
#
# noru.sh - block ru-related shit like domains/TLDs/IP ranges
#
# Primarry written for users in Ukraine, but, of course, can be used by
# anyone else who want protection against ru shit
#
# Must be run as root:
#     sudo bash noru.sh
#
# Modes (chosen interactively):
#   n  normal     - append a curated hosts blocklist to /etc/hosts
#   a  aggressive - normal + null-route entire Russian-linked TLDs
#                   (.ru, .su, .рф, .moscow, ...) via a local DNS resolver
#   e  extreme    - aggressive + drop outbound traffic to Russian IP
#                   ranges at the firewall level (nftables)
#
# Every file this script touches is backed up first under
# /etc/rublock-backup/<timestamp>/, and the script deletes itself after
# a successful run.

set -uo pipefail

SELF_PATH="$(readlink -f "$0" 2>/dev/null || true)"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/etc/rublock-backup/${TS}"

HOSTS_FILE="/etc/hosts"
MARK_START="# >>> rublock-managed block, do not edit >>>"
MARK_END="# <<< rublock-managed block <<<"

HOSTS_PRIMARY_URL="https://github.com/ualinuxoid/lintweak/raw/refs/heads/main/misc/rublock.txt"
HOSTS_FALLBACK_URL="https://codeberg.org/ualinuxoid/lintweak/raw/branch/main/misc/rublock.txt"

IPV4_PRIMARY_URL="https://www.ipdeny.com/ipblocks/data/aggregated/ru-aggregated.zone"
IPV4_FALLBACK_URL="https://www.ipdeny.com/ipblocks/data/countries/ru.zone"
IPV6_PRIMARY_URL="https://www.ipdeny.com/ipv6/ipaddresses/blocks/ru.zone"
IPV6_FALLBACK_URL="https://www.ipdeny.com/ipv6/ipblocks/data/countries/ru.zone"

RU_TLDS=(ru su xn--p1ai xn--d1acj3b moscow xn--80adxhks tatar)

HOSTS_DONE=0
TLD_DONE=0
IP_DONE=0

log()  { echo "[rublock] $*"; }
warn() { echo "[rublock] WARNING: $*" >&2; }
err()  { echo "[rublock] ERROR: $*" >&2; }

backup_file() {
  local f="$1"
  [[ -e "$f" ]] || return 0
  mkdir -p "$BACKUP_DIR"
  cp -a "$f" "${BACKUP_DIR}/$(basename "$f").bak" 2>/dev/null || true
}

# fetch <url> <output_file>
fetch() {
  local url="$1" out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --max-time 20 "$url" -o "$out" 2>/dev/null && return 0
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -q --timeout=20 -O "$out" "$url" 2>/dev/null && return 0
  fi
  return 1
}

# fetch_fallback <primary_url> <fallback_url> <output_file>
fetch_fallback() {
  local primary="$1" fallback="$2" out="$3"
  if fetch "$primary" "$out" && [[ -s "$out" ]]; then
    return 0
  fi
  warn "primary source unreachable ($primary), trying fallback..."
  if fetch "$fallback" "$out" && [[ -s "$out" ]]; then
    return 0
  fi
  return 1
}

detect_pkg_install() {
  if command -v apt-get >/dev/null 2>&1; then echo "apt-get install -y -qq"
  elif command -v dnf >/dev/null 2>&1; then echo "dnf install -y -q"
  elif command -v yum >/dev/null 2>&1; then echo "yum install -y -q"
  elif command -v pacman >/dev/null 2>&1; then echo "pacman -Sy --noconfirm --needed"
  elif command -v zypper >/dev/null 2>&1; then echo "zypper --non-interactive install"
  elif command -v apk >/dev/null 2>&1; then echo "apk add --no-cache"
  else echo ""
  fi
}

ensure_pkg() {
  local bin="$1" pkg="$2"
  command -v "$bin" >/dev/null 2>&1 && return 0
  log "'$bin' not found, attempting to install package '$pkg'..."
  local installer
  installer="$(detect_pkg_install)"
  if [[ -z "$installer" ]]; then
    err "no supported package manager found. Install '$pkg' manually and re-run."
    return 1
  fi
  # shellcheck disable=SC2086
  if ! $installer "$pkg" >/dev/null 2>&1; then
    err "failed to install '$pkg'."
    return 1
  fi
  command -v "$bin" >/dev/null 2>&1
}

install_hosts_block() {
  log "Fetching curated hosts blocklist..."
  local tmp added line
  tmp="$(mktemp)"

  if ! fetch_fallback "$HOSTS_PRIMARY_URL" "$HOSTS_FALLBACK_URL" "$tmp"; then
    err "could not download the hosts blocklist from either source."
    rm -f "$tmp"
    return 1
  fi

  backup_file "$HOSTS_FILE"

  # idempotent: strip a block added by a previous run, if any
  sed -i "/${MARK_START}/,/${MARK_END}/d" "$HOSTS_FILE"

  added=0
  {
    echo "$MARK_START"
    echo "# source: $HOSTS_PRIMARY_URL"
    echo "# installed: $(date -u +%FT%TZ)"
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%$'\r'}"
      line="${line#"${line%%[![:space:]]*}"}"   # trim leading whitespace
      line="${line%"${line##*[![:space:]]}"}"   # trim trailing whitespace
      if [[ -z "$line" || "$line" == \#* ]]; then
        echo "$line"
        continue
      fi
      if [[ "$line" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}[[:space:]] ]]; then
        echo "$line"          # already "ip domain" hosts syntax
      else
        echo "0.0.0.0 $line"  # bare domain -> null-route it
      fi
      added=$((added + 1))
    done < "$tmp"
    echo "$MARK_END"
  } >> "$HOSTS_FILE"

  rm -f "$tmp"
  log "Added ~${added} entries to ${HOSTS_FILE}."
  HOSTS_DONE=1
}

install_tld_block() {
  ensure_pkg dnsmasq dnsmasq || return 1

  mkdir -p /etc/dnsmasq.d
  backup_file /etc/dnsmasq.d/rublock-tld.conf

  if command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | grep -q ':53 ' \
      && ! systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    warn "port 53 already looks occupied by something other than" \
         "systemd-resolved; dnsmasq may fail to start. Check 'ss -ltnp | grep :53'."
  fi

  if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    backup_file /etc/systemd/resolved.conf
    mkdir -p /etc/systemd/resolved.conf.d
    cat > /etc/systemd/resolved.conf.d/rublock.conf <<-'EOF'
	[Resolve]
	DNSStubListener=no
	EOF
    systemctl restart systemd-resolved 2>/dev/null || true
  fi

  {
    echo "$MARK_START"
    echo "port=53"
    echo "listen-address=127.0.0.1"
    echo "bind-interfaces"
    echo "no-resolv"
    if [[ -e /run/systemd/resolve/resolv.conf ]]; then
      awk '/^nameserver/{print "server=" $2}' /run/systemd/resolve/resolv.conf
    else
      echo "server=1.1.1.1"
      echo "server=9.9.9.9"
    fi
    for tld in "${RU_TLDS[@]}"; do
      echo "address=/${tld}/0.0.0.0"
      echo "address=/${tld}/::"
    done
    echo "$MARK_END"
  } > /etc/dnsmasq.d/rublock-tld.conf

  if ! systemctl enable --now dnsmasq >/dev/null 2>&1; then
    if ! systemctl restart dnsmasq >/dev/null 2>&1; then
      err "failed to start dnsmasq. TLD-level blocking was not activated."
      return 1
    fi
  fi

  # point the system resolver at dnsmasq
  chattr -i /etc/resolv.conf 2>/dev/null || true
  if [[ -e /etc/resolv.conf ]]; then
    mkdir -p "$BACKUP_DIR"
    cat /etc/resolv.conf > "${BACKUP_DIR}/resolv.conf.bak" 2>/dev/null || true
  fi
  rm -f /etc/resolv.conf
  printf 'nameserver 127.0.0.1\n' > /etc/resolv.conf
  if ! chattr +i /etc/resolv.conf 2>/dev/null; then
    warn "'chattr' unavailable; a DHCP client or NetworkManager may" \
         "overwrite /etc/resolv.conf again later. Re-run this step if so."
  fi

  log "DNS-level blocking active for TLDs: ${RU_TLDS[*]}"
  TLD_DONE=1
}

install_ip_block() {
  ensure_pkg nft nftables || return 1

  local v4 v6 nft_conf
  v4="$(mktemp)"; v6="$(mktemp)"
  nft_conf="/etc/nftables-rublock/rublock.nft"
  mkdir -p /etc/nftables-rublock

  if ! fetch_fallback "$IPV4_PRIMARY_URL" "$IPV4_FALLBACK_URL" "$v4"; then
    warn "could not fetch IPv4 range list, IPv4 will not be blocked."
    : > "$v4"
  fi
  if ! fetch_fallback "$IPV6_PRIMARY_URL" "$IPV6_FALLBACK_URL" "$v6"; then
    warn "could not fetch IPv6 range list, IPv6 will not be blocked."
    : > "$v6"
  fi

  if [[ ! -s "$v4" && ! -s "$v6" ]]; then
    err "no IP range data available from any source, skipping IP-range block."
    rm -f "$v4" "$v6"
    return 1
  fi

  backup_file "$nft_conf"

  {
    echo "table inet rublock {"
    echo "  set ru_v4 {"
    echo "    type ipv4_addr; flags interval; auto-merge;"
    if [[ -s "$v4" ]]; then
      printf '    elements = { %s }\n' "$(grep -Ev '^[[:space:]]*(#.*)?$' "$v4" | paste -sd,)"
    fi
    echo "  }"
    echo "  set ru_v6 {"
    echo "    type ipv6_addr; flags interval; auto-merge;"
    if [[ -s "$v6" ]]; then
      printf '    elements = { %s }\n' "$(grep -Ev '^[[:space:]]*(#.*)?$' "$v6" | paste -sd,)"
    fi
    echo "  }"
    echo "  chain output {"
    echo "    type filter hook output priority 0; policy accept;"
    [[ -s "$v4" ]] && echo "    ip daddr @ru_v4 drop"
    [[ -s "$v6" ]] && echo "    ip6 daddr @ru_v6 drop"
    echo "  }"
    echo "}"
  } > "$nft_conf"

  rm -f "$v4" "$v6"

  if nft list table inet rublock >/dev/null 2>&1; then
    nft delete table inet rublock 2>/dev/null || true
  fi
  if ! nft -f "$nft_conf"; then
    err "failed to load nftables ruleset from $nft_conf."
    return 1
  fi

  # persist across reboots
  if [[ -f /etc/nftables.conf ]]; then
    backup_file /etc/nftables.conf
    if ! grep -qF "$nft_conf" /etc/nftables.conf; then
      echo "include \"$nft_conf\"" >> /etc/nftables.conf
    fi
    systemctl enable nftables >/dev/null 2>&1 || true
  else
    cat > /etc/systemd/system/rublock-nft.service <<-EOF
	[Unit]
	Description=Load rublock nftables rules (Russian IP ranges)
	After=network-pre.target
	Before=network.target

	[Service]
	Type=oneshot
	ExecStart=/usr/sbin/nft -f ${nft_conf}
	RemainAfterExit=yes

	[Install]
	WantedBy=multi-user.target
	EOF
    systemctl daemon-reload
    systemctl enable --now rublock-nft.service >/dev/null 2>&1 || true
  fi

  log "Outbound traffic to Russian IPv4/IPv6 ranges is now dropped via nftables."
  IP_DONE=1
}

print_banner() {
  cat <<'EOF'
==============================================================
 noru - your ultimate protection against russian propaganda,
 some malware, government spyware and just toxic community.
==============================================================
EOF
}

choose_mode() {
  local mode confirm
  while true; do
    echo
    echo "Choose a blocking mode:"
    echo "  [n] normal     - block a curated list of Russian domains via /etc/hosts"
    echo "  [a] aggressive - normal + null-route entire Russian-linked TLDs"
    echo "                   (.ru .su .рф .дети .moscow .москва .tatar) via DNS"
    echo "  [e] extreme    - aggressive + drop outbound traffic to Russian IP"
    echo "                   ranges at the firewall level (nftables)"
    read -rp "Your choice [n/a/e]: " mode
    case "$mode" in
      n|N)
        install_hosts_block || { err "normal mode failed, nothing else changed."; exit 1; }
        break
        ;;
      a|A)
        install_hosts_block || { err "hosts step failed, aborting."; exit 1; }
        install_tld_block   || { err "TLD-blocking step failed."; exit 1; }
        break
        ;;
      e|E)
        echo
        warn "extreme mode drops entire Russian IP ranges at the firewall level."
        echo "This can break legitimate, unrelated services that happen to be"
        echo "hosted on Russian IP space (some CDNs, game servers, cloud"
        echo "tenants, etc.). For most people, 'aggressive' or 'normal' already 
        echo "give solid protection with much less risk of collateral breakage."
        read -rp "Continue with extreme anyway? [y = continue / n = back to mode choice]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          install_hosts_block || { err "hosts step failed, aborting."; exit 1; }
          install_tld_block   || { err "TLD-blocking step failed, aborting."; exit 1; }
          install_ip_block    || { err "IP-range blocking step failed."; exit 1; }
          break
        fi
        ;;
      *)
        echo "Please enter n, a, or e."
        ;;
    esac
  done
}

print_summary() {
  echo
  log "Done. Changed files were backed up to: $BACKUP_DIR"
  if [[ "$HOSTS_DONE" -eq 1 ]]; then
    echo "  - /etc/hosts: remove the block between the rublock markers to undo."
  fi
  if [[ "$TLD_DONE" -eq 1 ]]; then
    echo "  - DNS: 'chattr -i /etc/resolv.conf', restore it from the backup,"
    echo "    remove /etc/dnsmasq.d/rublock-tld.conf, and disable dnsmasq"
    echo "    (and re-enable systemd-resolved's stub listener) to undo."
  fi
  if [[ "$IP_DONE" -eq 1 ]]; then
    echo "  - Firewall: 'nft delete table inet rublock' and disable/remove"
    echo "    rublock-nft.service (or the include line in nftables.conf) to undo."
  fi
}

self_delete() {
  if [[ -n "$SELF_PATH" && -f "$SELF_PATH" ]]; then
    rm -f -- "$SELF_PATH"
  fi
}

main() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "This script must be run as root, e.g.: sudo bash $0" >&2
    exit 1
  fi
  print_banner
  choose_mode
  print_summary
  self_delete
}

main "$@"
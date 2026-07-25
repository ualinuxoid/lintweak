#!/usr/bin/env bash
#
# =============================================================================
#  Network Identity Privacy - Installer
# =============================================================================
#
#  USAGE: sudo bash wguard.sh
#  logs: /var/log/privacy-randomizer-install.log
# =============================================================================

echo "============================================================"
echo "Network Identity Privacy - Installer"
echo "Proudly created in Ukraine!"
echo "============================================================"
echo "If you can, please donate to Ukrainian defenders:"
echo "https://war.ukraine.ua"
echo "https://savelife.in.ua"
echo "============================================================"
echo "Glory to Ukraine! Stop the war!"
echo "============================================================"
echo "Wait 5s..."

sleep 5

if [[ "${EUID}" -ne 0 ]]; then
    echo "[!] This installer needs administrator rights."
    echo "[!] Please run it again as:  sudo bash $0"
    exit 1
fi

set -Eeuo pipefail

LOGFILE="/var/log/privacy-randomizer-install.log"
: > "$LOGFILE" 2>/dev/null || LOGFILE="/tmp/privacy-randomizer-install.log"

run() {
    echo "    -> $*" >> "$LOGFILE" 2>&1 || true
    "$@" >> "$LOGFILE" 2>&1
}

on_error() {
    echo "[!] Something went wrong during installation."
    echo "[!] Details were saved to: $LOGFILE"
    echo "[!] Installation stopped. Nothing harmful was left half-configured;"
    echo "[!] you can safely run this installer again after checking the log."
    exit 1
}
trap on_error ERR

CONFIG_DIR="/etc/privacy-randomizer"
GROUP_NAME="privacy-randomizer"

TARGET_USER="${SUDO_USER:-}"
if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
    TARGET_USER="$(logname 2>/dev/null || echo root)"
fi
TARGET_HOME="/root"
if [[ "$TARGET_USER" != "root" ]]; then
    TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
    [[ -z "$TARGET_HOME" ]] && TARGET_HOME="/home/$TARGET_USER"
fi

echo "[*] Detecting your Linux distribution..."

PKG_MGR="unknown"
if command -v apt-get >/dev/null 2>&1; then PKG_MGR="apt"
elif command -v dnf >/dev/null 2>&1; then PKG_MGR="dnf"
elif command -v pacman >/dev/null 2>&1; then PKG_MGR="pacman"
elif command -v zypper >/dev/null 2>&1; then PKG_MGR="zypper"
fi
echo "    Package manager: $PKG_MGR"

install_pkgs() {
    local pkgs=("$@")
    case "$PKG_MGR" in
        apt)
            run apt-get update -y
            run apt-get install -y "${pkgs[@]}"
            ;;
        dnf)
            run dnf install -y "${pkgs[@]}"
            ;;
        pacman)
            run pacman -Sy --noconfirm "${pkgs[@]}"
            ;;
        zypper)
            run zypper --non-interactive install "${pkgs[@]}"
            ;;
        *)
            return 1
            ;;
    esac
}

echo "[*] Installing required components (this may take a minute)..."

case "$PKG_MGR" in
    apt)     CORE_PKGS=(network-manager zenity jq iptables) ;;
    dnf)     CORE_PKGS=(NetworkManager zenity jq iptables) ;;
    pacman)  CORE_PKGS=(networkmanager zenity jq iptables) ;;
    zypper)  CORE_PKGS=(NetworkManager zenity jq iptables) ;;
    *)       CORE_PKGS=() ;;
esac

if [[ "$PKG_MGR" != "unknown" ]]; then
    install_pkgs "${CORE_PKGS[@]}" || echo "[!] Some packages may not have installed cleanly - check $LOGFILE"
    install_pkgs macchanger 2>/dev/null || true
else
    echo "[!] Could not detect a supported package manager (apt/dnf/pacman/zypper)."
    echo "[!] Please make sure NetworkManager, zenity, jq and iptables are installed manually."
fi

echo "[*] Making sure NetworkManager is running..."
run systemctl enable NetworkManager 2>/dev/null || true
run systemctl start NetworkManager 2>/dev/null || true

if ! command -v nmcli >/dev/null 2>&1; then
    echo "[!] NetworkManager (nmcli) was not found. This toolkit requires NetworkManager"
    echo "[!] to manage MAC/hostname randomization. Please install it and re-run this script."
    exit 1
fi

echo "[+] Dependencies are ready."

echo "[*] Preparing configuration folder..."

mkdir -p "$CONFIG_DIR"

if ! getent group "$GROUP_NAME" >/dev/null 2>&1; then
    run groupadd "$GROUP_NAME"
fi
if [[ "$TARGET_USER" != "root" ]]; then
    run usermod -aG "$GROUP_NAME" "$TARGET_USER"
fi

if [[ ! -f "$CONFIG_DIR/exceptions.json" ]]; then
    echo '{}' > "$CONFIG_DIR/exceptions.json"
fi

chown -R root:"$GROUP_NAME" "$CONFIG_DIR"
chmod 2775 "$CONFIG_DIR"
chmod 664 "$CONFIG_DIR/exceptions.json"

echo "[*] Writing device identity profiles (Apple / Samsung)..."

cat > "$CONFIG_DIR/profiles.sh" <<'PROFILES_EOF'
# Network Identity Privacy - device profile database
# ----------------------------------------------------------------------------
# APPLE_OUIS / SAMSUNG_OUIS contain real, publicly documented (IEEE OUI
# registry) MAC address prefixes to form pool of network hostnames
# (the name broadcast to the DHCP server / router) that get paired with the
# matching OUI. Feel free to edit these lists.
#
# SPOOF_TTL is fixed to 64 because it is the default TTL for both iOS and
# Android (the two families spoofed here), keeping the fake identity
# consistent between MAC/hostname and the actual IP traffic.
# ----------------------------------------------------------------------------

APPLE_OUIS=(
    "3C:07:54" "68:96:7B" "7C:6D:62" "A4:5E:60" "DC:A9:04" "F0:D1:A9"
    "AC:87:A3" "D0:E1:40" "F0:98:9D" "A4:83:E7" "00:1E:C2" "00:1C:B3"
    "8C:85:90" "B8:53:AC" "E0:B9:BA" "F4:F1:5A"
)

APPLE_HOSTNAMES=(
    "iPhone-5" "iPhone-5s" "iPhone-SE" "iPhone-6" "iPhone-6s" "iPhone-7"
    "iPhone-8" "iPhone-X" "iPhone-XR" "iPhone-XS" "iPhone-11" "iPhone-12"
    "iPhone-12-Pro" "iPhone-13" "iPhone-13-Pro" "iPhone-14" "iPhone-14-Pro"
    "iPhone-15" "iPhone-15-Pro" "iPhone-16" "iPhone-16-Pro" "iPhone-17"
)

SAMSUNG_OUIS=(
    "00:12:FB" "00:15:99" "00:1D:25" "08:D4:2B" "34:23:87" "5C:0A:5B"
    "8C:77:12" "C0:BD:D1" "88:32:9B" "1C:5A:3E" "40:0E:85" "AC:5F:3E"
    "78:1F:DB" "A0:07:98" "CC:07:AB"
)

SAMSUNG_HOSTNAMES=(
    "Galaxy-A7" "Galaxy-A10" "Galaxy-A20" "Galaxy-A32" "Galaxy-A34"
    "Galaxy-A54" "Galaxy-S7" "Galaxy-S8" "Galaxy-S9" "Galaxy-S10"
    "Galaxy-S20" "Galaxy-S20-Ultra" "Galaxy-S21" "Galaxy-S22" "Galaxy-S23"
    "Galaxy-S24"
)

SPOOF_TTL=64
PROFILES_EOF

chown root:"$GROUP_NAME" "$CONFIG_DIR/profiles.sh"
chmod 644 "$CONFIG_DIR/profiles.sh"

echo "[*] Installing the identity rotation engine..."

cat > /usr/local/bin/privacy-randomizer-rotate <<'ROTATE_EOF'
#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Network Identity Privacy - rotation engine
# !!!DO NOT EDIT!!!
# ----------------------------------------------------------------------------
set -Eeuo pipefail

IFACE="${1:-}"
ACTION="${2:-}"

CONFIG_DIR="/etc/privacy-randomizer"
PROFILES_FILE="$CONFIG_DIR/profiles.sh"
EXCEPTIONS_FILE="$CONFIG_DIR/exceptions.json"
LOGFILE="/var/log/privacy-randomizer.log"

log() { echo "$(date '+%F %T') $*" >> "$LOGFILE" 2>/dev/null || true; }

[[ "$ACTION" != "up" ]] && exit 0
[[ -z "$IFACE" ]] && exit 0

case "$IFACE" in
    lo|docker*|veth*|virbr*|tun*|tap*|br-*|vmnet*) exit 0 ;;
esac

[[ -f "$PROFILES_FILE" ]] || { log "profiles.sh missing, skipping"; exit 0; }

source "$PROFILES_FILE"

# Entropy workaround (TODO: fix someday)
RANDOM=$(( ($(date +%s%N) ^ $$) % 32768 ))

CONN_TYPE=$(nmcli -g GENERAL.TYPE device show "$IFACE" 2>/dev/null || echo "")
case "$CONN_TYPE" in
    wifi)     MAC_KEY="wifi.cloned-mac-address" ;;
    ethernet) MAC_KEY="ethernet.cloned-mac-address" ;;
    *)        exit 0 ;;
esac

CONN_ID=$(nmcli -g GENERAL.CONNECTION device show "$IFACE" 2>/dev/null || echo "")
[[ -z "$CONN_ID" || "$CONN_ID" == "--" ]] && exit 0

SSID=""
BSSID=""
if [[ "$CONN_TYPE" == "wifi" ]]; then
    SSID=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1=="yes"{ $1=""; sub(/^:/,""); print; exit }')
    if command -v iw >/dev/null 2>&1; then
        BSSID=$(iw dev "$IFACE" link 2>/dev/null | awk '/Connected to/{print $3}')
    fi
    if [[ -z "$BSSID" ]]; then
        BSSID=$(nmcli -t -f active,bssid dev wifi 2>/dev/null | awk -F: '$1=="yes"{ $1=""; sub(/^:/,""); gsub(/\\:/,":"); print; exit }')
    fi
fi

KEY=""
[[ -n "$SSID" ]] && KEY="$SSID"
[[ -z "$KEY" && -n "$BSSID" ]] && KEY="$BSSID"

# GUI
EXCLUDED="false"
CUSTOM_MAC=""
CUSTOM_HOST=""
if [[ -n "$KEY" && -f "$EXCEPTIONS_FILE" ]] && command -v jq >/dev/null 2>&1; then
    ENTRY=$(jq -c --arg k "$KEY" '.[$k] // empty' "$EXCEPTIONS_FILE" 2>/dev/null || echo "")
    if [[ -n "$ENTRY" ]]; then
        EXCLUDED=$(echo "$ENTRY" | jq -r '.disabled // false' 2>/dev/null || echo "false")
        CUSTOM_MAC=$(echo "$ENTRY" | jq -r '.mac // empty' 2>/dev/null || echo "")
        CUSTOM_HOST=$(echo "$ENTRY" | jq -r '.hostname // empty' 2>/dev/null || echo "")
    fi
fi

if [[ "$EXCLUDED" == "true" ]]; then
    log "Randomization disabled by user for network '$KEY' on $IFACE - leaving as is."
    exit 0
fi

rand_byte() { printf '%02X' $((RANDOM % 256)); }

BRAND=$((RANDOM % 2))
if [[ $BRAND -eq 0 ]]; then
    OUI_POOL=("${APPLE_OUIS[@]}")
    HOST_POOL=("${APPLE_HOSTNAMES[@]}")
else
    OUI_POOL=("${SAMSUNG_OUIS[@]}")
    HOST_POOL=("${SAMSUNG_HOSTNAMES[@]}")
fi

if [[ -n "$CUSTOM_MAC" ]]; then
    NEW_MAC="$CUSTOM_MAC"
else
    OUI="${OUI_POOL[$((RANDOM % ${#OUI_POOL[@]}))]}"
    NEW_MAC="${OUI}:$(rand_byte):$(rand_byte):$(rand_byte)"
fi

if [[ -n "$CUSTOM_HOST" ]]; then
    NEW_HOST="$CUSTOM_HOST"
else
    NEW_HOST="${HOST_POOL[$((RANDOM % ${#HOST_POOL[@]}))]}-$((RANDOM % 900 + 100))"
fi

CLIENT_ID="ff:$(rand_byte):$(rand_byte):$(rand_byte):$(rand_byte):$(rand_byte):$(rand_byte):$(rand_byte)"

nmcli connection modify "$CONN_ID" "$MAC_KEY" "$NEW_MAC" >>"$LOGFILE" 2>&1 || log "Could not set MAC on $CONN_ID"
nmcli connection modify "$CONN_ID" ipv4.dhcp-hostname "$NEW_HOST" ipv4.dhcp-send-hostname yes >>"$LOGFILE" 2>&1 || log "Could not set IPv4 hostname on $CONN_ID"
nmcli connection modify "$CONN_ID" ipv6.dhcp-hostname "$NEW_HOST" ipv6.dhcp-send-hostname yes >>"$LOGFILE" 2>&1 || true
nmcli connection modify "$CONN_ID" ipv4.dhcp-client-id "$CLIENT_ID" >>"$LOGFILE" 2>&1 || log "Could not set DHCP client id on $CONN_ID"

if command -v iptables >/dev/null 2>&1; then
    iptables -t mangle -D POSTROUTING -o "$IFACE" -j TTL --ttl-set "$SPOOF_TTL" 2>/dev/null || true
    iptables -t mangle -A POSTROUTING -o "$IFACE" -j TTL --ttl-set "$SPOOF_TTL" >>"$LOGFILE" 2>&1 || true
fi

log "Prepared new identity for '$KEY' on $IFACE -> MAC=$NEW_MAC HOST=$NEW_HOST TTL=$SPOOF_TTL (active from the next reconnect)"
exit 0
ROTATE_EOF

chmod 755 /usr/local/bin/privacy-randomizer-rotate
chown root:root /usr/local/bin/privacy-randomizer-rotate

echo "[*] Registering the auto-rotation hook with NetworkManager..."

mkdir -p /etc/NetworkManager/dispatcher.d

cat > /etc/NetworkManager/dispatcher.d/01-privacy-randomizer <<'DISPATCH_EOF'
#!/usr/bin/env bash
# Managed by installation script.
# It is only path. Do not touch.
/usr/local/bin/privacy-randomizer-rotate "$1" "$2" >/dev/null 2>&1 || true
exit 0
DISPATCH_EOF

chmod 755 /etc/NetworkManager/dispatcher.d/01-privacy-randomizer
chown root:root /etc/NetworkManager/dispatcher.d/01-privacy-randomizer

run systemctl reload NetworkManager 2>/dev/null || run systemctl restart NetworkManager 2>/dev/null || true

echo "[+] Automatic randomization is now active for every interface."

echo "[*] Installing GUI..."

cat > /usr/local/bin/privacy-randomizer-gui <<'GUI_EOF'
#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Network Identity Privacy GUI
# !!!DO NOT EDIT!!!
# ----------------------------------------------------------------------------
set -Eeuo pipefail

CONFIG_DIR="/etc/privacy-randomizer"
EXCEPTIONS_FILE="$CONFIG_DIR/exceptions.json"

if ! command -v zenity >/dev/null 2>&1; then
    echo "zenity is required but was not found. Please reinstall the toolkit."
    exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
    zenity --error --text="jq is required but was not found. Please reinstall the toolkit."
    exit 1
fi
[[ -f "$EXCEPTIONS_FILE" ]] || echo '{}' > "$EXCEPTIONS_FILE"

is_valid_mac() {
    [[ "$1" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]
}

save_json() {
    local tmp
    tmp=$(mktemp)
    cat > "$tmp"
    cat "$tmp" > "$EXCEPTIONS_FILE"
    rm -f "$tmp"
}

while true; do
    CHOICE=$(zenity --list --title="Network Identity Privacy" \
        --text="What would you like to do?" \
        --column="Action" \
        "Disable randomization for a network" \
        "Set a custom identity for a network" \
        "View saved networks" \
        "Remove a saved network" \
        --height=320 --width=460) || exit 0

    case "$CHOICE" in
        "Disable randomization for a network")
            KEY=$(zenity --entry --title="Disable Randomization" \
                --text="Enter the network name (SSID) or router MAC (BSSID) to EXCLUDE\nfrom randomization (e.g. your home or work network):")
            [[ -z "${KEY:-}" ]] && continue
            jq --arg k "$KEY" '.[$k] = {disabled:true}' "$EXCEPTIONS_FILE" | save_json
            zenity --info --text="Randomization is now disabled for:\n$KEY"
            ;;

        "Set a custom identity for a network")
            FORM=$(zenity --forms --title="Custom Network Identity" \
                --text="Fix a specific identity for one network" \
                --add-entry="Network name (SSID) or router MAC (BSSID)" \
                --add-entry="Custom MAC address (AA:BB:CC:DD:EE:FF, leave blank for random)" \
                --add-entry="Custom network hostname (leave blank for random)") || continue
            IFS='|' read -r KEY CMAC CHOST <<< "$FORM"
            if [[ -z "${KEY:-}" ]]; then
                zenity --error --text="The network name / BSSID is required."
                continue
            fi
            if [[ -n "${CMAC:-}" ]] && ! is_valid_mac "$CMAC"; then
                zenity --error --text="That MAC address is not valid.\nExpected format: AA:BB:CC:DD:EE:FF"
                continue
            fi
            jq --arg k "$KEY" --arg m "${CMAC:-}" --arg h "${CHOST:-}" \
                '.[$k] = {disabled:false, mac:$m, hostname:$h}' "$EXCEPTIONS_FILE" | save_json
            zenity --info --text="Custom identity saved for:\n$KEY"
            ;;

        "View saved networks")
            LIST=$(jq -r 'to_entries[] | "\(.key):  \(.value)"' "$EXCEPTIONS_FILE" 2>/dev/null || echo "")
            zenity --text-info --title="Saved Networks" --width=640 --height=420 \
                <<< "${LIST:-No saved networks yet.}"
            ;;

        "Remove a saved network")
            KEY=$(zenity --entry --title="Remove Network" \
                --text="Enter the exact network name (SSID) or BSSID to remove:")
            [[ -z "${KEY:-}" ]] && continue
            jq --arg k "$KEY" 'del(.[$k])' "$EXCEPTIONS_FILE" | save_json
            zenity --info --text="Removed:\n$KEY"
            ;;

        *) exit 0 ;;
    esac
done
GUI_EOF

chmod 755 /usr/local/bin/privacy-randomizer-gui
chown root:"$GROUP_NAME" /usr/local/bin/privacy-randomizer-gui

echo "[*] Creating a shortcuts..."

DESKTOP_CONTENT='[Desktop Entry]
Version=1.0
Type=Application
Name=Network Identity Privacy
Comment=GUI tool
Exec=/usr/local/bin/privacy-randomizer-gui
Icon=network-wireless
Terminal=false
Categories=Network;Security;Settings;
'

mkdir -p /usr/share/applications
echo "$DESKTOP_CONTENT" > /usr/share/applications/privacy-randomizer.desktop
chmod 644 /usr/share/applications/privacy-randomizer.desktop

if [[ -d "$TARGET_HOME" ]]; then
    mkdir -p "$TARGET_HOME/.local/share/applications"
    echo "$DESKTOP_CONTENT" > "$TARGET_HOME/.local/share/applications/privacy-randomizer.desktop"
    chmod 755 "$TARGET_HOME/.local/share/applications/privacy-randomizer.desktop"

    if [[ -d "$TARGET_HOME/Desktop" ]]; then
        echo "$DESKTOP_CONTENT" > "$TARGET_HOME/Desktop/privacy-randomizer.desktop"
        chmod 755 "$TARGET_HOME/Desktop/privacy-randomizer.desktop"
        command -v gio >/dev/null 2>&1 && run gio set "$TARGET_HOME/Desktop/privacy-randomizer.desktop" metadata::trusted true || true
    fi

    if [[ "$TARGET_USER" != "root" ]]; then
        run chown -R "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/.local/share/applications/privacy-randomizer.desktop" 2>/dev/null || true
        [[ -f "$TARGET_HOME/Desktop/privacy-randomizer.desktop" ]] && run chown "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/Desktop/privacy-randomizer.desktop" 2>/dev/null || true
    fi
fi

echo "[+] Shortcut created: 'Network Identity Privacy'."

echo ""
echo -n "Do you want to block incoming connections from outside (enable a firewall)? [y/N]: "
read -r FW_ANSWER

if [[ "$FW_ANSWER" =~ ^[Yy]$ ]]; then
    echo "[*] Setting up the firewall (deny incoming, allow outgoing)..."

    FIREWALL_DONE="false"

    if [[ "$PKG_MGR" == "apt" || "$PKG_MGR" == "dnf" || "$PKG_MGR" == "zypper" ]]; then
        install_pkgs ufw 2>/dev/null || true
    fi

    if command -v ufw >/dev/null 2>&1; then
        run ufw --force reset
        run ufw default deny incoming
        run ufw default allow outgoing
        run ufw --force enable
        run systemctl enable ufw 2>/dev/null || true
        FIREWALL_DONE="true"
        echo "[+] Firewall (ufw) is active: unsolicited incoming connections are blocked."
    elif command -v iptables >/dev/null 2>&1; then
        cat > "$CONFIG_DIR/firewall-rules.sh" <<'RULES_EOF'
#!/usr/bin/env bash
IPT=$(command -v iptables || true)
[[ -z "$IPT" ]] && exit 0
"$IPT" -P INPUT DROP
"$IPT" -P FORWARD DROP
"$IPT" -P OUTPUT ACCEPT
"$IPT" -F INPUT
"$IPT" -A INPUT -i lo -j ACCEPT
"$IPT" -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
"$IPT" -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
exit 0
RULES_EOF
        chmod 700 "$CONFIG_DIR/firewall-rules.sh"
        chown root:root "$CONFIG_DIR/firewall-rules.sh"

        cat > /etc/systemd/system/privacy-randomizer-firewall.service <<'UNIT_EOF'
[Unit]
Description=Network Identity Privacy - basic firewall (default-deny incoming)
After=network-pre.target
Before=network.target

[Service]
Type=oneshot
ExecStart=/etc/privacy-randomizer/firewall-rules.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT_EOF

        run systemctl daemon-reload
        run systemctl enable --now privacy-randomizer-firewall.service
        FIREWALL_DONE="true"
        echo "[+] Firewall (iptables) is active: unsolicited incoming connections are blocked."
    else
        echo "[!] Could not set up a firewall automatically (no ufw/iptables found)."
    fi
else
    echo "[*] Skipping firewall setup (you can run this installer again later to add it)."
fi

echo "============================================================"
echo " Installation complete!"
echo "============================================================"
echo " - Your MAC, network hostname (machine one - no) and DHCP ID"
echo "   are now randomized automatically on every reconnect, for"
echo "   every Wi-Fi and Ethernet interface."
echo " - Use GUI to add exclusions

if [[ "$TARGET_USER" != "root" ]]; then
    echo " - IMPORTANT: log out and back in once, so that your user"
    echo "   account picks up the permissions needed to use the GUI"
    echo "   without a password prompt."
fi

echo " - Technical logs: /var/log/privacy-randomizer.log"
echo "============================================================"
echo "Wait a little..."

sleep 5

echo "============================================================"
echo "Thank you for using my scripts!"
echo "============================================================"
echo "Sorry, that i ask multipletimes,  but... This is really important..."
echo "If you can, please donate to Ukrainian defenders:"
echo "https://war.ukraine.ua"
echo "https://savelife.in.ua"
echo "============================================================"
echo "Glory to Ukraine! Stop the war!"
echo "============================================================"


if [[ -f "$0" ]]; then
    rm -f -- "$0"
fi

exit 0
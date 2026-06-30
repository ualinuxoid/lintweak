#!/usr/bin/env bash

set -euo pipefail

MAIN_GITHUB="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
MAIN_FALLBACK="http://sbc.io/hosts/hosts"

FAKENEWS_GITHUB="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-only/hosts"
FAKENEWS_FALLBACK="http://sbc.io/hosts/alternates/fakenews-only/hosts"

GAMBLING_GITHUB="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/gambling-only/hosts"
GAMBLING_FALLBACK="http://sbc.io/hosts/alternates/gambling-only/hosts"

PORN_GITHUB="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn-only/hosts"
PORN_FALLBACK="http://sbc.io/hosts/alternates/porn-only/hosts"

SOCIAL_GITHUB="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/social-only/hosts"
SOCIAL_FALLBACK="http://sbc.io/hosts/alternates/social-only/hosts"

# Temporary placeholder
# RUSSIAN_PROPAGANDA_URL="https://example.com"

CONFIG_FILE="/etc/hosts-block.conf"
UPDATE_SCRIPT="/usr/local/bin/update-hosts.sh"
SERVICE_NAME="update-hosts"
TIMER_NAME="update-hosts"

download_with_fallback() {
    local url1="$1" url2="$2" out="$3"
    if command -v wget >/dev/null 2>&1; then
        wget -q -O "$out" "$url1" 2>/dev/null || wget -q -O "$out" "$url2" 2>/dev/null
    elif command -v curl >/dev/null 2>&1; then
        curl -s -o "$out" "$url1" 2>/dev/null || curl -s -o "$out" "$url2" 2>/dev/null
    else
        return 1
    fi
    return $?
}

ask_yes_no() {
    local prompt="$1"
    local answer
    while true; do
        read -r -p "$prompt (y/n): " answer
        case "$answer" in
            [Yy]* ) return 0 ;;
            [Nn]* ) return 1 ;;
            * ) echo "Please answer y or n." ;;
        esac
    done
}


if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)."
    exit 1
fi

echo "=== Hosts-based Ad-Block Installer ==="
echo "Default - only Adblocking"
echo "Do you also want to enable the following additional filters?"

if ask_yes_no "Block fake news (fakenews-only)"; then
    INCLUDE_FAKENEWS="yes"
else
    INCLUDE_FAKENEWS="no"
fi

if ask_yes_no "Block gambling sites"; then
    INCLUDE_GAMBLING="yes"
else
    INCLUDE_GAMBLING="no"
fi

if ask_yes_no "Block pornographic sites"; then
    INCLUDE_PORN="yes"
else
    INCLUDE_PORN="no"
fi

if ask_yes_no "Block social media sites"; then
    INCLUDE_SOCIAL="yes"
else
    INCLUDE_SOCIAL="no"
fi

if ask_yes_no "Block Russian propaganda and sites supporting war in Ukraine (recommended)"; then
    INCLUDE_RUSSIAN="yes"
else
    INCLUDE_RUSSIAN="no"
fi

echo "Noted, bro! Proceeding..."

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

MAIN_FILE="$TMP_DIR/main.hosts"
echo "Downloading main ad-blocking list..."
if download_with_fallback "$MAIN_GITHUB" "$MAIN_FALLBACK" "$MAIN_FILE"; then
    echo "Main list downloaded successfully."
else
    echo "ERROR: Failed to download main hosts list from both sources." >&2
    exit 1
fi

EXTRA_FILES=()
add_extra() {
    local name="$1" url1="$2" url2="$3"
    local out="$TMP_DIR/${name}.hosts"
    echo "Downloading ${name} list..."
    if download_with_fallback "$url1" "$url2" "$out"; then
        EXTRA_FILES+=("$out")
        echo "  -> ${name} added."
    else
        echo "  -> WARNING: Failed to download ${name} list (skipped)." >&2
    fi
}

[[ "$INCLUDE_FAKENEWS" == "yes" ]] && add_extra "fakenews" "$FAKENEWS_GITHUB" "$FAKENEWS_FALLBACK"
[[ "$INCLUDE_GAMBLING" == "yes" ]] && add_extra "gambling" "$GAMBLING_GITHUB" "$GAMBLING_FALLBACK"
[[ "$INCLUDE_PORN" == "yes" ]] && add_extra "porn" "$PORN_GITHUB" "$PORN_FALLBACK"
[[ "$INCLUDE_SOCIAL" == "yes" ]] && add_extra "social" "$SOCIAL_GITHUB" "$SOCIAL_FALLBACK"

if [[ "$INCLUDE_RUSSIAN" == "yes" ]]; then
    RUSSIAN_FILE="$TMP_DIR/russian.hosts"
    echo "Downloading Russian propaganda list from $RUSSIAN_PROPAGANDA_URL..."
    if command -v wget >/dev/null 2>&1; then
        wget -q -O "$RUSSIAN_FILE" "$RUSSIAN_PROPAGANDA_URL" 2>/dev/null || {
            echo "WARNING: Failed to download Russian propaganda list (skipped)." >&2
        }
    elif command -v curl >/dev/null 2>&1; then
        curl -s -o "$RUSSIAN_FILE" "$RUSSIAN_PROPAGANDA_URL" 2>/dev/null || {
            echo "WARNING: Failed to download Russian propaganda list (skipped)." >&2
        }
    else
        echo "WARNING: Neither wget nor curl found, cannot download Russian list." >&2
    fi
    if [[ -f "$RUSSIAN_FILE" ]]; then
        EXTRA_FILES+=("$RUSSIAN_FILE")
        echo "  -> Russian propaganda list added."
    fi
fi

COMBINED="$TMP_DIR/combined.hosts"
cp "$MAIN_FILE" "$COMBINED"

for extra in "${EXTRA_FILES[@]}"; do
    base=$(basename "$extra" .hosts)
    echo "" >> "$COMBINED"
    echo "### === $base BLOCK ===" >> "$COMBINED"
    cat "$extra" >> "$COMBINED"
done

BACKUP="/etc/hosts.backup.$(date +%s)"
echo "Backing up current /etc/hosts to $BACKUP"
cp /etc/hosts "$BACKUP"

echo "Installing new /etc/hosts..."
cp "$COMBINED" /etc/hosts

cat > "$CONFIG_FILE" <<EOF
# Configuration for hosts-block auto-update
# Generated by installer on $(date)
INCLUDE_FAKENEWS="$INCLUDE_FAKENEWS"
INCLUDE_GAMBLING="$INCLUDE_GAMBLING"
INCLUDE_PORN="$INCLUDE_PORN"
INCLUDE_SOCIAL="$INCLUDE_SOCIAL"
INCLUDE_RUSSIAN="$INCLUDE_RUSSIAN"
RUSSIAN_PROPAGANDA_URL="$RUSSIAN_PROPAGANDA_URL"
EOF

echo "Creating auto-update script at $UPDATE_SCRIPT"
cat > "$UPDATE_SCRIPT" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

CONFIG_FILE="/etc/hosts-block.conf"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file $CONFIG_FILE not found." >&2
    exit 1
fi
source "$CONFIG_FILE"

download_with_fallback() {
    local url1="$1" url2="$2" out="$3"
    if command -v wget >/dev/null 2>&1; then
        wget -q -O "$out" "$url1" 2>/dev/null || wget -q -O "$out" "$url2" 2>/dev/null
    elif command -v curl >/dev/null 2>&1; then
        curl -s -o "$out" "$url1" 2>/dev/null || curl -s -o "$out" "$url2" 2>/dev/null
    else
        return 1
    fi
    return $?
}

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

MAIN_GITHUB="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
MAIN_FALLBACK="http://sbc.io/hosts/hosts"
FAKENEWS_GITHUB="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-only/hosts"
FAKENEWS_FALLBACK="http://sbc.io/hosts/alternates/fakenews-only/hosts"
GAMBLING_GITHUB="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/gambling-only/hosts"
GAMBLING_FALLBACK="http://sbc.io/hosts/alternates/gambling-only/hosts"
PORN_GITHUB="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn-only/hosts"
PORN_FALLBACK="http://sbc.io/hosts/alternates/porn-only/hosts"
SOCIAL_GITHUB="https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/social-only/hosts"
SOCIAL_FALLBACK="http://sbc.io/hosts/alternates/social-only/hosts"

download_with_fallback "$MAIN_GITHUB" "$MAIN_FALLBACK" "$TMP_DIR/main.hosts" || exit 1

EXTRA_FILES=()
add_extra() {
    local name="$1" url1="$2" url2="$3"
    local out="$TMP_DIR/${name}.hosts"
    if download_with_fallback "$url1" "$url2" "$out"; then
        EXTRA_FILES+=("$out")
    fi
}

[[ "$INCLUDE_FAKENEWS" == "yes" ]] && add_extra "fakenews" "$FAKENEWS_GITHUB" "$FAKENEWS_FALLBACK"
[[ "$INCLUDE_GAMBLING" == "yes" ]] && add_extra "gambling" "$GAMBLING_GITHUB" "$GAMBLING_FALLBACK"
[[ "$INCLUDE_PORN" == "yes" ]] && add_extra "porn" "$PORN_GITHUB" "$PORN_FALLBACK"
[[ "$INCLUDE_SOCIAL" == "yes" ]] && add_extra "social" "$SOCIAL_GITHUB" "$SOCIAL_FALLBACK"

if [[ "$INCLUDE_RUSSIAN" == "yes" ]] && [[ -n "$RUSSIAN_PROPAGANDA_URL" ]]; then
    RUSSIAN_FILE="$TMP_DIR/russian.hosts"
    if command -v wget >/dev/null 2>&1; then
        wget -q -O "$RUSSIAN_FILE" "$RUSSIAN_PROPAGANDA_URL" 2>/dev/null && EXTRA_FILES+=("$RUSSIAN_FILE")
    elif command -v curl >/dev/null 2>&1; then
        curl -s -o "$RUSSIAN_FILE" "$RUSSIAN_PROPAGANDA_URL" 2>/dev/null && EXTRA_FILES+=("$RUSSIAN_FILE")
    fi
fi

COMBINED="$TMP_DIR/combined.hosts"
cp "$TMP_DIR/main.hosts" "$COMBINED"
for extra in "${EXTRA_FILES[@]}"; do
    base=$(basename "$extra" .hosts)
    echo "" >> "$COMBINED"
    echo "### === $base BLOCK ===" >> "$COMBINED"
    cat "$extra" >> "$COMBINED"
done

BACKUP="/etc/hosts.backup.$(date +%s)"
cp /etc/hosts "$BACKUP" 2>/dev/null || true
cp "$COMBINED" /etc/hosts

rm -rf "$TMP_DIR"
EOF

chmod +x "$UPDATE_SCRIPT"

echo "Setting up systemd timer for automatic updates..."

SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
TIMER_FILE="/etc/systemd/system/${TIMER_NAME}.timer"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Update hosts-based blocklists
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$UPDATE_SCRIPT
StandardOutput=null
StandardError=journal
EOF

cat > "$TIMER_FILE" <<EOF
[Unit]
Description=Update hosts blocklists daily and after boot
Requires=${SERVICE_NAME}.service

[Timer]
OnBootSec=30
OnUnitActiveSec=24h
RandomizedDelaySec=5min

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload >/dev/null 2>&1
systemctl enable "$TIMER_NAME.timer" >/dev/null 2>&1
systemctl start "$TIMER_NAME.timer" >/dev/null 2>&1

echo "Installation completed successfully!"
echo " - Your choices have been saved in $CONFIG_FILE."
echo " - A backup of your previous /etc/hosts is stored in $BACKUP."
echo " - Automatic updates enabled for your convenience"

rm -f -- "$0"
exit 0
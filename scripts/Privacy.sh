#!/bin/bash

set -e

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root (use sudo)."
    exit 1
fi

echo "WARNING: This script is intended for Debian, Ubuntu, Linux Mint, and derivatives."
echo "Do not worry, all existing configuration files will be backed up with .bak extension."
echo

echo "=== Few questions :) ==="
echo "Select MAC address randomisation mode for NetworkManager:"
echo "  1) Stable randomisation – same MAC per network, persistent across reboots."
echo "  2) Full randomisation  – different MAC each connection (recommended for privacy)."
read -p "Enter choice (1 or 2): " mac_choice

case "$mac_choice" in
    1)
        MAC_MODE="stable"
        STABLE_ID="connection.stable-id=\${CONNECTION}/\${BOOT}"
        echo "[i] Stable randomisation selected."
        ;;
    2)
        MAC_MODE="random"
        STABLE_ID="connection.stable-id=\${BOOT}"
        echo "[i] Full randomisation selected (recommended)."
        ;;
    *)
        echo "Invalid choice. Defaulting to full randomisation (option 2)."
        MAC_MODE="random"
        STABLE_ID="connection.stable-id=\${BOOT}"
        ;;
esac

echo "[*] Checking and installing required packages (this may take a moment)..."
apt update > /dev/null 2>&1
apt install -y chrony network-manager systemd-resolved grub-common > /dev/null 2>&1
echo "[+] Dependencies OK."

RESOLVED_CONF="/etc/systemd/resolved.conf"
if [[ -f "$RESOLVED_CONF" ]]; then
    cp "$RESOLVED_CONF" "${RESOLVED_CONF}.bak"
    echo "[*] Backed up $RESOLVED_CONF to ${RESOLVED_CONF}.bak"
fi

cat > "$RESOLVED_CONF" <<'EOF'
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com
FallbackDNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net
DNSOverTLS=yes
EOF
echo "[+] DNS over TLS setup OK"

NM_CONF="/etc/NetworkManager/NetworkManager.conf"
if [[ -f "$NM_CONF" ]]; then
    cp "$NM_CONF" "${NM_CONF}.bak"
    echo "[*] Backed up $NM_CONF to ${NM_CONF}.bak"
fi

{
    echo "[device]"
    echo "wifi.scan-rand-mac-address=yes"
    echo ""
    echo "[connection]"
    echo "ethernet.cloned-mac-address=$MAC_MODE"
    echo "wifi.cloned-mac-address=$MAC_MODE"
    if [[ -n "$STABLE_ID" ]]; then
        echo "$STABLE_ID"
    fi
} > "$NM_CONF"

echo "[+] MAC privacy applied"

CHRONY_CONF="/etc/chrony/chrony.conf"
if [[ -f "$CHRONY_CONF" ]]; then
    cp "$CHRONY_CONF" "${CHRONY_CONF}.bak"
    echo "[*] Backed up $CHRONY_CONF to ${CHRONY_CONF}.bak"
fi

cat > "$CHRONY_CONF" <<'EOF'
# Servers
server time.cloudflare.com iburst nts
server time.cloudflare.com iburst nts
server ntppool1.time.nl iburst nts
server nts.netnod.se iburst nts
server ptbtime1.ptb.de iburst nts
server time.dfm.dk iburst nts
server time.cifelli.xyz iburst nts

keyfile /etc/chrony/chrony.keys
driftfile /var/lib/chrony/chrony.drift
ntsdumpdir /var/lib/chrony
minsources 3
authselectmode require
makestep 1.0 3
noclientlog
port 0
cmdport 0
leapsectz right/UTC
EOF
echo "[+] NTS instead of NTP setup successfull :)"

echo "[*] Now script will enforce generic hostname"

hostnamectl set-hostname "Android"

echo "[+] Done!"

echo "Next step (optional) GRUB hardening!"
echo "IMPORTANT: Remember these credentials – forgetting these will make you impossible to boot into system!"
ask_grub() {
    echo
    read -p "Do you want to set a GRUB password? (y/n): " answer
    case "$answer" in
        [Yy]* )
            echo "You will be prompted for a username and password."
            read -p "Enter GRUB username: " grub_user
            read -sp "Enter GRUB password: " grub_pass1
            echo
            read -sp "Confirm GRUB password: " grub_pass2
            echo

            if [[ "$grub_pass1" != "$grub_pass2" ]]; then
                echo "ERROR: Passwords do not match. Skipping GRUB password setup."
                return 1
            fi

            echo "[*] Generating PBKDF2 hash..."
            hashed=$(printf "%s\n%s" "$grub_pass1" "$grub_pass2" | grub-mkpasswd-pbkdf2 2>/dev/null | grep "PBKDF2 hash" | awk '{print $NF}')
            if [[ -z "$hashed" ]]; then
                echo "ERROR: Failed to generate hash. Is grub-common installed?"
                return 1
            fi

            GRUB_CUSTOM="/etc/grub.d/02_password"
            cat > "$GRUB_CUSTOM" <<EOF
set superusers="$grub_user"
password_pbkdf2 $grub_user $hashed
EOF
            chmod +x "$GRUB_CUSTOM"
            echo "[*] Applying..."
            update-grub > /dev/null 2>&1
            echo "[+] GRUB password set for user '$grub_user'."
            ;;
        * )
            echo "[i] Skipping GRUB password setup."
            ;;
    esac
}

ask_grub

SYSCTL_CONF="/etc/sysctl.conf"
if [[ -f "$SYSCTL_CONF" ]]; then
    cp "$SYSCTL_CONF" "${SYSCTL_CONF}.bak"
    echo "[*] Backed up $SYSCTL_CONF to ${SYSCTL_CONF}.bak"
fi

grep -q "net.ipv4.icmp_echo_ignore_all" "$SYSCTL_CONF" || \
    echo "net.ipv4.icmp_echo_ignore_all = 1" >> "$SYSCTL_CONF"
grep -q "net.ipv6.icmp_echo_ignore_all" "$SYSCTL_CONF" || \
    echo "net.ipv6.icmp_echo_ignore_all = 1" >> "$SYSCTL_CONF"
echo "[+] Invisible mode activated!"
echo "Now your PC won't be visible in LAN via ping"

sysctl -p > /dev/null 2>&1 || true

echo "[*] Final steps..."
systemctl restart systemd-resolved > /dev/null 2>&1
systemctl restart NetworkManager > /dev/null 2>&1
systemctl restart chrony > /dev/null 2>&1

echo "[+] DONE!"
echo "I recommend you to reboot your system to ensure all changes take full effect."

rm -f "$0"
exit 0
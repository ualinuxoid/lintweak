#!/usr/bin/env bash
#
# ssdshield.sh
# ------------
# Automatic SSD wear-reduction toolkit for Linux (Debian/Ubuntu, Fedora/RHEL,
# Arch-based systems). Run as root (for ex sudo bash ssdshield.sh).

set -Eeuo pipefail
IFS=$'\n\t'
export LC_ALL=C

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------
SCRIPT_NAME="ssdshield"
SCRIPT_VERSION="1.0"
LOG_FILE="/root/${SCRIPT_NAME}-install.log"
BACKUP_DIR="/root/${SCRIPT_NAME}-backup-$(date +%Y%m%d-%H%M%S)"

MODE="normal"
ZRAM_PERCENT=50
ZRAM_ALGO="zstd"
ZRAM_LEVEL=""
DISABLE_LOGS="no"
PKG_MANAGER="unknown"
CHANGES_LOG=()

C_INFO='\033[1;36m'; C_OK='\033[1;32m'; C_WARN='\033[1;33m'; C_ERR='\033[1;31m'; C_BOLD='\033[1m'; C_RST='\033[0m'

info()  { printf "%b\n" "${C_INFO}[*]${C_RST} $*"; }
ok()    { printf "%b\n" "${C_OK}[OK]${C_RST} $*"; }
warn()  { printf "%b\n" "${C_WARN}[!]${C_RST} $*"; }
err()   { printf "%b\n" "${C_ERR}[ERROR]${C_RST} $*" >&2; }
note()  { CHANGES_LOG+=("$*"); }

run() {
  {
    echo "+ $*"
    "$@"
  } >>"$LOG_FILE" 2>&1
}

trap 'err "Unexpected error near line $LINENO. Nothing destructive should have happened; check $LOG_FILE for details."; exit 1' ERR

ask_yes_no() {
  local prompt="$1" default="$2" reply
  if [[ ! -r /dev/tty ]]; then
    echo "$default"
    return 0
  fi
  while true; do
    read -rp "$prompt" reply < /dev/tty || reply=""
    reply="${reply:-$default}"
    case "${reply,,}" in
      y|yes) echo "yes"; return 0 ;;
      n|no)  echo "no";  return 0 ;;
      *) echo "Please answer y or n." >&2 ;;
    esac
  done
}

print_banner() {
  echo "============================================================"
  echo "Proudly created in Ukraine!"
  echo "============================================================"
  echo "If you can, please donate to Ukrainian defenders:"
  echo "https://war.ukraine.ua"
  echo "https://savelife.in.ua"
  echo "============================================================"
  echo "Glory to Ukraine! Stop the war!"
  echo -e "${C_BOLD}================================================${C_RST}"
  echo -e "${C_BOLD}  ssdshield v${SCRIPT_VERSION} - SSD wear protection${C_RST}"
  echo -e "${C_BOLD}================================================${C_RST}"
  echo "This script reduces disk writes to extend your SSD's lifespan:"
  echo "it replaces disk swap with compressed RAM (zram), moves temporary"
  echo "files, logs and package cache into RAM, disables access-time"
  echo "tracking and hibernation, and reduces browser disk writes."
  echo
}

check_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "Please run this script as root, e.g.: sudo bash ssdshield.sh"
    exit 1
  fi
}

detect_pkg_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER="apt"
  elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
  elif command -v pacman >/dev/null 2>&1; then
    PKG_MANAGER="pacman"
  else
    PKG_MANAGER="unknown"
    warn "No supported package manager detected (apt/dnf/pacman)."
    warn "Package-dependent features (APT cache in RAM, profile-sync-daemon) will be skipped."
  fi
}

detect_users() {
  awk -F: '$3>=1000 && $3<60000 && $6 ~ /^\/home\// {print $1":"$6}' /etc/passwd 2>/dev/null
}

backup_file() {
  local f="$1"
  [[ -e "$f" ]] || return 0
  mkdir -p "$BACKUP_DIR"
  cp -a "$f" "$BACKUP_DIR/" 2>>"$LOG_FILE" || true
}

fstab_has_mount() {
  local mp="$1"
  awk -v m="$mp" '$0 !~ /^#/ && $2==m {found=1} END{exit !found}' /etc/fstab
}

fstab_ensure_line() {
  # Usage: fstab_ensure_line <mountpoint> <full fstab line>
  local mp="$1" line="$2"
  if ! fstab_has_mount "$mp"; then
    echo "$line" >> /etc/fstab
  fi
}

ask_mode() {
  echo
  echo -e "${C_BOLD}Choose a protection mode:${C_RST}"
  echo "  [n] Normal      - balanced SSD protection, safer defaults (RECOMMENDED)"
  echo "  [a] Aggressive  - maximum SSD protection, uses more RAM, more crash-risk trade-offs"
  if [[ ! -r /dev/tty ]]; then
    MODE="normal"
    warn "No interactive terminal detected; using recommended Normal mode."
    return
  fi
  local reply
  while true; do
    read -rp "Your choice [n/a] (default: n): " reply < /dev/tty || reply=""
    reply="${reply:-n}"
    case "${reply,,}" in
      n) MODE="normal"; break ;;
      a) MODE="aggressive"; break ;;
      *) echo "Please enter n or a." ;;
    esac
  done
  ok "Mode selected: $MODE"
}

ask_zram_settings() {
  local default_pct=50
  [[ "$MODE" == "aggressive" ]] && default_pct=65

  echo
  local customize
  customize=$(ask_yes_no "Customize zram compression/size? Otherwise recommended defaults are used. [y/N]: " "no")

  if [[ "$customize" != "yes" ]]; then
    ZRAM_ALGO="zstd"; ZRAM_LEVEL=""; ZRAM_PERCENT=$default_pct
    ok "Using recommended zram settings (algorithm=zstd, size=${ZRAM_PERCENT}% of RAM)."
    return
  fi

  if [[ ! -r /dev/tty ]]; then
    ZRAM_ALGO="zstd"; ZRAM_LEVEL=""; ZRAM_PERCENT=$default_pct
    warn "No interactive terminal detected; using recommended zram settings."
    return
  fi

  echo "Compression level:"
  echo "  [l] low     - fastest, lowest CPU usage, modest ratio (lz4)"
  echo "  [m] medium  - balanced speed/ratio (zstd) - recommended"
  echo "  [h] high    - favors compression ratio over speed (zstd, higher effort)"
  echo "  [e] extreme - maximum compression, more CPU usage (zstd, highest effort)"
  local letter
  while true; do
    read -rp "Your choice [l/m/h/e] (default: m): " letter < /dev/tty || letter=""
    letter="${letter:-m}"
    case "${letter,,}" in
      l) ZRAM_ALGO="lz4";  ZRAM_LEVEL="";   break ;;
      m) ZRAM_ALGO="zstd"; ZRAM_LEVEL="";   break ;;
      h) ZRAM_ALGO="zstd"; ZRAM_LEVEL="8";  break ;;
      e) ZRAM_ALGO="zstd"; ZRAM_LEVEL="15"; break ;;
      *) echo "Please enter l, m, h or e." ;;
    esac
  done

  local size
  while true; do
    read -rp "zram size as % of RAM, 20-65 (default: ${default_pct}): " size < /dev/tty || size=""
    size="${size:-$default_pct}"
    if [[ "$size" =~ ^[0-9]+$ ]] && (( size >= 20 && size <= 65 )); then
      ZRAM_PERCENT="$size"
      break
    fi
    echo "Please enter a whole number between 20 and 65."
  done

  ok "zram settings: algorithm=${ZRAM_ALGO}${ZRAM_LEVEL:+ (level $ZRAM_LEVEL)}, size=${ZRAM_PERCENT}% of RAM"
}

ask_log_preference() {
  echo
  local reply
  reply=$(ask_yes_no "Disable system logging entirely, instead of keeping a small 5MB RAM log? [y/N]: " "no")
  [[ "$reply" == "yes" ]] && DISABLE_LOGS="yes" || DISABLE_LOGS="no"
}

confirm_and_summarize() {
  echo
  echo -e "${C_BOLD}ssdshield is about to apply the following changes:${C_RST}"
  echo "  Mode:            $MODE"
  echo "  Disk swap:       off + purged"
  echo "  zram swap:       algorithm=${ZRAM_ALGO}${ZRAM_LEVEL:+ level=$ZRAM_LEVEL}, size=${ZRAM_PERCENT}% of RAM"
  echo "  /tmp, /var/tmp:  moved to RAM (tmpfs)"
  if [[ "$DISABLE_LOGS" == "yes" ]]; then
    echo "  /var/log:        null (disabled)"
  else
    echo "  /var/log:        moved to RAM (5MB + auto-clean)"
  fi
  [[ "$PKG_MANAGER" == "apt" ]] && echo "  APT cache:       moved to RAM with auto-clean after installs"
  echo "  atime/diratime:       disabled on real filesystems"
  echo "  Hibernation (disk):   disabled"
  echo "  Browsers disk cache:  moved to RAM"
  echo "  Extras:               weekly TRIM enabled + periodic RAM cleanup job"
  echo "  NOTE: DO NOT WORRY! Everything backuped:"
  echo "  A backup of every changed config file will be saved to:"
  echo "    $BACKUP_DIR"
  echo "  if everything works fine, feel free to run to free up some space"
  echo "    sudo rm -rf $BACKUP_DIR $LOG_FILE"
  echo "========="
  echo
  local go
  go=$(ask_yes_no "Proceed with these changes now? [y/N]: " "no")
  if [[ "$go" != "yes" ]]; then
    warn "No changes were made. Exiting."
    exit 0
  fi
}

disable_swap() {
  info "Looking for active swap (files/partitions) to disable..."
  local found=0 name type

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    found=1
    name=$(awk '{print $1}' <<<"$line")
    type=$(awk '{print $2}' <<<"$line")
    info "Found swap: $name ($type)"

    run swapoff "$name" || warn "Could not turn off swap on $name (it may already be off)."

    backup_file /etc/fstab
    awk -v dev="$name" '
      BEGIN{OFS="\t"}
      $0 !~ /^#/ && $1==dev && $3=="swap" {print "#ssdshield-disabled# " $0; next}
      {print}
    ' /etc/fstab > /etc/fstab.ssdshield.tmp && mv /etc/fstab.ssdshield.tmp /etc/fstab

    if [[ "$type" == "file" ]]; then
      run rm -f "$name" || true
      note "Removed swap file $name"
      ok "Swap file $name removed."

    elif [[ "$type" == "partition" ]]; then
      local dtype=""
      dtype=$(lsblk -no TYPE "$name" 2>/dev/null | head -n1)

      if [[ "$dtype" == "lvm" ]] && command -v lvextend >/dev/null 2>&1; then
        warn "Swap partition $name is an LVM logical volume."
        local confirm
        confirm=$(ask_yes_no "Reclaim it and extend the root filesystem now? [y/N]: " "no")
        if [[ "$confirm" == "yes" ]]; then
          local root_dev root_fs ok_lvm=1
          root_dev=$(findmnt -rno SOURCE / 2>/dev/null)
          root_fs=$(findmnt -rno FSTYPE / 2>/dev/null)
          run lvremove -f "$name" || ok_lvm=0
          if [[ "$ok_lvm" -eq 1 ]]; then
            run lvextend -l +100%FREE "$root_dev" || ok_lvm=0
          fi
          if [[ "$ok_lvm" -eq 1 ]]; then
            case "$root_fs" in
              ext4|ext3|ext2) run resize2fs "$root_dev" ;;
              xfs)             run xfs_growfs / ;;
              btrfs)           run btrfs filesystem resize max / ;;
              *) warn "Unknown root filesystem ($root_fs); grow it manually with the matching tool." ;;
            esac
            note "Removed LVM swap $name and extended root ($root_dev) into the freed space"
            ok "Swap space reclaimed into the root filesystem."
          else
            warn "Automatic LVM reclaim failed; swap is off but the volume still exists. See $LOG_FILE."
          fi
        else
          info "Leaving the LVM volume in place (swap is now off; you can reclaim it manually later)."
        fi

      else
        run wipefs -a "$name" || warn "Could not erase the swap signature on $name."
        note "Swap partition $name disabled and its swap signature erased"
        warn "$name is a plain (non-LVM) partition: automatically repartitioning a live disk"
        warn "carries real risk of data loss, so ssdshield does not touch the partition table."
        warn "The partition is now unused - reclaim it later at your convenience with a tool"
        warn "such as GParted, parted, or growpart."
      fi
    fi
  done < <(swapon --show=NAME,TYPE --noheadings 2>/dev/null)

  if [[ "$found" -eq 0 ]]; then
    info "No active swap found."
  fi
  ok "Disk swap disabled."
}

setup_zram() {
  info "Setting up zram (compressed RAM swap): algorithm=${ZRAM_ALGO}${ZRAM_LEVEL:+ level=$ZRAM_LEVEL}, size=${ZRAM_PERCENT}% of RAM..."

  cat > /usr/local/sbin/ssdshield-zram-start.sh <<EOF
#!/bin/bash
set -euo pipefail
PERCENT=${ZRAM_PERCENT}
ALGO="${ZRAM_ALGO}"
LEVEL="${ZRAM_LEVEL}"

if swapon --show=NAME --noheadings 2>/dev/null | grep -qx "/dev/zram0"; then
  swapoff /dev/zram0 || true
fi

modprobe zram 2>/dev/null || true
if [[ ! -e /dev/zram0 ]]; then
  echo 1 > /sys/class/zram-control/hot_add 2>/dev/null || true
fi

echo 1 > /sys/block/zram0/reset 2>/dev/null || true

if [[ -n "\$LEVEL" ]]; then
  echo "\${ALGO} level=\${LEVEL}" > /sys/block/zram0/comp_algorithm 2>/dev/null \\
    || echo "\$ALGO" > /sys/block/zram0/comp_algorithm 2>/dev/null || true
else
  echo "\$ALGO" > /sys/block/zram0/comp_algorithm 2>/dev/null || true
fi

MEM_TOTAL_KB=\$(awk '/MemTotal/{print \$2}' /proc/meminfo)
SIZE_BYTES=\$(( MEM_TOTAL_KB * 1024 * PERCENT / 100 ))
echo "\$SIZE_BYTES" > /sys/block/zram0/disksize
mkswap /dev/zram0 >/dev/null
swapon -p 100 /dev/zram0
EOF
  chmod 755 /usr/local/sbin/ssdshield-zram-start.sh

  cat > /usr/local/sbin/ssdshield-zram-stop.sh <<'EOF'
#!/bin/bash
swapoff /dev/zram0 2>/dev/null || true
echo 1 > /sys/block/zram0/reset 2>/dev/null || true
EOF
  chmod 755 /usr/local/sbin/ssdshield-zram-stop.sh

  cat > /etc/systemd/system/ssdshield-zram.service <<'EOF'
[Unit]
Description=ssdshield zram swap device
DefaultDependencies=no
Before=swap.target
After=systemd-modules-load.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/ssdshield-zram-start.sh
ExecStop=/usr/local/sbin/ssdshield-zram-stop.sh

[Install]
WantedBy=swap.target multi-user.target
EOF

  run systemctl daemon-reload
  run systemctl enable --now ssdshield-zram.service

  note "zram configured: algo=${ZRAM_ALGO}${ZRAM_LEVEL:+ level=$ZRAM_LEVEL}, size=${ZRAM_PERCENT}% of RAM"
  ok "zram is active as swap."
}

setup_tmp_ram() {
  info "Mounting /tmp and /var/tmp in RAM..."
  local tmp_pct=20 vartmp_pct=10
  if [[ "$MODE" == "aggressive" ]]; then tmp_pct=30; vartmp_pct=15; fi

  backup_file /etc/fstab
  fstab_ensure_line "/tmp" "tmpfs /tmp tmpfs defaults,noatime,nosuid,nodev,mode=1777,size=${tmp_pct}% 0 0"
  fstab_ensure_line "/var/tmp" "tmpfs /var/tmp tmpfs defaults,noatime,nosuid,nodev,mode=1777,size=${vartmp_pct}% 0 0"

  if ! mountpoint -q /tmp; then
    run mount /tmp || warn "Could not mount /tmp in RAM right now; it will take effect after reboot."
  fi
  chmod 1777 /tmp 2>/dev/null || true

  if ! mountpoint -q /var/tmp; then
    run mount /var/tmp || warn "Could not mount /var/tmp in RAM right now; it will take effect after reboot."
  fi
  chmod 1777 /var/tmp 2>/dev/null || true

  note "/tmp (size=${tmp_pct}%) and /var/tmp (size=${vartmp_pct}%) mounted as tmpfs"
  ok "/tmp and /var/tmp now live in RAM."
}

setup_profile_sync() {
  info "Setting up profile-sync-daemon (keeps browser profiles out of disk writes)..."
  local pkg_ok="no"
  case "$PKG_MANAGER" in
    apt) run apt-get install -y profile-sync-daemon && pkg_ok="yes" ;;
    dnf) run dnf install -y profile-sync-daemon && pkg_ok="yes" ;;
    pacman) warn "profile-sync-daemon is only available via the AUR on Arch-based systems; skipping automatic install." ;;
    *) : ;;
  esac

  if [[ "$pkg_ok" != "yes" ]]; then
    warn "profile-sync-daemon could not be installed automatically; skipping this step."
    return 0
  fi

  local overlay="no"
  [[ "$MODE" == "aggressive" ]] && overlay="yes"

  if [[ -f /etc/psd.conf ]]; then
    backup_file /etc/psd.conf
    if grep -q '^USE_OVERLAYFS=' /etc/psd.conf; then
      sed -i -E "s/^USE_OVERLAYFS=.*/USE_OVERLAYFS=\"${overlay}\"/" /etc/psd.conf
    else
      echo "USE_OVERLAYFS=\"${overlay}\"" >> /etc/psd.conf
    fi
  fi

  local user home enabled=0
  while IFS=: read -r user home; do
    [[ -d "$home" ]] || continue
    if [[ -d "$home/.mozilla" || -d "$home/.config/chromium" || -d "$home/.config/google-chrome" || -d "$home/.librewolf" ]]; then
      run systemctl enable --now "psd@${user}.service" && enabled=$((enabled+1)) || warn "Could not enable psd for user $user"
      run systemctl enable --now "psd-resync@${user}.timer" || true
    fi
  done < <(detect_users)

  ok "profile-sync-daemon configured for ${enabled} user(s) (overlayfs mode: ${overlay})."
  note "profile-sync-daemon installed, overlayfs=${overlay}, enabled for ${enabled} user(s)"
}

find_profile_dirs() {
  local home="$1" base
  for base in "$home/.mozilla/firefox" "$home/.librewolf" "$home/.mullvad-browser" "$home/.tor-project/torbrowser"; do
    [[ -d "$base" ]] || continue
    find "$base" -maxdepth 3 -type f -name "prefs.js" 2>/dev/null | while read -r f; do dirname "$f"; done
  done
  find "$home" -maxdepth 6 -type d -iname "profile.default" 2>/dev/null
}

harden_browser_profile() {
  local dir="$1" marker="# --- added by ssdshield ---"
  [[ -d "$dir" ]] || return 0
  if [[ -f "$dir/user.js" ]] && grep -qF "$marker" "$dir/user.js" 2>/dev/null; then
    return 0
  fi
  {
    echo "$marker"
    cat <<'JS'
user_pref("browser.cache.disk.enable", false);
user_pref("browser.cache.disk.capacity", 0);
user_pref("browser.cache.disk.smart_size.enabled", false);
user_pref("browser.cache.offline.enable", false);
user_pref("media.cache_size", 0);
user_pref("browser.sessionstore.interval", 60000);
JS
    echo "# --- end ssdshield ---"
  } >> "$dir/user.js"
  local owner
  owner=$(stat -c '%U:%G' "$dir" 2>/dev/null || echo "")
  [[ -n "$owner" ]] && chown "$owner" "$dir/user.js" 2>/dev/null || true
}

harden_all_browsers() {
  info "Hardening browser profiles (disabling disk cache for Firefox/Tor/LibreWolf/Mullvad)..."
  local user home dir count=0
  while IFS=: read -r user home; do
    [[ -d "$home" ]] || continue
    while IFS= read -r dir; do
      [[ -z "$dir" ]] && continue
      harden_browser_profile "$dir"
      count=$((count+1))
    done < <(find_profile_dirs "$home" | sort -u)
  done < <(detect_users)

  if (( count > 0 )); then
    note "Disabled disk cache in $count browser profile(s)"
    ok "Hardened $count browser profile(s)."
  else
    info "No supported browser profiles found."
  fi
}

setup_var_log() {
  if [[ "$DISABLE_LOGS" == "yes" ]]; then
    info "Disabling system logging as requested..."
    backup_file /etc/systemd/journald.conf
    touch /etc/systemd/journald.conf
    if grep -q '^Storage=' /etc/systemd/journald.conf; then
      sed -i -E 's/^Storage=.*/Storage=none/' /etc/systemd/journald.conf
    else
      echo "Storage=none" >> /etc/systemd/journald.conf
    fi
    if grep -q '^ForwardToSyslog=' /etc/systemd/journald.conf; then
      sed -i -E 's/^ForwardToSyslog=.*/ForwardToSyslog=no/' /etc/systemd/journald.conf
    else
      echo "ForwardToSyslog=no" >> /etc/systemd/journald.conf
    fi
    run systemctl restart systemd-journald || true

    if systemctl list-unit-files 2>/dev/null | grep -q '^rsyslog.service'; then
      run systemctl disable --now rsyslog.service || true
    fi
    if systemctl list-unit-files 2>/dev/null | grep -q '^auditd.service'; then
      run systemctl disable --now auditd.service || true
    fi
    note "System logging disabled (journald Storage=none, rsyslog/auditd disabled)"
    ok "Logging disabled system-wide."
  else
    info "Moving /var/log to RAM (5MB, with automatic cleanup)..."
  fi

  backup_file /etc/fstab
  fstab_ensure_line "tmpfs\t/var/log\ttmpfs\tdefaults,noatime,nosuid,nodev,mode=0755,size=5M\t0\t0"

  local had_rsyslog=0
  if systemctl list-unit-files 2>/dev/null | grep -q '^rsyslog.service' && [[ "$DISABLE_LOGS" != "yes" ]]; then
    had_rsyslog=1
    run systemctl stop rsyslog.service || true
  fi
  run systemctl stop systemd-journald.service || true

  mkdir -p /var/log
  if ! mountpoint -q /var/log; then
    run mount /var/log || warn "Could not mount /var/log in RAM right now; it will take effect after reboot."
  fi
  mkdir -p /var/log/journal /var/log/apt
  chmod 2755 /var/log/journal 2>/dev/null || true

  run systemctl start systemd-journald.service || true
  if [[ "$had_rsyslog" -eq 1 ]]; then
    run systemctl start rsyslog.service || true
  fi

  if [[ "$DISABLE_LOGS" != "yes" ]]; then
    note "/var/log mounted as tmpfs (5M)"
    ok "/var/log now lives in RAM."
  fi
}

setup_apt_cache() {
  [[ "$PKG_MANAGER" == "apt" ]] || return 0
  info "Moving the APT package cache to RAM with auto-cleanup..."
  local size="512M"
  [[ "$MODE" == "aggressive" ]] && size="1024M"

  backup_file /etc/fstab
  mkdir -p /var/cache/apt/archives/partial
  fstab_ensure_line "tmpfs\t/var/cache/apt/archives\ttmpfs\tdefaults,noatime,mode=0755,size=${size}\t0\t0"

  if ! mountpoint -q /var/cache/apt/archives; then
    run mount /var/cache/apt/archives || warn "Could not mount the APT cache in RAM right now; it will take effect after reboot."
  fi
  mkdir -p /var/cache/apt/archives/partial

  cat > /etc/apt/apt.conf.d/99ssdshield-autoclean <<'EOF'
// Added by ssdshield: keep the RAM-backed package cache small
APT::Update::Post-Invoke {"/usr/bin/apt-get clean 2>/dev/null || true";};
DPkg::Post-Invoke {"/usr/bin/apt-get clean 2>/dev/null || true";};
EOF

  note "/var/cache/apt/archives mounted as tmpfs (${size}) with auto-clean hook"
  ok "APT cache now lives in RAM (auto-cleaned after every install)."
}

disable_atime() {
  info "Disabling atime/diratime on real filesystems..."
  backup_file /etc/fstab
  awk '
    BEGIN{OFS="\t"}
    /^[[:space:]]*#/ || NF<4 {print; next}
    $3=="swap" || $2=="none" {print; next}
    $4 !~ /noatime/ {$4=$4",noatime,nodiratime"}
    {print}
  ' /etc/fstab > /etc/fstab.ssdshield.tmp && mv /etc/fstab.ssdshield.tmp /etc/fstab

  while read -r mp; do
    case "$mp" in
      ""|/tmp|/var/tmp|/var/log|/var/cache/apt/archives) continue ;;
    esac
    run mount -o remount,noatime,nodiratime "$mp" || true
  done < <(findmnt -rno TARGET -t ext4,ext3,ext2,xfs,btrfs 2>/dev/null)

  note "noatime,nodiratime applied in /etc/fstab and remounted live"
  ok "atime/diratime disabled."
}

disable_hibernation() {
  info "Disabling hibernation..."
  run systemctl mask hibernate.target hybrid-sleep.target suspend-then-hibernate.target || true

  backup_file /etc/systemd/sleep.conf
  if mkdir -p /etc/systemd/sleep.conf.d 2>/dev/null; then
    cat > /etc/systemd/sleep.conf.d/ssdshield.conf <<'EOF'
[Sleep]
AllowHibernation=no
AllowHybridSleep=no
AllowSuspendThenHibernate=no
EOF
  fi

  if [[ -f /etc/systemd/logind.conf ]]; then
    backup_file /etc/systemd/logind.conf
    if grep -q '^HandleHibernateKey=' /etc/systemd/logind.conf; then
      sed -i -E 's/^HandleHibernateKey=.*/HandleHibernateKey=ignore/' /etc/systemd/logind.conf
    else
      echo "HandleHibernateKey=ignore" >> /etc/systemd/logind.conf
    fi
  fi

  if [[ -f /etc/default/grub ]] && command -v update-grub >/dev/null 2>&1; then
    backup_file /etc/default/grub
    sed -i -E 's/resume=[^ "]*//g' /etc/default/grub
    grep -q 'noresume' /etc/default/grub || sed -i -E 's/(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*)"/\1 noresume"/' /etc/default/grub
    run update-grub || warn "update-grub failed; hibernation is still disabled via systemd."
  elif [[ -f /etc/default/grub ]] && command -v grub2-mkconfig >/dev/null 2>&1; then
    backup_file /etc/default/grub
    sed -i -E 's/resume=[^ "]*//g' /etc/default/grub
    run grub2-mkconfig -o /boot/grub2/grub.cfg || warn "grub2-mkconfig failed; hibernation is still disabled via systemd."
  fi

  ok "Hibernation disabled "
}

setup_sysctl() {
  info "Tuning kernel memory/write-back parameters for $MODE mode..."
  local swappiness=100 cache_pressure=50 dirty_ratio=20 dirty_bg=10
  if [[ "$MODE" == "aggressive" ]]; then
    swappiness=150; cache_pressure=25; dirty_ratio=40; dirty_bg=20
  fi

  cat > /etc/sysctl.d/99-ssdshield.conf <<EOF
# Added by ssdshield - SSD wear reduction tuning ($MODE mode)
vm.swappiness=${swappiness}
vm.vfs_cache_pressure=${cache_pressure}
vm.dirty_ratio=${dirty_ratio}
vm.dirty_background_ratio=${dirty_bg}
EOF
  run sysctl --system || true

  if [[ "$MODE" == "aggressive" ]]; then
    local fstype
    fstype=$(findmnt -rno FSTYPE / 2>/dev/null || echo "")
    if [[ "$fstype" == "ext4" || "$fstype" == "ext3" || "$fstype" == "btrfs" ]]; then
      backup_file /etc/fstab
      awk '
        BEGIN{OFS="\t"}
        $2=="/" && $4 !~ /commit=/ {$4=$4",commit=60"}
        {print}
      ' /etc/fstab > /etc/fstab.ssdshield.tmp && mv /etc/fstab.ssdshield.tmp /etc/fstab
      run mount -o remount,commit=60 / || true
      note "Increased journal commit interval on / to 60s (aggressive mode)"
    fi
  fi

  note "sysctl: swappiness=${swappiness}, vfs_cache_pressure=${cache_pressure}, dirty_ratio=${dirty_ratio}, dirty_background_ratio=${dirty_bg}"
  ok "Kernel parameters tuned."
}

enable_fstrim() {
  info "Enabling weekly TRIM (fstrim.timer)..."
  if systemctl list-unit-files 2>/dev/null | grep -q '^fstrim.timer'; then
    run systemctl enable --now fstrim.timer || true
    note "fstrim.timer enabled (weekly TRIM)"
    ok "Weekly TRIM enabled."
  else
    warn "fstrim.timer is not available on this system; skipping."
  fi
}

setup_cleanup_timer() {
  info "Installing an automatic RAM cleanup job (keeps tmpfs logs/cache from filling up)..."
  cat > /usr/local/sbin/ssdshield-cleanup.sh <<'EOF'
#!/bin/bash
# ssdshield periodic cleanup: keeps RAM-backed logs and package cache small.
set -uo pipefail

command -v journalctl >/dev/null 2>&1 && journalctl --vacuum-size=3M >/dev/null 2>&1

if [[ -d /var/log ]]; then
  find /var/log -maxdepth 2 -type f -name "*.log" -size +1M -exec truncate -s 0 {} \; 2>/dev/null
fi

command -v apt-get >/dev/null 2>&1 && apt-get clean >/dev/null 2>&1

find /tmp -mindepth 1 -mtime +1 -delete 2>/dev/null
find /var/tmp -mindepth 1 -mtime +2 -delete 2>/dev/null

exit 0
EOF
  chmod 755 /usr/local/sbin/ssdshield-cleanup.sh

  cat > /etc/systemd/system/ssdshield-cleanup.service <<'EOF'
[Unit]
Description=ssdshield periodic RAM cleanup (logs & package cache)

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/ssdshield-cleanup.sh
EOF

  cat > /etc/systemd/system/ssdshield-cleanup.timer <<'EOF'
[Unit]
Description=Run ssdshield RAM cleanup periodically

[Timer]
OnBootSec=10min
OnUnitActiveSec=30min
Persistent=true

[Install]
WantedBy=timers.target
EOF

  run systemctl daemon-reload
  run systemctl enable --now ssdshield-cleanup.timer

  note "Cleanup timer installed: runs every 30 minutes"
  ok "Automatic RAM cleanup scheduled every 30 minutes."
}

final_report() {
  echo
  echo "============================================================"
  echo "Proudly created in Ukraine!"
  echo "============================================================"
  echo "If you can, please donate to Ukrainian defenders:"
  echo "https://war.ukraine.ua or https://savelife.in.ua"
  echo "============================================================"
  echo "Glory to Ukraine! Stop the war!"
  echo "============================================================"

  echo -e "${C_BOLD}=== ssdshield finished ===${C_RST}"
  echo "Applied changes:"
  local c
  for c in "${CHANGES_LOG[@]}"; do
    echo "  - $c"
  done
  echo
  echo "Config backups saved in: $BACKUP_DIR"
  echo "Full command log saved in: $LOG_FILE"
  echo
  warn "A reboot is recommended so every change (fstab mounts, grub) takes full effect."
  echo
}

self_destruct() {
  local path="${BASH_SOURCE[0]:-$0}"
  if [[ -f "$path" ]]; then
    rm -f -- "$path" 2>/dev/null && info "ssdshield.sh removed itself (to save up space)" || true
  fi
}

main() {
  print_banner
  check_root
  : > "$LOG_FILE" 2>/dev/null || true

  detect_pkg_manager
  ask_mode
  ask_zram_settings
  ask_log_preference
  confirm_and_summarize

  mkdir -p "$BACKUP_DIR"

  disable_swap
  setup_zram
  setup_tmp_ram
  setup_profile_sync
  harden_all_browsers
  setup_var_log
  setup_apt_cache
  disable_atime
  disable_hibernation
  setup_sysctl
  enable_fstrim
  setup_cleanup_timer

  final_report
  self_destruct
}

main "$@"
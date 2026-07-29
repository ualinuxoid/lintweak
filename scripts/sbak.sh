#!/usr/bin/env bash
#
# sbak.sh - Simple file backup/restore tool (7-Zip based, optional AES-256 encryption)
#
# WHAT IT DOES
#   1) Backup:  compress a directory into a .7z archive (optionally password
#      protected with AES-256), splitting it into ~1.8GB parts if the
#      resulting archive is larger than that (handy for e.g. Telegram).
#   2) Restore: decompress/decrypt a .7z archive (or its split parts) back
#      into a destination directory.
#
# HOW TO RUN IT
#   GUI mode (default, uses zenity dialogs):
#       ./sbak.sh
#
#   CLI / automation mode, e.g. for cron (-a = "auto"):
#       ./sbak.sh -a -m backup  -s /path/to/source_dir -d /path/to/dest_dir [-p PASSWORD]
#       ./sbak.sh -a -m restore -s /path/to/archive.7z  -d /path/to/dest_dir [-p PASSWORD]
#
# DEPENDENCIES
#   - p7zip (provides one of: 7z / 7za / 7zr)
#   - zenity (only required for the GUI mode, i.e. when -a is NOT used)
#   - standard coreutils: split, cat, stat, mktemp, date, find, sort
#
# LOG FILE
#   /tmp/sbak/log.txt
#
# !!!SEE LOG IF SOMETHING FAILED!!!
# Probably just missing dependency...
# ============================================================
# Proudly created in Ukraine!
# If you can, please donate to Ukrainian defenders:
# https://war.ukraine.ua or https://savelife.in.ua
# Glory to Ukraine! Stop the war!
# ============================================================


set -u


LOG_DIR="/tmp/sbak"
LOG_FILE="${LOG_DIR}/log.txt"

SPLIT_SIZE_MB=1800                                   # ~1.8 GB per volume (adapted for telegram, but can be edited)
SPLIT_SIZE_BYTES=$((SPLIT_SIZE_MB * 1024 * 1024))
SPLIT_MARKER=".part_"                                # marker used in split file names, changeable if you wanna

AUTO_MODE=0
MODE=""
SRC=""
DST=""
PASSWORD="${SBAK_PASSWORD:-}"
RESULT_MESSAGE=""
SEVENZIP=""

log() {
    mkdir -p "$LOG_DIR" 2>/dev/null
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$ts] $1" >> "$LOG_FILE" 2>/dev/null
}

die() {
    # Log the error and report it: via zenity dialog in GUI mode (if
    # available), otherwise to stderr. Then exit.
    log "ERROR: $1"
    if [[ $AUTO_MODE -eq 0 ]] && command -v zenity >/dev/null 2>&1; then
        zenity --error --title="sbak - Error" --text="$1" 2>/dev/null
    else
        echo "ERROR: $1" >&2
    fi
    exit 1
}


find_7zip() {
    local bin
    for bin in 7z 7za 7zr; do
        if command -v "$bin" >/dev/null 2>&1; then
            SEVENZIP="$bin"
            return 0
        fi
    done
    return 1
}

check_dependencies() {
    if ! find_7zip; then
        die "7-Zip is not installed (need 7z, 7za or 7zr in PATH, e.g. package 'p7zip-full'/'p7zip'). This script does not install packages automatically - please install it manually and re-run."
    fi

    if [[ $AUTO_MODE -eq 0 ]] && ! command -v zenity >/dev/null 2>&1; then
        die "zenity is not installed and no CLI arguments (-a) were given, so the GUI cannot be shown. Install 'zenity' or run this script in CLI mode with -a (see -h)."
    fi
}

usage() {
    cat <<EOF
sbak.sh - simple backup/restore tool (7z, optional AES-256 encryption)

Usage:
  $(basename "$0")                        Launch interactive GUI mode (zenity)
  $(basename "$0") -a -m backup  -s SRC -d DST [-p PASSWORD]
  $(basename "$0") -a -m restore -s SRC -d DST [-p PASSWORD]

Options:
  -a            Auto/CLI mode: no zenity dialogs, everything comes from the
                command line. Intended for scripting/cron.
  -m MODE       backup | restore     (required together with -a)
  -s SRC        Source path.
                  backup:  directory to archive
                  restore: the .7z archive file, or any one of its
                           "<name>.7z${SPLIT_MARKER}NNN" parts - the rest of
                           the parts are found automatically next to it
  -d DST        Destination directory.
                  backup:  where the resulting archive (or its parts) is written
                  restore: where the archive contents are extracted
  -p PASSWORD   Password to encrypt (backup) / decrypt (restore) the archive.
                If omitted, the SBAK_PASSWORD environment variable is used
                when set; otherwise no password is applied.
  -h            Show this help and exit.

Notes:
  - Archives larger than ${SPLIT_SIZE_MB}MB (~1.8GB) are automatically split into
    several "${SPLIT_MARKER}NNN" part files during backup, e.g. to fit
    services like Telegram. Restore reassembles them automatically.
  - Passing the password on the command line (-p) can be visible to other
    local users via the process list; prefer the SBAK_PASSWORD environment
    variable for slightly better privacy when scripting.
  - Log file: $LOG_FILE

EOF
}


do_backup() {
    local src="$1" dst="$2" pass="$3"

    [[ -d "$src" ]] || die "Source directory does not exist or is not a directory: $src"
    mkdir -p "$dst" 2>/dev/null
    [[ -d "$dst" ]] || die "Cannot create/access destination directory: $dst"

    local base ts archive
    base="$(basename "$src")"
    ts="$(date '+%Y%m%d_%H%M%S')"
    archive="${dst%/}/${base}_${ts}.7z"

    log "Backup started: src='$src' -> archive='$archive' (encrypted: $([[ -n "$pass" ]] && echo yes || echo no))"

    local rc
    if [[ -n "$pass" ]]; then
        "$SEVENZIP" a -mhe=on -p"$pass" "$archive" "$src" >>"$LOG_FILE" 2>&1
        rc=$?
    else
        "$SEVENZIP" a "$archive" "$src" >>"$LOG_FILE" 2>&1
        rc=$?
    fi

    if [[ $rc -ne 0 || ! -f "$archive" ]]; then
        die "7-Zip failed to create the archive (exit code $rc). See $LOG_FILE for details."
    fi

    local size
    size=$(stat -c%s "$archive" 2>/dev/null || stat -f%z "$archive" 2>/dev/null)

    if [[ -n "$size" && "$size" -gt "$SPLIT_SIZE_BYTES" ]]; then
        log "Archive size ${size} bytes exceeds ${SPLIT_SIZE_BYTES} bytes, splitting into ${SPLIT_SIZE_MB}MB parts..."
        if ! split -b "${SPLIT_SIZE_MB}M" -d -a 3 "$archive" "${archive}${SPLIT_MARKER}" 2>>"$LOG_FILE"; then
            die "Failed to split the archive into parts. See $LOG_FILE for details."
        fi
        rm -f "$archive"
        log "Backup finished successfully. Parts created with prefix: ${archive}${SPLIT_MARKER}NNN"
        RESULT_MESSAGE="Backup completed successfully.

The archive was larger than ${SPLIT_SIZE_MB}MB and was split into parts:
$(basename "$archive")${SPLIT_MARKER}000, ${SPLIT_MARKER}001, ...
in: $dst

Keep all parts together in the same folder - restore only needs one of them, the rest is found automatically."
    else
        log "Backup finished successfully: $archive (${size:-unknown} bytes)"
        RESULT_MESSAGE="Backup completed successfully.

Archive: $archive"
    fi

    if [[ -n "$pass" ]]; then
        RESULT_MESSAGE="${RESULT_MESSAGE}

IMPORTANT: save this password somewhere safe. It is not stored anywhere by this script and the archive CANNOT be recovered without it."
    fi
}

do_restore() {
    local src="$1" dst="$2" pass="$3"

    [[ -e "$src" ]] || die "Source archive/part does not exist: $src"
    mkdir -p "$dst" 2>/dev/null
    [[ -d "$dst" ]] || die "Cannot create/access destination directory: $dst"

    local archive_to_open tmp_combined=""

    if [[ "$src" == *"${SPLIT_MARKER}"* ]]; then
        local dir prefix parts=()
        dir="$(dirname "$src")"
        prefix="$(basename "$src")"
        prefix="${prefix%%"${SPLIT_MARKER}"*}${SPLIT_MARKER}"

        log "Detected a split archive part. Looking for siblings with prefix '$prefix' in '$dir'"

        while IFS= read -r -d '' f; do
            parts+=("$f")
        done < <(find "$dir" -maxdepth 1 -type f -name "${prefix}*" -print0 | sort -z)

        [[ ${#parts[@]} -gt 0 ]] || die "No archive parts found matching prefix: $prefix"

        tmp_combined="$(mktemp "${LOG_DIR}/sbak_combined_XXXXXX.7z")" || die "Failed to create a temporary file for reassembling the archive."
        log "Reassembling ${#parts[@]} part(s) into temporary file: $tmp_combined"

        if ! cat "${parts[@]}" > "$tmp_combined" 2>>"$LOG_FILE"; then
            rm -f "$tmp_combined"
            die "Failed to reassemble archive parts. See $LOG_FILE for details."
        fi
        archive_to_open="$tmp_combined"
    else
        archive_to_open="$src"
    fi

    log "Restore started: archive='$archive_to_open' -> dst='$dst'"

    local rc
    if [[ -n "$pass" ]]; then
        "$SEVENZIP" x -p"$pass" -o"$dst" -y "$archive_to_open" >>"$LOG_FILE" 2>&1
        rc=$?
    else
        "$SEVENZIP" x -o"$dst" -y "$archive_to_open" >>"$LOG_FILE" 2>&1
        rc=$?
    fi

    [[ -n "$tmp_combined" ]] && rm -f "$tmp_combined"

    if [[ $rc -ne 0 ]]; then
        die "7-Zip failed to extract the archive (exit code $rc). Wrong password, or a corrupted/incomplete archive? See $LOG_FILE for details."
    fi

    log "Restore finished successfully into: $dst"
    RESULT_MESSAGE="Restore completed successfully.

Files extracted to: $dst"
}


gui_main() {
    local action
    action=$(zenity --list --title="sbak - Backup Tool" \
        --text="What do you want to do?" \
        --radiolist --column="Pick" --column="Action" \
        TRUE "backup" FALSE "restore" \
        --height=220 --width=380 2>/dev/null)

    [[ -z "$action" ]] && exit 0   # user cancelled

    if [[ "$action" == "backup" ]]; then
        local src dst pass="" pass2=""

        src=$(zenity --file-selection --directory --title="Select the directory to back up" 2>/dev/null)
        [[ -z "$src" ]] && exit 0

        dst=$(zenity --file-selection --directory --title="Select the destination directory for the archive" 2>/dev/null)
        [[ -z "$dst" ]] && exit 0

        if zenity --question --title="Encryption" \
            --text="Do you want to encrypt the archive with a password (AES-256)?" 2>/dev/null; then
            pass=$(zenity --password --title="Enter archive password" 2>/dev/null)
            [[ -z "$pass" ]] && die "Empty password entered, aborting."
            pass2=$(zenity --password --title="Confirm archive password" 2>/dev/null)
            [[ "$pass" == "$pass2" ]] || die "Passwords do not match, aborting."
            zenity --warning --title="Important" \
                --text="Please save this password somewhere safe.\nIt is NOT stored anywhere by this script and the archive CANNOT be recovered if you lose it." 2>/dev/null
        fi

        do_backup "$src" "$dst" "$pass"
        zenity --info --title="Backup finished" --text="$RESULT_MESSAGE" 2>/dev/null

    elif [[ "$action" == "restore" ]]; then
        local src dst pass=""

        src=$(zenity --file-selection --title="Select the archive (.7z), or any of its .part_ files" 2>/dev/null)
        [[ -z "$src" ]] && exit 0

        dst=$(zenity --file-selection --directory --title="Select the destination directory for extracted files" 2>/dev/null)
        [[ -z "$dst" ]] && exit 0

        if zenity --question --title="Encryption" \
            --text="Is this archive password-protected?" 2>/dev/null; then
            pass=$(zenity --password --title="Enter archive password" 2>/dev/null)
        fi

        do_restore "$src" "$dst" "$pass"
        zenity --info --title="Restore finished" --text="$RESULT_MESSAGE" 2>/dev/null
    fi
}


cli_main() {
    [[ -n "$MODE" ]] || die "-m (backup|restore) is required in auto mode (-a). See -h."
    [[ -n "$SRC"  ]] || die "-s SOURCE is required. See -h."
    [[ -n "$DST"  ]] || die "-d DESTINATION is required. See -h."

    case "$MODE" in
        backup)
            do_backup "$SRC" "$DST" "$PASSWORD"
            echo "$RESULT_MESSAGE"
            ;;
        restore)
            do_restore "$SRC" "$DST" "$PASSWORD"
            echo "$RESULT_MESSAGE"
            ;;
        *)
            die "Unknown mode '$MODE' (expected 'backup' or 'restore'). See -h."
            ;;
    esac
}


while getopts ":am:s:d:p:h" opt; do
    case "$opt" in
        a) AUTO_MODE=1 ;;
        m) MODE="$OPTARG" ;;
        s) SRC="$OPTARG" ;;
        d) DST="$OPTARG" ;;
        p) PASSWORD="$OPTARG" ;;
        h) usage; exit 0 ;;
        \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 1 ;;
        :) echo "Option -$OPTARG requires an argument." >&2; usage; exit 1 ;;
    esac
done

check_dependencies

if [[ $AUTO_MODE -eq 1 ]]; then
    cli_main
else
    gui_main
fi
#!/usr/bin/env bash
#
# ==============================================================================
#  rbak.sh
# ------------------------------------------------------------------------------
#  Graphical wrapper around rsync. Handles only NEW or CHANGED files from a SOURCE folder
#  into a DESTINATION folder. 
#
#  Requirements: bash, zenity, rsync
#  Usage:        chmod +x rbak.sh
#                bash rbak.sh
#
#  Log files are saved to:  /tmp/rbak/logs/
# ==============================================================================
# Proudly created in Ukraine!
# If you can, please donate to Ukrainian defenders:
# https://war.ukraine.ua or https://savelife.in.ua
# Glory to Ukraine! Stop the war!

if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi

set -o pipefail

SCRIPT_NAME="RBak"
LOG_DIR="/tmp/rbak/logs"
LOG_FILE="${LOG_DIR}/sync_$(date +%Y-%m-%d_%H-%M-%S).log"
ZENITY_WIDTH=560

missing=()
command -v zenity >/dev/null 2>&1 || missing+=("zenity")
command -v rsync  >/dev/null 2>&1 || missing+=("rsync")

if [ "${#missing[@]}" -ne 0 ]; then
    msg="The following required program(s) are missing:\n\n"
    for p in "${missing[@]}"; do msg+="  - ${p}\n"; done
    msg+="\nPlease install them with your distribution's package manager, e.g.:\n"
    msg+="  sudo apt install ${missing[*]}     (Debian / Ubuntu / Mint)\n"
    msg+="  sudo dnf install ${missing[*]}     (Fedora)\n"
    msg+="  sudo pacman -S ${missing[*]}       (Arch / Manjaro)\n"
    echo -e "ERROR: ${msg}" >&2
    if command -v zenity >/dev/null 2>&1; then
        zenity --error --title="${SCRIPT_NAME}" --width="${ZENITY_WIDTH}" --text="${msg}"
    fi
    exit 1
fi

mkdir -p "${LOG_DIR}" 2>/dev/null
if [ ! -d "${LOG_DIR}" ]; then
    LOG_DIR="/tmp/rbak/"
    mkdir -p "${LOG_DIR}"
    LOG_FILE="${LOG_DIR}/sync_$(date +%Y-%m-%d_%H-%M-%S).log"
fi

STATUS_FILE=""
trap 'rm -f "${STATUS_FILE}" 2>/dev/null' EXIT

abort() {
    zenity --warning --title="${SCRIPT_NAME}" --width="${ZENITY_WIDTH}" \
        --text="Operation cancelled.\n\nNo files were copied."
    exit 1
}

zenity --info --title="${SCRIPT_NAME}" --width="${ZENITY_WIDTH}" \
    --text="This tool helps you perform backups.\n\n<b>Only new or changed files are copied.</b> \n\nThe <i>contents</i> of the source folder will be placed inside the destination folder.\n\nYou will now select the SOURCE folder, then the DESTINATION folder." \
    || abort

SOURCE_DIR=$(zenity --file-selection --directory \
    --title="Select the SOURCE folder (copy FROM)") || abort

if [ -z "${SOURCE_DIR}" ] || [ ! -d "${SOURCE_DIR}" ]; then
    zenity --error --title="${SCRIPT_NAME}" --width="${ZENITY_WIDTH}" \
        --text="The selected source folder is not valid."
    exit 1
fi

DEST_DIR=$(zenity --file-selection --directory \
    --title="Select the DESTINATION folder (copy TO)") || abort

if [ -z "${DEST_DIR}" ] || [ ! -d "${DEST_DIR}" ]; then
    zenity --error --title="${SCRIPT_NAME}" --width="${ZENITY_WIDTH}" \
        --text="The selected destination folder is not valid."
    exit 1
fi

SOURCE_DIR="${SOURCE_DIR%/}/"
DEST_DIR="${DEST_DIR%/}"

REAL_SOURCE="$(readlink -f "${SOURCE_DIR}")"
REAL_DEST="$(readlink -f "${DEST_DIR}")"

if [ "${REAL_SOURCE}" = "${REAL_DEST}" ]; then
    zenity --error --title="${SCRIPT_NAME}" --width="${ZENITY_WIDTH}" \
        --text="Source and destination folders are the same.\nPlease choose two different folders."
    exit 1
fi

case "${REAL_DEST}/" in
    "${REAL_SOURCE}"/*)
        zenity --error --title="${SCRIPT_NAME}" --width="${ZENITY_WIDTH}" \
            --text="The destination folder is located inside the source folder.\nPlease choose a destination outside of the source folder."
        exit 1
        ;;
esac

if [ ! -w "${DEST_DIR}" ]; then
    zenity --error --title="${SCRIPT_NAME}" --width="${ZENITY_WIDTH}" \
        --text="You don't have write permission for the destination folder:\n${DEST_DIR}"
    exit 1
fi

zenity --question --title="${SCRIPT_NAME}" --width="${ZENITY_WIDTH}" \
    --text="Would you like to do a TEST RUN first?\n\nA test run shows what WOULD be copied, without changing any files. Recommended if you're not sure yet." \
    --ok-label="Yes, test first" --cancel-label="No, copy now"
if [ $? -eq 0 ]; then
    DRY_RUN=1
else
    DRY_RUN=0
fi

if [ "${DRY_RUN}" -eq 1 ]; then
    MODE_TEXT="TEST RUN (no files will be changed)"
else
    MODE_TEXT="REAL COPY"
fi

zenity --question --title="${SCRIPT_NAME}" --width="${ZENITY_WIDTH}" \
    --text="<b>Please confirm:</b>\n\nMode:        <b>${MODE_TEXT}</b>\nFrom:        ${SOURCE_DIR}\nTo:          ${DEST_DIR}/\n\nOnly new or more recently changed files will be copied.\nExisting files in the destination will never be deleted or overwritten by older data.\n\nProceed?" \
    --ok-label="Proceed" --cancel-label="Cancel" || abort

RSYNC_VER=$(rsync --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
SUPPORTS_PROGRESS2=false
if [ -n "${RSYNC_VER}" ]; then
    OLDEST=$(printf '%s\n%s\n' "3.1.0" "${RSYNC_VER}" | sort -V | head -n1)
    [ "${OLDEST}" = "3.1.0" ] && SUPPORTS_PROGRESS2=true
fi


RSYNC_OPTS=(
    -a              # recursive, preserves permissions/times/symlinks/owner
    -u              # no overwrite a file that is newer in the destination
    -h              # human-readable log
    --stats         # files transferred, size, etc
)

if [ "${SUPPORTS_PROGRESS2}" = true ]; then
    RSYNC_OPTS+=(--info=progress2)
else
    RSYNC_OPTS+=(--progress)
fi

[ "${DRY_RUN}" -eq 1 ] && RSYNC_OPTS+=(--dry-run)

{
    echo "=== Sync started: $(date) ==="
    echo "Source:      ${SOURCE_DIR}"
    echo "Destination: ${DEST_DIR}"
    echo "Mode:        ${MODE_TEXT}"
    echo "rsync version detected: ${RSYNC_VER:-unknown}"
    echo "Command: rsync ${RSYNC_OPTS[*]} \"${SOURCE_DIR}\" \"${DEST_DIR}\""
    echo "============================================================"
    echo "RBak util - proudly created in Ukraine!"
    echo "============================================================"
    echo "If you can, please donate to Ukrainian defenders:"
    echo "https://war.ukraine.ua or https://savelife.in.ua"
    echo "============================================================"
    echo "Glory to Ukraine! Stop the war!"
    echo "============================================================"

    echo
} >> "${LOG_FILE}"

STATUS_FILE=$(mktemp)

if [ "${SUPPORTS_PROGRESS2}" = true ]; then
    ZENITY_PROGRESS_FLAGS=(--percentage=0)
else
    ZENITY_PROGRESS_FLAGS=(--pulsate)
fi

(
    rsync "${RSYNC_OPTS[@]}" "${SOURCE_DIR}" "${DEST_DIR}" 2>>"${LOG_FILE}" |
    while IFS= read -r line; do
        printf '%s\n' "${line}" >> "${LOG_FILE}"
        pct="$(printf '%s\n' "${line}" | grep -oE '[0-9]{1,3}%' | tr -d '%' | tail -n1)"
        if [ -n "${pct}" ]; then
            [ "${SUPPORTS_PROGRESS2}" = true ] && printf '%s\n' "${pct}"
            printf '# Copying files... %s%%\n' "${pct}"
        fi
    done
    printf '%s' "${PIPESTATUS[0]}" > "${STATUS_FILE}"
) | zenity --progress \
      --title="${SCRIPT_NAME}" \
      --text="Preparing to copy..." \
      --auto-close \
      --width="${ZENITY_WIDTH}" \
      "${ZENITY_PROGRESS_FLAGS[@]}"

ZENITY_EXIT=$?
RSYNC_STATUS="$(cat "${STATUS_FILE}" 2>/dev/null)"
rm -f "${STATUS_FILE}"
STATUS_FILE=""

if [ "${ZENITY_EXIT}" -ne 0 ]; then
    echo "=== Sync CANCELLED by user: $(date) ===" >> "${LOG_FILE}"
    zenity --warning --title="${SCRIPT_NAME}" --width="${ZENITY_WIDTH}" \
        --text="The operation was cancelled.\n\nSome files may already have been copied before cancellation.\nLog saved to:\n${LOG_FILE}"
    exit 1
fi

if [ -z "${RSYNC_STATUS}" ] || [ "${RSYNC_STATUS}" != "0" ]; then
    echo "=== Sync FINISHED WITH ERRORS: $(date) (rsync exit code: ${RSYNC_STATUS:-unknown}) ===" >> "${LOG_FILE}"
    zenity --error --title="${SCRIPT_NAME}" --width="${ZENITY_WIDTH}" \
        --text="rsync finished with an error (exit code ${RSYNC_STATUS:-unknown}).\n\nCheck the log for details:\n${LOG_FILE}"
    exit "${RSYNC_STATUS:-1}"
fi

echo "=== Sync finished successfully: $(date) ===" >> "${LOG_FILE}"

FILES_TRANSFERRED=$(grep -m1 -i "Number of.*files transferred" "${LOG_FILE}" | grep -oE '[0-9,]+$')
TOTAL_SIZE=$(grep -m1 -i "Total transferred file size" "${LOG_FILE}" | grep -oE '[0-9.,]+ ?[A-Za-z]*bytes' | head -n1)

if [ "${DRY_RUN}" -eq 1 ]; then
    zenity --info --title="${SCRIPT_NAME}" --width="${ZENITY_WIDTH}" \
        --text="<b>Test run complete.</b>\n\nNo files were changed — this only shows what WOULD be copied.\n\nFiles that would be transferred: ${FILES_TRANSFERRED:-see log}\n\nFull log:\n${LOG_FILE}\n\nRun the script again and choose \"No, copy now\" to perform the real copy."
else
    zenity --info --title="${SCRIPT_NAME}" --width="${ZENITY_WIDTH}" \
        --text="<b>Sync complete!</b>\n\nFiles copied: ${FILES_TRANSFERRED:-0}\nData transferred: ${TOTAL_SIZE:-see log}\n\nFull log saved to:\n${LOG_FILE}"
fi

if zenity --question --title="${SCRIPT_NAME}" --width="${ZENITY_WIDTH}" \
    --text="Would you like to view the full log now?" \
    --ok-label="View log" --cancel-label="Close"; then
    zenity --text-info --title="Sync Log — ${LOG_FILE}" --width=800 --height=550 --filename="${LOG_FILE}"
fi

exit 0
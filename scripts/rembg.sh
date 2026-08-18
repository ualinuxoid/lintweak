#!/usr/bin/env bash
# rembg.sh

set -uo pipefail

SCRIPT_PATH="$(readlink -f "$0")"
LOG_FILE="$(mktemp /tmp/remove-bg-install.XXXXXX.log)"

APP_BIN_DIR="$HOME/.local/bin"
ACTION_DIR="$HOME/.local/share/nemo/actions"
WRAPPER_SCRIPT="$APP_BIN_DIR/remove-bg-action.sh"
ACTION_FILE="$ACTION_DIR/remove-background.nemo_action"

step() {
    echo ">> $1"
}

fail() {
    echo ""
    echo "[ERROR] $1"
    echo "A detailed log was saved to: $LOG_FILE"
    echo "Please show this file to support, or run the installer again."
    exit 1
}

run_quiet() {
    if ! "$@" >>"$LOG_FILE" 2>&1; then
        return 1
    fi
    return 0
}

echo "============================================================"
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

step "Starting setup. This will take a couple of minutes, please wait..."

if ! command -v apt-get >/dev/null 2>&1; then
    fail "This installer only supports Debian/Ubuntu-based systems (like Linux Mint)."
fi

if ! command -v nemo >/dev/null 2>&1; then
    fail "The Nemo file manager was not found on this system."
fi

if ! run_quiet sudo -v; then
    fail "sudo access required"
fi

step "Installing required system packages..."

if ! run_quiet sudo apt-get update -qq; then
    fail "Could not update the package list. Check your internet connection."
fi

if ! run_quiet sudo apt-get install -y -qq \
        python3 python3-venv python3-pip pipx libnotify-bin; then
    fail "Could not install required system packages."
fi

mkdir -p "$APP_BIN_DIR" "$ACTION_DIR"

run_quiet python3 -m pipx ensurepath || true

step "Installing the background removal engine (this is the slow part)..."

REMBG_BIN="$APP_BIN_DIR/rembg"

if [[ -x "$REMBG_BIN" ]]; then
    step "Background removal engine is already installed, skipping."
else
    if ! run_quiet python3 -m pipx install rembg; then
        fail "Could not install the background removal engine."
    fi
fi

if [[ ! -x "$REMBG_BIN" ]]; then
    fail "Installation finished but the tool was not found where expected."
fi

step "Setting up the right-click menu action..."

cat > "$WRAPPER_SCRIPT" <<WRAPPER_EOF
#!/usr/bin/env bash
# Auto-generated wrapper. Removes the background from one or more images
# and saves the result next to the original file as "<name>_no_bg.png".

set -uo pipefail

REMBG_BIN="$REMBG_BIN"
ICON="image-x-generic"

notify() {
    notify-send -i "\$ICON" "Remove Background" "\$1"
}

if [[ \$# -eq 0 ]]; then
    exit 0
fi

for INPUT_FILE in "\$@"; do
    if [[ ! -f "\$INPUT_FILE" ]]; then
        continue
    fi

    DIR="\$(dirname "\$INPUT_FILE")"
    BASE="\$(basename "\$INPUT_FILE")"
    NAME="\${BASE%.*}"
    OUTPUT_FILE="\$DIR/\${NAME}_no_bg.png"

    notify "Processing \$BASE ..."

    if "\$REMBG_BIN" i "\$INPUT_FILE" "\$OUTPUT_FILE" >/dev/null 2>&1; then
        notify "Done: \${NAME}_no_bg.png"
    else
        notify "Failed to process \$BASE"
    fi
done
WRAPPER_EOF

chmod +x "$WRAPPER_SCRIPT"

cat > "$ACTION_FILE" <<ACTION_EOF
[Nemo Action]
Name=Remove Background
Comment=Remove the background from the selected image(s)
Exec=$WRAPPER_SCRIPT %F
Icon-Name=image-x-generic
Selection=Any
Extensions=png;jpg;jpeg;bmp;webp;
ACTION_EOF

run_quiet nemo -q || true

echo ""
echo "Setup complete!"
echo "Right-click any image (png, jpg, jpeg, bmp, webp) and choose"
echo "\"Remove Background\" from the menu."
echo ""

echo "============================================================"
echo "Proudly created in Ukraine!"
echo "============================================================"
echo "If you can, please donate to Ukrainian defenders:"
echo "https://war.ukraine.ua"
echo "https://savelife.in.ua"
echo "============================================================"
echo "Glory to Ukraine! Stop the war!"
echo "============================================================"


rm -f "$LOG_FILE"
rm -f "$SCRIPT_PATH"

exit 0
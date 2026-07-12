#!/bin/bash

echo "============================================"
echo "    Reed-Solomon Protector — Installer"
echo "============================================"
echo ""
echo "Target system: Debian-based distributions"
echo "(Ubuntu, Linux Mint, Zorin OS, Pop!_OS, etc.)"
echo ""

{
    apt-get update -qq >/dev/null 2>&1
    apt-get install -y -qq zenity python3 python3-venv >/dev/null 2>&1

    APP_DIR="/opt/reed-solomon-gui"
    mkdir -p "$APP_DIR"

    python3 -m venv "$APP_DIR/venv" >/dev/null 2>&1
    "$APP_DIR/venv/bin/pip" install --upgrade pip >/dev/null 2>&1
    "$APP_DIR/venv/bin/pip" install reedsolo >/dev/null 2>&1

    cat > "$APP_DIR/reed-solomon-core.py" << 'PYEOF'
#!/usr/bin/env python3
"""
Reed-Solomon Protector — Core Engine
"""

import sys
import struct
from reedsolo import RSCodec

MAGIC = b'REED'
VERSION = 1


def encode_file(input_path, output_path, strength):
    """Add Reed-Solomon parity to a file."""
    if strength == 'low':
        nsym = 32
    elif strength == 'medium':
        nsym = 64
    else:  # high
        nsym = 128

    with open(input_path, 'rb') as f:
        data = f.read()

    original_size = len(data)

    rsc = RSCodec(nsym=nsym)
    encoded = rsc.encode(data)

    with open(output_path, 'wb') as f:
        # Header: magic(4) + version(1) + nsym(1) + original_size(8) = 14 bytes
        header = struct.pack('<4sBBQ', MAGIC, VERSION, nsym, original_size)
        f.write(header)
        f.write(encoded)

    return True


def decode_file(input_path, output_path):
    """Recover original file from a .reed protected file."""
    with open(input_path, 'rb') as f:
        header = f.read(14)
        if len(header) < 14:
            raise ValueError("File is too small to be a valid .reed file")

        magic, version, nsym, original_size = struct.unpack('<4sBBQ', header)

        if magic != MAGIC:
            raise ValueError("Invalid file format (missing REED magic header)")

        encoded = f.read()

    rsc = RSCodec(nsym=nsym)
    decoded = rsc.decode(encoded)[0]

    decoded = decoded[:original_size]

    with open(output_path, 'wb') as f:
        f.write(decoded)

    return True


if __name__ == '__main__':
    if len(sys.argv) < 4:
        print("Usage: reed-solomon-core.py <encode|decode> <input> <output> [strength]", file=sys.stderr)
        sys.exit(1)

    mode = sys.argv[1]
    input_path = sys.argv[2]
    output_path = sys.argv[3]
    strength = sys.argv[4] if len(sys.argv) > 4 else 'medium'

    try:
        if mode == 'encode':
            encode_file(input_path, output_path, strength)
        else:
            decode_file(input_path, output_path)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
PYEOF
    chmod +x "$APP_DIR/reed-solomon-core.py"

    cat > "$APP_DIR/reed-solomon-gui" << 'BASHEOF'
#!/bin/bash

# Reed-Solomon Protector — GUI

VENV_PYTHON="/opt/reed-solomon-gui/venv/bin/python3"
CORE_SCRIPT="/opt/reed-solomon-gui/reed-solomon-core.py"

MODE=$(zenity --list \
    --title="Reed-Solomon Protector" \
    --text="What would you like to do?" \
    --column="Action" \
    "Protect File" \
    "Extract File" \
    --width=450 \
    --height=250 \
    --cancel-label="Exit")

if [ -z "$MODE" ]; then
    exit 0
fi

if [ "$MODE" == "Protect File (Add Reed-Solomon)" ]; then
    FILE=$(zenity --file-selection \
        --title="Select a file to protect" \
        --file-filter="All files | *")
else
    FILE=$(zenity --file-selection \
        --title="Select a .reed file to extract" \
        --file-filter="Reed-Solomon files | *.reed" \
        --file-filter="All files | *")
fi

if [ -z "$FILE" ]; then
    exit 0
fi

DIR=$(dirname "$FILE")
BASENAME=$(basename "$FILE")

if [ "$MODE" == "Protect File (Add Reed-Solomon)" ]; then

    STRENGTH=$(zenity --list \
        --title="Protection Strength" \
        --text="Select Reed-Solomon protection level:" \
        --column="Level" \
        --column="Description" \
        --column="Approx. Recovery" \
        "low"    "Basic protection"     "~7% error recovery" \
        "medium" "Standard protection"  "~14% error recovery" \
        "high"   "Maximum protection"   "~28% error recovery" \
        --width=520 \
        --height=300 \
        --cancel-label="Back")

    if [ -z "$STRENGTH" ]; then
        exit 0
    fi

    OUTPUT="$DIR/${BASENAME}.reed"

    # Overwrite check
    if [ -f "$OUTPUT" ]; then
        zenity --question \
            --title="File Exists" \
            --text="A protected version already exists:\n$OUTPUT\n\nOverwrite it?" \
            --ok-label="Overwrite" \
            --cancel-label="Cancel"
        if [ $? -ne 0 ]; then
            exit 0
        fi
    fi

    "$VENV_PYTHON" "$CORE_SCRIPT" \
        encode "$FILE" "$OUTPUT" "$STRENGTH" >/dev/null 2>&1 &
    PID=$!

    (
        while kill -0 $PID 2>/dev/null; do
            echo "50"
            sleep 0.5
        done
        echo "100"
    ) | zenity --progress \
        --title="Protecting File..." \
        --text="Please wait, adding Reed-Solomon parity data..." \
        --pulsate \
        --auto-close \
        --no-cancel

    wait $PID
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ] && [ -f "$OUTPUT" ]; then
        zenity --question \
            --title="Success!" \
            --text="File protected successfully!\n\nOriginal: $FILE\nProtected: $OUTPUT\n\nIMPORTANT WARNING:\nDo NOT archive, compress, or zip the .reed file! Archiving destroys the Reed-Solomon error-correction structure and makes the protection useless. Always keep the .reed file as-is.\n\nWould you like to open the containing folder?" \
            --ok-label="Open Folder" \
            --cancel-label="Close"

        if [ $? -eq 0 ]; then
            xdg-open "$DIR"
        fi
    else
        zenity --error \
            --title="Error" \
            --text="Failed to protect the file.\nPlease make sure the file is readable and you have enough free disk space."
    fi

else

    if [[ "$BASENAME" == *.reed ]]; then
        OUTPUT="$DIR/${BASENAME%.reed}"
    else
        OUTPUT="$DIR/extracted_$BASENAME"
    fi

    if [ -f "$OUTPUT" ]; then
        OUTPUT=$(zenity --file-selection \
            --save \
            --title="Save extracted file as..." \
            --filename="$OUTPUT")
        if [ -z "$OUTPUT" ]; then
            exit 0
        fi
    fi

    "$VENV_PYTHON" "$CORE_SCRIPT" \
        decode "$FILE" "$OUTPUT" >/dev/null 2>&1 &
    PID=$!

    (
        while kill -0 $PID 2>/dev/null; do
            echo "50"
            sleep 0.5
        done
        echo "100"
    ) | zenity --progress \
        --title="Extracting File..." \
        --text="Please wait, recovering original data..." \
        --pulsate \
        --auto-close \
        --no-cancel

    wait $PID
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ] && [ -f "$OUTPUT" ]; then
        zenity --question \
            --title="Success!" \
            --text="File extracted successfully!\n\nExtracted to: $OUTPUT\n\nWould you like to open the containing folder?" \
            --ok-label="Open Folder" \
            --cancel-label="Close"

        if [ $? -eq 0 ]; then
            xdg-open "$DIR"
        fi
    else
        zenity --error \
            --title="Error" \
            --text="Failed to extract the file.\nThe file may be corrupted, truncated, or not a valid Reed-Solomon protected file."
    fi
fi
BASHEOF
    chmod +x "$APP_DIR/reed-solomon-gui"

    ln -sf "$APP_DIR/reed-solomon-gui" /usr/local/bin/reed-solomon-gui

    cat > /usr/share/applications/reed-solomon-protector.desktop << 'DESKEOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Reed-Solomon Protector
Comment=Protect and recover files with Reed-Solomon error correction
Exec=/opt/reed-solomon-gui/reed-solomon-gui
Icon=document-save
Terminal=false
Categories=Utility;Archiving;System;
Keywords=backup;protection;error;correction;reed;solomon;
DESKEOF
    chmod +x /usr/share/applications/reed-solomon-protector.desktop

    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        if [ -d "$USER_HOME/Desktop" ]; then
            cp /usr/share/applications/reed-solomon-protector.desktop \
               "$USER_HOME/Desktop/"
            chown "$SUDO_USER":"$SUDO_USER" \
                  "$USER_HOME/Desktop/reed-solomon-protector.desktop"
            chmod +x "$USER_HOME/Desktop/reed-solomon-protector.desktop"
        fi
    else
        if [ -d "$HOME/Desktop" ]; then
            cp /usr/share/applications/reed-solomon-protector.desktop \
               "$HOME/Desktop/"
            chmod +x "$HOME/Desktop/reed-solomon-protector.desktop"
        fi
    fi

} >/dev/null 2>&1

echo "Installation complete!"
echo ""
echo "You can now launch the tool from:"
echo "  - Application Menu : 'Reed-Solomon Protector'"
echo "  - Desktop          : Desktop shortcut"
echo "  - Terminal         : run "reed-solomon-gui""
echo ""

SCRIPT_PATH="$(readlink -f "$0")"
rm -f "$SCRIPT_PATH"
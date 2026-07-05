#!/bin/bash

set -e

die() {
    echo "ERROR: $*" >&2
    exit 1
}

warn() {
    echo "WARNING: $*" >&2
}

echo "Checking required packages..."
MISSING=()
for pkg in zenity gpg tar gzip xz-utils zip; do
    if ! command -v "$pkg" &>/dev/null; then
        MISSING+=("$pkg")
    fi
done

if [ ${#MISSING[@]} -ne 0 ]; then
    echo "The following packages are missing: ${MISSING[*]}"
    echo "Script will try to fix that for ya... (requires sudo)"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo apt-get update
        sudo apt-get install -y "${MISSING[@]}" || die "ERR"
    else
        die "ERR"
    fi
fi

mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/share/nemo/actions"

echo "Creating core logic..."

HELPER="$HOME/.local/bin/nemo-encrypt"
cat > "$HELPER" << 'EOF'
#!/bin/bash
# CORE!!!

GPG_OPTS="--symmetric --cipher-algo AES256 --batch --no-symkey-cache"

error_dialog() {
    zenity --error --text="$1" --title="Encryption Error" 2>/dev/null
}

info_dialog() {
    zenity --info --text="$1" --title="Encryption Info" 2>/dev/null
}

action=$(zenity --list --radiolist --title="File Encryption" \
    --column="Pick" --column="Action" \
    TRUE "Encrypt" FALSE "Decrypt" \
    --width=300 --height=200 2>/dev/null)

case "$action" in
    "Encrypt")
        if zenity --question --text="Do you want to compress the file before encryption?" --title="Compress?" 2>/dev/null; then
            comp_format=$(zenity --list --radiolist --title="Compression format" \
                --column="Pick" --column="Format" \
                TRUE "tar.xz" FALSE "tar.gz" FALSE ".zip" \
                --width=300 --height=200 2>/dev/null)
            if [ -z "$comp_format" ]; then
                error_dialog "No compression format selected."
                exit 1
            fi
        else
            comp_format="none"
        fi

        password=$(zenity --password --title="Encryption Password" 2>/dev/null)
        if [ -z "$password" ]; then
            error_dialog "No password provided."
            exit 1
        fi

        for file in "$@"; do
            if [ ! -f "$file" ]; then
                warn "Skipping non‑regular file: $file"
                continue
            fi
            base="${file%.*}"
            dir=$(dirname "$file")
            name=$(basename "$file")

            tmp_work=""
            if [ "$comp_format" != "none" ]; then
                case "$comp_format" in
                    "tar.xz")
                        archive="$dir/$base.tar.xz"
                        tar -cJf "$archive" -C "$dir" "$name" || { error_dialog "FAIL"; continue; }
                        tmp_work="$archive"
                        ;;
                    "tar.gz")
                        archive="$dir/$base.tar.gz"
                        tar -czf "$archive" -C "$dir" "$name" || { error_dialog "FAIL"; continue; }
                        tmp_work="$archive"
                        ;;
                    ".zip")
                        archive="$dir/$base.zip"
                        zip -j "$archive" "$file" || { error_dialog "FAIL"; continue; }
                        tmp_work="$archive"
                        ;;
                esac
                encrypted_file="$archive.gpg"
            else
                tmp_work="$file"
                encrypted_file="$file.gpg"
            fi

            if echo "$password" | gpg $GPG_OPTS --passphrase-fd 0 -o "$encrypted_file" "$tmp_work"; then
                info_dialog "Encryption successful.\nOutput: $encrypted_file"
            else
                error_dialog " Failed: $file"
            fi

            if [ "$comp_format" != "none" ] && [ -f "$tmp_work" ]; then
                rm -f "$tmp_work"
            fi
        done
        ;;

    "Decrypt")
        password=$(zenity --password --title="Decryption Password" 2>/dev/null)
        if [ -z "$password" ]; then
            error_dialog "No password provided."
            exit 1
        fi

        for file in "$@"; do
            if [ ! -f "$file" ]; then
                warn "Skipping non‑regular file: $file"
                continue
            fi

            if [[ "$file" != *.gpg ]]; then
                error_dialog "Wrong file extension."
                continue
            fi
            output="${file%.gpg}"
            if echo "$password" | gpg --decrypt --batch --passphrase-fd 0 -o "$output" "$file"; then
                info_dialog "Decryption successful.\nOutput: $output"
            else
                error_dialog "FAIL"
            fi
        done
        ;;

    *)
        error_dialog "No action selected."
        exit 1
        ;;
esac
EOF

chmod +x "$HELPER"
echo "DONE!"

echo "Now script will create .nemo_action file..."
ACTION_FILE="$HOME/.local/share/nemo/actions/encrypt.nemo_action"
cat > "$ACTION_FILE" << 'EOF'
[Nemo Action]
Name=Encrypt/Decrypt
Comment=Bash GPG GUI (AES-256)
Exec=/home/username/.local/bin/nemo-encrypt %F
Icon-Name=security-high
Selection=Any
Extensions=any;
EOF

sed -i "s|/home/username/|$HOME/|g" "$ACTION_FILE"
echo "DONE!"

if pgrep -x "nemo" >/dev/null; then
    echo "Restarting Nemo to load the new action..."
    nemo -q 2>/dev/null || killall nemo 2>/dev/null || true
    sleep 1
    echo "DONE!"
else
    echo "You shoud reboot your PC"
fi

echo "DONE!"
rm -- "$0"
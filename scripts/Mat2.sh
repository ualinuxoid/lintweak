#!/bin/bash

set -e

die() {
    echo "ERR! $1"
    exit 1
}


if ! sudo -v; then
    die "You need sudo privileges to install packages."
fi

echo "Updating package lists..."
sudo apt-get update || die "apt-get update failed."

echo "Installing mat2, zenity, nemo..."
sudo apt-get install -y mat2 zenity nemo || die "Package installation failed."

mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/share/nemo/actions"

cat > "$HOME/.local/bin/mat2.sh" << 'EOF'
#!/bin/bash

for file in "$@"; do
    if [[ ! -f "$file" ]]; then
        continue
    fi

    ext="${file##*.}"
    [[ "$ext" == "$file" ]] && ext=""

    random=$(tr -dc 'a-z0-9' </dev/urandom | head -c $((RANDOM % 5 + 12)))
    new_name="$random${ext:+.$ext}"
    dir=$(dirname "$file")
    full_new="$dir/$new_name"

    if ! mv -- "$file" "$full_new"; then
        continue
    fi

    if mat2 --inplace -- "$full_new"; then
        zenity --info --text="Metadata successfully removed" --title="MAT2" --no-wrap
    else
        mv -- "$full_new" "$file"
        zenity --error --text="MAT2 failed to process file(s)" --title="MAT2"
    fi
done
EOF

chmod +x "$HOME/.local/bin/mat2.sh"

cat > "$HOME/.local/share/nemo/actions/mat2.nemo_action" << EOF
[Nemo Action]
Active=true
Name=Delete Metadata
Comment=Remove metadata from selected files
Icon-Name=view-conceal-symbolic

Exec=$HOME/.local/bin/mat2.sh %F

Selection=NotNone
Extensions=any;
Quote=double
Terminal=false
EOF

echo "Success!"

rm -- "$0"
#!/bin/bash

set -e  # exit on error

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Use: sudo $0"
    exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
DESKTOP_DIR=$(sudo -u "$REAL_USER" xdg-user-dir DESKTOP 2>/dev/null || echo "$REAL_HOME/Desktop")

echo "==> Updating package lists..."
apt update > /dev/null 2>&1 && echo "    Done." || { echo "    FAILED to update packages."; exit 1; }

echo "==> Installing requirements..."
apt install -y yt-dlp zenity ffmpeg > /dev/null 2>&1 && echo "    Packages installed." || { echo "    FAILED to install packages."; exit 1; }

GUI_SCRIPT="/usr/local/bin/yt-dlp-gui"
echo "==> Setting up main logic :)"

cat > "$GUI_SCRIPT" << 'EOF'
#!/bin/bash

URL=$(zenity --entry --title="yt-dlp GUI" --text="Enter the video URL:" --width=500)
[[ -z "$URL" ]] && exit 0

QUALITY=$(zenity --list --title="Select quality" --text="What do you want to download?" \
    --radiolist --column="" --column="Option" \
    TRUE "Best video + audio (default)" \
    FALSE "Audio only (best, mp3)" \
    --width=500 --height=250)

case "$QUALITY" in
    "Audio only (best, mp3)")
        FORMAT_OPT="-f bestaudio -x --audio-format mp3"
        ;;
    *)
        FORMAT_OPT="-f bestvideo+bestaudio/best"
        ;;
esac

DEFAULT_DIR="$HOME/Downloads"
OUTDIR=$(zenity --file-selection --directory --title="Select download folder" --filename="$DEFAULT_DIR/")
[[ -z "$OUTDIR" ]] && exit 0

zenity --question --title="Start download" --text="Download\n$URL\nto\n$OUTDIR\nwith option:\n$FORMAT_OPT\n\nProceed?" \
    --width=500 || exit 0

x-terminal-emulator -e bash -c \
    "yt-dlp $FORMAT_OPT -o '$OUTDIR/%(title)s.%(ext)s' '$URL'; echo; echo 'Download finished. Press Enter to close...'; read"
EOF

chmod +x "$GUI_SCRIPT"
echo "==> DONE!"

echo "==> Creating desktop shortcut..."
mkdir -p "$DESKTOP_DIR"
cat > "$DESKTOP_DIR/yt-dlp-gui.desktop" << EOF
[Desktop Entry]
Name=yt-dlp GUI
Comment=Download videos with yt-dlp
Exec=$GUI_SCRIPT
Icon=video-x-generic
Terminal=false
Type=Application
Categories=AudioVideo;
EOF

chown "$REAL_USER:$REAL_USER" "$DESKTOP_DIR/yt-dlp-gui.desktop" 2>/dev/null || true
chmod +x "$DESKTOP_DIR/yt-dlp-gui.desktop" 2>/dev/null || true
echo "==> DONE!"

echo "==> Creating menu entry..."
cat > /usr/share/applications/yt-dlp-gui.desktop << EOF
[Desktop Entry]
Name=yt-dlp GUI
Comment=Download videos with yt-dlp
Exec=$GUI_SCRIPT
Icon=video-x-generic
Terminal=false
Type=Application
Categories=AudioVideo;
EOF
echo "==> DONE!"

echo "=============================================="
echo "---- Installation complete! ----"
echo "If you like my utils, please consider donating Ukrainian defenders:"
echo "https://war.ukraine.ua"
echo "=============================================="

rm -- "$0"
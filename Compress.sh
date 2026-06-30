#!/bin/bash

set -e 

if ! command -v sudo &>/dev/null; then
    echo "Error: 'sudo' is required but not installed."
    exit 1
fi

HOME_DIR="$HOME"
BIN_DIR="$HOME_DIR/.local/bin"
ACTIONS_DIR="$HOME_DIR/.local/share/nemo/actions"

SCRIPT_NAME="shrink.sh"
ACTION_NAME="shrink.nemo_action"

mkdir -p "$BIN_DIR"
mkdir -p "$ACTIONS_DIR"

cat > "$BIN_DIR/$SCRIPT_NAME" << 'EOF'
#!/bin/bash

total=$#
success=0
failed=0
processed=0

notify-send "Shrink" "Compressing started. It may take a while..."

for file in "$@"; do
    [ ! -f "$file" ] && continue

    dir=$(dirname "$file")
    ext="${file##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    new_name=$(uuidgen | tr '[:upper:]' '[:lower:]')
    temp_file="${dir}/${new_name}.tmp.${ext}"
    final_file="${dir}/${new_name}.${ext}"

    processed=$((processed + 1))

    case "$ext" in
        jpg|jpeg)
            ffmpeg -i "$file" -map_metadata -1 -c:v mjpeg -q:v 2 -vf "format=yuvj420p" "$temp_file" -y -loglevel quiet
            ;;
        png)
            ffmpeg -i "$file" -map_metadata -1 -c:v png -compression_level 9 "$temp_file" -y -loglevel quiet
            ;;
        webp)
            ffmpeg -i "$file" -map_metadata -1 -c:v libwebp -quality 82 -compression_level 6 "$temp_file" -y -loglevel quiet
            ;;
        heic|avif)
            ffmpeg -i "$file" -map_metadata -1 -c:v libwebp -quality 85 "$temp_file" -y -loglevel quiet
            ;;
        mp4|mkv|mov|avi|webm)
            ffmpeg -i "$file" -map_metadata -1 \
                   -c:v libx264 -crf 23 -preset slower \
                   -c:a aac -b:a 192k \
                   "$temp_file" -y -loglevel quiet
            ;;
        mp3|flac|wav|m4a|ogg|aac)
            ffmpeg -i "$file" -map_metadata -1 -c:a libopus -b:a 128k "$temp_file" -y -loglevel quiet 2>/dev/null || \
            ffmpeg -i "$file" -map_metadata -1 -c:a copy "$temp_file" -y -loglevel quiet
            ;;
        *)
            failed=$((failed + 1))
            continue
            ;;
    esac

    if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
        mv "$temp_file" "$final_file"
        rm -f "$file"
        success=$((success + 1))
    else
        rm -f "$temp_file"
        failed=$((failed + 1))
    fi
done

if [ $success -eq $total ]; then
    notify-send "Shrink" "Compressed: $success out of $total"
else
    notify-send "Shrink" "Compressed: $success failed: $failed"
fi
EOF

chmod +x "$BIN_DIR/$SCRIPT_NAME"

cat > "$ACTIONS_DIR/$ACTION_NAME" << EOF
[Nemo Action]
Name=Compress media
Comment=Compress media
Icon-Name=image-x-generic
Exec=$BIN_DIR/$SCRIPT_NAME %F
Selection=notnone
Extensions=jpg;jpeg;png;webp;heic;avif;mp4;mkv;mov;avi;webm;mp3;flac;wav;m4a;ogg;aac;
Quote=double
Dependencies=ffmpeg;uuidgen;notify-send;
EOF

echo "Installing required packages (ffmpeg, uuid-runtime, libnotify-bin)..."

sudo apt-get update -qq
sudo apt-get install -y ffmpeg uuid-runtime libnotify-bin

for cmd in ffmpeg uuidgen notify-send; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Warning: $cmd was not found after installation. Please check manually."
    fi
done

echo "Installation completed successfully!"
echo "Shrink script installed to: $BIN_DIR/$SCRIPT_NAME"
echo "Nemo action installed to: $ACTIONS_DIR/$ACTION_NAME"
echo "You may need to restart PC for the action to appear."

rm -- "$0"
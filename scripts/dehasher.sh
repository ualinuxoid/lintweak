#!/bin/bash
# dehasher.sh - Create a visually identical copy of image/video that is completely different for any analyzer
# 
# Motivation: Simple anti-forensic tool to prevent tracking your photos/videos.
# Do not use for illict purposes, please :)
#
#
# Dependencies:
#
# On Debian/Ubuntu:
#   sudo apt update
#   sudo apt install -y imagemagick ffmpeg
#
# On Fedora/RHEL:
#   sudo dnf install -y ImageMagick ffmpeg
#
# On Arch:
#   sudo pacman -S imagemagick ffmpeg
#
#
# Use:
# chmod +x dehasher.sh
# ./dehasher.sh /path/to/photo.jpg
# ./dehasher.sh /path/to/video.mp4

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 /path/to/file"
    exit 1
fi

INPUT="$1"

if [[ ! -f "$INPUT" ]]; then
    echo "Error: File not found: $INPUT"
    exit 1
fi

DIR=$(dirname "$INPUT")
BASE=$(basename "$INPUT")
NAME="${BASE%.*}"
EXT="${BASE##*.}"
EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')
OUTPUT="${DIR}/${NAME}_dehashed.${EXT}"

SEED=$RANDOM$RANDOM
NOISE_LEVEL=$(awk -v s="$SEED" 'BEGIN{srand(s); printf "%.2f", 0.3 + rand()*0.4}')
BRIGHT=$(awk -v s="$SEED" 'BEGIN{srand(s+1); printf "%.3f", 0.995 + rand()*0.01}')
CONTRAST=$(awk -v s="$SEED" 'BEGIN{srand(s+2); printf "%.3f", 0.995 + rand()*0.01}')
MODULATE=$(awk -v s="$SEED" 'BEGIN{srand(s+3); printf "%d", 99 + int(rand()*3)}')

case "$EXT_LOWER" in
    jpg|jpeg|png|webp|bmp|tiff|tif)
        convert "$INPUT" \
            -evaluate Gaussian-noise "${NOISE_LEVEL}%" \
            -brightness-contrast "${BRIGHT}x${CONTRAST}" \
            -modulate "${MODULATE},100,100" \
            -resize 99.9% -resize 100.1% \
            -quality 95 \
            "$OUTPUT"
        ;;
    mp4|mkv|mov|avi|webm|m4v|flv)
        CRF=$((17 + SEED % 3))
        KEYINT=$((48 + SEED % 24))
        PRESET=$( [[ $((SEED % 2)) -eq 0 ]] && echo "medium" || echo "slow" )

        ffmpeg -y -i "$INPUT" \
            -vf "noise=alls=${NOISE_LEVEL}:allf=t+u" \
            -c:v libx264 -crf "$CRF" -preset "$PRESET" \
            -g "$KEYINT" -keyint_min $((KEYINT/2)) \
            -c:a aac -b:a 192k \
            -movflags +faststart \
            "$OUTPUT" 2>/dev/null
        ;;
    *)
        echo "Unsupported file type: .$EXT"
        echo "Supported: jpg jpeg png webp bmp tiff  |  mp4 mkv mov avi webm m4v flv"
        exit 1
        ;;
esac

echo "Done!"
echo "  → $OUTPUT"
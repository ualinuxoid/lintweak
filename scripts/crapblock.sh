#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
OUTPUT_FILE="$SCRIPT_DIR/crapblock.txt"
TMP_ZIP="$SCRIPT_DIR/top-1m.csv.zip"
TMP_CSV="$SCRIPT_DIR/top-1m.csv"
URL="http://s3-us-west-1.amazonaws.com/umbrella-static/top-1m.csv.zip"

for tool in curl unzip awk; do
    if ! command -v "$tool" &> /dev/null; then
        echo "Err.'$tool' not found."
        exit 1
    fi
done

echo "This script is EXPERIMENTAL."
echo "Do not worry, script will just create a crapblock.txt file"

sleep 2

echo "This script will create few temporary files."
echo "Please, do not edit anything in script folder untill end."
echo "Do not worry, script will clean them up..."

sleep 2

echo "[1/5] Fetching..."
if ! curl -# -L -o "$TMP_ZIP" "$URL"; then
    echo "Err. Fetch fail."
    exit 1
fi

echo "[2/5] Unpacking"
if ! unzip -q -o "$TMP_ZIP" top-1m.csv -d "$SCRIPT_DIR"; then
    echo "Err. unzip fail."
    rm -f "$TMP_ZIP"
    exit 1
fi

echo "[3/5] Parsing .ru and .su..."
awk -F',' '{
    domain = tolower($2)
    gsub(/"/, "", domain)
    gsub(/\r/, "", domain)
    gsub(/^[ \t]+|[ \t]+$/, "", domain)
    if (domain ~ /\.(ru|su)$/) {
        print "0.0.0.0 " domain
    }
}' "$TMP_CSV" > "$OUTPUT_FILE"

echo "[4/5] Final steps..."

echo "[5/5] Removing temporary files..."
rm -f "$TMP_ZIP" "$TMP_CSV"

TOTAL=$(wc -l < "$OUTPUT_FILE")

echo "DONE!"
echo "File: $OUTPUT_FILE"
echo "Total blocked: $TOTAL"
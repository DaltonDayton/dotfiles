#!/usr/bin/env bash
# OCR Screenshot Script for Hyprland
# Takes a screenshot, extracts text using tesseract, and copies to clipboard

set -e

TEMP_SCREENSHOT="/tmp/ocr-screenshot.png"
TEMP_OUTPUT="/tmp/ocr-result"

cleanup() {
    rm -f "$TEMP_SCREENSHOT" "${TEMP_OUTPUT}.txt"
}
trap cleanup EXIT

grimblast --freeze copysave area "$TEMP_SCREENSHOT"

if tesseract "$TEMP_SCREENSHOT" "$TEMP_OUTPUT" -l eng 2>/dev/null; then
    if [[ -f "${TEMP_OUTPUT}.txt" ]]; then
        wl-copy <"${TEMP_OUTPUT}.txt"
        notify-send "OCR" "Text extracted and copied to clipboard" -i "$TEMP_SCREENSHOT"
    else
        notify-send "OCR Error" "Failed to extract text" -u critical
        exit 1
    fi
else
    notify-send "OCR Error" "Tesseract failed to process image" -u critical
    exit 1
fi

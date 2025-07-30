#!/bin/bash

# 檢視 GDSII 檔案的腳本
# Script to view GDSII file

echo "================================"
echo "GDSII Viewer"
echo "================================"

# 找到最新的 run 目錄
LATEST_RUN=$(ls -td runs/run_* 2>/dev/null | head -1)

if [ -z "$LATEST_RUN" ]; then
    echo "Error: No run directory found!"
    exit 1
fi

GDS_FILE="$LATEST_RUN/results/final/gds/temp_ctrl_top.gds"

if [ ! -f "$GDS_FILE" ]; then
    echo "Error: GDSII file not found at $GDS_FILE"
    exit 1
fi

echo "Found GDSII: $GDS_FILE"
echo "File size: $(ls -lh "$GDS_FILE" | awk '{print $5}')"
echo ""

# 檢查 KLayout 是否已安裝
if command -v klayout &> /dev/null; then
    echo "Opening with KLayout..."
    klayout "$GDS_FILE" &
elif [ -f "/Applications/KLayout/klayout.app/Contents/MacOS/klayout" ]; then
    echo "Opening with KLayout (using full path)..."
    /Applications/KLayout/klayout.app/Contents/MacOS/klayout "$GDS_FILE" &
else
    echo "KLayout not found. Installing..."
    echo "Please run: brew install --cask klayout"
    echo ""
    echo "Alternative: Use Magic with Docker"
    echo "Run: ./view_with_magic.sh"
    exit 1
fi

echo "================================"
echo "Done!"
echo "================================"
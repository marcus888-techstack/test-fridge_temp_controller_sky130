#!/bin/bash

# 安裝並檢視 GDSII
# Install and view GDSII

echo "================================"
echo "GDSII Viewer Setup"
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

# Install KLayout if not present
if ! command -v klayout &> /dev/null; then
    echo "Installing KLayout..."
    brew install --cask klayout
    
    if [ $? -eq 0 ]; then
        echo "KLayout installed successfully!"
    else
        echo "Failed to install KLayout."
        echo ""
        echo "Alternative options:"
        echo "1. Download KLayout manually from: https://www.klayout.de/build.html"
        echo "2. Use online viewer: https://www.klayout.de/klayout-viewer/"
        echo "   - Upload file: $GDS_FILE"
        exit 1
    fi
fi

# Open with KLayout
echo "Opening GDSII with KLayout..."
klayout "$GDS_FILE" &

echo ""
echo "================================"
echo "KLayout Tips:"
echo "================================"
echo "• Use mouse wheel to zoom in/out"
echo "• Click layer names on right to show/hide layers"
echo "• Press 'F' to fit to window"
echo "• Different colors = different metal/poly layers"
echo "• Your chip size: 300 x 300 μm"
echo "================================"
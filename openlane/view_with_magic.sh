#!/bin/bash

# 使用 Magic 檢視 GDSII 檔案
# View GDSII file with Magic

echo "================================"
echo "Magic GDSII Viewer"
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
echo ""
echo "Note: You need XQuartz installed for GUI display on macOS"
echo "Install with: brew install --cask xquartz"
echo ""

# 啟動 XQuartz
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -d "/Applications/Utilities/XQuartz.app" ] || [ -d "/Applications/XQuartz.app" ]; then
        open -a XQuartz
        export DISPLAY=:0
        echo "Starting XQuartz..."
        sleep 2
    else
        echo "XQuartz not found. Please install it first."
        exit 1
    fi
fi

echo "Starting Magic..."
docker run --rm -it \
    -e DISPLAY=host.docker.internal:0 \
    -v $(pwd):/work \
    -w /work \
    efabless/openlane:latest \
    magic -T /root/.volare/volare/sky130/versions/bdc9412b3e468c102d01b7cf6337be06ec6e9c9a/sky130A/libs.tech/magic/sky130A.tech \
    "$GDS_FILE"

echo "================================"
echo "Done!"
echo "================================"
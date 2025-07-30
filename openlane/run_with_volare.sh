#!/bin/sh
# Run OpenLane with volare-installed PDK

echo "================================"
echo "OpenLane with volare PDK"
echo "================================"

# Check if volare PDK volume exists
if ! docker volume ls | grep -q openlane_pdk_volare; then
    echo "PDK not found. Please run ./install_volare.sh first"
    exit 1
fi

echo "Running OpenLane flow..."
echo "================================"

# Run with volare PDK
docker run --rm \
    -v $(pwd):/openlane/designs/temp_controller/openlane \
    -v $(pwd)/..:/openlane/designs/temp_controller \
    -v openlane_pdk_volare:/root/.volare \
    -e PDK=sky130A \
    -e STD_CELL_LIBRARY=sky130_fd_sc_hd \
    -e DESIGN_NAME=temp_ctrl_top \
    efabless/openlane:latest \
    flow.tcl -design /openlane/designs/temp_controller/openlane -tag run_$(date +%Y%m%d_%H%M%S)

echo "================================"
echo "Done!"
echo ""
echo "Check results in: runs/"
echo "================================"
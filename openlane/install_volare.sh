#!/bin/sh
# Install Sky130 PDK using volare (recommended)

echo "================================"
echo "Installing Sky130 PDK with volare"
echo "================================"

# Create volume
docker volume create openlane_pdk_volare

# Install correct version using volare
echo "Installing PDK version: bdc9412b3e468c102d01b7cf6337be06ec6e9c9a"
echo "This may take several minutes..."
docker run --rm \
    -v openlane_pdk_volare:/root/.volare \
    efabless/openlane:latest \
    sh -c "python3 -m volare enable --pdk sky130 bdc9412b3e468c102d01b7cf6337be06ec6e9c9a"

echo "================================"
echo "PDK installed successfully!"
echo "================================"
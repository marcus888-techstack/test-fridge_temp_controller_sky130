#!/bin/bash
# Simplified macOS Setup Script for Fridge Temperature Controller Project
# This script installs available tools via Homebrew

echo "=== Fridge Temperature Controller - macOS Setup ==="
echo

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Error: Homebrew is not installed."
    echo "Please install Homebrew first:"
    echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
fi

# Update Homebrew
echo "Updating Homebrew..."
brew update

# Install RTL development tools
echo
echo "Installing RTL development tools..."
brew install \
    icarus-verilog \
    yosys \
    verilator \
    ngspice \
    python@3.11 \
    git \
    wget \
    curl

# Install GTKWave
echo
echo "Installing GTKWave..."
echo "Note: For GTKWave, we recommend building from source to avoid Perl issues"
echo "Please follow instructions at: https://github.com/gtkwave/gtkwave"
echo "Or download pre-built binaries from their releases page"
# brew install --cask gtkwave  # Commented out due to Perl dependency issues

# Install KLayout
echo
echo "Installing KLayout..."
brew install --cask klayout

# Install Docker Desktop
echo
echo "Installing Docker Desktop..."
if ! command -v docker &> /dev/null; then
    brew install --cask docker
    echo "Please start Docker Desktop manually after installation."
else
    echo "Docker is already installed."
fi

# Create PDK directory
echo
echo "Setting up PDK directory..."
export PDK_ROOT=$HOME/pdk
mkdir -p $PDK_ROOT

# Clone Sky130 PDK
echo
echo "Cloning Sky130 PDK..."
cd $PDK_ROOT
if [ ! -d "skywater-pdk" ]; then
    git clone https://github.com/google/skywater-pdk.git
    cd skywater-pdk
    git checkout main
    git submodule update --init libraries/sky130_fd_sc_hd/latest
else
    echo "Sky130 PDK already cloned."
fi

# Clone OpenLane
echo
echo "Setting up OpenLane..."
cd ~/
if [ ! -d "OpenLane" ]; then
    git clone https://github.com/The-OpenROAD-Project/OpenLane.git
else
    echo "OpenLane already cloned."
fi

# Set up Python environment
echo
echo "Setting up Python environment..."
cd ~/fridge_temp_controller_sky130
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install numpy matplotlib pandas pyyaml click rich

# Create environment setup file
echo
echo "Creating environment setup file..."
cat > ~/fridge_temp_controller_sky130/env.sh << 'EOF'
#!/bin/bash
# Environment setup for Fridge Temperature Controller

# PDK paths
export PDK_ROOT=$HOME/pdk
export PDK=sky130A
# For skywater-pdk source installation:
export PDK_PATH=$PDK_ROOT/skywater-pdk

# OpenLane paths
export OPENLANE_ROOT=$HOME/OpenLane

# Project paths
export PROJECT_ROOT=$HOME/fridge_temp_controller_sky130

# Add tools to PATH
export PATH="/Applications/gtkwave.app/Contents/Resources/bin:$PATH"
export PATH="/Applications/klayout.app/Contents/MacOS:$PATH"

# Activate Python environment
if [ -f "$PROJECT_ROOT/venv/bin/activate" ]; then
    source $PROJECT_ROOT/venv/bin/activate
fi

echo "Environment ready for Fridge Temperature Controller project"
EOF

chmod +x ~/fridge_temp_controller_sky130/env.sh

# Verification
echo
echo "=== Installation Summary ==="
echo

# Check installations
check_tool() {
    if command -v $1 &> /dev/null || [ -f "$2" ]; then
        echo "✅ $3: Installed"
    else
        echo "❌ $3: Not found"
    fi
}

check_tool iverilog "" "Icarus Verilog"
check_tool yosys "" "Yosys"
check_tool verilator "" "Verilator"
check_tool ngspice "" "Ngspice"
check_tool docker "" "Docker"
check_tool gtkwave "" "GTKWave (check if built from source)"
check_tool "" "/Applications/klayout.app/Contents/MacOS/klayout" "KLayout"

echo
echo "=== Next Steps ==="
echo "1. Start Docker Desktop manually"
echo "2. Source the environment: source ~/fridge_temp_controller_sky130/env.sh"
echo "3. Pull OpenLane Docker image: cd ~/OpenLane && make pull-openlane"
echo "4. Run simulations: cd ~/fridge_temp_controller_sky130/testbench && make sim_top"
echo
echo "For physical design tools (Magic, Netgen, etc.), use the OpenLane Docker container:"
echo "docker run -it -v \$(pwd):/work efabless/openlane:latest bash"
echo
echo "Setup complete!"
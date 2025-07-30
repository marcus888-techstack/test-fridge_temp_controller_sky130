# Development Environment Setup Guide - macOS

This guide will walk you through setting up the complete development environment for the Fridge Temperature Controller IC project on macOS.

## 📋 System Requirements

### Minimum Requirements
- **OS**: macOS 11 Big Sur or later
- **RAM**: 8 GB minimum, 16 GB recommended
- **Storage**: 50 GB free space
- **CPU**: Intel or Apple Silicon (M1/M2/M3)
- **Xcode Command Line Tools**: Required

## 🛠️ Installation Steps

### Step 1: Install Homebrew and Xcode Tools

```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# For Apple Silicon Macs, add Homebrew to PATH
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
eval "$(/opt/homebrew/bin/brew shellenv)"

# Update Homebrew
brew update
brew upgrade
```

### Step 2: Install Basic Development Tools

```bash
# Install essential tools
brew install \
    git \
    wget \
    curl \
    python@3.11 \
    make \
    cmake \
    autoconf \
    automake \
    libtool \
    pkg-config \
    boost
```

### Step 3: Install RTL Simulation Tools

#### Icarus Verilog (RTL Simulator)
```bash
# Install Icarus Verilog
brew install icarus-verilog

# Verify installation
iverilog -V
```

#### GTKWave (Waveform Viewer)

**Option 1: Build from Source (Recommended)**
```bash
# Clone GTKWave repository
cd ~/
git clone https://github.com/gtkwave/gtkwave.git
cd gtkwave

# Install dependencies
brew install gtk+3 tcl-tk

# Build GTKWave
./autogen.sh
./configure --prefix=/usr/local --enable-gtk3
make
sudo make install

# Verify installation
gtkwave --version
```

**Option 2: Pre-built Application (May have issues)**
```bash
# Download pre-built app from:
# https://github.com/gtkwave/gtkwave/releases

# Or use Homebrew cask (may have Perl dependency issues)
brew install --cask gtkwave

# If using the app, create alias:
echo 'alias gtkwave="open -a gtkwave"' >> ~/.zshrc
source ~/.zshrc
```

### Step 4: Install Synthesis Tools

#### Yosys (Open Source Synthesis Tool)
```bash
# Install Yosys
brew install yosys

# Verify installation
yosys -V
```

### Step 5: Install Sky130 PDK

#### Create PDK Directory
```bash
# Set PDK environment variable
export PDK_ROOT=$HOME/pdk
echo 'export PDK_ROOT=$HOME/pdk' >> ~/.zshrc

# Create directory
mkdir -p $PDK_ROOT
cd $PDK_ROOT
```

#### Install Sky130 PDK
```bash
# Note: Some PDK tools need to be built from source on macOS
# For basic RTL simulation and synthesis, the following is sufficient:

# Clone the PDK
git clone https://github.com/google/skywater-pdk.git
cd skywater-pdk

# Checkout stable version
git checkout main
git submodule update --init libraries/sky130_fd_sc_hd/latest

# Note: Full PDK build requires additional steps on macOS
# For basic RTL work, the above is sufficient
```

#### Install Open_PDKs (Simplified for macOS)
```bash
cd $PDK_ROOT

# Clone open_pdks
git clone https://github.com/RTimothyEdwards/open_pdks.git
cd open_pdks

# Configure for macOS (basic install)
./configure --enable-sky130-pdk=$PDK_ROOT/skywater-pdk/libraries

# Note: Full installation may require additional configuration
```

### Step 6: Install Docker for OpenLane

#### Install Docker Desktop
```bash
# Download and install Docker Desktop for Mac
brew install --cask docker

# Start Docker Desktop
open -a Docker

# Wait for Docker to start, then verify
docker --version
docker run hello-world
```

#### Configure Docker Resources
1. Open Docker Desktop preferences
2. Go to Resources → Advanced
3. Set:
   - CPUs: 4 or more
   - Memory: 8 GB or more
   - Disk image size: 60 GB or more

### Step 7: Install OpenLane

```bash
cd ~/
git clone https://github.com/The-OpenROAD-Project/OpenLane.git
cd OpenLane

# For macOS, use the dockerized version
make pull-openlane

# Test OpenLane installation
make test
```

### Step 8: Install Additional Tools

#### Magic (Layout Viewer) - Build from Source
```bash
# Install dependencies
brew install cairo tcl-tk

# Build Magic from source
cd ~/
git clone https://github.com/RTimothyEdwards/magic.git
cd magic

# Configure and build
./configure --prefix=/usr/local
make
sudo make install

# Verify installation
magic -V

# Alternative: Use Docker version with OpenLane
# Magic is included in the OpenLane Docker image
```

#### KLayout (Alternative Layout Viewer)
```bash
# Install KLayout
brew install --cask klayout

# Verify installation
/Applications/klayout.app/Contents/MacOS/klayout -v
```

#### Ngspice (Circuit Simulator)
```bash
# Install Ngspice
brew install ngspice

# Verify installation
ngspice -v
```

#### Verilator (Verilog Simulator/Linter)
```bash
# Install Verilator
brew install verilator

# Verify installation
verilator --version
```

### Step 9: Python Environment Setup

```bash
# Install Python dependencies
pip3 install --upgrade pip

# Create virtual environment for the project
cd ~/fridge_temp_controller_sky130
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Install required Python packages
pip install \
    numpy \
    matplotlib \
    pandas \
    pyyaml \
    click \
    rich \
    jupyter \
    plotly
```

## 🔧 Environment Configuration

### Create Environment Setup Script

Create a file `~/fridge_temp_controller_sky130/env_setup_macos.sh`:

```bash
#!/bin/bash
# Environment setup script for Fridge Temperature Controller project on macOS

# PDK paths
export PDK_ROOT=$HOME/pdk
export PDK=sky130A
# Note: The actual PDK path structure depends on your installation method
# For skywater-pdk source: $PDK_ROOT/skywater-pdk
# For open_pdks installation: $PDK_ROOT/$PDK
export PDK_PATH=$PDK_ROOT/skywater-pdk

# OpenLane paths
export OPENLANE_ROOT=$HOME/OpenLane
export OPENLANE_IMAGE_NAME=efabless/openlane:latest

# Project paths
export PROJECT_ROOT=$HOME/fridge_temp_controller_sky130
export RTL_DIR=$PROJECT_ROOT/rtl
export TB_DIR=$PROJECT_ROOT/testbench
export SYNTH_DIR=$PROJECT_ROOT/synthesis

# Tool paths for macOS
export PATH="/opt/homebrew/bin:$PATH"
export PATH="/Applications/gtkwave.app/Contents/Resources/bin:$PATH"
export PATH="/Applications/klayout.app/Contents/MacOS:$PATH"

# Python virtual environment
if [ -f "$PROJECT_ROOT/venv/bin/activate" ]; then
    source $PROJECT_ROOT/venv/bin/activate
fi

# Docker check
if ! docker info > /dev/null 2>&1; then
    echo "Warning: Docker is not running. Please start Docker Desktop for OpenLane."
fi

echo "Environment configured for Fridge Temperature Controller project (macOS)"
echo "PDK_ROOT: $PDK_ROOT"
echo "OPENLANE_ROOT: $OPENLANE_ROOT"
echo "PROJECT_ROOT: $PROJECT_ROOT"
```

Make it executable:
```bash
chmod +x ~/fridge_temp_controller_sky130/env_setup_macos.sh
```

### Add to .zshrc (Optional)
```bash
echo 'source ~/fridge_temp_controller_sky130/env_setup_macos.sh' >> ~/.zshrc
```

## ✅ Verification

### Verify All Tools

Create a verification script `verify_tools_macos.sh`:

```bash
#!/bin/bash

echo "=== Verifying Tool Installation on macOS ==="
echo

# Check Homebrew
echo -n "Homebrew: "
if command -v brew &> /dev/null; then
    brew --version | head -n1
else
    echo "NOT INSTALLED"
fi

# Check Icarus Verilog
echo -n "Icarus Verilog: "
if command -v iverilog &> /dev/null; then
    iverilog -V | head -n1
else
    echo "NOT INSTALLED"
fi

# Check GTKWave
echo -n "GTKWave: "
if [ -f "/Applications/gtkwave.app/Contents/Resources/bin/gtkwave" ]; then
    /Applications/gtkwave.app/Contents/Resources/bin/gtkwave --version | head -n1
else
    echo "NOT INSTALLED"
fi

# Check Yosys
echo -n "Yosys: "
if command -v yosys &> /dev/null; then
    yosys -V | head -n1
else
    echo "NOT INSTALLED"
fi

# Check Docker
echo -n "Docker: "
if command -v docker &> /dev/null; then
    docker --version
    # Check if Docker daemon is running
    if docker info > /dev/null 2>&1; then
        echo "  Docker daemon: Running"
    else
        echo "  Docker daemon: NOT RUNNING - Please start Docker Desktop"
    fi
else
    echo "NOT INSTALLED"
fi

# Check OpenLane
echo -n "OpenLane: "
if [ -d "$OPENLANE_ROOT" ]; then
    echo "Installed at $OPENLANE_ROOT"
else
    echo "NOT INSTALLED"
fi

# Check PDK
echo -n "Sky130 PDK: "
if [ -d "$PDK_ROOT/skywater-pdk" ]; then
    echo "Installed at $PDK_ROOT/skywater-pdk"
else
    echo "NOT INSTALLED"
fi

# Check Magic
echo -n "Magic: "
if command -v magic &> /dev/null; then
    magic -V 2>&1 | head -n1
else
    echo "NOT INSTALLED"
fi

# Check KLayout
echo -n "KLayout: "
if [ -f "/Applications/klayout.app/Contents/MacOS/klayout" ]; then
    echo "Installed"
else
    echo "NOT INSTALLED"
fi

# Check Ngspice
echo -n "Ngspice: "
if command -v ngspice &> /dev/null; then
    ngspice -v | grep "ngspice" | head -n1
else
    echo "NOT INSTALLED"
fi

# Check Verilator
echo -n "Verilator: "
if command -v verilator &> /dev/null; then
    verilator --version
else
    echo "NOT INSTALLED"
fi

echo
echo "=== Verification Complete ==="
```

Run the verification:
```bash
chmod +x verify_tools_macos.sh
./verify_tools_macos.sh
```

## 🚀 Quick Test

### Test RTL Simulation
```bash
cd ~/fridge_temp_controller_sky130/testbench
make sim_top
```

### Test Synthesis
```bash
cd ~/fridge_temp_controller_sky130/synthesis
./run_synthesis.sh
```

### Test OpenLane (Docker must be running)
```bash
cd ~/fridge_temp_controller_sky130/openlane
# Make sure Docker Desktop is running first
./run_openlane.sh
```

## 📝 Important Notes for macOS Users

### PDK Tools Availability
Many EDA tools like Magic, Netgen, and OpenVAF are not available directly through Homebrew and need to be:
1. Built from source (as shown for Magic)
2. Used through Docker containers (recommended)
3. Accessed via OpenLane Docker image

### Recommended Approach for Physical Design
For physical design steps (OpenLane, Magic, etc.), we recommend using the Docker-based workflow:
```bash
# All PDK tools are available inside OpenLane Docker
docker run -it -v $(pwd):/work efabless/openlane:latest bash

# Inside Docker, you have access to:
# - magic
# - netgen
# - klayout
# - All OpenROAD tools
```

## 🔍 Troubleshooting - macOS Specific

### Common Issues and Solutions

#### 1. GTKWave Won't Open
```bash
# If you see "cannot be opened because the developer cannot be verified"
xattr -d com.apple.quarantine /Applications/gtkwave.app

# For display issues
export DISPLAY=:0
```

#### 2. Docker Desktop Not Starting
```bash
# Reset Docker Desktop
rm -rf ~/Library/Containers/com.docker.docker
rm -rf ~/.docker

# Reinstall
brew reinstall --cask docker
```

#### 3. Homebrew Installation Issues (Apple Silicon)
```bash
# Ensure correct PATH
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
source ~/.zshrc
```

#### 4. OpenLane Docker Issues
```bash
# Increase Docker resources in Docker Desktop settings
# Ensure virtualization is enabled in macOS

# For Apple Silicon, ensure Rosetta 2 is installed
softwareupdate --install-rosetta --agree-to-license
```

#### 5. Permission Issues
```bash
# Fix permissions for tools
chmod +x ~/fridge_temp_controller_sky130/scripts/*
chmod +x ~/fridge_temp_controller_sky130/synthesis/*.sh
chmod +x ~/fridge_temp_controller_sky130/openlane/*.sh
```

## 📚 macOS-Specific Considerations

### Apple Silicon (M1/M2/M3) Notes
- Most tools now have native ARM64 support
- Some older tools may run under Rosetta 2
- Docker Desktop has native support
- Performance is generally excellent

### X11 Display (for GTKWave)
- macOS doesn't include X11 by default
- GTKWave bundles its own display system
- For other X11 apps, install XQuartz:
  ```bash
  brew install --cask xquartz
  ```

### File System Case Sensitivity
- macOS is case-insensitive by default
- Be careful with file names in scripts
- Consider creating a case-sensitive volume for the project if needed

## 🎯 Next Steps

After completing the installation:
1. Clone the project repository
2. Run the quickstart script: `./quickstart.sh`
3. Follow the [RTL Simulation Guide](../03_verification/01_verification_strategy.md)
4. Proceed to [Synthesis Guide](../05_implementation/02_synthesis_guide.md)

## 📚 Additional Resources

- [Homebrew Documentation](https://brew.sh)
- [Docker Desktop for Mac](https://docs.docker.com/desktop/mac/)
- [macOS Development Guide](https://developer.apple.com/macos/)
- [Rosetta 2 Information](https://support.apple.com/en-us/HT211861)

---

**Note**: While macOS is excellent for RTL development and simulation, some EDA tools have limited support compared to Linux. For production tape-out work, consider using a Linux environment or Docker containers.
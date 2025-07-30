# Development Environment Setup Guide

This guide will walk you through setting up the complete development environment for the Fridge Temperature Controller IC project using Sky130 PDK.

## 📋 System Requirements

### Minimum Requirements
- **OS**: Ubuntu 20.04 LTS or later (WSL2 supported on Windows)
- **RAM**: 8 GB minimum, 16 GB recommended
- **Storage**: 50 GB free space
- **CPU**: 4 cores minimum, 8 cores recommended

### Supported Operating Systems
- Ubuntu 20.04/22.04 LTS
- Debian 11/12
- CentOS 8/Rocky Linux 8
- macOS (with some limitations)
- Windows 10/11 (via WSL2)

## 🛠️ Installation Steps

### Step 1: Update System and Install Base Dependencies

```bash
# Update package list
sudo apt-get update
sudo apt-get upgrade -y

# Install essential build tools
sudo apt-get install -y \
    build-essential \
    git \
    wget \
    curl \
    python3 \
    python3-pip \
    python3-venv \
    make \
    autoconf \
    automake \
    libtool \
    pkg-config
```

### Step 2: Install RTL Simulation Tools

#### Icarus Verilog (RTL Simulator)
```bash
# Install Icarus Verilog
sudo apt-get install -y iverilog

# Verify installation
iverilog -V
```

#### GTKWave (Waveform Viewer)
```bash
# Install GTKWave
sudo apt-get install -y gtkwave

# Verify installation
gtkwave --version
```

### Step 3: Install Synthesis Tools

#### Yosys (Open Source Synthesis Tool)
```bash
# Install dependencies
sudo apt-get install -y \
    clang \
    bison \
    flex \
    libreadline-dev \
    gawk \
    tcl-dev \
    libffi-dev \
    graphviz \
    xdot \
    pkg-config \
    python3 \
    libboost-system-dev \
    libboost-python-dev \
    libboost-filesystem-dev \
    zlib1g-dev

# Clone and build Yosys
cd ~/
git clone https://github.com/YosysHQ/yosys.git
cd yosys
make -j$(nproc)
sudo make install

# Verify installation
yosys -V
```

### Step 4: Install Sky130 PDK

#### Create PDK Directory
```bash
# Set PDK environment variable
export PDK_ROOT=$HOME/pdk
echo 'export PDK_ROOT=$HOME/pdk' >> ~/.bashrc

# Create directory
mkdir -p $PDK_ROOT
cd $PDK_ROOT
```

#### Install Sky130 PDK
```bash
# Clone the PDK
git clone https://github.com/google/skywater-pdk.git
cd skywater-pdk

# Checkout stable version
git checkout main
git submodule update --init libraries/sky130_fd_sc_hd/latest

# Build the PDK
make timing
```

#### Install Open_PDKs
```bash
cd $PDK_ROOT
git clone https://github.com/RTimothyEdwards/open_pdks.git
cd open_pdks
./configure --enable-sky130-pdk=$PDK_ROOT/skywater-pdk/libraries --with-sky130-local-path=$PDK_ROOT
make
sudo make install
```

### Step 5: Install OpenLane

#### Install Docker (Required for OpenLane)
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in for group changes to take effect
# Or run: newgrp docker
```

#### Install OpenLane
```bash
cd ~/
git clone https://github.com/The-OpenROAD-Project/OpenLane.git
cd OpenLane

# Pull OpenLane Docker image
make pull-openlane

# Test OpenLane installation
make test
```

### Step 6: Install Additional Tools

#### Magic (Layout Viewer)
```bash
sudo apt-get install -y \
    m4 \
    tcsh \
    csh \
    libx11-dev \
    tcl-dev \
    tk-dev \
    libcairo2-dev \
    libncurses-dev \
    libglu1-mesa-dev \
    freeglut3-dev

cd ~/
git clone https://github.com/RTimothyEdwards/magic.git
cd magic
./configure
make
sudo make install
```

#### KLayout (Alternative Layout Viewer)
```bash
# Install KLayout
sudo apt-get install -y klayout
```

#### Ngspice (Circuit Simulator)
```bash
# Install Ngspice
sudo apt-get install -y ngspice

# Verify installation
ngspice -v
```

### Step 7: Python Environment Setup

```bash
# Create virtual environment for the project
cd ~/fridge_temp_controller_sky130
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Install required Python packages
pip install --upgrade pip
pip install \
    numpy \
    matplotlib \
    pandas \
    pyyaml \
    click \
    rich
```

## 🔧 Environment Configuration

### Create Environment Setup Script

Create a file `~/fridge_temp_controller_sky130/env_setup.sh`:

```bash
#!/bin/bash
# Environment setup script for Fridge Temperature Controller project

# PDK paths
export PDK_ROOT=$HOME/pdk
export PDK=sky130A
export PDK_PATH=$PDK_ROOT/$PDK

# OpenLane paths
export OPENLANE_ROOT=$HOME/OpenLane
export OPENLANE_IMAGE_NAME=efabless/openlane:latest

# Project paths
export PROJECT_ROOT=$HOME/fridge_temp_controller_sky130
export RTL_DIR=$PROJECT_ROOT/rtl
export TB_DIR=$PROJECT_ROOT/testbench
export SYNTH_DIR=$PROJECT_ROOT/synthesis

# Tool paths (adjust if installed elsewhere)
export PATH=$PATH:/usr/local/bin

# Python virtual environment
if [ -f "$PROJECT_ROOT/venv/bin/activate" ]; then
    source $PROJECT_ROOT/venv/bin/activate
fi

echo "Environment configured for Fridge Temperature Controller project"
echo "PDK_ROOT: $PDK_ROOT"
echo "OPENLANE_ROOT: $OPENLANE_ROOT"
echo "PROJECT_ROOT: $PROJECT_ROOT"
```

Make it executable:
```bash
chmod +x ~/fridge_temp_controller_sky130/env_setup.sh
```

### Add to .bashrc (Optional)
```bash
echo 'source ~/fridge_temp_controller_sky130/env_setup.sh' >> ~/.bashrc
```

## ✅ Verification

### Verify All Tools

Create a verification script `verify_tools.sh`:

```bash
#!/bin/bash

echo "=== Verifying Tool Installation ==="
echo

# Check Icarus Verilog
echo -n "Icarus Verilog: "
if command -v iverilog &> /dev/null; then
    iverilog -V | head -n1
else
    echo "NOT INSTALLED"
fi

# Check GTKWave
echo -n "GTKWave: "
if command -v gtkwave &> /dev/null; then
    gtkwave --version | head -n1
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
if [ -d "$PDK_ROOT/sky130A" ]; then
    echo "Installed at $PDK_ROOT/sky130A"
else
    echo "NOT INSTALLED"
fi

# Check Magic
echo -n "Magic: "
if command -v magic &> /dev/null; then
    magic -V | head -n1
else
    echo "NOT INSTALLED"
fi

# Check Ngspice
echo -n "Ngspice: "
if command -v ngspice &> /dev/null; then
    ngspice -v | grep "ngspice"
else
    echo "NOT INSTALLED"
fi

echo
echo "=== Verification Complete ==="
```

Run the verification:
```bash
chmod +x verify_tools.sh
./verify_tools.sh
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

## 🔍 Troubleshooting

### Common Issues and Solutions

#### 1. Permission Denied for Docker
```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Log out and log back in
```

#### 2. Yosys Build Fails
```bash
# Install missing dependencies
sudo apt-get install -y libboost-all-dev
```

#### 3. GTKWave Display Issues
```bash
# For WSL2 users, install X server (VcXsrv or Xming)
export DISPLAY=:0
```

#### 4. OpenLane Docker Pull Fails
```bash
# Check Docker service
sudo systemctl status docker
sudo systemctl start docker
```

## 📚 Additional Resources

- [Sky130 PDK Documentation](https://skywater-pdk.readthedocs.io/)
- [OpenLane Documentation](https://openlane.readthedocs.io/)
- [Yosys Manual](http://www.clifford.at/yosys/documentation.html)
- [Icarus Verilog Guide](http://iverilog.icarus.com/home)

## 🎯 Next Steps

After completing the installation:
1. Clone the project repository
2. Run the quickstart script: `./quickstart.sh`
3. Follow the [RTL Simulation Guide](../03_verification/01_verification_strategy.md)
4. Proceed to [Synthesis Guide](../05_implementation/02_synthesis_guide.md)

---

**Note**: This installation guide is for Ubuntu-based systems. For other operating systems, please refer to the respective tool documentation for platform-specific instructions.
#!/bin/bash
# ==============================================================================
# run_openlane.sh - OpenLane flow runner
# Description: Automated RTL-to-GDSII flow using OpenLane
# Author: IC Design Team
# Date: 2024-12-19
# ==============================================================================

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Function to print colored messages
print_msg() {
    echo -e "${1}${2}${NC}"
}

# Header
clear
print_msg $BLUE "============================================="
print_msg $BLUE "Temperature Controller - OpenLane Flow"
print_msg $BLUE "============================================="
echo

# Check environment
print_msg $YELLOW "Checking environment..."

# Check if OpenLane is installed
if [ -z "$OPENLANE_ROOT" ]; then
    print_msg $RED "Error: OPENLANE_ROOT is not set!"
    print_msg $YELLOW "Please set up OpenLane environment first."
    print_msg $CYAN "Installation guide:"
    print_msg $CYAN "git clone https://github.com/The-OpenROAD-Project/OpenLane"
    print_msg $CYAN "cd OpenLane"
    print_msg $CYAN "make"
    exit 1
fi

# Check if PDK is installed
if [ -z "$PDK_ROOT" ]; then
    print_msg $RED "Error: PDK_ROOT is not set!"
    print_msg $YELLOW "Please install SKY130 PDK first."
    print_msg $CYAN "Installation guide:"
    print_msg $CYAN "git clone https://github.com/google/skywater-pdk"
    print_msg $CYAN "cd skywater-pdk"
    print_msg $CYAN "make sky130"
    exit 1
fi

print_msg $GREEN "Environment check passed!"
print_msg $BLUE "OPENLANE_ROOT: $OPENLANE_ROOT"
print_msg $BLUE "PDK_ROOT: $PDK_ROOT"
echo

# Design name
DESIGN_NAME="temp_ctrl_top"
DESIGN_DIR=$(pwd)

# Flow options
print_msg $YELLOW "Select flow option:"
echo "1. Full flow (RTL to GDSII)"
echo "2. Synthesis only"
echo "3. Floorplan only"
echo "4. Placement only"
echo "5. CTS only"
echo "6. Routing only"
echo "7. Interactive mode"
echo "8. Clean runs"
echo -n "Enter choice [1-8]: "
read choice

case $choice in
    1)
        print_msg $CYAN "\nRunning full RTL-to-GDSII flow..."
        cd $OPENLANE_ROOT
        ./flow.tcl -design $DESIGN_DIR -tag $(date +%Y%m%d_%H%M%S)
        ;;
    2)
        print_msg $CYAN "\nRunning synthesis only..."
        cd $OPENLANE_ROOT
        ./flow.tcl -design $DESIGN_DIR -tag synth_$(date +%Y%m%d_%H%M%S) -from synthesis -to synthesis
        ;;
    3)
        print_msg $CYAN "\nRunning floorplan only..."
        cd $OPENLANE_ROOT
        ./flow.tcl -design $DESIGN_DIR -tag fp_$(date +%Y%m%d_%H%M%S) -from floorplan -to floorplan
        ;;
    4)
        print_msg $CYAN "\nRunning placement only..."
        cd $OPENLANE_ROOT
        ./flow.tcl -design $DESIGN_DIR -tag place_$(date +%Y%m%d_%H%M%S) -from placement -to placement
        ;;
    5)
        print_msg $CYAN "\nRunning CTS only..."
        cd $OPENLANE_ROOT
        ./flow.tcl -design $DESIGN_DIR -tag cts_$(date +%Y%m%d_%H%M%S) -from cts -to cts
        ;;
    6)
        print_msg $CYAN "\nRunning routing only..."
        cd $OPENLANE_ROOT
        ./flow.tcl -design $DESIGN_DIR -tag route_$(date +%Y%m%d_%H%M%S) -from routing -to routing
        ;;
    7)
        print_msg $CYAN "\nStarting interactive mode..."
        print_msg $YELLOW "Use the following commands in OpenLane:"
        print_msg $BLUE "prep -design $DESIGN_DIR"
        print_msg $BLUE "run_synthesis"
        print_msg $BLUE "run_floorplan"
        print_msg $BLUE "run_placement"
        print_msg $BLUE "run_cts"
        print_msg $BLUE "run_routing"
        print_msg $BLUE "run_magic"
        print_msg $BLUE "run_lvs"
        print_msg $BLUE "run_drc"
        echo
        cd $OPENLANE_ROOT
        ./flow.tcl -interactive
        ;;
    8)
        print_msg $YELLOW "\nCleaning previous runs..."
        rm -rf runs/*
        print_msg $GREEN "Clean complete!"
        ;;
    *)
        print_msg $RED "\nInvalid choice!"
        exit 1
        ;;
esac

# Check results
if [ -d "runs" ]; then
    print_msg $BLUE "\n============================================="
    print_msg $BLUE "Run Summary"
    print_msg $BLUE "============================================="
    
    # Find latest run
    LATEST_RUN=$(ls -t runs/ | head -1)
    if [ ! -z "$LATEST_RUN" ]; then
        RUN_DIR="runs/$LATEST_RUN"
        
        print_msg $GREEN "Latest run: $LATEST_RUN"
        
        # Check for key outputs
        if [ -f "$RUN_DIR/results/synthesis/synthesized.v" ]; then
            print_msg $GREEN "✓ Synthesis complete"
        fi
        
        if [ -f "$RUN_DIR/results/floorplan/floorplan.def" ]; then
            print_msg $GREEN "✓ Floorplan complete"
        fi
        
        if [ -f "$RUN_DIR/results/placement/placement.def" ]; then
            print_msg $GREEN "✓ Placement complete"
        fi
        
        if [ -f "$RUN_DIR/results/cts/cts.def" ]; then
            print_msg $GREEN "✓ CTS complete"
        fi
        
        if [ -f "$RUN_DIR/results/routing/routing.def" ]; then
            print_msg $GREEN "✓ Routing complete"
        fi
        
        if [ -f "$RUN_DIR/results/magic/magic.gds" ]; then
            print_msg $GREEN "✓ GDSII generated"
        fi
        
        # Display reports
        if [ -f "$RUN_DIR/reports/synthesis/synthesis.stat.rpt" ]; then
            print_msg $BLUE "\n--- Synthesis Statistics ---"
            tail -n 20 "$RUN_DIR/reports/synthesis/synthesis.stat.rpt"
        fi
        
        if [ -f "$RUN_DIR/reports/placement/placement.rpt" ]; then
            print_msg $BLUE "\n--- Placement Summary ---"
            grep -E "(utilization|wire|timing)" "$RUN_DIR/reports/placement/placement.rpt" | head -10
        fi
    fi
fi

print_msg $BLUE "\n============================================="
print_msg $GREEN "Flow execution complete!"
print_msg $BLUE "============================================="
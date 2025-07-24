#!/bin/bash
# ==============================================================================
# run_synthesis.sh - Automated synthesis flow
# Description: Run Yosys synthesis with SKY130 PDK
# Author: IC Design Team
# Date: 2024-12-19
# ==============================================================================

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to print colored messages
print_msg() {
    echo -e "${1}${2}${NC}"
}

# Header
print_msg $BLUE "============================================="
print_msg $BLUE "Temperature Controller Synthesis Flow"
print_msg $BLUE "============================================="
echo

# Check if Yosys is installed
if ! command -v yosys &> /dev/null; then
    print_msg $RED "Error: Yosys is not installed!"
    print_msg $YELLOW "Please install Yosys to continue."
    print_msg $YELLOW "Ubuntu/Debian: sudo apt-get install yosys"
    print_msg $YELLOW "Or build from source: https://github.com/YosysHQ/yosys"
    exit 1
fi

# Create necessary directories
print_msg $YELLOW "Creating output directories..."
mkdir -p output
mkdir -p reports
mkdir -p logs

# Check for SKY130 library file
if [ ! -f "../libs/sky130_fd_sc_hd__tt_025C_1v80.lib" ]; then
    print_msg $YELLOW "Warning: SKY130 liberty file not found!"
    print_msg $YELLOW "Creating libs directory..."
    mkdir -p ../libs
    
    print_msg $YELLOW "Please download SKY130 PDK liberty files from:"
    print_msg $BLUE "https://github.com/google/skywater-pdk"
    print_msg $YELLOW "Or use the simplified liberty file for testing."
    
    # Create a minimal liberty file for testing
    cat > ../libs/sky130_fd_sc_hd__tt_025C_1v80.lib << 'EOF'
/* Minimal Liberty file for testing - NOT FOR PRODUCTION */
library (sky130_fd_sc_hd__tt_025C_1v80) {
  technology (cmos);
  delay_model : table_lookup;
  voltage_unit : "1V";
  current_unit : "1mA";
  time_unit : "1ns";
  capacitive_load_unit (1.0, pf);
  
  cell (sky130_fd_sc_hd__buf_2) {
    area : 2.0;
    pin(A) {
      direction : input;
      capacitance : 0.01;
    }
    pin(X) {
      direction : output;
      function : "A";
    }
  }
  
  cell (sky130_fd_sc_hd__inv_2) {
    area : 1.5;
    pin(A) {
      direction : input;
      capacitance : 0.01;
    }
    pin(Y) {
      direction : output;
      function : "!A";
    }
  }
  
  cell (sky130_fd_sc_hd__dfrtp_2) {
    area : 8.0;
    ff(IQ, IQN) {
      clocked_on : "CLK";
      next_state : "D";
      clear : "!RESET_B";
    }
    pin(CLK) {
      direction : input;
      capacitance : 0.02;
      clock : true;
    }
    pin(D) {
      direction : input;
      capacitance : 0.01;
    }
    pin(RESET_B) {
      direction : input;
      capacitance : 0.01;
    }
    pin(Q) {
      direction : output;
      function : "IQ";
    }
  }
}
EOF
    print_msg $GREEN "Created minimal liberty file for testing."
fi

# Run synthesis
print_msg $YELLOW "\nStarting synthesis..."
print_msg $BLUE "Logging to: logs/synthesis.log"

# Execute Yosys
yosys -l logs/synthesis.log synth_top.ys

# Check if synthesis completed successfully
if [ $? -eq 0 ]; then
    print_msg $GREEN "\nSynthesis completed successfully!"
    
    # Check if output files were generated
    if [ -f "output/temp_ctrl_synthesized.v" ]; then
        print_msg $GREEN "✓ Synthesized netlist generated"
    else
        print_msg $RED "✗ Synthesized netlist not found"
    fi
    
    # Display summary
    if [ -f "reports/synth_stat.txt" ]; then
        print_msg $BLUE "\n--- Synthesis Statistics ---"
        tail -n 20 reports/synth_stat.txt
    fi
    
    print_msg $BLUE "\n--- Output Files ---"
    ls -la output/
    
    print_msg $BLUE "\n--- Reports ---"
    ls -la reports/
    
else
    print_msg $RED "\nSynthesis failed! Check logs/synthesis.log for details."
    print_msg $YELLOW "Last 20 lines of log:"
    tail -n 20 logs/synthesis.log
fi

echo
print_msg $BLUE "============================================="
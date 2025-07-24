#!/bin/bash
#==============================================================================
# run_sim.sh - Simulation runner script
# Description: Automated simulation environment setup and execution
# Author: IC Design Team
# Date: 2024-12-19
#==============================================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
}

# Function to check if command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_msg $RED "Error: $1 is not installed!"
        print_msg $YELLOW "Please install $1 to continue."
        exit 1
    fi
}

# Header
clear
print_msg $BLUE "================================================"
print_msg $BLUE "Temperature Controller Simulation Environment"
print_msg $BLUE "================================================"
echo

# Check required tools
print_msg $YELLOW "Checking required tools..."
check_command iverilog
check_command vvp
check_command gtkwave
print_msg $GREEN "All required tools found!"
echo

# Create work directory
if [ ! -d "work" ]; then
    mkdir -p work
    print_msg $GREEN "Created work directory"
fi

# Menu
while true; do
    print_msg $BLUE "\nSelect simulation to run:"
    echo "1. Top-level testbench (full system)"
    echo "2. PID controller testbench"
    echo "3. Run all testbenches"
    echo "4. Lint check (Verilator)"
    echo "5. Clean work directory"
    echo "6. Exit"
    echo -n "Enter choice [1-6]: "
    read choice

    case $choice in
        1)
            print_msg $YELLOW "\nCompiling top-level testbench..."
            make compile_top
            if [ $? -eq 0 ]; then
                print_msg $GREEN "Compilation successful!"
                print_msg $YELLOW "Running simulation..."
                make sim_top
                echo -n "View waveform? (y/n): "
                read view_wave
                if [ "$view_wave" = "y" ]; then
                    cd work && gtkwave temp_ctrl_top_tb.vcd &
                    cd ..
                fi
            else
                print_msg $RED "Compilation failed!"
            fi
            ;;
        2)
            print_msg $YELLOW "\nCompiling PID controller testbench..."
            make compile_pid
            if [ $? -eq 0 ]; then
                print_msg $GREEN "Compilation successful!"
                print_msg $YELLOW "Running simulation..."
                make sim_pid
                echo -n "View waveform? (y/n): "
                read view_wave
                if [ "$view_wave" = "y" ]; then
                    cd work && gtkwave pid_controller_tb.vcd &
                    cd ..
                fi
            else
                print_msg $RED "Compilation failed!"
            fi
            ;;
        3)
            print_msg $YELLOW "\nRunning all testbenches..."
            make compile
            if [ $? -eq 0 ]; then
                print_msg $GREEN "All compilations successful!"
                print_msg $YELLOW "\nRunning top-level simulation..."
                make sim_top
                print_msg $YELLOW "\nRunning PID simulation..."
                make sim_pid
                print_msg $GREEN "\nAll simulations complete!"
            else
                print_msg $RED "Compilation failed!"
            fi
            ;;
        4)
            if command -v verilator &> /dev/null; then
                print_msg $YELLOW "\nRunning Verilator lint check..."
                make lint
            else
                print_msg $RED "Verilator not installed!"
                print_msg $YELLOW "Install with: sudo apt-get install verilator"
            fi
            ;;
        5)
            print_msg $YELLOW "\nCleaning work directory..."
            make clean
            print_msg $GREEN "Clean complete!"
            ;;
        6)
            print_msg $GREEN "\nExiting simulation environment."
            exit 0
            ;;
        *)
            print_msg $RED "\nInvalid choice! Please select 1-6."
            ;;
    esac
done
# Makefile for Temperature Controller Testbench
# Target: Icarus Verilog and GTKWave

# Directories
RTL_DIR = ../rtl
TB_DIR = .
WORK_DIR = work

# Verilog files
RTL_FILES = $(RTL_DIR)/temp_ctrl_top.v \
            $(RTL_DIR)/adc_spi_interface.v \
            $(RTL_DIR)/pid_controller.v \
            $(RTL_DIR)/pwm_generator.v \
            $(RTL_DIR)/display_controller.v

# Testbench files
TB_TOP = $(TB_DIR)/temp_ctrl_top_tb.v
TB_PID = $(TB_DIR)/pid_controller_tb.v

# Simulation files
TOP_SIM = $(WORK_DIR)/temp_ctrl_top.vvp
PID_SIM = $(WORK_DIR)/pid_controller.vvp

# Waveform files
TOP_VCD = temp_ctrl_top_tb.vcd
PID_VCD = pid_controller_tb.vcd

# Tools
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave
VERILATOR = verilator

# Compiler flags
VFLAGS = -Wall -g2012

# Default target
all: compile

# Create work directory
$(WORK_DIR):
	mkdir -p $(WORK_DIR)

# Compile top-level testbench
compile_top: $(WORK_DIR)
	$(IVERILOG) $(VFLAGS) -o $(TOP_SIM) $(TB_TOP) $(RTL_FILES)

# Compile PID testbench
compile_pid: $(WORK_DIR)
	$(IVERILOG) $(VFLAGS) -o $(PID_SIM) $(TB_PID) $(RTL_DIR)/pid_controller.v

# Compile all testbenches
compile: compile_top compile_pid

# Run top-level simulation
sim_top: compile_top
	cd $(WORK_DIR) && $(VVP) temp_ctrl_top.vvp

# Run PID simulation
sim_pid: compile_pid
	cd $(WORK_DIR) && $(VVP) pid_controller.vvp

# View top-level waveform
wave_top: sim_top
	$(GTKWAVE) $(WORK_DIR)/$(TOP_VCD) &

# View PID waveform
wave_pid: sim_pid
	$(GTKWAVE) $(WORK_DIR)/$(PID_VCD) &

# Lint check with Verilator
lint:
	$(VERILATOR) --lint-only -Wall $(RTL_FILES)

# Clean up
clean:
	rm -rf $(WORK_DIR)
	rm -f *.vcd
	rm -f *.log

# Help
help:
	@echo "Temperature Controller Testbench Makefile"
	@echo "========================================"
	@echo "Targets:"
	@echo "  make compile      - Compile all testbenches"
	@echo "  make sim_top      - Run top-level simulation"
	@echo "  make sim_pid      - Run PID controller simulation"
	@echo "  make wave_top     - View top-level waveforms"
	@echo "  make wave_pid     - View PID waveforms"
	@echo "  make lint         - Run Verilator lint check"
	@echo "  make clean        - Clean build files"
	@echo "  make help         - Show this help"

.PHONY: all compile compile_top compile_pid sim_top sim_pid wave_top wave_pid lint clean help
# Simple Yosys synthesis script for Sky130
# Read liberty file
read_liberty -lib /Users/marcus/Documents/Projects/test-tech/doing/test-eda/fridge_temp_controller_sky130/pdk/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# Read Verilog files
read_verilog ../rtl/temp_ctrl_top.v
read_verilog ../rtl/adc_spi_interface.v
read_verilog ../rtl/pid_controller.v
read_verilog ../rtl/pwm_generator.v
read_verilog ../rtl/display_controller.v

# Elaborate design hierarchy
hierarchy -check -top temp_ctrl_top

# The high-level stuff
proc
opt
fsm
opt
memory
opt

# Mapping to internal cell library
techmap
opt

# Mapping flip-flops
dfflibmap -liberty /Users/marcus/Documents/Projects/test-tech/doing/test-eda/fridge_temp_controller_sky130/pdk/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# Mapping logic
abc -liberty /Users/marcus/Documents/Projects/test-tech/doing/test-eda/fridge_temp_controller_sky130/pdk/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# Cleanup
clean

# Check
stat

# Write outputs
write_verilog -noattr output/temp_ctrl_synthesized.v
write_verilog -noexpr output/temp_ctrl_synthesized_sim.v
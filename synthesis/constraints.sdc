# ==============================================================================
# File: constraints.sdc
# Description: Timing constraints for temperature controller
# Target: SKY130 PDK @ 10 MHz
# Author: IC Design Team
# Date: 2024-12-19
# ==============================================================================

# Create clock constraint
# 10 MHz clock = 100 ns period
create_clock -period 100 [get_ports clk]

# Set clock uncertainty (jitter + skew)
set_clock_uncertainty 1.0 [get_clocks clk]

# Set input delays
# Assume inputs arrive 20ns after clock edge
set_input_delay -clock clk 20 [all_inputs]
set_input_delay -clock clk 0 [get_ports clk]
set_input_delay -clock clk 0 [get_ports rst_n]

# Set output delays
# Assume outputs need to be stable 20ns before next clock edge
set_output_delay -clock clk 20 [all_outputs]

# Set driving cell for inputs
# Use a medium strength buffer from SKY130
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_2 [all_inputs]

# Set output load
# Assume 50fF load on all outputs
set_load 0.05 [all_outputs]

# False paths
# Reset is asynchronous
set_false_path -from [get_ports rst_n]

# Multi-cycle paths
# ADC interface operates at 1 MHz (10x slower)
set_multicycle_path 10 -setup -from [get_pins *adc_spi*/*] -to [get_pins *adc_spi*/*]
set_multicycle_path 9 -hold -from [get_pins *adc_spi*/*] -to [get_pins *adc_spi*/*]

# PWM operates at 1 kHz (10000x slower)
set_multicycle_path 10000 -setup -from [get_pins *pwm_generator*/*] -to [get_pins *pwm_generator*/*]
set_multicycle_path 9999 -hold -from [get_pins *pwm_generator*/*] -to [get_pins *pwm_generator*/*]

# Display operates at 100 Hz (100000x slower)
set_multicycle_path 100000 -setup -from [get_pins *display_controller*/*] -to [get_pins *display_controller*/*]
set_multicycle_path 99999 -hold -from [get_pins *display_controller*/*] -to [get_pins *display_controller*/*]

# Max transition time
set_max_transition 5.0 [current_design]

# Max fanout
set_max_fanout 20 [current_design]

# Operating conditions
# Use typical corner for synthesis
set_operating_conditions tt_025C_1v80

# Wire load model
# Use appropriate model for target area
set_wire_load_model -name "Small"

# Design rules
set_max_capacitance 0.2 [current_design]
set_max_area 500000  ;# 0.5 mm^2 in um^2

# Power constraints
# Target 5mW dynamic power at 10MHz
set_max_dynamic_power 5.0

# Clock gating
# Enable clock gating for power optimization
set_clock_gating_style -sequential_cell latch \
                       -control_point before \
                       -control_signal scan_enable \
                       -minimum_bitwidth 4

# Report constraints
report_constraint -all_violators
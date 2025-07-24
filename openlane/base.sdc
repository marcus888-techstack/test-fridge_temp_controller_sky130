# ==============================================================================
# File: base.sdc
# Description: Base SDC constraints for OpenLane flow
# Target: SKY130 PDK @ 10 MHz
# Author: IC Design Team
# Date: 2024-12-19
# ==============================================================================

# Clock definition
# 10 MHz = 100 ns period
create_clock [get_ports $::env(CLOCK_PORT)]  -name $::env(CLOCK_PORT)  -period $::env(CLOCK_PERIOD)

# Clock uncertainty
set_clock_uncertainty 0.25 [get_clocks $::env(CLOCK_PORT)]

# Clock transition
set_clock_transition 0.15 [get_clocks $::env(CLOCK_PORT)]

# Input delays
set input_delay_value [expr $::env(CLOCK_PERIOD) * 0.20]
set_input_delay $input_delay_value -clock [get_clocks $::env(CLOCK_PORT)] [all_inputs]

# Output delays
set output_delay_value [expr $::env(CLOCK_PERIOD) * 0.20]
set_output_delay $output_delay_value -clock [get_clocks $::env(CLOCK_PORT)] [all_outputs]

# Don't touch the clock network
set_dont_touch [get_nets $::env(CLOCK_NET)]

# Maximum fanout
set_max_fanout 10 [current_design]

# Maximum transition
set_max_transition 1.5 [current_design]

# Input transition
set_input_transition 0.5 [all_inputs]

# Output load (50 fF)
set_load 0.05 [all_outputs]

# False paths
set_false_path -from [get_ports rst_n]
set_false_path -to [get_ports alarm]
set_false_path -to [get_ports defrost_heater]

# Multi-cycle paths for slow interfaces
# ADC SPI interface (1 MHz)
set_multicycle_path -setup 10 -through [get_pins -hierarchical *adc_spi*/*]
set_multicycle_path -hold 9 -through [get_pins -hierarchical *adc_spi*/*]

# PWM interface (1 kHz)
set_multicycle_path -setup 100 -through [get_pins -hierarchical *pwm*/*]
set_multicycle_path -hold 99 -through [get_pins -hierarchical *pwm*/*]

# Display interface (100 Hz)
set_multicycle_path -setup 1000 -through [get_pins -hierarchical *display*/*]
set_multicycle_path -hold 999 -through [get_pins -hierarchical *display*/*]

# Disable timing for test ports (if any)
set_case_analysis 0 [get_ports -quiet test_en]
set_case_analysis 0 [get_ports -quiet scan_en]
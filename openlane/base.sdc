# ==============================================================================
# File: base.sdc
# Description: Base SDC constraints for OpenLane flow
# Target: SKY130 PDK @ 10 MHz
# Author: IC Design Team
# Date: 2024-12-19
# ==============================================================================
# 中文說明：OpenLane 時序約束檔案
# 用途：定義時脈、輸入/輸出延遲、多週期路徑等時序約束
# ==============================================================================

# Clock definition | 時脈定義
# 10 MHz = 100 ns period | 10 MHz = 100 ns 週期
create_clock [get_ports $::env(CLOCK_PORT)]  -name $::env(CLOCK_PORT)  -period $::env(CLOCK_PERIOD)

# Clock uncertainty | 時脈不確定性（用於時序分析餘量）
set_clock_uncertainty 0.25 [get_clocks $::env(CLOCK_PORT)]

# Clock transition | 時脈轉換時間（上升/下降時間）
set_clock_transition 0.15 [get_clocks $::env(CLOCK_PORT)]

# Input delays | 輸入延遲
# 設定為時脈週期的 20%
set input_delay_value [expr $::env(CLOCK_PERIOD) * 0.20]
# Set input delay for all non-clock ports | 為所有非時脈端口設定輸入延遲
set_input_delay $input_delay_value -clock [get_clocks $::env(CLOCK_PORT)] [get_ports {rst_n door_sensor button_up button_down button_mode adc_miso}]
set_input_delay $input_delay_value -clock [get_clocks $::env(CLOCK_PORT)] [get_ports {adc_mosi adc_sclk adc_cs_n}]

# Output delays | 輸出延遲
# 設定為時脈週期的 20%
set output_delay_value [expr $::env(CLOCK_PERIOD) * 0.20]
set_output_delay $output_delay_value -clock [get_clocks $::env(CLOCK_PORT)] [all_outputs]

# Clock network is handled by CTS | 時脈網路由 CTS 處理
# set_dont_touch is not supported in OpenSTA | set_dont_touch 在 OpenSTA 中不支援

# Maximum fanout | 最大扇出（一個輸出可驅動的輸入數量）
set_max_fanout 10 [current_design]

# Maximum transition | 最大轉換時間
set_max_transition 1.5 [current_design]

# Input transition | 輸入轉換時間
set_input_transition 0.5 [all_inputs]

# Output load (50 fF) | 輸出負載（50 飛法拉）
set_load 0.05 [all_outputs]

# False paths | 假路徑（不需要時序檢查的路徑）
set_false_path -from [get_ports rst_n]          # 重置信號
set_false_path -to [get_ports alarm]            # 警報輸出
set_false_path -to [get_ports defrost_heater]   # 除霜加熱器輸出

# Multi-cycle paths for slow interfaces | 慢速介面的多週期路徑
# ADC SPI interface (1 MHz) | ADC SPI 介面（1 MHz）
set_multicycle_path -setup 10 -through [get_pins -hierarchical *adc_spi*/*]
set_multicycle_path -hold 9 -through [get_pins -hierarchical *adc_spi*/*]

# PWM interface (1 kHz) | PWM 介面（1 kHz）
set_multicycle_path -setup 100 -through [get_pins -hierarchical *pwm*/*]
set_multicycle_path -hold 99 -through [get_pins -hierarchical *pwm*/*]

# Display interface (100 Hz) | 顯示器介面（100 Hz）
set_multicycle_path -setup 1000 -through [get_pins -hierarchical *display*/*]
set_multicycle_path -hold 999 -through [get_pins -hierarchical *display*/*]

# Disable timing for test ports (if any) | 禁用測試端口的時序檢查（如果有）
set_case_analysis 0 [get_ports -quiet test_en]
set_case_analysis 0 [get_ports -quiet scan_en]
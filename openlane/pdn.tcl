# ==============================================================================
# File: pdn.tcl
# Description: Power Distribution Network configuration for OpenLane
# Target: SKY130 PDK
# Author: IC Design Team
# Date: 2024-12-19
# ==============================================================================
# 中文說明：電源分配網路 (PDN) 配置檔案
# 用途：定義電源軌道、電源條、連接方式等
# ==============================================================================

# Stdcell power pins | 標準單元電源接腳
set ::power_nets $::env(VDD_NETS)     # 電源網路
set ::ground_nets $::env(GND_NETS)    # 接地網路

# Voltage domains | 電壓域設定
set ::voltage_domains [list {
    name {default}      # 預設電壓域名稱
    power {vccd1}       # 電源網路名稱
    ground {vssd1}      # 接地網路名稱
}]

# Standard cell grid configuration | 標準單元網格配置
pdngen::specify_grid stdcell {
    name grid
    rails {
        # Metal 1 電源軌道：寬度 0.48μm，間距 2.72μm
        met1 {width 0.48 pitch 2.72 offset 0}
    }
    straps {
        # Metal 4 電源條：寬度 1.6μm，間距 50μm，偏移 16.65μm
        met4 {width 1.6 pitch 50.0 offset 16.65}
        # Metal 5 電源條：寬度 1.6μm，間距 50μm，偏移 16.65μm
        met5 {width 1.6 pitch 50.0 offset 16.65}
    }
    # 金屬層連接：met1 連到 met4，met4 連到 met5
    connect {{met1 met4} {met4 met5}}
    # Power and ground pins for standard cells | 標準單元的電源和接地接腳
    power_pins "VPWR"
    ground_pins "VGND"
}

# Macro cell grid configuration | 巨集單元網格配置
pdngen::specify_grid macro {
    power_pins "VPWR"                            # 電源接腳名稱（標準單元的電源腳）
    ground_pins "VGND"                           # 接地接腳名稱（標準單元的接地腳）
    blockages "li1 met1 met2 met3 met4"          # 阻擋層（避免短路）
    straps {
        # Metal 4 電源條：寬度 1.6μm，間距 50μm，偏移 16.65μm
        met4 {width 1.6 pitch 50.0 offset 16.65}
        # Metal 5 電源條：寬度 1.6μm，間距 50μm，偏移 16.65μm
        met5 {width 1.6 pitch 50.0 offset 16.65}
    }
    # 金屬層連接：met4 連到 met5
    connect {{met4 met5}}
}

# Halo spacing around macros | 巨集周圍的保護間距
set ::halo 0

# PDN connections | PDN 連接設定
# 定義每個金屬層上的電源和接地網路連接
set ::connections [list \
    {met1 {$::power_nets $::ground_nets}} \     # Metal 1 層
    {met2 {$::power_nets $::ground_nets}} \     # Metal 2 層
    {met3 {$::power_nets $::ground_nets}} \     # Metal 3 層
    {met4 {$::power_nets $::ground_nets}} \     # Metal 4 層
    {met5 {$::power_nets $::ground_nets}} \     # Metal 5 層
]

# Global connections for standard cells | 標準單元的全域連接
# Map VPWR to vccd1 and VGND to vssd1 | 將 VPWR 映射到 vccd1，VGND 映射到 vssd1
add_global_connection -net {vccd1} -inst_pattern {.*} -pin_pattern {^VPWR$} -power
add_global_connection -net {vssd1} -inst_pattern {.*} -pin_pattern {^VGND$} -ground
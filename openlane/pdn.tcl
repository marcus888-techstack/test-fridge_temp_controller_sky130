# ==============================================================================
# File: pdn.tcl
# Description: Power Distribution Network configuration for OpenLane
# Target: SKY130 PDK
# Author: IC Design Team
# Date: 2024-12-19
# ==============================================================================

# Stdcell power pins
set ::power_nets $::env(VDD_NETS)
set ::ground_nets $::env(GND_NETS)

# Voltage domains
set ::voltage_domains [list {
    name {default}
    power {vccd1}
    ground {vssd1}
}]

pdngen::specify_grid stdcell {
    name grid
    rails {
        met1 {width 0.48 pitch 2.72 offset 0}
    }
    straps {
        met4 {width 1.6 pitch 50.0 offset 16.65}
        met5 {width 1.6 pitch 50.0 offset 16.65}
    }
    connect {{met1 met4} {met4 met5}}
}

pdngen::specify_grid macro {
    power_pins "VPWR"
    ground_pins "VGND"
    blockages "li1 met1 met2 met3 met4"
    straps {
        met4 {width 1.6 pitch 50.0 offset 16.65}
        met5 {width 1.6 pitch 50.0 offset 16.65}
    }
    connect {{met4 met5}}
}

set ::halo 0

# PDN connections
set ::connections [list \
    {met1 {$::power_nets $::ground_nets}} \
    {met2 {$::power_nets $::ground_nets}} \
    {met3 {$::power_nets $::ground_nets}} \
    {met4 {$::power_nets $::ground_nets}} \
    {met5 {$::power_nets $::ground_nets}} \
]
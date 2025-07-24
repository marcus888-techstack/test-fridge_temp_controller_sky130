# 物理設計指南與優化技巧

## 目錄

1. [SKY130 PDK 概述](#1-sky130-pdk-概述)
2. [Floorplan 策略](#2-floorplan-策略)
3. [電源規劃](#3-電源規劃)
4. [時脈樹合成](#4-時脈樹合成)
5. [佈局優化](#5-佈局優化)
6. [繞線策略](#6-繞線策略)
7. [DRC/LVS 調試](#7-drclvs-調試)
8. [時序優化技術](#8-時序優化技術)
9. [功耗優化](#9-功耗優化)
10. [晶片完成與驗證](#10-晶片完成與驗證)

## 1. SKY130 PDK 概述

### 1.1 製程特性

```
SKY130 關鍵參數：
- 製程節點：130nm
- 金屬層數：5層 (Local Interconnect + 5 Metal)
- 核心電壓：1.8V
- I/O 電壓：3.3V/5.0V
- 最小特徵尺寸：0.13μm
- 閘極密度：~200k gates/mm²
```

### 1.2 標準單元庫

```tcl
# SKY130 標準單元庫選擇
set LIB_TYPICAL "$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
set LIB_FAST    "$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ff_n40C_1v95.lib"
set LIB_SLOW    "$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__ss_100C_1v60.lib"

# 單元類型
# sky130_fd_sc_hd: High Density (最常用)
# sky130_fd_sc_hdll: High Density Low Leakage
# sky130_fd_sc_hs: High Speed
# sky130_fd_sc_ms: Medium Speed
# sky130_fd_sc_ls: Low Speed
```

### 1.3 設計規則概要

```
最小寬度/間距規則 (單位: μm)：
- Poly: 0.15 / 0.21
- Metal1: 0.14 / 0.14
- Metal2: 0.14 / 0.14
- Metal3: 0.30 / 0.30
- Metal4: 0.30 / 0.30
- Metal5: 1.60 / 1.60
- Via1: 0.15 × 0.15
- Via2: 0.20 × 0.20
- Via3: 0.20 × 0.20
- Via4: 0.80 × 0.80
```

## 2. Floorplan 策略

### 2.1 晶片規劃

```tcl
# OpenLane Floorplan 配置
set ::env(FP_SIZING) "absolute"
set ::env(DIE_AREA) "0 0 500 500"  # 500μm × 500μm
set ::env(CORE_AREA) "50 50 450 450"  # 留出 I/O 空間

# 利用率設定
set ::env(FP_CORE_UTIL) 40  # 40% 利用率
set ::env(FP_ASPECT_RATIO) 1  # 正方形

# I/O 配置
set ::env(FP_IO_MODE) 1  # 等間距模式
set ::env(FP_IO_HLENGTH) 4
set ::env(FP_IO_VLENGTH) 4
```

### 2.2 模組擺放策略

```tcl
# 手動擺放關鍵模組
proc custom_floorplan {} {
    # PID 控制器靠近中心（減少連線）
    place_macro -inst_name u_pid_controller \
                -origin {200 200} \
                -orientation R0
    
    # ADC 介面靠近相應 I/O
    place_macro -inst_name u_adc_interface \
                -origin {400 250} \
                -orientation R0
    
    # PWM 靠近輸出 pad
    place_macro -inst_name u_pwm_generator \
                -origin {100 250} \
                -orientation R0
    
    # 顯示控制器靠近顯示 I/O
    place_macro -inst_name u_display_ctrl \
                -origin {250 100} \
                -orientation R0
}

# 創建擺放阻擋區
create_placement_blockage -type hard \
    -bbox {150 150 350 350} \
    -name critical_logic_area
```

### 2.3 I/O 規劃

```tcl
# I/O 位置約束 (使用 pin_order.cfg)
#N
clk
rst_n
button_up
button_down
button_mode

#E  
adc_miso
adc_mosi
adc_sclk
adc_cs_n

#S
seven_seg[0]
seven_seg[1]
seven_seg[2]
seven_seg[3]
seven_seg[4]
seven_seg[5]
seven_seg[6]
digit_sel[0]
digit_sel[1]
digit_sel[2]
digit_sel[3]

#W
compressor_pwm
defrost_heater
alarm
status_led[0]
status_led[1]
status_led[2]
door_sensor
```

## 3. 電源規劃

### 3.1 電源網格設計

```tcl
# PDN (Power Distribution Network) 配置
set ::env(FP_PDN_ENABLE_RAILS) 1
set ::env(FP_PDN_RAILS_WIDTH) 0.48
set ::env(FP_PDN_RAIL_OFFSET) 0

# 電源環
set ::env(FP_PDN_CORE_RING) 1
set ::env(FP_PDN_CORE_RING_VWIDTH) 3.1
set ::env(FP_PDN_CORE_RING_HWIDTH) 3.1
set ::env(FP_PDN_CORE_RING_VSPACING) 1.6
set ::env(FP_PDN_CORE_RING_HSPACING) 1.6

# 電源條紋
set ::env(FP_PDN_VWIDTH) 1.6
set ::env(FP_PDN_HWIDTH) 1.6
set ::env(FP_PDN_VPITCH) 50
set ::env(FP_PDN_HPITCH) 50

# 使用的金屬層
set ::env(FP_PDN_LOWER_LAYER) met1
set ::env(FP_PDN_UPPER_LAYER) met5
```

### 3.2 去耦電容插入

```tcl
# 去耦電容策略
proc insert_decap_cells {} {
    # SKY130 去耦電容單元
    set decap_cells {
        sky130_fd_sc_hd__decap_12
        sky130_fd_sc_hd__decap_8
        sky130_fd_sc_hd__decap_6
        sky130_fd_sc_hd__decap_4
        sky130_fd_sc_hd__decap_3
    }
    
    # 在高活動區域增加去耦電容
    insert_decap -cells $decap_cells \
                 -density high \
                 -regions {pid_controller pwm_generator}
    
    # 填充剩餘空間
    insert_filler -cells {
        sky130_fd_sc_hd__fill_1
        sky130_fd_sc_hd__fill_2
        sky130_fd_sc_hd__fill_4
        sky130_fd_sc_hd__fill_8
    }
}
```

### 3.3 電源分析

```tcl
# IR Drop 分析設置
set power_analysis_config {
    # 功耗估算
    set avg_switching_activity 0.2
    set clock_frequency 10e6
    
    # 電流計算
    set dynamic_current [expr {$total_cap * $vdd * $clock_frequency * $avg_switching_activity}]
    set static_current [expr {$leakage_power / $vdd}]
    set total_current [expr {$dynamic_current + $static_current}]
    
    # IR Drop 限制
    set max_ir_drop [expr {$vdd * 0.05}]  # 5% of VDD
    
    # 檢查電源網格
    check_power_grid -current $total_current \
                     -ir_drop_limit $max_ir_drop
}
```

## 4. 時脈樹合成

### 4.1 CTS 策略

```tcl
# 時脈樹合成配置
set ::env(CLOCK_TREE_SYNTH) 1
set ::env(CTS_TARGET_SKEW) 100  # 100ps 目標偏斜
set ::env(CTS_ROOT_BUFFER) "sky130_fd_sc_hd__clkbuf_16"

# 時脈緩衝器選擇
set ::env(CTS_CLK_BUFFER_LIST) "sky130_fd_sc_hd__clkbuf_1 \
                                 sky130_fd_sc_hd__clkbuf_2 \
                                 sky130_fd_sc_hd__clkbuf_4 \
                                 sky130_fd_sc_hd__clkbuf_8 \
                                 sky130_fd_sc_hd__clkbuf_16"

# 時脈樹拓撲
set ::env(CTS_TECH_DIR) "N/A"
set ::env(CTS_MAX_WIRE_LENGTH) 0
set ::env(CTS_CLUSTERING_SIZE) 25
set ::env(CTS_CLUSTERING_MAX_DIAMETER) 50
```

### 4.2 時脈域處理

```tcl
# 定義時脈域
create_clock -name clk -period 100 [get_ports clk]
create_clock -name spi_clk -period 1000 [get_pins u_adc_interface/sclk]

# 設置時脈群組
set_clock_groups -exclusive \
    -group [get_clocks clk] \
    -group [get_clocks spi_clk]

# 時脈不確定性
set_clock_uncertainty -setup 0.15 [get_clocks clk]
set_clock_uncertainty -hold 0.1 [get_clocks clk]
```

### 4.3 時脈閘控實現

```tcl
# 整合時脈閘控單元插入
proc insert_clock_gates {} {
    # 識別時脈閘控機會
    identify_clock_gating_opportunities \
        -min_registers 4 \
        -max_fanout 32
    
    # 插入 ICG 單元
    insert_clock_gating \
        -cell sky130_fd_sc_hd__icgtp_1 \
        -global_clock clk
    
    # 驗證時脈閘控
    report_clock_gating -file reports/clock_gating.rpt
}
```

## 5. 佈局優化

### 5.1 全局佈局

```tcl
# 全局佈局設置
set ::env(PL_TARGET_DENSITY) 0.5  # 目標密度
set ::env(PL_TIME_DRIVEN) 1       # 時序驅動
set ::env(PL_ROUTABILITY_DRIVEN) 1  # 可繞性驅動

# 佈局優化選項
set ::env(PL_BASIC_PLACEMENT) 0
set ::env(PL_ESTIMATE_PARASITICS) 1
set ::env(PL_OPTIMIZE_MIRRORING) 1
set ::env(PL_RESIZER_DESIGN_OPTIMIZATIONS) 1
set ::env(PL_RESIZER_TIMING_OPTIMIZATIONS) 1
```

### 5.2 詳細佈局優化

```tcl
# 關鍵路徑優化
proc optimize_critical_paths {} {
    # 識別關鍵路徑
    set critical_paths [get_timing_paths -max_paths 10 -nworst 1]
    
    foreach path $critical_paths {
        # 獲取路徑上的單元
        set cells [get_cells -of_objects $path]
        
        # 優化策略
        foreach cell $cells {
            # 1. 單元大小調整
            size_cell $cell -lib_cell [get_higher_drive_cell $cell]
            
            # 2. 緩衝器插入
            if {[get_fanout $cell] > 4} {
                insert_buffer -cell sky130_fd_sc_hd__buf_4 \
                              -at_pin [get_pins $cell/Y]
            }
            
            # 3. 邏輯重組
            restructure_logic -cell $cell -effort high
        }
    }
}
```

### 5.3 擁塞緩解

```tcl
# 擁塞分析與緩解
proc mitigate_congestion {} {
    # 生成擁塞地圖
    report_congestion -routing_stage global
    
    # 識別擁塞區域
    set congested_regions [get_congested_regions -threshold 0.9]
    
    foreach region $congested_regions {
        # 降低局部密度
        set_attribute $region target_density 0.7
        
        # 增加繞線資源
        set_routing_channel -region $region -add_tracks 2
        
        # 分散高扇出網路
        spread_ports -region $region -effort high
    }
    
    # 重新佈局擁塞區域
    refine_placement -regions $congested_regions
}
```

## 6. 繞線策略

### 6.1 全局繞線

```tcl
# 全局繞線配置
set ::env(ROUTING_CORES) 4
set ::env(RT_MAX_LAYER) "met4"  # 限制使用層數
set ::env(RT_MIN_LAYER) "met1"

# 繞線策略
set ::env(GLOBAL_ROUTER) "fastroute"
set ::env(ROUTING_OPT_ITERS) 64  # 優化迭代次數

# DRC 驅動繞線
set ::env(DIODE_INSERTION_STRATEGY) 3
set ::env(GRT_REPAIR_ANTENNAS) 1
```

### 6.2 詳細繞線

```tcl
# 詳細繞線設置
set ::env(DETAILED_ROUTER) "tritonroute"
set ::env(DRT_MIN_LAYER) "li1"
set ::env(DRT_MAX_LAYER) "met4"
set ::env(DRT_OPT_ITERS) 64

# 繞線規則
proc setup_routing_rules {} {
    # 關鍵信號使用較寬金屬
    set_routing_rule -net {clk rst_n} \
                     -min_width 0.28 \
                     -min_spacing 0.28 \
                     -preferred_layer {met2 met3}
    
    # 電源網路規則
    set_routing_rule -net {VDD VSS} \
                     -min_width 3.0 \
                     -min_spacing 1.6 \
                     -use_layer {met1 met4 met5}
    
    # 高速信號屏蔽
    set_routing_rule -net {adc_data[*]} \
                     -shielding VSS \
                     -shield_width 0.28
}
```

### 6.3 天線效應修復

```tcl
# 天線規則檢查與修復
proc fix_antenna_violations {} {
    # SKY130 天線規則
    set antenna_ratio_limit 400
    
    # 檢查違規
    check_antennas -ratio $antenna_ratio_limit
    
    # 修復策略
    # 1. 插入天線二極體
    insert_diodes -cell sky130_fd_sc_hd__diode_2 \
                  -net_pattern {*} \
                  -violations_only
    
    # 2. 層跳躍
    foreach net [get_antenna_violations] {
        route_layer_jumping -net $net \
                           -max_length 100
    }
    
    # 3. 重新繞線
    reroute_nets -nets [get_antenna_violations] \
                 -effort high
}
```

## 7. DRC/LVS 調試

### 7.1 常見 DRC 違規及修復

```tcl
# DRC 違規類型與修復
proc fix_common_drc_violations {} {
    # 1. 最小間距違規
    set spacing_errors [get_drc_errors -type "spacing"]
    foreach error $spacing_errors {
        # 增加間距
        spread_wires -location $error -spacing 0.14
    }
    
    # 2. 最小寬度違規
    set width_errors [get_drc_errors -type "width"]
    foreach error $width_errors {
        # 加寬金屬線
        widen_wire -location $error -width 0.14
    }
    
    # 3. Via 覆蓋違規
    set via_errors [get_drc_errors -type "via_coverage"]
    foreach error $via_errors {
        # 增加冗餘 via
        add_redundant_via -location $error
    }
    
    # 4. 密度違規
    set density_errors [get_drc_errors -type "density"]
    foreach error $density_errors {
        # 添加填充圖形
        add_fill_shapes -region $error -layer [get_layer $error]
    }
}

# Magic DRC 腳本
tclsh << 'EOF'
# 載入設計
load temp_ctrl_top

# 執行 DRC
drc euclidean on
drc style drc(full)
drc check

# 生成錯誤報告
drc listall count
drc listall

# 互動式修復
drc find
EOF
```

### 7.2 LVS 調試流程

```tcl
# LVS 調試策略
proc debug_lvs_issues {} {
    # 1. 檢查短路
    set shorts [get_lvs_errors -type "shorts"]
    foreach short $shorts {
        puts "Short between nets: [get_nets $short]"
        # 可視化短路位置
        highlight_short -location $short
    }
    
    # 2. 檢查開路
    set opens [get_lvs_errors -type "opens"]
    foreach open $opens {
        puts "Open in net: [get_net $open]"
        # 追蹤斷開位置
        trace_open -net $open
    }
    
    # 3. 裝置不匹配
    set mismatches [get_lvs_errors -type "device_mismatch"]
    foreach mismatch $mismatches {
        puts "Device mismatch: $mismatch"
        # 比較網表
        compare_netlists -device $mismatch
    }
}

# Netgen LVS 腳本
set lvs_netgen_script {
    # 讀取文件
    readnet spice ../netlist/temp_ctrl_top.spice
    readnet verilog ../results/temp_ctrl_top.v
    
    # LVS 比較
    lvs {temp_ctrl_top} {temp_ctrl_top} \
        $PDK_ROOT/sky130A/libs.tech/netgen/sky130A_setup.tcl \
        reports/temp_ctrl_top.lvs.out -json
}
```

### 7.3 調試技巧集

```python
# DRC/LVS 自動調試腳本
import json
import re

class DRCLVSDebugger:
    def __init__(self, design_name):
        self.design = design_name
        self.drc_rules = self.load_drc_rules()
        
    def load_drc_rules(self):
        """載入 SKY130 DRC 規則"""
        return {
            'met1.1': {'desc': 'Metal1 width', 'min': 0.14},
            'met1.2': {'desc': 'Metal1 spacing', 'min': 0.14},
            'via.1': {'desc': 'Via size', 'min': 0.15},
            # ... 更多規則
        }
    
    def analyze_drc_report(self, report_file):
        """分析 DRC 報告"""
        violations = {}
        with open(report_file, 'r') as f:
            for line in f:
                match = re.search(r'(\w+\.\d+).*count:\s*(\d+)', line)
                if match:
                    rule = match.group(1)
                    count = int(match.group(2))
                    violations[rule] = count
        
        return violations
    
    def suggest_fixes(self, violations):
        """建議修復方案"""
        suggestions = []
        for rule, count in violations.items():
            if rule in self.drc_rules:
                suggestion = {
                    'rule': rule,
                    'description': self.drc_rules[rule]['desc'],
                    'count': count,
                    'fix': self.get_fix_suggestion(rule)
                }
                suggestions.append(suggestion)
        
        return suggestions
    
    def get_fix_suggestion(self, rule):
        """獲取具體修復建議"""
        fix_map = {
            'met1.1': 'Increase metal width to 0.14um',
            'met1.2': 'Increase spacing to 0.14um',
            'via.1': 'Use 0.15um x 0.15um via size',
            # ... 更多建議
        }
        return fix_map.get(rule, 'Check DRC manual')
```

## 8. 時序優化技術

### 8.1 時序分析設置

```tcl
# 時序約束
create_clock -period 100 -name clk [get_ports clk]
set_input_delay -clock clk -max 20 [all_inputs]
set_input_delay -clock clk -min 2 [all_inputs]
set_output_delay -clock clk -max 20 [all_outputs]
set_output_delay -clock clk -min 2 [all_outputs]

# 時序例外
set_false_path -from [get_ports rst_n]
set_multicycle_path -setup 2 -from [get_pins u_pid/integral_reg*/Q]

# 時序 derate
set_timing_derate -early 0.95
set_timing_derate -late 1.05
```

### 8.2 時序優化流程

```tcl
proc optimize_timing {} {
    # 1. 初始時序分析
    report_timing -max_paths 100 -file reports/timing_initial.rpt
    
    # 2. 識別關鍵路徑
    set critical_paths [get_timing_paths -slack_lesser_than 0 -max_paths 20]
    
    # 3. 優化技術應用
    foreach path $critical_paths {
        set slack [get_attribute $path slack]
        
        if {$slack < -1.0} {
            # 嚴重違規：考慮架構改變
            puts "CRITICAL: Path requires architectural change"
            suggest_pipeline_stage $path
        } elseif {$slack < -0.5} {
            # 中度違規：邏輯優化
            optimize_logic_depth $path
            upsize_cells $path
        } else {
            # 輕度違規：局部調整
            insert_buffers $path
            adjust_placement $path
        }
    }
    
    # 4. 驗證改善
    report_timing -max_paths 100 -file reports/timing_optimized.rpt
}

# 具體優化函數
proc upsize_cells {path} {
    set cells [get_cells -of_objects $path]
    foreach cell $cells {
        set current_ref [get_attribute $cell ref_name]
        set new_ref [get_stronger_cell $current_ref]
        if {$new_ref != ""} {
            size_cell $cell $new_ref
        }
    }
}
```

### 8.3 有用偏斜優化

```tcl
# 有用偏斜 (Useful Skew) 優化
proc apply_useful_skew {} {
    # 識別可受益於偏斜的路徑
    set paths [get_timing_paths -group clk -max_paths 1000]
    
    # 計算最佳偏斜值
    foreach path $paths {
        set launch_ff [get_attribute $path startpoint]
        set capture_ff [get_attribute $path endpoint]
        
        # 如果路徑有正 slack，可以增加 launch 延遲
        # 如果路徑有負 slack，可以減少 capture 延遲
        set optimal_skew [calculate_optimal_skew $path]
        
        # 應用偏斜
        set_clock_latency -source -rise $optimal_skew $launch_ff
    }
    
    # 重新平衡時脈樹
    balance_clock_tree -consider_useful_skew
}
```

## 9. 功耗優化

### 9.1 功耗分析

```tcl
# 功耗分析設置
set power_enable_analysis true
set power_analysis_mode time_based

# 活動率設置
set_switching_activity -input_ports 0.2
set_switching_activity -clock_nets 1.0
set_switching_activity -internal_nets 0.1

# 功耗報告
report_power -file reports/power.rpt \
             -hierarchy \
             -verbose
```

### 9.2 低功耗實現技術

```tcl
# 多閾值電壓優化
proc multi_vt_optimization {} {
    # 可用的閾值電壓單元
    set hvt_cells [get_lib_cells *_hvt]  # High VT (低漏電)
    set svt_cells [get_lib_cells *_svt]  # Standard VT
    set lvt_cells [get_lib_cells *_lvt]  # Low VT (高速)
    
    # 初始使用 HVT
    swap_cells -to_lib $hvt_cells
    
    # 關鍵路徑使用 LVT
    set critical_cells [get_cells -of [get_critical_paths]]
    swap_cells -cells $critical_cells -to_lib $lvt_cells
    
    # 中等關鍵路徑使用 SVT
    set medium_critical [get_cells -slack_less_than 0.5]
    swap_cells -cells $medium_critical -to_lib $svt_cells
    
    # 報告 VT 分佈
    report_threshold_voltage_distribution
}

# 時脈閘控插入
proc insert_clock_gating {} {
    set_clock_gating_style -sequential_cell latch \
                          -control_point before \
                          -control_signal scan_enable \
                          -observation_point true \
                          -positive_edge_logic {and} \
                          -negative_edge_logic {nor}
    
    insert_clock_gating -global \
                       -min_bitwidth 4 \
                       -max_fanout 32
    
    report_clock_gating -file reports/clock_gating.rpt
}
```

### 9.3 電源域實現

```tcl
# 電源域定義（如果需要）
proc create_power_domains {} {
    # 創建電源域
    create_power_domain PD_ALWAYS_ON -include_scope
    create_power_domain PD_SWITCHABLE
    
    # 指定模組到電源域
    set_scope_to_power_domain {u_ctrl_fsm u_reg_bank} PD_ALWAYS_ON
    set_scope_to_power_domain {u_pid_controller u_pwm_generator} PD_SWITCHABLE
    
    # 電源開關
    create_power_switch ps_main \
        -domain PD_SWITCHABLE \
        -input_supply VDD \
        -output_supply VDD_SW \
        -control_port SLEEP_N \
        -on_state {on_state input_supply {SLEEP_N}}
    
    # 隔離策略
    set_isolation iso_pid \
        -domain PD_SWITCHABLE \
        -isolation_power_net VDD \
        -isolation_ground_net VSS \
        -clamp_value 0 \
        -applies_to outputs
}
```

## 10. 晶片完成與驗證

### 10.1 最終 DRC/LVS

```bash
#!/bin/bash
# 最終驗證腳本

# DRC 檢查
echo "Running final DRC..."
magic -dnull -noconsole << EOF
load $DESIGN.mag
drc euclidean on
drc style drc(full)
drc check
drc catchup
drc count
quit
EOF

# LVS 檢查
echo "Running final LVS..."
netgen -batch lvs "$DESIGN.spice $DESIGN" \
              "$DESIGN.v $DESIGN" \
              $PDK_ROOT/sky130A/libs.tech/netgen/sky130A_setup.tcl \
              reports/final_lvs.out -json

# 天線檢查
echo "Running antenna check..."
magic -dnull -noconsole << EOF
load $DESIGN.mag
antennacheck
quit
EOF
```

### 10.2 密度與填充

```tcl
# 金屬密度填充
proc add_metal_fill {} {
    # SKY130 密度要求
    set density_rules {
        {met1 0.35 0.70}
        {met2 0.35 0.70}
        {met3 0.35 0.70}
        {met4 0.35 0.70}
        {met5 0.35 0.70}
    }
    
    foreach rule $density_rules {
        set layer [lindex $rule 0]
        set min_density [lindex $rule 1]
        set max_density [lindex $rule 2]
        
        # 添加填充
        add_fill_shapes -layer $layer \
                       -min_density $min_density \
                       -max_density $max_density \
                       -space_to_signal 0.5
    }
    
    # 驗證密度
    check_density -window_size 100 \
                  -step_size 50 \
                  -file reports/density.rpt
}
```

### 10.3 GDSII 生成

```tcl
# 最終 GDSII 輸出
proc generate_final_gds {} {
    # 設置 GDSII 選項
    set gds_options {
        -units 1000
        -precision 5
        -max_vertices 200
        -max_wire_segments 200
    }
    
    # 寫出 GDSII
    write_gds -output_file $::env(DESIGN_NAME).gds \
              -lib_name $::env(DESIGN_NAME) \
              -top_cell $::env(DESIGN_NAME) \
              {*}$gds_options
    
    # 驗證 GDSII
    read_gds $::env(DESIGN_NAME).gds
    
    # 生成 LEF
    write_lef -output_file $::env(DESIGN_NAME).lef \
              -tech_lef_file $::env(TECH_LEF)
    
    # 最終報告
    report_design -file reports/final_design.rpt
}
```

### 10.4 交付檢查清單

```markdown
## 晶片交付檢查清單

### 設計文件
- [ ] GDSII 文件
- [ ] LEF 文件  
- [ ] CDL netlist
- [ ] Verilog netlist
- [ ] SDF 時序文件
- [ ] LIB 時序模型

### 驗證報告
- [ ] DRC 清潔報告
- [ ] LVS 匹配報告
- [ ] 天線檢查報告
- [ ] 密度檢查報告
- [ ] ERC 報告

### 性能報告
- [ ] 時序報告 (setup/hold)
- [ ] 功耗分析報告
- [ ] 面積使用報告
- [ ] IR drop 分析

### 製造文件
- [ ] 層次對應表
- [ ] Pad 座標文件
- [ ] 測試向量
- [ ] 封裝規格

### 文檔
- [ ] 設計規格書
- [ ] 使用手冊
- [ ] 應用筆記
- [ ] 已知問題列表
```

## 11. 優化總結

### 11.1 關鍵優化點

1. **時序優化優先級**
   - 架構優化 > 邏輯優化 > 物理優化
   - 早期介入，後期微調

2. **功耗優化策略**
   - 時脈閘控是最有效的動態功耗優化
   - 多閾值電壓平衡速度與漏電

3. **DRC/LVS 預防**
   - 設計時考慮製造規則
   - 使用 DRC-clean 庫單元
   - 保持合理的設計裕度

### 11.2 最佳實踐建議

```python
# 優化決策樹
optimization_decision_tree = {
    "timing_violation": {
        "severe": ["pipeline", "architecture_change"],
        "moderate": ["logic_optimization", "sizing"],
        "minor": ["buffering", "placement_adjustment"]
    },
    "power_violation": {
        "dynamic": ["clock_gating", "switching_reduction"],
        "static": ["multi_vt", "power_gating"]
    },
    "area_violation": {
        "logic": ["resource_sharing", "logic_minimization"],
        "routing": ["layer_assignment", "congestion_reduction"]
    }
}
```

---

文件版本：1.0  
最後更新：2024-12-19  
作者：IC 設計團隊  
下一份文件：[問題排除與調試指南](../06_reference/01_troubleshooting.md)
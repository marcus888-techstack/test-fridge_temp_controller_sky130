# 📋 Yosys 合成指南

本文件詳細說明如何使用 Yosys 將 RTL 設計合成為 SKY130 標準元件網表。

## 🎯 合成目標

- 將 Verilog RTL 轉換為閘級網表
- 優化面積和時序
- 產生適合 OpenLane 的網表格式

## 🛠️ 環境準備

### 安裝 Yosys
```bash
# Ubuntu/Debian
sudo apt-get install yosys

# 或從源碼編譯最新版
git clone https://github.com/YosysHQ/yosys.git
cd yosys
make
sudo make install
```

### 設置 SKY130 PDK
```bash
export PDK_ROOT=/path/to/skywater-pdk
export STD_CELL_LIBRARY=sky130_fd_sc_hd
```

## 📁 專案結構

```
synthesis/
├── Makefile              # 自動化腳本
├── synth.tcl            # Yosys 合成腳本
├── constraints.sdc      # 時序約束
├── reports/             # 合成報告
└── results/             # 輸出網表
```

## 🔧 合成腳本詳解

### 基本合成流程 (synth.tcl)

```tcl
# 1. 讀取 Verilog 檔案
yosys read_verilog -sv ../rtl/temp_ctrl_top.v
yosys read_verilog -sv ../rtl/pid_controller.v
yosys read_verilog -sv ../rtl/adc_spi_interface.v
yosys read_verilog -sv ../rtl/pwm_generator.v

# 2. 設定頂層模組
yosys hierarchy -check -top temp_ctrl_top

# 3. 高階合成優化
yosys proc          # 處理 always 區塊
yosys opt           # 邏輯優化
yosys fsm           # 狀態機優化
yosys memory        # 記憶體推斷
yosys opt

# 4. 技術映射
yosys techmap       # 通用技術映射
yosys opt

# 5. SKY130 特定映射
yosys dfflibmap -liberty $::env(PDK_ROOT)/$::env(STD_CELL_LIBRARY)/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
yosys abc -liberty $::env(PDK_ROOT)/$::env(STD_CELL_LIBRARY)/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
yosys clean

# 6. 輸出網表
yosys write_verilog -noattr results/synth.v
```

## 📊 合成選項詳解

### 1. 面積優化
```tcl
# 使用更激進的優化
yosys opt -full
yosys share        # 共享子表達式
yosys opt_muxtree  # 優化多工器樹
```

### 2. 時序優化
```tcl
# ABC 時序導向優化
yosys abc -liberty $LIBERTY_FILE -constr constraints.sdc
```

### 3. 功耗優化
```tcl
# 插入時脈閘控
yosys clkgate -pos
```

## 📈 約束檔案 (constraints.sdc)

```tcl
# 時脈定義
create_clock -period 100 -name clk [get_ports clk]

# 輸入延遲
set_input_delay -clock clk -max 20 [get_ports {rst_n door_sensor button_*}]
set_input_delay -clock clk -min 5 [get_ports {rst_n door_sensor button_*}]

# 輸出延遲
set_output_delay -clock clk -max 20 [get_ports {compressor_pwm alarm}]
set_output_delay -clock clk -min 5 [get_ports {compressor_pwm alarm}]

# 不檢查的路徑
set_false_path -from [get_ports rst_n] -to [all_outputs]
```

## 🔍 分析合成結果

### 1. 面積報告
```bash
yosys -p "read_verilog synth.v; stat"
```

輸出範例：
```
=== temp_ctrl_top ===
   Number of wires:                892
   Number of wire bits:           2341
   Number of cells:               1523
     sky130_fd_sc_hd__a21o_2         12
     sky130_fd_sc_hd__a22o_2         34
     sky130_fd_sc_hd__and2_2         67
     sky130_fd_sc_hd__dfrtp_2       234
     ...
```

### 2. 時序分析
使用 OpenSTA 進行詳細時序分析：
```tcl
read_liberty $::env(LIBERTY_FILE)
read_verilog results/synth.v
link_design temp_ctrl_top
read_sdc constraints.sdc
report_checks -path_delay max
```

### 3. 功耗估算
```tcl
# 簡單功耗估算
yosys -p "read_verilog synth.v; power"
```

## 🚨 常見問題與解決

### 問題 1：找不到標準元件庫
```
ERROR: Can't open liberty file
```
**解決**：確認 PDK_ROOT 環境變數設置正確

### 問題 2：時序違規
```
Warning: Critical path delay exceeds clock period
```
**解決**：
1. 插入暫存器切割長路徑
2. 使用更快的標準元件
3. 調整合成策略

### 問題 3：面積過大
**解決**：
1. 共享資源（如乘法器）
2. 使用狀態機編碼優化
3. 移除未使用的邏輯

## 📝 Makefile 範例

```makefile
# synthesis/Makefile
PDK_ROOT ?= $(HOME)/skywater-pdk
STD_CELL_LIBRARY = sky130_fd_sc_hd

VERILOG_SRCS = ../rtl/*.v
TOP_MODULE = temp_ctrl_top

.PHONY: all synth clean

all: synth

synth:
	@mkdir -p results reports
	yosys -c synth.tcl | tee reports/synth.log
	@echo "Synthesis complete. Check reports/synth.log"

area:
	@yosys -p "read_verilog results/synth.v; stat" | tee reports/area.rpt

clean:
	rm -rf results reports

view:
	yosys -p "read_verilog results/synth.v; show -format svg -viewer firefox"
```

## 🎯 優化建議

### 1. 迭代優化流程
```tcl
# 多次優化迭代
for {set i 0} {$i < 3} {incr i} {
    yosys opt -full
    yosys share -aggressive
    yosys opt_muxtree
}
```

### 2. 特定模組優化
```tcl
# 針對 PID 控制器優化
yosys select pid_controller
yosys opt_expr -mux_undef
yosys select -clear
```

### 3. 使用不同的標準元件
根據需求選擇：
- `sky130_fd_sc_hd`: High Density（預設）
- `sky130_fd_sc_hdll`: High Density Low Leakage
- `sky130_fd_sc_hs`: High Speed
- `sky130_fd_sc_ms`: Medium Speed

## 🔗 下一步

合成完成後，進入 [OpenLane 流程](03_openlane_guide.md) 進行物理實現。

---

[返回實作文件](README.md) | [返回主目錄](../README.md)
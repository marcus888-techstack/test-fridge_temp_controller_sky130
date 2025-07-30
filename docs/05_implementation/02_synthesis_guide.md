# 📋 Yosys 合成指南

本文件詳細說明如何使用 Yosys 將 RTL 設計合成為 SKY130 標準元件網表。

## 🎯 合成目標

- 將 Verilog RTL 轉換為閘級網表
- 優化面積和時序
- 產生適合 OpenLane 的網表格式

## 🛠️ 環境準備

### 安裝 Yosys
```bash
# macOS (使用 Homebrew)
brew install yosys

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
# 本專案的 PDK 路徑
export PDK_ROOT=/Users/marcus/Documents/Projects/test-tech/doing/test-eda/fridge_temp_controller_sky130/pdk
export PDK_PATH=$PDK_ROOT/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A
export STD_CELL_LIBRARY=sky130_fd_sc_hd
```

## 📁 專案結構

```
synthesis/
├── synth_top.ys         # 主要 Yosys 合成腳本（含中文註解）
├── synth_top_clean.ys   # 清潔版合成腳本
├── simple_synth.tcl     # 簡化版合成腳本
├── constraints.sdc      # 時序約束
├── reports/             # 合成報告
│   └── synth_stat.txt   # 合成統計報告
└── output/              # 輸出網表
    ├── temp_ctrl_synthesized.v      # APR 用網表
    └── temp_ctrl_synthesized_sim.v  # 模擬用網表
```

## 🔧 合成腳本詳解

### Yosys 腳本 vs TCL 腳本差異

#### 1. **語法差異**

**Yosys 腳本 (.ys)**
- 使用 Yosys 原生命令
- 不支援變數和流程控制
- 簡單直接的命令序列

```yosys
# Yosys 原生語法範例
read_liberty -lib /path/to/library.lib
read_verilog design.v
hierarchy -check -top top_module
synth -top top_module
```

**TCL 腳本 (.tcl)**
- 使用 TCL 語言語法
- 支援變數、迴圈、條件判斷
- 可以使用 TCL 的所有功能

```tcl
# TCL 語法範例
set PDK_PATH "/path/to/pdk"
set LIBERTY_FILE "$PDK_PATH/library.lib"

# 可以使用條件判斷
if {[file exists $LIBERTY_FILE]} {
    yosys read_liberty -lib $LIBERTY_FILE
}

# 可以使用迴圈
foreach file [glob ../rtl/*.v] {
    yosys read_verilog $file
}
```

#### 2. **執行方式**

```bash
# Yosys 腳本執行
yosys script.ys          # 直接執行
yosys -s script.ys       # 使用 -s 參數

# TCL 腳本執行
yosys -c script.tcl      # 必須使用 -c 參數
```

#### 3. **功能比較**

| 特性 | Yosys 腳本 (.ys) | TCL 腳本 (.tcl) |
|------|------------------|-----------------|
| 語法複雜度 | 簡單 | 較複雜 |
| 變數支援 | ❌ | ✅ |
| 流程控制 | ❌ | ✅ (if/for/while) |
| 錯誤處理 | ❌ | ✅ (catch/try) |
| 函數定義 | ❌ | ✅ |
| 檔案操作 | 有限 | 完整 |
| 適用場景 | 固定流程 | 動態流程 |

#### 4. **選擇建議**

**使用 Yosys 腳本當：**
- 合成流程固定不變
- 不需要參數化
- 快速測試和原型開發

**使用 TCL 腳本當：**
- 需要根據條件執行不同流程
- 需要參數化設計
- 整合到自動化系統
- 需要錯誤處理和日誌記錄

### 實際使用的合成流程 (simple_synth.tcl)

```tcl
# 1. 讀取 Liberty 標準單元庫
read_liberty -lib /Users/marcus/Documents/Projects/test-tech/doing/test-eda/fridge_temp_controller_sky130/pdk/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# 2. 讀取所有 RTL 檔案
read_verilog ../rtl/temp_ctrl_top.v        # 頂層模組
read_verilog ../rtl/adc_spi_interface.v    # ADC SPI 介面
read_verilog ../rtl/pid_controller.v       # PID 控制器
read_verilog ../rtl/pwm_generator.v        # PWM 產生器
read_verilog ../rtl/display_controller.v   # 七段顯示器控制器

# 3. 展開設計階層
hierarchy -check -top temp_ctrl_top

# 4. 高階合成優化
proc          # 處理 always 區塊，轉換為內部表示
opt           # 第一次優化，移除冗餘邏輯
fsm           # 有限狀態機提取和優化
opt           # 第二次優化
memory        # 記憶體推斷（本設計無記憶體）
opt           # 第三次優化

# 5. 技術映射
techmap       # 將高階構造映射到基本邏輯閘
opt           # 映射後優化

# 6. Sky130 標準單元映射
# 映射觸發器到 Sky130 標準單元
dfflibmap -liberty /Users/marcus/Documents/Projects/test-tech/doing/test-eda/fridge_temp_controller_sky130/pdk/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# 使用 ABC 工具進行組合邏輯優化和映射
abc -liberty /Users/marcus/Documents/Projects/test-tech/doing/test-eda/fridge_temp_controller_sky130/pdk/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# 7. 清理未使用的單元
clean

# 8. 顯示統計資訊
stat

# 9. 輸出網表
write_verilog -noattr output/temp_ctrl_synthesized.v      # 無屬性網表（APR用）
write_verilog -noexpr output/temp_ctrl_synthesized_sim.v  # 展開表達式（模擬用）
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

### 1. 實際合成結果統計
```bash
# 執行合成
cd synthesis
yosys -s simple_synth.tcl
```

實際輸出結果：
```
=== temp_ctrl_top ===

   Number of wires:               2163
   Number of wire bits:           2636
   Number of public wires:          84
   Number of public wire bits:     293
   Number of ports:                 15
   Number of port bits:             53
   Number of memories:               0
   Number of memory bits:            0
   Number of processes:              0
   Number of cells:               2038
     sky130_fd_sc_hd__a2111oi_0      1
     sky130_fd_sc_hd__a2111oi_1      2
     sky130_fd_sc_hd__a2111o_1       3
     sky130_fd_sc_hd__a2111o_2       1
     sky130_fd_sc_hd__a211oi_1      17
     sky130_fd_sc_hd__a211oi_2       2
     sky130_fd_sc_hd__a211o_1       16
     sky130_fd_sc_hd__a211o_2        8
     sky130_fd_sc_hd__a21boi_0       5
     sky130_fd_sc_hd__a21bo_1        1
     sky130_fd_sc_hd__a21oi_1       50
     sky130_fd_sc_hd__a21oi_2        3
     sky130_fd_sc_hd__a21o_1        19
     sky130_fd_sc_hd__a21o_2         3
     sky130_fd_sc_hd__a221oi_1       8
     sky130_fd_sc_hd__a221o_1       10
     sky130_fd_sc_hd__a221o_2        1
     sky130_fd_sc_hd__a22oi_1       12
     sky130_fd_sc_hd__a22oi_2        2
     sky130_fd_sc_hd__a22o_1        11
     sky130_fd_sc_hd__a22o_2         1
     sky130_fd_sc_hd__a2bb2oi_1      1
     sky130_fd_sc_hd__a2bb2o_1       1
     sky130_fd_sc_hd__a311o_1        4
     sky130_fd_sc_hd__a311o_2        2
     sky130_fd_sc_hd__a31oi_1       11
     sky130_fd_sc_hd__a31o_1        17
     sky130_fd_sc_hd__a31o_2         1
     sky130_fd_sc_hd__a32o_1         8
     sky130_fd_sc_hd__a32o_2         1
     sky130_fd_sc_hd__a41oi_1        2
     sky130_fd_sc_hd__a41o_1         3
     sky130_fd_sc_hd__and2_0         2
     sky130_fd_sc_hd__and2_1        66
     sky130_fd_sc_hd__and2_2         5
     sky130_fd_sc_hd__and2b_1        6
     sky130_fd_sc_hd__and3_1        42
     sky130_fd_sc_hd__and3_2         2
     sky130_fd_sc_hd__and3b_1        1
     sky130_fd_sc_hd__and4_1        11
     sky130_fd_sc_hd__and4_2         1
     sky130_fd_sc_hd__and4bb_1       2
     sky130_fd_sc_hd__and4b_1        2
     sky130_fd_sc_hd__buf_1          4
     sky130_fd_sc_hd__buf_2          6
     sky130_fd_sc_hd__conb_1         1
     sky130_fd_sc_hd__dfrtp_1       10
     sky130_fd_sc_hd__dfrtp_2      435
     sky130_fd_sc_hd__dfrtp_4       78
     sky130_fd_sc_hd__inv_1        181
     sky130_fd_sc_hd__inv_2         29
     sky130_fd_sc_hd__mux2_1       158
     sky130_fd_sc_hd__mux2_2         5
     sky130_fd_sc_hd__mux4_1        23
     sky130_fd_sc_hd__mux4_2         2
     sky130_fd_sc_hd__nand2_1      125
     sky130_fd_sc_hd__nand2_2        1
     sky130_fd_sc_hd__nand2b_1       3
     sky130_fd_sc_hd__nand3_1       14
     sky130_fd_sc_hd__nand3b_1       5
     sky130_fd_sc_hd__nand4_1        4
     sky130_fd_sc_hd__nor2_1       113
     sky130_fd_sc_hd__nor2_2         5
     sky130_fd_sc_hd__nor2b_1        8
     sky130_fd_sc_hd__nor3_1        10
     sky130_fd_sc_hd__nor3_2         1
     sky130_fd_sc_hd__nor3b_1        2
     sky130_fd_sc_hd__nor4_1         2
     sky130_fd_sc_hd__nor4b_1        2
     sky130_fd_sc_hd__o2111ai_1      1
     sky130_fd_sc_hd__o2111a_1       2
     sky130_fd_sc_hd__o211ai_1      12
     sky130_fd_sc_hd__o211ai_2       1
     sky130_fd_sc_hd__o211a_1       12
     sky130_fd_sc_hd__o211a_2        6
     sky130_fd_sc_hd__o21ai_0       25
     sky130_fd_sc_hd__o21ai_1       23
     sky130_fd_sc_hd__o21ai_2        1
     sky130_fd_sc_hd__o21a_1        17
     sky130_fd_sc_hd__o21a_2         1
     sky130_fd_sc_hd__o21bai_1       2
     sky130_fd_sc_hd__o21ba_1        2
     sky130_fd_sc_hd__o221ai_1       2
     sky130_fd_sc_hd__o221a_1        5
     sky130_fd_sc_hd__o221a_2        2
     sky130_fd_sc_hd__o22ai_1        6
     sky130_fd_sc_hd__o22a_1         6
     sky130_fd_sc_hd__o22a_2         1
     sky130_fd_sc_hd__o2bb2ai_1      1
     sky130_fd_sc_hd__o2bb2a_1       3
     sky130_fd_sc_hd__o311a_1        3
     sky130_fd_sc_hd__o31ai_1        1
     sky130_fd_sc_hd__o31ai_2        2
     sky130_fd_sc_hd__o31a_1         7
     sky130_fd_sc_hd__o31a_2         1
     sky130_fd_sc_hd__o32a_1         3
     sky130_fd_sc_hd__o41a_1         3
     sky130_fd_sc_hd__or2_1         16
     sky130_fd_sc_hd__or2_2          7
     sky130_fd_sc_hd__or2b_1         2
     sky130_fd_sc_hd__or3_1         15
     sky130_fd_sc_hd__or3_2          1
     sky130_fd_sc_hd__or4_1          5
     sky130_fd_sc_hd__or4_2          1
     sky130_fd_sc_hd__or4b_1         1
     sky130_fd_sc_hd__xnor2_1        4
     sky130_fd_sc_hd__xor2_1         6

   Chip area for module '\temp_ctrl_top': 14773.564800
```

### 2. 關鍵指標分析
- **總單元數量**: 2,038 個
- **觸發器數量**: 523 個 (各種 dfrtp 類型)
- **組合邏輯**: 1,515 個
- **晶片面積**: 14773.564800 平方微米

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

### 問題 1：Yosys 變數語法錯誤
```
ERROR: No such command: set (type 'help' for a command overview)
```
**解決**：Yosys 不支援 Tcl 的 set 命令，直接使用完整路徑

### 問題 2：記憶體轉換警告
```
Warning: Replacing memory \digit_value with list of registers
```
**解決**：這是正常行為，小型陣列會被轉換為獨立暫存器

### 問題 3：Echo 命令錯誤
```
ERROR: Command syntax error: Unexpected argument
```
**解決**：將 echo 命令移除或使用 Yosys 內建的 log 命令

### 問題 4：路徑問題
**解決**：
1. 使用絕對路徑而非相對路徑
2. 確認 PDK 安裝位置正確
3. 檢查檔案權限

## 📝 實際使用的執行命令

### 執行合成
```bash
cd synthesis
yosys -s simple_synth.tcl
```

### 檢視合成結果
```bash
# 查看統計資訊
yosys -p "read_verilog output/temp_ctrl_synthesized.v; stat"

# 圖形化顯示（需要 graphviz）
yosys -p "read_verilog output/temp_ctrl_synthesized.v; show -format dot -viewer dot"
```

### 輸出檔案說明
- `temp_ctrl_synthesized.v`: 用於 APR（自動佈局佈線）的網表
- `temp_ctrl_synthesized_sim.v`: 用於後合成模擬的網表

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

### 3. Sky130 標準單元庫說明
本專案使用 `sky130_fd_sc_hd` (High Density) 庫：
- **優點**: 面積最小，適合大部分數位設計
- **時序**: tt_025C_1v80 (typical-typical, 25°C, 1.8V)
- **單元類型**: 包含基本邏輯閘、觸發器、多工器等

其他可用的庫：
- `sky130_fd_sc_hdll`: High Density Low Leakage（低漏電）
- `sky130_fd_sc_hs`: High Speed（高速度）
- `sky130_fd_sc_ms`: Medium Speed（中等速度）
- `sky130_fd_sc_ls`: Low Speed（低速度）

## 💡 學習資源

### Yosys 官方資源
- [Yosys 官方文檔](https://yosyshq.readthedocs.io/)
- [Yosys GitHub](https://github.com/YosysHQ/yosys)
- [Yosys 命令參考](https://yosyshq.readthedocs.io/projects/yosys/en/latest/cmd_ref.html)

### Sky130 PDK 資源
- [Sky130 PDK 文檔](https://skywater-pdk.readthedocs.io/)
- [標準單元庫規格](https://skywater-pdk.readthedocs.io/en/main/contents/libraries/sky130_fd_sc_hd/docs/user_guide.html)

### 教學資源
- [FOSSi Foundation - Yosys 教學](https://www.youtube.com/watch?v=HUUZbxbSDI8)
- [Digital VLSI Design RTL2GDS](https://github.com/kunalg123/sky130RTLDesignAndSynthesisWorkshop)

## 🔗 下一步

合成完成後，進入 [OpenLane 流程](03_openlane_guide.md) 進行物理實現。

---

[返回實作文件](README.md) | [返回主目錄](../README.md)
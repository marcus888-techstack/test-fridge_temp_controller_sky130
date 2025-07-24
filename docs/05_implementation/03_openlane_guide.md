# 🚀 OpenLane 自動化流程指南

本文件說明如何使用 OpenLane 將合成後的網表實現為 GDSII 佈局。

## 🎯 OpenLane 簡介

OpenLane 是一個完整的 RTL-to-GDSII 自動化流程，整合了多個開源 EDA 工具：
- Yosys (合成)
- OpenROAD (布局、擺放、繞線)
- Magic (DRC、LVS、GDSII 產生)
- KLayout (檢視與驗證)

## 🛠️ 環境設置

### 1. 安裝 OpenLane
```bash
# 使用 Docker（推薦）
git clone https://github.com/The-OpenROAD-Project/OpenLane.git
cd OpenLane
make
```

### 2. 設置環境變數
```bash
export OPENLANE_ROOT=/path/to/OpenLane
export PDK_ROOT=$OPENLANE_ROOT/pdks
export PDK=sky130A
```

## 📁 專案結構

```
openlane/
├── temp_controller/
│   ├── config.json          # 主要配置檔
│   ├── pin_order.cfg        # 接腳配置
│   ├── macro_placement.cfg  # 巨集擺放
│   └── src/
│       ├── temp_ctrl_top.v  # 設計檔案
│       └── constraints.sdc  # 時序約束
├── runs/                    # 執行結果
└── scripts/                 # 自定義腳本
```

## 🔧 配置檔詳解

### config.json
```json
{
    "DESIGN_NAME": "temp_ctrl_top",
    "VERILOG_FILES": "dir::src/*.v",
    "CLOCK_PERIOD": 100,
    "CLOCK_PORT": "clk",
    
    "FP_SIZING": "relative",
    "DIE_AREA": "0 0 500 500",
    "FP_CORE_UTIL": 40,
    "FP_ASPECT_RATIO": 1,
    
    "SYNTH_STRATEGY": "DELAY 0",
    "SYNTH_MAX_FANOUT": 6,
    
    "PL_TARGET_DENSITY": 0.5,
    "PL_RANDOM_GLB_PLACEMENT": 1,
    
    "ROUTING_CORES": 8,
    "RT_MAX_LAYER": "met4",
    
    "DIODE_INSERTION_STRATEGY": 3,
    "RUN_CVC": 1,
    
    "MAGIC_EXT_USE_GDS": 1,
    "RUN_MAGIC_DRC": 1,
    "RUN_KLAYOUT_DRC": 1
}
```

## 📊 執行流程

### 1. 互動模式執行
```bash
cd $OPENLANE_ROOT
make mount
```

在 OpenLane 容器內：
```tcl
./flow.tcl -interactive

# 載入套件
package require openlane 0.9

# 準備設計
prep -design temp_controller

# 執行合成
run_synthesis

# 執行布局規劃
run_floorplan

# 執行擺放
run_placement

# 執行時脈樹合成
run_cts

# 執行繞線
run_routing

# 產生 GDSII
run_magic

# 執行 DRC
run_magic_drc
run_klayout_drc

# 執行 LVS
run_lvs
```

### 2. 自動模式執行
```bash
./flow.tcl -design temp_controller
```

## 🔍 關鍵步驟詳解

### 1. 布局規劃 (Floorplan)
```tcl
# 設定晶片尺寸
set ::env(DIE_AREA) "0 0 500 500"

# 設定核心利用率
set ::env(FP_CORE_UTIL) 40

# 設定 IO 間距
set ::env(FP_IO_VEXTEND) 2
set ::env(FP_IO_HEXTEND) 2
```

### 2. 電源網路
```tcl
# 電源環設定
set ::env(FP_PDN_VWIDTH) 1.6
set ::env(FP_PDN_HWIDTH) 1.6
set ::env(FP_PDN_VSPACING) 3.4
set ::env(FP_PDN_HSPACING) 3.4
```

### 3. 擺放優化
```tcl
# 全域擺放
set ::env(PL_TARGET_DENSITY) 0.5

# 詳細擺放
set ::env(PL_RESIZER_DESIGN_OPTIMIZATIONS) 1
set ::env(PL_RESIZER_TIMING_OPTIMIZATIONS) 1
```

### 4. 時脈樹合成
```tcl
# CTS 目標
set ::env(CTS_TARGET_SKEW) 200
set ::env(CTS_TOLERANCE) 50
set ::env(CTS_CLK_BUFFER_LIST) "sky130_fd_sc_hd__clkbuf_4 sky130_fd_sc_hd__clkbuf_8"
```

### 5. 繞線策略
```tcl
# 全域繞線
set ::env(GLB_RT_ADJUSTMENT) 0.3

# 詳細繞線
set ::env(DRT_OPT_ITERS) 64
set ::env(ROUTING_CORES) 8
```

## 📈 結果分析

### 1. 面積報告
```bash
# 查看面積使用
cat runs/*/reports/synthesis/1-synthesis.stat.rpt
```

### 2. 時序報告
```bash
# 最差路徑分析
cat runs/*/reports/synthesis/2-sta.timing.rpt
```

### 3. 功耗分析
```bash
# 功耗估算
cat runs/*/reports/synthesis/2-sta.power.rpt
```

### 4. DRC 報告
```bash
# Magic DRC
cat runs/*/reports/magic/magic.drc

# KLayout DRC
cat runs/*/reports/klayout/klayout.drc
```

## 🎨 視覺化工具

### 1. 使用 KLayout 檢視
```bash
klayout runs/*/results/final/gds/temp_ctrl_top.gds
```

### 2. 使用 Magic 檢視
```bash
magic -T $PDK_ROOT/sky130A/libs.tech/magic/sky130A.tech \
      runs/*/results/final/mag/temp_ctrl_top.mag
```

### 3. 3D 視覺化
```bash
# 使用 GDS3D
gds3d runs/*/results/final/gds/temp_ctrl_top.gds
```

## 🚨 常見問題處理

### 問題 1：DRC 違規
```
[ERROR]: There are violations in the design after Magic DRC!
```
**解決方案**：
1. 檢查 DRC 報告定位問題
2. 調整布局密度
3. 修改繞線參數

### 問題 2：時序違規
```
[ERROR]: Setup time violations detected
```
**解決方案**：
1. 增加緩衝器
2. 調整時脈樹
3. 優化關鍵路徑

### 問題 3：繞線擁塞
```
[ERROR]: Routing congestion in region
```
**解決方案**：
1. 降低擺放密度
2. 增加繞線層
3. 調整宏塊位置

## 📝 自定義優化腳本

### 時序優化腳本
```tcl
# scripts/timing_opt.tcl
proc optimize_timing {} {
    # 插入緩衝器
    insert_buffer -net [get_nets critical_net*]
    
    # 調整驅動強度
    resize_cell -cell [get_cells slow_cell*] -lib_cell sky130_fd_sc_hd__buf_4
    
    # 重新時序分析
    report_timing -path_type full_clock_expanded
}
```

### 功耗優化腳本
```tcl
# scripts/power_opt.tcl
proc optimize_power {} {
    # 時脈閘控
    insert_clock_gating
    
    # 降低非關鍵路徑驅動
    downsize_cell -cell [get_cells non_critical*]
}
```

## 🎯 最佳實踐

### 1. 迭代優化
```bash
# 執行多次優化迭代
for i in {1..3}; do
    ./flow.tcl -design temp_controller -tag iteration_$i
    # 分析結果並調整參數
done
```

### 2. 參數掃描
```python
# 參數掃描腳本
import subprocess
import json

densities = [0.4, 0.45, 0.5, 0.55]
for density in densities:
    config = json.load(open("config.json"))
    config["PL_TARGET_DENSITY"] = density
    json.dump(config, open("config_sweep.json", "w"))
    subprocess.run(["./flow.tcl", "-design", "temp_controller", 
                    "-config_file", "config_sweep.json",
                    "-tag", f"density_{density}"])
```

### 3. 結果比較
```bash
# 比較不同執行的結果
python3 $OPENLANE_ROOT/scripts/compare_runs.py \
    --designs temp_controller \
    --tags iteration_1,iteration_2,iteration_3 \
    --metrics area,timing,power
```

## 🔗 相關資源

- [OpenLane 官方文件](https://openlane.readthedocs.io/)
- [OpenROAD 專案](https://theopenroadproject.org/)
- [SKY130 設計規則](https://skywater-pdk.readthedocs.io/en/main/rules.html)

## 下一步

完成 OpenLane 流程後：
1. 進行完整的 DRC/LVS 驗證
2. 執行後模擬驗證
3. 準備 Tape-out 文件

---

[返回實作文件](README.md) | [返回主目錄](../README.md)
# 冰箱溫度控制器 IC 設計教學

本教學將引導您完成從 RTL 到 GDSII 的完整數位 IC 設計流程。

## 目錄

1. [環境設置](#1-環境設置)
2. [RTL 設計與驗證](#2-rtl-設計與驗證)
3. [邏輯合成](#3-邏輯合成)
4. [OpenLane 實體設計](#4-openlane-實體設計)
5. [驗證與分析](#5-驗證與分析)
6. [常見問題](#6-常見問題)

## 1. 環境設置

### 1.1 必要工具安裝

#### Ubuntu/Debian 系統

```bash
# 基礎開發工具
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    git \
    python3 \
    python3-pip \
    tcl \
    tk

# RTL 開發工具
sudo apt-get install -y \
    iverilog \
    gtkwave \
    verilator

# 合成工具
sudo apt-get install -y \
    yosys

# 其他實用工具
sudo apt-get install -y \
    make \
    vim \
    nano
```

### 1.2 SKY130 PDK 安裝

```bash
# 設置環境變數
export PDK_ROOT=$HOME/pdk
export PDK=sky130A

# 下載 PDK
cd $HOME
git clone https://github.com/google/skywater-pdk.git
cd skywater-pdk
git submodule update --init libraries/sky130_fd_sc_hd/latest

# 下載 open_pdks
cd $HOME
git clone https://github.com/RTimothyEdwards/open_pdks.git
cd open_pdks
./configure --enable-sky130-pdk=$HOME/skywater-pdk/libraries
make
make install
```

### 1.3 OpenLane 安裝

```bash
# 下載 OpenLane
cd $HOME
git clone https://github.com/The-OpenROAD-Project/OpenLane.git
cd OpenLane

# 使用 Docker（推薦）
make

# 或本地安裝
make dependencies
make pdk
make openlane
```

### 1.4 環境變數設置

將以下內容加入 `~/.bashrc`：

```bash
# PDK 設置
export PDK_ROOT=$HOME/pdk
export PDK=sky130A

# OpenLane 設置
export OPENLANE_ROOT=$HOME/OpenLane
export PATH=$PATH:$OPENLANE_ROOT

# 專案路徑
export PROJECT_ROOT=$HOME/fridge_temp_controller_sky130
```

## 2. RTL 設計與驗證

### 2.1 專案結構

```
fridge_temp_controller_sky130/
├── docs/               # 文件
├── rtl/               # RTL 原始碼
├── testbench/         # 測試平台
├── synthesis/         # 合成腳本
├── openlane/          # OpenLane 配置
└── results/           # 輸出結果
```

### 2.2 RTL 模組說明

#### 頂層模組 (temp_ctrl_top.v)
- 整合所有子模組
- 管理系統狀態機
- 處理使用者介面

#### ADC SPI 介面 (adc_spi_interface.v)
- 實現 SPI 協定
- 讀取溫度感測器資料
- 12-bit 解析度

#### PID 控制器 (pid_controller.v)
- 16-bit 定點運算
- 比例、積分、微分控制
- 抗積分飽和

#### PWM 產生器 (pwm_generator.v)
- 10-bit 解析度
- 1 kHz 頻率
- 軟啟動功能

#### 顯示控制器 (display_controller.v)
- 七段顯示器驅動
- 多工掃描
- BCD 轉換

### 2.3 RTL 模擬

#### 編譯和執行測試

```bash
cd $PROJECT_ROOT/testbench

# 執行頂層測試
make sim_top

# 執行 PID 測試
make sim_pid

# 查看波形
make wave_top
```

#### 使用互動式腳本

```bash
cd $PROJECT_ROOT/testbench
./run_sim.sh
```

### 2.4 驗證檢查清單

- [ ] 功能正確性
  - [ ] 溫度讀取準確
  - [ ] PID 控制穩定
  - [ ] PWM 輸出正確
  - [ ] 顯示正常
- [ ] 時序要求
  - [ ] 無 setup/hold 違規
  - [ ] 時脈頻率達標
- [ ] 程式碼品質
  - [ ] Lint 檢查通過
  - [ ] 無 latch
  - [ ] 無組合迴路

## 3. 邏輯合成

### 3.1 Yosys 合成流程

#### 執行合成

```bash
cd $PROJECT_ROOT/synthesis
./run_synthesis.sh
```

#### 手動執行 Yosys

```bash
cd $PROJECT_ROOT/synthesis
yosys

# 在 Yosys 內執行
yosys> script synth_top.ys
```

### 3.2 合成結果分析

檢查輸出報告：

```bash
# 查看統計資訊
cat reports/synth_stat.txt

# 查看面積報告
cat reports/synth_area.txt

# 查看時序報告
cat reports/synth_timing.txt
```

### 3.3 優化建議

1. **面積優化**
   - 使用資源共享
   - 減少暫存器數量
   - 優化邏輯表達式

2. **時序優化**
   - 增加管線階段
   - 減少關鍵路徑邏輯
   - 使用更快的邏輯結構

3. **功耗優化**
   - 時脈閘控
   - 運算閘控
   - 減少切換活動

## 4. OpenLane 實體設計

### 4.1 配置說明

主要配置檔案：
- `config.json` - 主要配置
- `base.sdc` - 時序約束
- `pdn.tcl` - 電源網格
- `pin_order.cfg` - 引腳配置

### 4.2 執行 OpenLane

#### 完整流程

```bash
cd $PROJECT_ROOT/openlane
./run_openlane.sh

# 選擇 1 執行完整流程
```

#### 互動模式

```bash
cd $OPENLANE_ROOT
./flow.tcl -interactive

# OpenLane 命令
prep -design $PROJECT_ROOT/openlane
run_synthesis
run_floorplan
run_placement
run_cts
run_routing
run_magic
run_lvs
run_drc
```

### 4.3 各階段說明

#### 4.3.1 Synthesis (合成)
- 將 RTL 轉換為 gate-level netlist
- 優化時序、面積、功耗

#### 4.3.2 Floorplan (平面規劃)
- 定義晶片尺寸
- 放置 I/O pads
- 規劃電源網格

#### 4.3.3 Placement (放置)
- 標準單元放置
- 優化線長
- 滿足時序要求

#### 4.3.4 CTS (時脈樹合成)
- 建立時脈分配網路
- 平衡時脈偏斜
- 插入時脈緩衝器

#### 4.3.5 Routing (繞線)
- 全局繞線
- 詳細繞線
- 優化寄生效應

#### 4.3.6 Final Steps
- DRC 檢查
- LVS 驗證
- GDSII 生成

### 4.4 結果檢視

```bash
# 查看最新運行結果
cd runs/
ls -la

# 使用 Magic 查看佈局
magic -T $PDK_ROOT/sky130A/libs.tech/magic/sky130A.tech \
      runs/[latest_run]/results/magic/temp_ctrl_top.gds

# 使用 KLayout 查看
klayout runs/[latest_run]/results/magic/temp_ctrl_top.gds
```

## 5. 驗證與分析

### 5.1 DRC (設計規則檢查)

```bash
# 使用 Magic 進行 DRC
cd runs/[latest_run]/results/magic/
magic -T $PDK_ROOT/sky130A/libs.tech/magic/sky130A.tech

# 在 Magic 中
% load temp_ctrl_top
% drc check
% drc why
```

### 5.2 LVS (佈局與電路圖比對)

```bash
# 檢查 LVS 報告
cd runs/[latest_run]/results/lvs/
cat temp_ctrl_top.lvs.log

# 成功的 LVS 應顯示
# "Circuits match uniquely."
```

### 5.3 時序分析

```bash
# 查看時序報告
cd runs/[latest_run]/reports/
cat synthesis/opensta_timing.rpt

# 檢查 setup/hold 時間
grep -i "slack" *.rpt
```

### 5.4 功耗分析

```bash
# 查看功耗報告
cat runs/[latest_run]/reports/power.rpt

# 關鍵指標：
# - Total Power
# - Dynamic Power
# - Leakage Power
```

## 6. 常見問題

### 6.1 RTL 模擬問題

**Q: 模擬無法執行**
```bash
# 檢查 iverilog 安裝
which iverilog

# 檢查檔案路徑
ls -la ../rtl/*.v
```

**Q: 波形無法顯示**
```bash
# 檢查 GTKWave 安裝
which gtkwave

# 確認 VCD 檔案生成
ls -la work/*.vcd
```

### 6.2 合成問題

**Q: Yosys 找不到 liberty 檔案**
```bash
# 創建符號連結
ln -s $PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib \
      ../libs/
```

**Q: 合成失敗**
```bash
# 檢查語法錯誤
yosys -p "read_verilog ../rtl/*.v; hierarchy -check"
```

### 6.3 OpenLane 問題

**Q: OpenLane 無法啟動**
```bash
# 檢查 Docker
docker --version
docker ps

# 重新安裝
cd $OPENLANE_ROOT
make clean
make
```

**Q: 時序違規**
```bash
# 調整時脈週期
# 在 config.json 中修改
"CLOCK_PERIOD": 120,  # 增加到 120ns
```

**Q: DRC 違規**
```bash
# 檢查具體違規
magic -T $PDK_ROOT/sky130A/libs.tech/magic/sky130A.tech

# 常見修復：
# - 調整 FP_CORE_UTIL
# - 修改 PL_TARGET_DENSITY
```

## 總結

完成以上步驟後，您將獲得：

1. **RTL 檔案** - 完整的 Verilog 設計
2. **測試報告** - 功能驗證結果
3. **合成網表** - Gate-level netlist
4. **GDSII 檔案** - 可製造的晶片佈局
5. **驗證報告** - DRC/LVS 結果

### 下一步

1. **優化設計**
   - 減少面積
   - 提高頻率
   - 降低功耗

2. **增加功能**
   - 無線通訊
   - 雲端連接
   - AI 預測

3. **準備製造**
   - 完整驗證
   - 測試向量
   - 封裝設計

---

如有任何問題，請參考專案文檔或聯繫開發團隊。

祝您設計順利！
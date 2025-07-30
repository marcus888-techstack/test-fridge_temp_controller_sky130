# OpenLane Docker 模式執行指南

## 🚀 快速開始 (Docker 模式)

### 1. 安裝 OpenLane (Docker)
```bash
# 克隆 OpenLane
git clone --depth 1 https://github.com/The-OpenROAD-Project/OpenLane.git
cd OpenLane

# 拉取 Docker 映像並設置環境
make pull-openlane
make pdk
```

### 2. 執行流程

#### 方法一：自動模式 (推薦)
```bash
cd OpenLane
make mount

# 在 Docker 容器內執行
./flow.tcl -design /openlane/designs/fridge_temp_controller_sky130/openlane -tag run_$(date +%Y%m%d_%H%M%S)
```

#### 方法二：互動模式 (除錯用)
```bash
cd OpenLane
make mount

# 在 Docker 容器內執行
./flow.tcl -interactive

# 在 OpenLane shell 中逐步執行：
package require openlane 0.9
prep -design /openlane/designs/fridge_temp_controller_sky130/openlane -tag manual

run_synthesis
run_floorplan
run_placement
run_cts
run_routing
run_magic
run_magic_drc
run_klayout_drc
run_lvs
```

#### 方法三：從主機直接執行
```bash
# 從專案根目錄執行
cd /path/to/fridge_temp_controller_sky130
docker run -it -v $(pwd):/openlane/designs/temp_controller \
  -v $HOME/.volare:/home/tool/.volare \
  -e PDK=sky130A \
  efabless/openlane:latest \
  ./flow.tcl -design /openlane/designs/temp_controller/openlane
```

## 📁 檔案結構

```
openlane/
├── config.json         # 主要配置檔（已調整）
├── src/               # RTL 源檔案
│   ├── temp_ctrl_top.v
│   ├── adc_spi_interface.v
│   ├── pid_controller.v
│   ├── pwm_generator.v
│   └── display_controller.v
├── base.sdc           # 時序約束
├── pdn.tcl           # 電源網路配置
├── pin_order.cfg     # 接腳配置
└── runs/             # 執行結果（執行後產生）
```

## 🔧 重要參數

### config.json 中的關鍵設定：
- **DIE_AREA**: "0 0 300 300" (300x300 微米)
- **CORE_AREA**: "10 10 290 290" 
- **FP_CORE_UTIL**: 35% (核心利用率)
- **CLOCK_PERIOD**: 100 ns (10 MHz)
- **PL_TARGET_DENSITY**: 0.5

## 📊 預期結果

基於合成結果：
- 單元數量：~2,038
- 面積：~14,773 平方微米
- 觸發器：~523

## 🔍 結果位置

執行完成後，檢查以下檔案：
- GDSII: `runs/<tag>/results/magic/<design_name>.gds`
- DEF: `runs/<tag>/results/routing/<design_name>.def`
- 時序報告: `runs/<tag>/reports/synthesis/synthesis.stat.rpt`
- DRC 報告: `runs/<tag>/reports/magic/magic.drc`

## ⚠️ 注意事項

1. 確保已安裝 Docker（OpenLane 需要）
2. 首次執行可能需要下載 Docker 映像
3. 完整流程可能需要 30-60 分鐘
4. 確保有足夠的磁碟空間（至少 10GB）

## 🐳 Docker Compose 方式（最簡單）

```bash
# 啟動 OpenLane 容器
docker-compose run --rm openlane

# 在容器內執行完整流程
./flow.tcl -design /openlane/designs/temp_controller/openlane

# 或使用互動模式
./flow.tcl -interactive
```

## 🚨 常見問題

### OpenLane 找不到設計
確保路徑正確指向 openlane 目錄

### Docker 權限問題
```bash
sudo usermod -aG docker $USER
# 重新登入
```

### 記憶體不足
調整 Docker Desktop 設定：
- macOS: Docker Desktop → Preferences → Resources → Memory: 8GB+
- Linux: 檢查 Docker daemon 設定

### PDK 下載緩慢
使用鏡像或預先下載的 PDK：
```bash
docker volume create openlane_pdk_sky130
# PDK 會被緩存在 Docker volume 中
```
# 冰箱溫度控制器 IC - SKY130 PDK

使用 SKY130 開源 PDK 設計的數位溫度控制器 IC，展示完整的 RTL 到 GDSII 設計流程。

## 🎯 專案特色

- **完整數位設計流程**：從規格到 GDSII
- **開源工具鏈**：Yosys + OpenLane + SKY130 PDK
- **實用應用**：家用冰箱溫度控制
- **教學導向**：詳細文檔和範例

## 📋 系統規格

- **溫度範圍**：-20°C ~ +10°C
- **控制精度**：±0.5°C
- **控制演算法**：數位 PID
- **工作頻率**：10 MHz
- **製程技術**：SKY130 (130nm)
- **晶片面積**：< 0.5 mm²
- **功耗目標**：< 5 mW

## 🏗️ 專案結構

```
fridge_temp_controller_sky130/
├── docs/                 # 設計文檔
│   ├── 00_design_introduction_for_beginners.md  # 🆕 新手入門指南
│   ├── 01_specification.md
│   ├── 02_architecture.md
│   ├── 03_tutorial.md
│   ├── 04_design_decisions.md
│   ├── 05_rtl_implementation.md
│   ├── 06_verification_strategy.md
│   ├── 07_physical_design_guide.md
│   └── 08_troubleshooting.md
├── rtl/                  # RTL 設計檔案
│   ├── temp_ctrl_top.v
│   ├── adc_spi_interface.v
│   ├── pid_controller.v
│   ├── pwm_generator.v
│   └── display_controller.v
├── testbench/           # 測試平台
│   ├── temp_ctrl_top_tb.v
│   ├── pid_controller_tb.v
│   └── Makefile
├── synthesis/           # 合成腳本
│   ├── synth_top.ys
│   └── constraints.sdc
├── openlane/           # OpenLane 配置
│   ├── config.json
│   ├── base.sdc
│   └── pdn.tcl
└── results/            # 輸出結果
```

## 🚀 快速開始

### 環境需求

- Ubuntu 20.04+ 或相容系統
- 至少 8GB RAM
- 20GB 可用硬碟空間

### 安裝步驟

1. **安裝基礎工具**
```bash
sudo apt-get update
sudo apt-get install -y git make python3 python3-pip iverilog gtkwave yosys
```

2. **安裝 SKY130 PDK**
```bash
export PDK_ROOT=$HOME/pdk
git clone https://github.com/google/skywater-pdk.git
cd skywater-pdk
# 按照官方說明完成安裝
```

3. **安裝 OpenLane**
```bash
git clone https://github.com/The-OpenROAD-Project/OpenLane.git
cd OpenLane
make
```

4. **克隆專案**
```bash
git clone [your-repo-url]
cd fridge_temp_controller_sky130
```

### 執行模擬

```bash
cd testbench
make sim_top      # 執行頂層測試
make wave_top     # 查看波形
```

### 執行合成

```bash
cd synthesis
./run_synthesis.sh
```

### 執行 OpenLane

```bash
cd openlane
./run_openlane.sh
# 選擇 1 執行完整流程
```

## 📊 設計指標

| 指標 | 目標 | 實際 |
|------|------|------|
| 工作頻率 | 10 MHz | TBD |
| 晶片面積 | < 0.5 mm² | TBD |
| 功耗 | < 5 mW | TBD |
| 邏輯閘數 | - | TBD |
| 暫存器數 | - | TBD |

## 🔧 主要功能模組

### 1. ADC SPI 介面
- 12-bit 解析度
- 1 MHz SPI 時脈
- 支援多通道

### 2. PID 控制器
- 16-bit 定點運算
- 可調整 Kp、Ki、Kd
- 抗積分飽和

### 3. PWM 產生器
- 10-bit 解析度
- 1 kHz 頻率
- 軟啟動/停止

### 4. 顯示控制器
- 4 位數七段顯示
- 溫度顯示格式：XX.X°C
- 多工掃描

## 📝 文檔

### 入門文檔
- [🆕 新手入門指南](docs/00_design_introduction_for_beginners.md) - **從這裡開始！**
- [系統規格書](docs/01_specification.md)
- [架構設計](docs/02_architecture.md)
- [完整教學](docs/03_tutorial.md)

### 進階文檔
- [設計決策說明](docs/04_design_decisions.md)
- [RTL 實作細節](docs/05_rtl_implementation.md)
- [驗證策略](docs/06_verification_strategy.md)
- [物理設計指南](docs/07_physical_design_guide.md)
- [問題排除指南](docs/08_troubleshooting.md)
- [🔍 GTKWave 與 Testbench 使用指南](docs/09_gtkwave_testbench_guide.md) - **驗證必讀！**

## 🧪 測試覆蓋率

- [ ] 單元測試
  - [x] PID 控制器
  - [x] PWM 產生器
  - [ ] ADC 介面
  - [ ] 顯示控制器
- [x] 整合測試
- [ ] 時序驗證
- [ ] 功耗分析

## 🛠️ 開發工具

- **RTL 設計**：Verilog
- **模擬器**：Icarus Verilog
- **波形檢視**：GTKWave
- **合成**：Yosys
- **實體設計**：OpenLane
- **PDK**：SKY130

## 📈 專案進度

- [x] 系統規格定義
- [x] 架構設計
- [x] RTL 實作
- [x] 功能驗證
- [x] 邏輯合成
- [x] OpenLane 設置
- [ ] 實體設計完成
- [ ] DRC/LVS 驗證
- [ ] 最終 GDSII

## 🤝 貢獻指南

歡迎提交 Issue 和 Pull Request！

1. Fork 專案
2. 建立功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交變更 (`git commit -m 'Add some AmazingFeature'`)
4. 推送分支 (`git push origin feature/AmazingFeature`)
5. 開啟 Pull Request

## 📄 授權

本專案採用 Apache License 2.0 - 詳見 [LICENSE](LICENSE) 檔案

## 🙏 致謝

- Google/SkyWater 提供開源 PDK
- OpenLane 團隊提供自動化流程
- 開源 EDA 社群的支援

## 📞 聯絡資訊

- 專案維護者：IC Design Team
- Email：[your-email]
- 專案連結：[your-repo-url]

---

**注意**：本專案為教學示範用途，實際製造前需要完整的驗證流程。
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
├── docs/                    # 📚 完整設計文檔
│   ├── 01_getting_started/  # 入門指南
│   ├── 02_design/          # 設計文件
│   ├── 03_verification/    # 驗證文件
│   ├── 04_tutorials/       # 教學材料
│   ├── 05_implementation/  # 實作指南
│   └── 06_reference/       # 參考資源
├── rtl/                    # RTL 設計檔案
│   ├── temp_ctrl_top.v     # 頂層模組
│   ├── adc_spi_interface.v # ADC SPI 介面
│   ├── pid_controller.v    # PID 控制器
│   ├── pwm_generator.v     # PWM 產生器
│   └── display_controller.v # 顯示控制器
├── testbench/             # 測試平台
│   ├── temp_ctrl_top_tb.v
│   ├── pid_controller_tb.v
│   └── Makefile
├── synthesis/             # 合成腳本
│   ├── synth_top.ys
│   ├── constraints.sdc
│   └── run_synthesis.sh
├── openlane/             # OpenLane 配置
│   ├── config.json
│   ├── base.sdc
│   ├── pdn.tcl
│   └── run_openlane.sh
└── quickstart.sh         # 快速開始腳本
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
git clone git@github.com:marcus888-techstack/test-fridge_temp_controller_sky130.git
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

完整的專案文檔已經按照學習路徑和專業領域進行組織。請訪問 [📚 文檔中心](docs/README.md) 查看：

- 🌱 **初學者路徑** - 從系統規格到 SPI 教學的循序漸進學習
- 🔧 **設計工程師路徑** - RTL 實作、架構設計與驗證策略
- 🏗️ **物理設計路徑** - 合成、OpenLane 流程與 PDK 使用指南

### 快速連結
- [新手入門指南](docs/01_getting_started/00_design_introduction_for_beginners.md)
- [系統規格書](docs/01_getting_started/01_system_specification.md)
- [SPI 深入教學](docs/04_tutorials/02_understanding_spi.md)
- [GTKWave 驗證指南](docs/03_verification/02_gtkwave_testbench_guide.md)

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
- 專案儲存庫：[GitHub](https://github.com/marcus888-techstack/test-fridge_temp_controller_sky130)
- 問題回報：[GitHub Issues](https://github.com/marcus888-techstack/test-fridge_temp_controller_sky130/issues)
- 討論區：[GitHub Discussions](https://github.com/marcus888-techstack/test-fridge_temp_controller_sky130/discussions)

---

**注意**：本專案為教學示範用途，實際製造前需要完整的驗證流程。
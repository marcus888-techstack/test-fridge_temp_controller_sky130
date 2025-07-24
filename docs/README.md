# 📚 冰箱溫度控制器 IC 設計文件總覽

歡迎來到冰箱溫度控制器 IC 設計專案的文件中心！本專案使用 SKY130 PDK，從 RTL 設計到 GDSII 佈局的完整流程。

## 🎯 快速導航

### 初學者路徑 🌱
如果您是 IC 設計新手，建議按照以下順序閱讀：

1. **[系統規格書](01_getting_started/01_system_specification.md)** - 了解專案需求
2. **[透過冰箱專案理解 SPI](04_tutorials/02_understanding_spi.md)** - 深入淺出的 SPI 教學
3. **[SPI 實作練習手冊](04_tutorials/03_spi_practice_workbook.md)** - 動手練習加深理解
4. **[GTKWave 與 Testbench 指南](03_verification/02_gtkwave_testbench_guide.md)** - 學習驗證和除錯

### 設計工程師路徑 🔧
如果您要實作或修改設計：

1. **[架構設計](02_design/01_architecture.md)** - 系統架構總覽
2. **[RTL 實作細節](02_design/03_rtl_implementation.md)** - 詳細的模組設計
3. **[設計決策文件](02_design/02_design_decisions.md)** - 理解設計選擇的原因
4. **[驗證策略](03_verification/01_verification_strategy.md)** - 完整的測試計畫

### 物理設計路徑 🏗️
如果您負責後端實作：

1. **[物理設計指南](05_implementation/01_physical_design_guide.md)** - SKY130 PDK 使用指南
2. **[Yosys 合成指南](05_implementation/02_synthesis_guide.md)** - 合成流程詳解
3. **[OpenLane 流程](05_implementation/03_openlane_guide.md)** - 自動化 PnR 配置

---

## 📖 完整文件清單

### 🌱 入門文件
| 文件 | 說明 | 適合對象 |
|------|------|----------|
| [IC 設計入門](01_getting_started/00_design_introduction_for_beginners.md) | IC 設計基礎介紹 | 初學者 |
| [系統規格書](01_getting_started/01_system_specification.md) | 系統規格與需求定義 | 所有人 |

### 🎨 設計文件
| 文件 | 說明 | 適合對象 |
|------|------|----------|
| [架構設計](02_design/01_architecture.md) | 系統架構與模組劃分 | 設計師 |
| [設計決策](02_design/02_design_decisions.md) | 重要設計決策與理由 | 設計師 |
| [RTL 實作](02_design/03_rtl_implementation.md) | RTL 程式碼實作細節 | 開發者 |

### 🧪 驗證文件
| 文件 | 說明 | 適合對象 |
|------|------|----------|
| [驗證策略](03_verification/01_verification_strategy.md) | 完整驗證計畫與覆蓋率 | 驗證工程師 |
| [GTKWave 指南](03_verification/02_gtkwave_testbench_guide.md) | 波形分析實戰指南 | 所有人 |

### 📚 教學文件
| 文件 | 說明 | 適合對象 |
|------|------|----------|
| [基礎教學](04_tutorials/01_basic_tutorial.md) | 基礎入門教學 | 初學者 |
| [SPI 深入解析](04_tutorials/02_understanding_spi.md) | SPI 通訊深入教學（5000+ 字） | 初學者 |
| [SPI 練習手冊](04_tutorials/03_spi_practice_workbook.md) | SPI 實作練習題 | 學習者 |

### 🏭 實作文件
| 文件 | 說明 | 適合對象 |
|------|------|----------|
| [物理設計指南](05_implementation/01_physical_design_guide.md) | 物理設計與優化技巧 | 後端工程師 |
| [Yosys 合成](05_implementation/02_synthesis_guide.md) | 合成流程詳解 | 工程師 |
| [OpenLane 流程](05_implementation/03_openlane_guide.md) | 自動化實作指南 | 工程師 |

### 📖 參考資源
| 文件 | 說明 | 適合對象 |
|------|------|----------|
| [問題排除](06_reference/01_troubleshooting.md) | 問題排除與除錯指南 | 所有人 |
| [術語表](06_reference/02_glossary.md) | 專業術語解釋 | 初學者 |
| [外部資源](06_reference/03_resources.md) | 學習資源連結 | 所有人 |

---

## 🗂️ 專案結構導覽

```
fridge_temp_controller_sky130/
├── docs/                    # 您在這裡 📍
│   ├── 01_getting_started/  # 入門指南
│   ├── 02_design/          # 設計文件
│   ├── 03_verification/    # 驗證文件
│   ├── 04_tutorials/       # 教學材料
│   ├── 05_implementation/  # 實作指南
│   └── 06_reference/       # 參考資源
├── rtl/                    # Verilog 源碼
│   ├── temp_ctrl_top.v     # 頂層模組
│   ├── pid_controller.v    # PID 控制器
│   ├── adc_spi_interface.v # SPI 介面
│   └── ...
├── testbench/             # 測試檔案
│   ├── temp_ctrl_top_tb.v
│   ├── pid_controller_tb.v
│   └── Makefile
├── synthesis/             # Yosys 合成
├── openlane/             # OpenLane 配置
└── scripts/              # 輔助腳本
```

---

## 🚀 快速開始

### 1. 環境設置
```bash
# 克隆專案
git clone <repository-url>
cd fridge_temp_controller_sky130

# 安裝相依套件
./scripts/setup_env.sh
```

### 2. 執行模擬
```bash
cd testbench
make sim_top     # 執行系統測試
make wave_top    # 查看波形
```

### 3. 執行合成
```bash
cd synthesis
make all
```

---

## 💡 學習建議

### 給初學者
1. 先理解系統需求（規格書）
2. 透過 SPI 教學了解數位通訊
3. 動手做練習題加深印象
4. 嘗試修改參數觀察變化

### 給有經驗者
1. 直接查看 RTL 實作
2. 研究設計決策的權衡
3. 優化現有設計
4. 貢獻新功能

---

## 🤝 貢獻指南

歡迎貢獻！請：
1. Fork 專案
2. 創建功能分支
3. 提交 Pull Request

文件撰寫規範：
- 使用繁體中文
- 包含程式碼範例
- 提供視覺化圖表
- 考慮初學者需求

---

## 📧 聯絡資訊

- 專案維護者：IC Design Team
- 問題回報：[GitHub Issues](https://github.com/...)
- 討論區：[Discussions](https://github.com/...)

---

## 🏆 致謝

感謝所有貢獻者，特別是：
- SKY130 PDK 團隊
- OpenLane 開發團隊
- 開源 EDA 社群

---

最後更新：2024-12-19 | 版本：1.0
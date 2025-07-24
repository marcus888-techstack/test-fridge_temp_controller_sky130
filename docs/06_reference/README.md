# 📖 Reference Documentation - 參考文件

本章節提供快速查詢資源，包括問題排除、術語解釋和外部資源連結。

## 📖 本章節文件

| 文件 | 說明 | 使用時機 |
|------|------|----------|
| [01_troubleshooting.md](01_troubleshooting.md) | 問題排除與除錯指南 | 遇到問題時 |
| [02_glossary.md](02_glossary.md) | 專業術語解釋 | 不懂術語時 |
| [03_resources.md](03_resources.md) | 外部資源與連結 | 深入學習時 |

## 🔍 快速查詢

### 常見問題分類

1. **模擬問題**
   - Testbench 無法執行
   - 波形顯示異常
   - 時序不符預期

2. **合成問題**
   - Yosys 錯誤訊息
   - 面積過大
   - 時序違規

3. **物理設計問題**
   - DRC 違規
   - LVS 不匹配
   - 繞線擁塞

### 常用術語

- **RTL**: Register Transfer Level
- **PID**: Proportional-Integral-Derivative
- **SPI**: Serial Peripheral Interface
- **PDK**: Process Design Kit
- **DRC**: Design Rule Check
- **LVS**: Layout vs. Schematic

## 💡 除錯技巧

1. **系統化方法**
   - 確認環境設置
   - 隔離問題範圍
   - 逐步測試
   - 記錄結果

2. **常用工具**
   ```bash
   # 檢查語法
   iverilog -g2012 -o test module.v
   
   # 查看網表
   yosys -p "read_verilog module.v; show"
   
   # 分析時序
   sta timing_analysis.tcl
   ```

## 📚 學習資源推薦

### 入門書籍
- "Digital Design and Computer Architecture"
- "CMOS VLSI Design"

### 線上課程
- Coursera: VLSI CAD
- edX: Digital Systems Design

### 社群資源
- [/r/FPGA](https://reddit.com/r/FPGA)
- [EDAboard](https://www.edaboard.com/)

## 🔗 快速連結

- [OpenLane Issue Tracker](https://github.com/The-OpenROAD-Project/OpenLane/issues)
- [SKY130 PDK Slack](https://join.skywater.tools/)
- [Icarus Verilog Wiki](https://iverilog.fandom.com/)

---

[返回主目錄](../README.md)
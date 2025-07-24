# RTL 模組說明

本目錄包含冰箱溫度控制器的所有 RTL (Register Transfer Level) 設計檔案。

## 模組清單

### 1. temp_ctrl_top.v
- **功能**: 頂層模組，整合所有子模組
- **主要特性**:
  - 10 MHz 系統時脈
  - 整合 ADC、PID、PWM、顯示控制
  - 狀態機控制系統運行模式
  - 使用者介面處理

### 2. adc_spi_interface.v
- **功能**: ADC SPI 介面模組
- **主要特性**:
  - 相容 ADC128S022 12-bit ADC
  - SPI Mode 0 (CPOL=0, CPHA=0)
  - 1 MHz SPI 時脈
  - 自動通道選擇

### 3. pid_controller.v
- **功能**: 數位 PID 控制器
- **主要特性**:
  - 16-bit 定點運算 (Q8.8 格式)
  - 抗積分飽和 (Anti-windup)
  - 可調整 Kp、Ki、Kd 參數
  - 輸出飽和保護

### 4. pwm_generator.v
- **功能**: PWM 信號產生器
- **主要特性**:
  - 10-bit 解析度 (1024 級)
  - 1 kHz PWM 頻率
  - 軟啟動/停止功能
  - 可變佔空比 0-100%

### 5. display_controller.v
- **功能**: 七段顯示器控制器
- **主要特性**:
  - 4 位數多工顯示
  - 100 Hz 掃描頻率
  - 支援小數點顯示
  - 閃爍功能

## 介面規格

### 系統時脈
- 主時脈: 10 MHz
- SPI 時脈: 1 MHz
- PWM 時脈: 1 kHz
- 顯示掃描: 100 Hz

### 資料格式
- 溫度值: Q8.8 定點格式
- PID 係數: Q8.8 定點格式
- ADC 資料: 12-bit 無符號
- PWM 佔空比: 10-bit 無符號

## 設計規範

1. **同步設計**: 所有時序邏輯使用單一時脈域
2. **重置策略**: 非同步重置，同步釋放
3. **編碼風格**: 遵循 Verilog-2001 標準
4. **命名規則**:
   - 模組名: 小寫加底線
   - 參數: 大寫加底線
   - 信號: 小寫加底線
   - 常數: 大寫

## 綜合注意事項

1. 目標 PDK: SKY130
2. 時序約束: 10 MHz (100 ns period)
3. 面積目標: < 0.5 mm²
4. 功耗目標: < 5 mW

## 驗證檔案

相關測試平台檔案位於 `/testbench` 目錄。

## 使用方式

```bash
# Lint 檢查
verilator --lint-only rtl/*.v

# 編譯所有 RTL
iverilog -o temp_ctrl.vvp rtl/*.v

# 執行模擬 (需要 testbench)
vvp temp_ctrl.vvp
```

---
最後更新: 2024-12-19
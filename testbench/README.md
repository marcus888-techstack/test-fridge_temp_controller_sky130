# Testbench 目錄說明

本目錄包含冰箱溫度控制器 IC 的所有測試檔案。

## 📁 檔案結構

```
testbench/
├── Makefile                 # 自動化編譯和執行腳本
├── pid_controller_tb.v      # PID 控制器測試平台
├── temp_ctrl_top_tb.v       # 頂層模組測試平台
├── run_sim.sh              # 互動式測試腳本
└── wave_config.gtkw        # GTKWave 預設配置
```

## 🚀 快速開始

### 執行 PID 控制器測試
```bash
# 編譯並執行模擬
make sim_pid

# 執行並查看波形（推薦）
make wave_pid
```

### 執行完整系統測試
```bash
# 編譯並執行模擬
make sim_top

# 執行並查看波形
make wave_top
```

## 📊 GTKWave 使用提示

當執行 `make wave_pid` 或 `make wave_top` 時，GTKWave 會自動開啟。

### 重要信號觀察清單

**PID 控制器測試：**
- `setpoint` - 設定溫度
- `feedback` - 實際溫度
- `error` - 溫度誤差
- `integral_acc` - 積分累加器（觀察飽和）
- `output` - PID 輸出

**系統測試：**
- `current_state` - 系統狀態機
- `adc_data` - ADC 讀數
- `pwm_out` - PWM 輸出
- `seven_seg` - 顯示輸出

### 快速技巧
1. 使用滑鼠滾輪縮放時間軸
2. 按 M 設置時間標記
3. 右鍵信號選擇數據格式
4. 拖曳選擇測量時間間隔

## 📝 測試案例說明

### PID 控制器測試 (`pid_controller_tb.v`)

包含 4 個測試案例：

1. **階躍響應** - 測試系統達到設定溫度的能力
2. **干擾抑制** - 測試抗干擾能力
3. **參數變化** - 測試不同 PID 參數效果
4. **積分飽和** - 測試防積分飽和機制

### 系統測試 (`temp_ctrl_top_tb.v`)

包含完整系統整合測試：
- ADC 讀取測試
- 狀態機轉換測試
- PWM 輸出驗證
- 顯示功能測試
- 異常處理測試

## 🔧 Makefile 目標

```bash
make help        # 顯示所有可用命令
make compile     # 編譯所有測試
make sim_pid     # 執行 PID 測試
make sim_top     # 執行系統測試
make wave_pid    # PID 測試 + 波形
make wave_top    # 系統測試 + 波形
make lint        # 語法檢查
make clean       # 清理檔案
```

## 💡 調試技巧

1. **修改參數測試**
   ```verilog
   // 在 pid_controller_tb.v 中
   kp = real_to_q8_8(3.0);  // 修改 P 參數
   ```

2. **增加顯示輸出**
   ```verilog
   $display("Debug: signal=%h", signal);
   ```

3. **延長模擬時間**
   ```verilog
   #(CLK_PERIOD * 1000);  // 增加延遲
   ```

## 📚 深入學習

詳細的波形分析和測試方法，請參考：
[GTKWave 與 Testbench 使用指南](../docs/09_gtkwave_testbench_guide.md)

---

提示：第一次使用建議從 PID 控制器測試開始，較容易理解！
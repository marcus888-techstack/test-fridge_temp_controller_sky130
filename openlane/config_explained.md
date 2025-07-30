# OpenLane 配置檔說明 (config.json)

## 🎯 基本設計資訊
```json
"DESIGN_NAME": "temp_ctrl_top",              // 設計名稱：溫度控制器頂層模組
"VERILOG_FILES": [                           // Verilog 源檔案列表
    "dir::src/temp_ctrl_top.v",              // 頂層模組
    "dir::src/adc_spi_interface.v",          // ADC SPI 介面
    "dir::src/pid_controller.v",             // PID 控制器
    "dir::src/pwm_generator.v",              // PWM 產生器
    "dir::src/display_controller.v"          // 七段顯示器控制器
],
```

## ⏰ 時脈設定
```json
"CLOCK_PERIOD": 100,                         // 時脈週期：100ns (10 MHz)
"CLOCK_PORT": "clk",                         // 時脈端口名稱
"CLOCK_NET": "clk",                          // 時脈網路名稱
```

## 📐 布局規劃 (Floorplan)
```json
"FP_SIZING": "absolute",                     // 晶片尺寸模式：絕對尺寸
"DIE_AREA": "0 0 300 300",                   // 晶片面積：300x300 微米
"CORE_AREA": "10 10 290 290",                // 核心面積：280x280 微米（留10微米邊界）
"FP_CORE_UTIL": 35,                          // 核心利用率：35%
"FP_ASPECT_RATIO": 1,                        // 長寬比：1:1（正方形）
"FP_PDN_MULTILAYER": true,                   // 啟用多層電源分配網路
```

## 🔧 放置 (Placement) 設定
```json
"PL_TARGET_DENSITY": 0.5,                    // 目標放置密度：50%
"PL_BASIC_PLACEMENT": false,                 // 不使用基本放置（使用進階算法）
"PL_SKIP_INITIAL_PLACEMENT": false,          // 不跳過初始放置
"PL_RESIZER_DESIGN_OPTIMIZATIONS": true,     // 啟用設計優化
"PL_RESIZER_TIMING_OPTIMIZATIONS": true,     // 啟用時序優化
"PL_RESIZER_BUFFER_OUTPUT_PORTS": true,      // 對輸出端口加緩衝器
```

## 🛤️ 繞線 (Routing) 設定
```json
"ROUTING_CORES": 4,                          // 使用 4 個 CPU 核心進行繞線
"GLB_RT_ADJUSTMENT": 0.1,                    // 全域繞線調整係數
"GLB_RT_MAX_DIODE_INS_ITERS": 5,            // 最大二極體插入迭代次數
"GLB_RESIZER_TIMING_OPTIMIZATIONS": true,    // 全域繞線時序優化
```

## 🔨 合成 (Synthesis) 策略
```json
"SYNTH_STRATEGY": "AREA 0",                  // 合成策略：面積優先
"SYNTH_USE_PG_PINS_DEFINES": "USE_POWER_PINS", // 使用電源接腳定義
"SYNTH_BUFFERING": true,                     // 啟用緩衝器插入
"SYNTH_SIZING": true,                        // 啟用門尺寸調整
"SYNTH_NO_FLAT": false,                      // 保持階層結構
```

## 🕐 時脈樹合成 (CTS)
```json
"CTS_TARGET_SKEW": 10,                       // 目標時脈偏斜：10 ps
"CTS_TOLERANCE": 50,                         // 容許誤差：50 ps
"CTS_CLK_BUFFER_LIST": "sky130_fd_sc_hd__clkbuf_4 sky130_fd_sc_hd__clkbuf_8", // 時脈緩衝器列表
"CTS_ROOT_BUFFER": "sky130_fd_sc_hd__clkbuf_16", // 根緩衝器
```

## ⚡ 電源分配網路 (PDN)
```json
"VDD_NETS": "vccd1",                         // 電源網路名稱
"GND_NETS": "vssd1",                         // 接地網路名稱
"PDN_CFG": "dir::pdn.tcl",                   // PDN 配置檔案
"FP_PDN_ENABLE_RAILS": true,                 // 啟用電源軌
"FP_PDN_VPITCH": 50,                         // 垂直電源條間距：50 微米
"FP_PDN_HPITCH": 50,                         // 水平電源條間距：50 微米
"FP_PDN_VWIDTH": 1.6,                        // 垂直電源條寬度：1.6 微米
"FP_PDN_HWIDTH": 1.6,                        // 水平電源條寬度：1.6 微米
```

## 🛡️ 天線效應修復
```json
"DIODE_INSERTION_STRATEGY": 4,               // 二極體插入策略：4（自動）
```

## ✅ 驗證設定
```json
"RUN_CVC": true,                             // 執行電路驗證檢查
"RUN_MAGIC": true,                           // 執行 Magic 佈局工具
"RUN_KLAYOUT": true,                         // 執行 KLayout 檢視器
"RUN_SPICE_EXTRACTION": true,                // 執行 SPICE 參數萃取
"RUN_MAGIC_DRC": true,                       // 執行 Magic DRC 檢查
"RUN_KLAYOUT_DRC": true,                     // 執行 KLayout DRC 檢查
"RUN_LVS": true,                             // 執行 LVS（佈局與電路圖比對）
```

## 🎯 檢查設定
```json
"MAGIC_DRC_USE_GDS": true,                   // DRC 使用 GDS 格式
"MAGIC_EXT_USE_GDS": true,                   // 萃取使用 GDS 格式
"LVS_CONNECT_BY_LABEL": true,                // LVS 使用標籤連接
"MAGIC_CONVERT_DRC_TO_RDB": true,            // 轉換 DRC 結果為 RDB 格式
"KLAYOUT_XOR_GDS": true,                     // KLayout XOR 比對 GDS
"KLAYOUT_XOR_XML": true,                     // KLayout XOR 輸出 XML
```

## ⚠️ 錯誤處理
```json
"QUIT_ON_TIMING_VIOLATIONS": false,          // 時序違規時不停止
"QUIT_ON_MAGIC_DRC": false,                  // DRC 錯誤時不停止
"QUIT_ON_LVS_ERROR": false,                  // LVS 錯誤時不停止
```

## 📄 其他設定
```json
"BASE_SDC_FILE": "dir::base.sdc",            // SDC 約束檔案
"EXTRA_LEFS": [],                            // 額外的 LEF 檔案
"EXTRA_GDS_FILES": [],                       // 額外的 GDS 檔案
```
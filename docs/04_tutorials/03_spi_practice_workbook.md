# SPI 通訊實作練習手冊

> 🎯 **本手冊目標**：透過動手練習，加深對 SPI 通訊的理解。每個練習都基於冰箱溫度控制器專案。

## 前置準備

確保您已經：
1. 閱讀完 [SPI 通訊深入理解文件](02_understanding_spi.md)
2. 設置好專案環境
3. 能夠執行 testbench

```bash
cd fridge_temp_controller_sky130/testbench
make sim_top  # 確認環境正常
```

---

## 練習 1：觀察 SPI 時序

### 目標
學會在 GTKWave 中觀察和測量 SPI 時序。

### 步驟

1. **執行測試並開啟波形**
```bash
make wave_top
```

2. **加入關鍵信號**
在 GTKWave 中加入以下信號：
- `DUT.adc_intf.spi_cs_n`
- `DUT.adc_intf.spi_sclk`
- `DUT.adc_intf.spi_mosi`
- `DUT.adc_intf.spi_miso`
- `DUT.adc_intf.current_state`
- `DUT.adc_intf.bit_counter`

3. **測量任務**
- [ ] 測量 CS 下降到第一個 SCLK 的時間
- [ ] 測量 SCLK 的週期
- [ ] 計算 SPI 的通訊速率
- [ ] 找出第一個有效資料位元出現的時間

### 預期結果
- CS 建立時間：______ ns (應該 ≥ 400ns)
- SCLK 週期：______ ns (應該 = 1000ns)
- SPI 速率：______ MHz (應該 = 1 MHz)
- 第一個資料位元時間：______ ns

### 思考題
1. 為什麼 CS 建立時間要這麼長？
2. 如果把 SCLK 改成 2 MHz 會發生什麼？

---

## 練習 2：追蹤資料傳輸

### 目標
理解 SPI 資料如何在移位暫存器中移動。

### 任務

1. **修改 testbench 顯示**
在 `temp_ctrl_top_tb.v` 中加入除錯訊息：

```verilog
// 在第 185 行附近，加入移位暫存器監控
always @(posedge clk) begin
    if (DUT.adc_intf.current_state == 3'b010 || 
        DUT.adc_intf.current_state == 3'b011) begin
        $display("Time: %0t | Bit: %d | TX: %h | RX: %h | MOSI: %b | MISO: %b",
                 $time,
                 DUT.adc_intf.bit_counter,
                 DUT.adc_intf.tx_shift_reg,
                 DUT.adc_intf.rx_shift_reg,
                 DUT.adc_intf.spi_mosi,
                 DUT.adc_intf.spi_miso);
    end
end
```

2. **重新執行測試**
```bash
make sim_top > spi_trace.log
```

3. **分析紀錄**
從 log 檔中找出：
- [ ] 通道 0 的命令是什麼？(16 位元十六進位)
- [ ] ADC 回傳的第一個位元是什麼？
- [ ] 完整的 12 位元 ADC 值是多少？

### 驗證計算
如果溫度是 5°C，ADC 值應該是：
```
ADC = (5 + 50) × 4096 / 100 = _______
二進位 = ____________
```

---

## 練習 3：修改 SPI 時序參數

### 目標
了解時序參數對 SPI 通訊的影響。

### 實驗 A：改變 CS 延遲

1. **修改 `adc_spi_interface.v`**
```verilog
// 第 160 行，原本是 4'd3
if (cs_delay_counter < 4'd1)  // 改成只等 2 個週期
```

2. **執行測試觀察結果**
- [ ] 通訊是否仍然正常？
- [ ] ADC 讀數是否正確？

3. **恢復原設定並改成更長延遲**
```verilog
if (cs_delay_counter < 4'd7)  // 改成等 8 個週期
```

4. **比較差異**
- 延遲太短的影響：_______________
- 延遲太長的影響：_______________

### 實驗 B：改變 SPI 時脈

1. **在頂層模組產生 2 MHz 時脈**
修改 `temp_ctrl_top.v`：
```verilog
// 加入 2 MHz 時脈產生
reg [1:0] clk_div_2mhz;
reg clk_2mhz;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        clk_div_2mhz <= 2'd0;
        clk_2mhz <= 1'b0;
    end else begin
        clk_div_2mhz <= clk_div_2mhz + 1'b1;
        if (clk_div_2mhz == 2'd2) begin
            clk_div_2mhz <= 2'd0;
            clk_2mhz <= ~clk_2mhz;
        end
    end
end
```

2. **連接到 ADC 介面**
```verilog
.clk_1mhz(clk_2mhz),  // 使用 2 MHz
```

3. **觀察結果**
- [ ] SPI 通訊時間變成多少？
- [ ] 是否仍在 ADC 規格內？

---

## 練習 4：處理多通道讀取

### 目標
實作輪流讀取多個 ADC 通道。

### 任務

1. **修改主控制器**
在 `temp_ctrl_top.v` 中實作通道切換：

```verilog
// 狀態機中加入通道切換邏輯
reg [2:0] current_channel;
reg [11:0] adc_readings [0:2];  // 儲存 3 個通道

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_channel <= 3'd0;
    end else if (adc_valid) begin
        // 儲存當前通道讀數
        adc_readings[current_channel] <= adc_data;
        
        // 切換到下一個通道
        if (current_channel == 3'd2)
            current_channel <= 3'd0;
        else
            current_channel <= current_channel + 1'b1;
    end
end

// 修改 ADC 啟動邏輯
assign adc_channel = current_channel;
```

2. **在 testbench 中模擬多個感測器**
```verilog
// 根據通道返回不同溫度
always @(*) begin
    case (spi_shift_reg[13:11])  // 提取通道號
        3'd0: adc_value = 2253;  // 5°C - 冷藏室
        3'd1: adc_value = 1311;  // -18°C - 冷凍室
        3'd2: adc_value = 2949;  // 22°C - 環境
        default: adc_value = 2048;  // 0°C
    endcase
end
```

3. **驗證結果**
- [ ] 三個通道是否都能正確讀取？
- [ ] 切換順序是否正確？
- [ ] 每個通道的更新頻率是多少？

---

## 練習 5：錯誤處理實作

### 目標
加入 SPI 通訊錯誤偵測和處理。

### 任務 A：逾時保護

1. **加入逾時計數器**
```verilog
// 在 adc_spi_interface.v 中
reg [15:0] timeout_counter;
localparam TIMEOUT_LIMIT = 16'd50000;  // 5ms @ 10MHz

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        timeout_counter <= 16'd0;
    end else if (current_state == STATE_IDLE) begin
        timeout_counter <= 16'd0;
    end else begin
        timeout_counter <= timeout_counter + 1'b1;
    end
end

// 加入逾時檢查
wire timeout_error = (timeout_counter >= TIMEOUT_LIMIT);
```

2. **處理逾時**
```verilog
// 在狀態機中
if (timeout_error) begin
    next_state = STATE_IDLE;
    // 設定錯誤旗標
end
```

### 任務 B：資料驗證

1. **加入簡單校驗**
```verilog
// 檢查 ADC 值是否在合理範圍
wire adc_value_valid = (adc_data >= 12'd819) &&   // -30°C
                       (adc_data <= 12'd3277);      // 30°C

output reg adc_error;
always @(posedge clk) begin
    if (adc_valid && !adc_value_valid) begin
        adc_error <= 1'b1;
        $display("ERROR: Invalid ADC value: %d", adc_data);
    end
end
```

2. **測試錯誤處理**
在 testbench 中故意產生錯誤：
```verilog
// 模擬 ADC 故障
if (test_case == 6) begin
    adc_value = 12'd4095;  // 超出範圍
end
```

---

## 練習 6：效能優化

### 目標
優化 SPI 介面以提高效率。

### 挑戰任務

1. **減少狀態機狀態**
思考：能否將 6 個狀態簡化為 4 個？
提示：哪些狀態可以合併？

2. **實作連續讀取模式**
讓 ADC 可以連續讀取而不需要每次都重新啟動：
```verilog
input wire continuous_mode;
// 完成後自動開始下一次轉換
```

3. **加入 DMA 式資料緩衝**
```verilog
// 實作 FIFO 儲存多筆讀數
reg [11:0] adc_fifo [0:7];
reg [2:0] fifo_wr_ptr;
reg [2:0] fifo_rd_ptr;
```

---

## 綜合挑戰：設計溫度趨勢分析器

### 目標
結合所學，設計一個能分析溫度變化趨勢的模組。

### 需求
1. 每秒讀取一次溫度
2. 儲存最近 8 筆資料
3. 計算平均值
4. 偵測上升/下降趨勢
5. 預測下一個溫度值

### 框架程式碼
```verilog
module temperature_analyzer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [11:0] adc_data,
    input  wire        adc_valid,
    output reg  [11:0] avg_temp,
    output reg         trend_up,
    output reg         trend_down,
    output reg  [11:0] predicted_temp
);
    // 實作您的設計
endmodule
```

### 驗證要點
- [ ] 平均值計算是否正確？
- [ ] 趨勢偵測是否準確？
- [ ] 預測值是否合理？

---

## 學習檢核表

完成所有練習後，您應該能夠：

- [ ] 理解 SPI 協定的時序要求
- [ ] 使用 GTKWave 分析數位訊號
- [ ] 修改和優化 SPI 介面
- [ ] 處理多通道資料讀取
- [ ] 實作錯誤偵測和處理
- [ ] 設計基於 SPI 的系統

## 進階學習資源

1. **SPI 協定規格書**
   - [ADC128S022 Datasheet](https://www.ti.com/product/ADC128S022)
   - SPI 協定標準文件

2. **相關專案**
   - I2C 介面實作
   - UART 通訊模組
   - CAN Bus 控制器

3. **推薦書籍**
   - "Digital Design and Computer Architecture"
   - "FPGA Prototyping by Verilog Examples"

---

恭喜您完成 SPI 實作練習！記得將您的實作成果提交到專案倉庫。

如有問題，請參考：
- [SPI 理論教學](02_understanding_spi.md)
- [除錯指南](../06_reference/01_troubleshooting.md)
- [GTKWave 使用指南](../03_verification/02_gtkwave_testbench_guide.md)
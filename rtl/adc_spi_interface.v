//==============================================================================
// File: adc_spi_interface.v
// Description: SPI interface for ADC128S022 compatible 12-bit ADC
// Author: IC Design Team
// Date: 2024-12-19
// Target: SKY130 PDK
//==============================================================================
//
// SPI 通訊時序圖：
// 
// CS_N    ‾‾‾‾‾‾‾\___________________________________________________/‾‾‾‾‾‾‾
//                  ↑                                                 ↑
//                  CS Setup Time                                     CS Hold Time
// 
// SCLK    _________/‾‾\__/‾‾\__/‾‾\__/‾‾\__/‾‾\__/‾‾\__/‾‾\________
//                  1    2    3    4    5    6    ...   16
// 
// MOSI    -------<D15><D14><D13><D12><D11>......................<D0>--------
//                 ↑    ↑    ↑
//                 控制位元  通道選擇位元
// 
// MISO    -------<----><----><B11><B10><B9>.....................<B0>--------
//                             ↑
//                             12位元ADC數據開始
//
// ADC128S022 控制字格式（16位元）：
// ┌────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┐
// │ 15 │ 14 │ 13 │ 12 │ 11 │ 10 │  9 │  8 │  7 │  6 │  5 │  4 │  3 │  2 │  1 │  0 │
// ├────┼────┼────┼────┼────┼────┼────┼────┼────┼────┼────┼────┼────┼────┼────┼────┤
// │ 0  │ 0  │CH2 │CH1 │CH0 │ 0  │ 0  │ 0  │ 0  │ 0  │ 0  │ 0  │ 0  │ 0  │ 0  │ 0  │
// └────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┘
//           └─────┴─────┘
//           通道選擇（0-7）

`timescale 1ns / 1ps

module adc_spi_interface (
    // System signals
    input  wire        clk,         // System clock (10 MHz) - 系統時鐘
    input  wire        rst_n,       // Active-low reset - 低電平有效重置
    input  wire        clk_1mhz,    // 1 MHz clock for SPI - SPI通訊時鐘
    
    // Control interface - 控制介面
    input  wire        start,       // Start conversion - 啟動轉換信號
    input  wire [2:0]  channel,     // ADC channel select (0-7) - ADC通道選擇
    output reg  [11:0] adc_data,    // 12-bit ADC result - 12位元ADC結果
    output reg         adc_valid,   // Data valid flag - 數據有效標誌
    
    // SPI interface - SPI介面
    input  wire        spi_miso,    // Master In Slave Out - 從設備數據輸出
    output reg         spi_mosi,    // Master Out Slave In - 主設備數據輸出
    output reg         spi_sclk,    // SPI clock - SPI時鐘
    output reg         spi_cs_n     // Chip select (active low) - 片選信號（低電平有效）
);

    //==========================================================================
    // State machine definitions - 狀態機定義
    // 使用6個狀態完成一次完整的SPI通訊週期
    //==========================================================================
    
    localparam STATE_IDLE       = 3'b000;  // 空閒狀態，等待啟動信號
    localparam STATE_CS_LOW     = 3'b001;  // CS拉低，等待建立時間
    localparam STATE_XFER_HIGH  = 3'b010;  // SCLK高電平，採樣MISO
    localparam STATE_XFER_LOW   = 3'b011;  // SCLK低電平，更新MOSI
    localparam STATE_CS_HIGH    = 3'b100;  // CS拉高，等待保持時間
    localparam STATE_DONE       = 3'b101;  // 完成狀態，輸出有效數據
    
    reg [2:0] current_state;
    reg [2:0] next_state;
    
    //==========================================================================
    // Internal signals - 內部信號
    //==========================================================================
    
    reg [4:0]  bit_counter;      // Counts bits (0-15) - 位元計數器，追蹤16位傳輸
    reg [15:0] tx_shift_reg;     // Transmit shift register - 發送移位寄存器
    reg [15:0] rx_shift_reg;     // Receive shift register - 接收移位寄存器
    reg        clk_1mhz_prev;    // Previous clock for edge detection - 用於邊沿檢測
    wire       clk_1mhz_posedge; // Rising edge of 1MHz clock - 1MHz時鐘上升沿
    wire       clk_1mhz_negedge; // Falling edge of 1MHz clock - 1MHz時鐘下降沿
    reg [3:0]  cs_delay_counter; // CS setup/hold delay - CS建立/保持時間計數器
    
    //==========================================================================
    // Clock edge detection - 時鐘邊沿檢測
    // 為什麼需要邊沿檢測：
    // 1. clk_1mhz是時鐘使能信號，不是真正的時鐘
    // 2. 需要在系統時鐘域中檢測1MHz時鐘的邊沿
    // 3. 確保SPI時序的精確控制
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_1mhz_prev <= 1'b0;
        end else begin
            clk_1mhz_prev <= clk_1mhz;  // 延遲一個週期，用於邊沿檢測
        end
    end
    
    // 邊沿檢測邏輯
    assign clk_1mhz_posedge = clk_1mhz & ~clk_1mhz_prev;   // 檢測上升沿
    assign clk_1mhz_negedge = ~clk_1mhz & clk_1mhz_prev;   // 檢測下降沿
    
    //==========================================================================
    // State machine - sequential logic - 狀態機時序邏輯
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    //==========================================================================
    // State machine - combinational logic - 狀態機組合邏輯
    // 狀態轉換說明：
    // IDLE → CS_LOW：收到start信號
    // CS_LOW → XFER_HIGH：CS建立時間完成
    // XFER_HIGH ↔ XFER_LOW：交替16次完成數據傳輸
    // XFER_LOW → CS_HIGH：16位傳輸完成
    // CS_HIGH → DONE：CS保持時間完成
    // DONE → IDLE：輸出數據後返回空閒
    //==========================================================================
    
    always @(*) begin
        next_state = current_state;
        
        case (current_state)
            STATE_IDLE: begin
                if (start)
                    next_state = STATE_CS_LOW;  // 收到啟動信號，開始SPI通訊
            end
            
            STATE_CS_LOW: begin
                // 等待CS建立時間（4個時鐘週期）
                if (cs_delay_counter == 4'd0)
                    next_state = STATE_XFER_HIGH;
            end
            
            STATE_XFER_HIGH: begin
                // 在1MHz時鐘下降沿切換到低電平狀態
                if (clk_1mhz_negedge)
                    next_state = STATE_XFER_LOW;
            end
            
            STATE_XFER_LOW: begin
                // 在1MHz時鐘上升沿決定下一狀態
                if (clk_1mhz_posedge) begin
                    if (bit_counter == 5'd15)
                        next_state = STATE_CS_HIGH;  // 16位傳輸完成
                    else
                        next_state = STATE_XFER_HIGH; // 繼續下一位
                end
            end
            
            STATE_CS_HIGH: begin
                // 等待CS保持時間（4個時鐘週期）
                if (cs_delay_counter == 4'd0)
                    next_state = STATE_DONE;
            end
            
            STATE_DONE: begin
                next_state = STATE_IDLE;  // 立即返回空閒狀態
            end
            
            default: next_state = STATE_IDLE;
        endcase
    end
    
    //==========================================================================
    // Control logic - 控制邏輯
    // 根據狀態機控制SPI信號和數據傳輸
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_cs_n         <= 1'b1;      // CS默認高電平（未選中）
            spi_sclk         <= 1'b0;      // SCLK默認低電平
            spi_mosi         <= 1'b0;      // MOSI默認低電平
            bit_counter      <= 5'd0;      // 位計數器清零
            tx_shift_reg     <= 16'd0;     // 發送寄存器清零
            rx_shift_reg     <= 16'd0;     // 接收寄存器清零
            adc_data         <= 12'd0;     // ADC數據清零
            adc_valid        <= 1'b0;      // 數據無效
            cs_delay_counter <= 4'd0;      // 延遲計數器清零
        end else begin
            // Default values
            adc_valid <= 1'b0;  // 默認數據無效，只在DONE狀態時有效
            
            case (current_state)
                STATE_IDLE: begin
                    spi_cs_n     <= 1'b1;      // 保持CS高電平
                    spi_sclk     <= 1'b0;      // 保持SCLK低電平
                    spi_mosi     <= 1'b0;      // 保持MOSI低電平
                    bit_counter  <= 5'd0;      // 重置位計數器
                    // 準備發送數據：通道選擇在位13:11
                    // 格式：00 + channel[2:0] + 00000000000
                    tx_shift_reg <= {2'b00, channel, 11'b0};
                end
                
                STATE_CS_LOW: begin
                    spi_cs_n <= 1'b0;  // 拉低CS，選中ADC
                    // CS建立時間計數（確保ADC準備好）
                    if (cs_delay_counter < 4'd3)
                        cs_delay_counter <= cs_delay_counter + 1'b1;
                    else
                        cs_delay_counter <= 4'd0;
                end
                
                STATE_XFER_HIGH: begin
                    // SCLK高電平期間
                    if (clk_1mhz_negedge) begin
                        spi_sclk <= 1'b1;  // 產生SCLK上升沿
                        // 在SCLK上升沿採樣MISO數據
                        // ADC在SCLK上升沿更新MISO，我們在同一時刻採樣
                        rx_shift_reg <= {rx_shift_reg[14:0], spi_miso};
                    end
                end
                
                STATE_XFER_LOW: begin
                    // SCLK低電平期間
                    if (clk_1mhz_posedge) begin
                        spi_sclk <= 1'b0;  // 產生SCLK下降沿
                        // 在SCLK下降沿更新MOSI數據
                        // ADC在SCLK下降沿採樣MOSI，我們提前更新
                        spi_mosi <= tx_shift_reg[15];  // 輸出最高位
                        tx_shift_reg <= {tx_shift_reg[14:0], 1'b0};  // 左移一位
                        bit_counter <= bit_counter + 1'b1;  // 增加位計數
                    end
                end
                
                STATE_CS_HIGH: begin
                    spi_cs_n <= 1'b1;  // 拉高CS，結束通訊
                    spi_sclk <= 1'b0;  // 確保SCLK為低
                    // CS保持時間計數（確保ADC正確結束）
                    if (cs_delay_counter < 4'd3)
                        cs_delay_counter <= cs_delay_counter + 1'b1;
                    else
                        cs_delay_counter <= 4'd0;
                end
                
                STATE_DONE: begin
                    // 提取12位ADC結果
                    // ADC128S022在位11:0返回轉換結果
                    adc_data  <= rx_shift_reg[11:0];
                    adc_valid <= 1'b1;  // 標記數據有效
                end
                
                default: begin
                    spi_cs_n <= 1'b1;
                    spi_sclk <= 1'b0;
                    spi_mosi <= 1'b0;
                end
            endcase
        end
    end
    
    //==========================================================================
    // 設計考量說明：
    // 1. 為什麼選擇ADC128S022：
    //    - 12位解析度，適合溫度測量精度要求
    //    - SPI介面簡單，易於實現
    //    - 8通道輸入，可擴展多點溫度監測
    //
    // 2. 時序設計：
    //    - CS建立/保持時間：確保ADC正確識別命令
    //    - SCLK頻率1MHz：在ADC規格範圍內，確保可靠通訊
    //    - 16位傳輸：符合ADC128S022協議要求
    //
    // 3. 狀態機設計優點：
    //    - 清晰的狀態轉換，易於調試
    //    - 精確的時序控制
    //    - 良好的可擴展性
    //==========================================================================
    
endmodule
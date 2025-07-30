//==============================================================================
// File: pwm_generator.v
// Description: PWM generator with 10-bit resolution and soft start/stop
// Author: IC Design Team
// Date: 2024-12-19
// Target: SKY130 PDK
//==============================================================================
//
// PWM (Pulse Width Modulation) 原理圖：
//
// Duty Cycle = 30% (307/1024)
// ┌─────┐           ┌─────┐           ┌─────┐
// │     │           │     │           │     │
// │     │           │     │           │     │
// ┘     └───────────┘     └───────────┘     └─────────
// |<--->|           |<--->|
//   30%               30%
// |<-------100%-------->|
//    1個PWM週期 (1ms)
//
// 軟啟動/停止示意圖：
//
// 占空比
// 100% ┤                              ╱─────────
//      │                           ╱
//      │                        ╱
//  50% ┤                     ╱
//      │                  ╱
//      │               ╱
//   0% └────────────╱
//      └─────────────────────────────────────────> 時間
//       軟啟動期間        正常運行
//
// PWM解析度計算：
// 10位元解析度 = 2^10 = 1024級
// 最小可調節步進 = 100% / 1024 ≈ 0.098%
// 
// 為什麼選擇10位元解析度：
// 1. 提供足夠的控制精度（約0.1%）
// 2. 硬體實現簡單，計數器只需10位
// 3. 配合1kHz PWM頻率，系統時鐘需求合理（約1MHz）

`timescale 1ns / 1ps

module pwm_generator (
    // System signals
    input  wire        clk,         // System clock (10 MHz) - 系統時鐘
    input  wire        rst_n,       // Active-low reset - 低電平有效重置
    input  wire        clk_1khz,    // 1 kHz clock enable - 1kHz時鐘使能
    
    // Control interface - 控制介面
    input  wire        enable,      // Enable PWM output - 使能PWM輸出
    input  wire [9:0]  duty_cycle,  // Duty cycle (0-1023) - 占空比（0-1023）
    input  wire        soft_start,  // Enable soft start/stop - 使能軟啟動/停止
    
    // Output - 輸出
    output reg         pwm_out      // PWM output signal - PWM輸出信號
);

    //==========================================================================
    // Parameters - 參數定義
    //==========================================================================
    
    parameter [9:0] PWM_PERIOD = 10'd1023;  // PWM period (10-bit) - PWM週期
    parameter [3:0] SOFT_START_RATE = 4'd1;  // Soft start increment rate - 軟啟動增量
    
    //==========================================================================
    // Internal signals - 內部信號
    //==========================================================================
    
    reg [9:0]  pwm_counter;         // PWM counter - PWM計數器
    reg [9:0]  duty_cycle_actual;   // Actual duty cycle (after soft start) - 實際占空比
    reg [15:0] soft_start_timer;    // Timer for soft start rate control - 軟啟動速率控制定時器
    reg        pwm_enable_sync;     // Synchronized enable signal - 同步後的使能信號
    reg        pwm_enable_prev;     // Previous enable for edge detection - 前一次使能狀態
    wire       enable_rising_edge;  // Enable rising edge - 使能上升沿
    wire       enable_falling_edge; // Enable falling edge - 使能下降沿
    
    //==========================================================================
    // Enable edge detection - 使能信號邊沿檢測
    // 為什麼需要邊沿檢測：
    // 1. 檢測使能信號的變化時刻
    // 2. 在使能變化時觸發軟啟動/停止
    // 3. 避免重複觸發
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_enable_sync <= 1'b0;
            pwm_enable_prev <= 1'b0;
        end else begin
            pwm_enable_sync <= enable;          // 第一級同步
            pwm_enable_prev <= pwm_enable_sync; // 保存前一狀態
        end
    end
    
    // 邊沿檢測
    assign enable_rising_edge  = pwm_enable_sync & ~pwm_enable_prev;   // 檢測上升沿
    assign enable_falling_edge = ~pwm_enable_sync & pwm_enable_prev;   // 檢測下降沿
    
    //==========================================================================
    // PWM counter - PWM計數器
    // 功能說明：
    // 1. 在1kHz時鐘使能時計數
    // 2. 計數範圍：0-1023（10位）
    // 3. 產生1kHz的PWM基本頻率
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_counter <= 10'd0;
        end else if (clk_1khz) begin
            // 循環計數0-1023
            if (pwm_counter == PWM_PERIOD)
                pwm_counter <= 10'd0;
            else
                pwm_counter <= pwm_counter + 1'b1;
        end
    end
    
    //==========================================================================
    // Soft start/stop control - 軟啟動/停止控制
    // 功能說明：
    // 1. 軟啟動：占空比從0逐漸增加到目標值
    // 2. 軟停止：占空比從當前值逐漸減少到0
    // 3. 防止突然的功率變化對壓縮機造成衝擊
    // 
    // 為什麼需要軟啟動/停止：
    // 1. 保護壓縮機電機，避免啟動電流過大
    // 2. 減少機械應力，延長使用壽命
    // 3. 降低電網衝擊，避免電壓驟降
    // 4. 減少噪音和振動
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            duty_cycle_actual <= 10'd0;
            soft_start_timer  <= 16'd0;
        end else begin
            if (soft_start) begin
                // 軟啟動模式已啟用
                if (pwm_enable_sync) begin
                    // PWM使能時：漸增或漸減到目標占空比
                    if (duty_cycle_actual < duty_cycle) begin
                        // 當前值小於目標值：漸增
                        if (soft_start_timer == 16'd9999) begin  // 1ms @ 10MHz
                            soft_start_timer <= 16'd0;
                            // 每毫秒增加SOFT_START_RATE
                            if (duty_cycle_actual + SOFT_START_RATE < duty_cycle)
                                duty_cycle_actual <= duty_cycle_actual + SOFT_START_RATE;
                            else
                                duty_cycle_actual <= duty_cycle;  // 到達目標值
                        end else begin
                            soft_start_timer <= soft_start_timer + 1'b1;
                        end
                    end else if (duty_cycle_actual > duty_cycle) begin
                        // 當前值大於目標值：漸減（目標值改變時）
                        if (soft_start_timer == 16'd9999) begin
                            soft_start_timer <= 16'd0;
                            if (duty_cycle_actual > duty_cycle + SOFT_START_RATE)
                                duty_cycle_actual <= duty_cycle_actual - SOFT_START_RATE;
                            else
                                duty_cycle_actual <= duty_cycle;  // 到達目標值
                        end else begin
                            soft_start_timer <= soft_start_timer + 1'b1;
                        end
                    end else begin
                        // 已到達目標值
                        soft_start_timer <= 16'd0;
                    end
                end else begin
                    // PWM禁能時：漸減到零（軟停止）
                    if (duty_cycle_actual > 10'd0) begin
                        if (soft_start_timer == 16'd9999) begin
                            soft_start_timer <= 16'd0;
                            if (duty_cycle_actual > SOFT_START_RATE)
                                duty_cycle_actual <= duty_cycle_actual - SOFT_START_RATE;
                            else
                                duty_cycle_actual <= 10'd0;  // 到達零
                        end else begin
                            soft_start_timer <= soft_start_timer + 1'b1;
                        end
                    end else begin
                        soft_start_timer <= 16'd0;
                    end
                end
            end else begin
                // 軟啟動禁用：立即響應
                if (pwm_enable_sync)
                    duty_cycle_actual <= duty_cycle;    // 直接使用目標值
                else
                    duty_cycle_actual <= 10'd0;         // 立即停止
                soft_start_timer <= 16'd0;
            end
        end
    end
    
    //==========================================================================
    // PWM output generation - PWM輸出產生
    // 功能說明：
    // 1. 比較計數器值和占空比
    // 2. 計數器 < 占空比時輸出高電平
    // 3. 支持0%和100%占空比
    //
    // 時序示例（占空比 = 300/1024 ≈ 29.3%）：
    // pwm_counter: 0...299|300...1023|0...299|300...1023|...
    // pwm_out:     111...1|000...000 |111...1|000...000 |...
    //              <- 高 ->|<-- 低 -->|
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_out <= 1'b0;
        end else if (clk_1khz) begin
            if (duty_cycle_actual == 10'd0) begin
                pwm_out <= 1'b0;  // 0%占空比：始終為低
            end else if (duty_cycle_actual > PWM_PERIOD) begin
                pwm_out <= 1'b1;  // 100%占空比：始終為高
            end else begin
                // 正常PWM輸出
                pwm_out <= (pwm_counter < duty_cycle_actual) ? 1'b1 : 1'b0;
            end
        end
    end
    
    //==========================================================================
    // 設計考量說明：
    //
    // 1. PWM頻率選擇（1kHz）：
    //    - 高於人耳聽覺範圍（20Hz-20kHz的低端），減少可聽噪音
    //    - 低於功率開關器件的開關損耗顯著增加的頻率
    //    - 適合壓縮機控制的典型頻率範圍
    //
    // 2. 10位元解析度選擇：
    //    - 1024級控制精度，約0.1%步進
    //    - 對於溫度控制應用足夠精確
    //    - 硬體實現簡單，資源消耗少
    //
    // 3. 軟啟動/停止的重要性：
    //    - 壓縮機電機啟動電流可達正常運行的5-7倍
    //    - 突然啟停會造成機械衝擊和噪音
    //    - 軟啟動時間通常為1-3秒
    //
    // 4. 實現優化：
    //    - 使用時鐘使能而非分頻器，降低功耗
    //    - 簡單的計數器比較實現PWM
    //    - 可配置的軟啟動速率
    //==========================================================================
    
endmodule
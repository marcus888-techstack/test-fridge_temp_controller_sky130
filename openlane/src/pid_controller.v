//==============================================================================
// File: pid_controller.v
// Description: Digital PID controller with 16-bit fixed-point arithmetic
// Author: IC Design Team
// Date: 2024-12-19
// Target: SKY130 PDK
//==============================================================================
//
// PID控制器原理圖：
// 
//                    ┌─────────────┐
//    Setpoint ───────┤      -      │
//                    │             ├──── Error ───┬───────────────────┐
//    Feedback ───────┤             │              │                   │
//                    └─────────────┘              │                   │
//                                                 │                   │
//                    ┌─────────────┐              │   ┌───────────┐   │
//                    │  Kp × Error ├──────────────┼───┤           │   │
//                    └─────────────┘              │   │           │   │
//                                                 │   │           │   │
//                    ┌─────────────┐              │   │    Sum    ├───┴──── Output
//                    │  Ki × ∫Error├──────────────┼───┤           │
//                    └─────────────┘              │   │           │
//                                                 │   │           │
//                    ┌─────────────┐              │   └───────────┘
//                    │ Kd × d/dt   ├──────────────┘
//                    └─────────────┘
//
// 定點數格式說明：
// Q8.8 格式：16位元定點數
// ┌────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┐
// │ S  │ I7 │ I6 │ I5 │ I4 │ I3 │ I2 │ I1 │ I0 │ F7 │ F6 │ F5 │ F4 │ F3 │ F2 │ F1 │ F0 │
// └────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┘
//   │  └──────────── 整數部分 ────────────┘ └──────────── 小數部分 ────────────┘
//   └─ 符號位
//
// 範圍：-128.0 到 +127.996
// 精度：1/256 ≈ 0.0039
//
// Q16.16 格式：32位元定點數（用於內部計算）
// 範圍：-32768.0 到 +32767.99998
// 精度：1/65536 ≈ 0.0000153

`timescale 1ns / 1ps

module pid_controller (
    // System signals
    input  wire               clk,       // System clock - 系統時鐘
    input  wire               rst_n,     // Active-low reset - 低電平有效重置
    
    // Control interface - 控制介面
    input  wire               enable,    // Enable PID calculation - 使能PID計算
    input  wire signed [15:0] setpoint,  // Desired temperature (Q8.8) - 目標溫度
    input  wire signed [15:0] feedback,  // Current temperature (Q8.8) - 當前溫度
    
    // PID coefficients (Q8.8 format) - PID係數
    input  wire signed [15:0] kp,        // Proportional gain - 比例增益
    input  wire signed [15:0] ki,        // Integral gain - 積分增益  
    input  wire signed [15:0] kd,        // Derivative gain - 微分增益
    
    // Output - 輸出
    output reg  signed [15:0] pid_out    // PID output (Q8.8) - PID輸出
);

    //==========================================================================
    // Parameters - 參數定義
    //==========================================================================
    
    // Saturation limits for integral term (Q16.16)
    // 積分項飽和限制 - 防止積分項過大導致系統不穩定
    // 為什麼需要積分飽和限制：
    // 1. 防止積分器飽和（Integral Windup）
    // 2. 當誤差長時間存在時，積分項會持續累積
    // 3. 如果不限制，可能導致過大的控制輸出和系統震盪
    parameter signed [31:0] INTEGRAL_MAX = 32'h0000_FFFF;  // +255.99 (Q16.16)
    parameter signed [31:0] INTEGRAL_MIN = -32'h0001_0000; // -256.00 (Q16.16)
    
    // Output saturation limits (Q8.8)
    // 輸出飽和限制 - 確保輸出在合理範圍內
    parameter signed [15:0] OUTPUT_MAX = 16'h7FFF;  // Maximum positive - 最大正值
    parameter signed [15:0] OUTPUT_MIN = 16'h8000;  // Maximum negative - 最大負值
    
    //==========================================================================
    // Internal signals - 內部信號
    //==========================================================================
    
    // Error calculations - 誤差計算
    reg  signed [15:0] error;           // Current error (Q8.8) - 當前誤差
    reg  signed [15:0] error_prev;      // Previous error (Q8.8) - 前一次誤差
    wire signed [15:0] error_diff;      // Error difference (Q8.8) - 誤差變化量
    
    // PID terms (Q16.16 for higher precision) - PID項（使用更高精度）
    wire signed [31:0] p_term_temp;     // Proportional term - 比例項臨時值
    reg  signed [31:0] i_term_temp;     // Integral term temporary - 積分項臨時值
    wire signed [31:0] d_term_temp;     // Derivative term - 微分項臨時值
    reg  signed [31:0] integral_acc;    // Integral accumulator (Q16.16) - 積分累加器
    
    // Final PID terms (Q8.8) - 最終PID項
    wire signed [15:0] p_term;          // Proportional term - 比例項
    wire signed [15:0] i_term;          // Integral term - 積分項
    wire signed [15:0] d_term;          // Derivative term - 微分項
    
    // Output calculation - 輸出計算
    wire signed [17:0] output_sum;      // Sum before saturation - 飽和前的總和
    
    //==========================================================================
    // Error calculation - 誤差計算
    // 誤差 = 設定值 - 反饋值
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            error      <= 16'd0;
            error_prev <= 16'd0;
        end else if (enable) begin
            error      <= setpoint - feedback;  // 計算當前誤差
            error_prev <= error;                // 保存前一次誤差，用於微分計算
        end
    end
    
    // 計算誤差變化量（用於微分項）
    assign error_diff = error - error_prev;
    
    //==========================================================================
    // Proportional term calculation - 比例項計算
    // P = Kp * error
    // 比例項作用：
    // 1. 提供與誤差成正比的控制作用
    // 2. 誤差越大，控制作用越強
    // 3. 決定系統的響應速度
    //==========================================================================
    
    // Q8.8 × Q8.8 = Q16.16
    assign p_term_temp = $signed(kp) * $signed(error);
    // 將Q16.16轉換回Q8.8（右移8位）
    assign p_term = p_term_temp[23:8];
    
    //==========================================================================
    // Integral term calculation with anti-windup - 積分項計算（含防飽和）
    // I = Ki * Σ(error)
    // 積分項作用：
    // 1. 消除穩態誤差
    // 2. 累積歷史誤差的影響
    // 3. 需要防止積分飽和
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integral_acc <= 32'd0;
        end else if (enable) begin
            // Calculate new integral value - 計算新的積分值
            // 將Q8.8誤差擴展到Q16.16格式再累加
            i_term_temp = integral_acc + {{16{error[15]}}, error};
            
            // Anti-windup: Saturate integral accumulator
            // 防積分飽和：限制積分累加器的範圍
            if (i_term_temp > INTEGRAL_MAX)
                integral_acc <= INTEGRAL_MAX;      // 限制在最大值
            else if (i_term_temp < INTEGRAL_MIN)
                integral_acc <= INTEGRAL_MIN;      // 限制在最小值
            else
                integral_acc <= i_term_temp;       // 正常累加
        end
    end
    
    // Calculate integral term - 計算積分項
    // Q8.8 × Q16.16 = Q24.24，需要調整到Q8.8
    wire signed [47:0] i_term_mult = $signed(ki) * $signed(integral_acc);
    assign i_term = i_term_mult[31:16];  // 提取Q8.8結果
    
    //==========================================================================
    // Derivative term calculation - 微分項計算
    // D = Kd * (error - error_prev)
    // 微分項作用：
    // 1. 預測誤差的變化趨勢
    // 2. 提供阻尼作用，減少超調
    // 3. 改善系統的動態響應
    //==========================================================================
    
    // Q8.8 × Q8.8 = Q16.16
    assign d_term_temp = $signed(kd) * $signed(error_diff);
    // 將Q16.16轉換回Q8.8
    assign d_term = d_term_temp[23:8];
    
    //==========================================================================
    // Output calculation with saturation - 輸出計算（含飽和處理）
    // Output = P + I + D
    // 為什麼需要飽和處理：
    // 1. 防止數值溢出
    // 2. 限制控制輸出在合理範圍
    // 3. 保護執行機構（如壓縮機）
    //==========================================================================
    
    // 將三個項相加（擴展到18位防止溢出）
    assign output_sum = $signed({p_term[15], p_term}) + 
                       $signed({i_term[15], i_term}) + 
                       $signed({d_term[15], d_term});
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pid_out <= 16'd0;
        end else if (enable) begin
            // Saturate output - 輸出飽和處理
            if (output_sum > $signed({1'b0, OUTPUT_MAX}))
                pid_out <= OUTPUT_MAX;          // 限制在最大值
            else if (output_sum < $signed({1'b1, OUTPUT_MIN}))
                pid_out <= OUTPUT_MIN;          // 限制在最小值
            else
                pid_out <= output_sum[15:0];    // 正常輸出
        end
    end
    
    //==========================================================================
    // Debug signals (synthesis will optimize away if unused)
    // 調試信號 - 綜合時如果未使用會被優化掉
    //==========================================================================
    
    `ifdef DEBUG
    wire signed [15:0] debug_p_term = p_term;
    wire signed [15:0] debug_i_term = i_term;
    wire signed [15:0] debug_d_term = d_term;
    wire signed [31:0] debug_integral = integral_acc;
    wire signed [15:0] debug_error = error;
    `endif
    
    //==========================================================================
    // 設計考量說明：
    // 
    // 1. 為什麼使用定點數而非浮點數：
    //    - 硬體實現簡單，面積小
    //    - 運算速度快，功耗低
    //    - 精度足夠溫度控制應用
    //
    // 2. Q8.8和Q16.16格式的選擇：
    //    - Q8.8：適合溫度範圍（-128°C到+127°C）和精度要求（0.004°C）
    //    - Q16.16：內部計算使用，防止中間結果溢出
    //
    // 3. PID參數調整建議：
    //    - Kp：從小值開始（如0.5），逐漸增加直到系統響應迅速但不震盪
    //    - Ki：從0開始，緩慢增加以消除穩態誤差
    //    - Kd：通常較小（如0.1），用於減少超調
    //
    // 4. 防積分飽和的重要性：
    //    - 冰箱門打開時，溫度會快速上升
    //    - 如果不限制積分項，會導致過度製冷
    //    - 限制範圍需要根據實際系統調整
    //==========================================================================
    
endmodule
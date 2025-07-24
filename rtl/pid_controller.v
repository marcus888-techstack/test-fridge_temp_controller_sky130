//==============================================================================
// File: pid_controller.v
// Description: Digital PID controller with 16-bit fixed-point arithmetic
// Author: IC Design Team
// Date: 2024-12-19
// Target: SKY130 PDK
//==============================================================================

`timescale 1ns / 1ps

module pid_controller (
    // System signals
    input  wire               clk,       // System clock
    input  wire               rst_n,     // Active-low reset
    
    // Control interface
    input  wire               enable,    // Enable PID calculation
    input  wire signed [15:0] setpoint,  // Desired temperature (Q8.8)
    input  wire signed [15:0] feedback,  // Current temperature (Q8.8)
    
    // PID coefficients (Q8.8 format)
    input  wire signed [15:0] kp,        // Proportional gain
    input  wire signed [15:0] ki,        // Integral gain
    input  wire signed [15:0] kd,        // Derivative gain
    
    // Output
    output reg  signed [15:0] output     // PID output (Q8.8)
);

    //==========================================================================
    // Parameters
    //==========================================================================
    
    // Saturation limits for integral term (Q16.16)
    parameter signed [31:0] INTEGRAL_MAX = 32'h0000_FFFF;  // +255.99
    parameter signed [31:0] INTEGRAL_MIN = -32'h0001_0000; // -256.00
    
    // Output saturation limits (Q8.8)
    parameter signed [15:0] OUTPUT_MAX = 16'h7FFF;  // Maximum positive
    parameter signed [15:0] OUTPUT_MIN = 16'h8000;  // Maximum negative
    
    //==========================================================================
    // Internal signals
    //==========================================================================
    
    // Error calculations
    reg  signed [15:0] error;           // Current error (Q8.8)
    reg  signed [15:0] error_prev;      // Previous error (Q8.8)
    wire signed [15:0] error_diff;      // Error difference (Q8.8)
    
    // PID terms (Q16.16 for higher precision)
    wire signed [31:0] p_term_temp;     // Proportional term
    wire signed [31:0] i_term_temp;     // Integral term temporary
    wire signed [31:0] d_term_temp;     // Derivative term
    reg  signed [31:0] integral_acc;    // Integral accumulator (Q16.16)
    
    // Final PID terms (Q8.8)
    wire signed [15:0] p_term;          // Proportional term
    wire signed [15:0] i_term;          // Integral term
    wire signed [15:0] d_term;          // Derivative term
    
    // Output calculation
    wire signed [17:0] output_sum;      // Sum before saturation
    
    //==========================================================================
    // Error calculation
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            error      <= 16'd0;
            error_prev <= 16'd0;
        end else if (enable) begin
            error      <= setpoint - feedback;
            error_prev <= error;
        end
    end
    
    assign error_diff = error - error_prev;
    
    //==========================================================================
    // Proportional term calculation
    // P = Kp * error
    //==========================================================================
    
    assign p_term_temp = $signed(kp) * $signed(error);
    assign p_term = p_term_temp[23:8];  // Convert Q16.16 to Q8.8
    
    //==========================================================================
    // Integral term calculation with anti-windup
    // I = Ki * Σ(error)
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integral_acc <= 32'd0;
        end else if (enable) begin
            // Calculate new integral value
            i_term_temp = integral_acc + {{16{error[15]}}, error};
            
            // Anti-windup: Saturate integral accumulator
            if (i_term_temp > INTEGRAL_MAX)
                integral_acc <= INTEGRAL_MAX;
            else if (i_term_temp < INTEGRAL_MIN)
                integral_acc <= INTEGRAL_MIN;
            else
                integral_acc <= i_term_temp;
        end
    end
    
    // Calculate integral term
    wire signed [47:0] i_term_mult = $signed(ki) * $signed(integral_acc);
    assign i_term = i_term_mult[31:16];  // Extract Q8.8 result
    
    //==========================================================================
    // Derivative term calculation
    // D = Kd * (error - error_prev)
    //==========================================================================
    
    assign d_term_temp = $signed(kd) * $signed(error_diff);
    assign d_term = d_term_temp[23:8];  // Convert Q16.16 to Q8.8
    
    //==========================================================================
    // Output calculation with saturation
    //==========================================================================
    
    assign output_sum = $signed({p_term[15], p_term}) + 
                       $signed({i_term[15], i_term}) + 
                       $signed({d_term[15], d_term});
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            output <= 16'd0;
        end else if (enable) begin
            // Saturate output
            if (output_sum > $signed({1'b0, OUTPUT_MAX}))
                output <= OUTPUT_MAX;
            else if (output_sum < $signed({1'b1, OUTPUT_MIN}))
                output <= OUTPUT_MIN;
            else
                output <= output_sum[15:0];
        end
    end
    
    //==========================================================================
    // Debug signals (synthesis will optimize away if unused)
    //==========================================================================
    
    `ifdef DEBUG
    wire signed [15:0] debug_p_term = p_term;
    wire signed [15:0] debug_i_term = i_term;
    wire signed [15:0] debug_d_term = d_term;
    wire signed [31:0] debug_integral = integral_acc;
    wire signed [15:0] debug_error = error;
    `endif
    
endmodule
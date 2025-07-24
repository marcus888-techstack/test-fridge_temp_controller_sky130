//==============================================================================
// File: pwm_generator.v
// Description: PWM generator with 10-bit resolution and soft start/stop
// Author: IC Design Team
// Date: 2024-12-19
// Target: SKY130 PDK
//==============================================================================

`timescale 1ns / 1ps

module pwm_generator (
    // System signals
    input  wire        clk,         // System clock (10 MHz)
    input  wire        rst_n,       // Active-low reset
    input  wire        clk_1khz,    // 1 kHz clock enable
    
    // Control interface
    input  wire        enable,      // Enable PWM output
    input  wire [9:0]  duty_cycle,  // Duty cycle (0-1023)
    input  wire        soft_start,  // Enable soft start/stop
    
    // Output
    output reg         pwm_out      // PWM output signal
);

    //==========================================================================
    // Parameters
    //==========================================================================
    
    parameter [9:0] PWM_PERIOD = 10'd1023;  // PWM period (10-bit)
    parameter [3:0] SOFT_START_RATE = 4'd1;  // Soft start increment rate
    
    //==========================================================================
    // Internal signals
    //==========================================================================
    
    reg [9:0]  pwm_counter;         // PWM counter
    reg [9:0]  duty_cycle_actual;   // Actual duty cycle (after soft start)
    reg [15:0] soft_start_timer;    // Timer for soft start rate control
    reg        pwm_enable_sync;     // Synchronized enable signal
    reg        pwm_enable_prev;     // Previous enable for edge detection
    wire       enable_rising_edge;  // Enable rising edge
    wire       enable_falling_edge; // Enable falling edge
    
    //==========================================================================
    // Enable edge detection
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_enable_sync <= 1'b0;
            pwm_enable_prev <= 1'b0;
        end else begin
            pwm_enable_sync <= enable;
            pwm_enable_prev <= pwm_enable_sync;
        end
    end
    
    assign enable_rising_edge  = pwm_enable_sync & ~pwm_enable_prev;
    assign enable_falling_edge = ~pwm_enable_sync & pwm_enable_prev;
    
    //==========================================================================
    // PWM counter
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_counter <= 10'd0;
        end else if (clk_1khz) begin
            if (pwm_counter == PWM_PERIOD)
                pwm_counter <= 10'd0;
            else
                pwm_counter <= pwm_counter + 1'b1;
        end
    end
    
    //==========================================================================
    // Soft start/stop control
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            duty_cycle_actual <= 10'd0;
            soft_start_timer  <= 16'd0;
        end else begin
            if (soft_start) begin
                // Soft start enabled
                if (pwm_enable_sync) begin
                    // Ramping up
                    if (duty_cycle_actual < duty_cycle) begin
                        if (soft_start_timer == 16'd9999) begin  // 1ms @ 10MHz
                            soft_start_timer <= 16'd0;
                            if (duty_cycle_actual + SOFT_START_RATE < duty_cycle)
                                duty_cycle_actual <= duty_cycle_actual + SOFT_START_RATE;
                            else
                                duty_cycle_actual <= duty_cycle;
                        end else begin
                            soft_start_timer <= soft_start_timer + 1'b1;
                        end
                    end else if (duty_cycle_actual > duty_cycle) begin
                        // Target decreased, ramp down
                        if (soft_start_timer == 16'd9999) begin
                            soft_start_timer <= 16'd0;
                            if (duty_cycle_actual > duty_cycle + SOFT_START_RATE)
                                duty_cycle_actual <= duty_cycle_actual - SOFT_START_RATE;
                            else
                                duty_cycle_actual <= duty_cycle;
                        end else begin
                            soft_start_timer <= soft_start_timer + 1'b1;
                        end
                    end else begin
                        // At target
                        soft_start_timer <= 16'd0;
                    end
                end else begin
                    // Ramping down to zero
                    if (duty_cycle_actual > 10'd0) begin
                        if (soft_start_timer == 16'd9999) begin
                            soft_start_timer <= 16'd0;
                            if (duty_cycle_actual > SOFT_START_RATE)
                                duty_cycle_actual <= duty_cycle_actual - SOFT_START_RATE;
                            else
                                duty_cycle_actual <= 10'd0;
                        end else begin
                            soft_start_timer <= soft_start_timer + 1'b1;
                        end
                    end else begin
                        soft_start_timer <= 16'd0;
                    end
                end
            end else begin
                // Soft start disabled - immediate response
                if (pwm_enable_sync)
                    duty_cycle_actual <= duty_cycle;
                else
                    duty_cycle_actual <= 10'd0;
                soft_start_timer <= 16'd0;
            end
        end
    end
    
    //==========================================================================
    // PWM output generation
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_out <= 1'b0;
        end else if (clk_1khz) begin
            if (duty_cycle_actual == 10'd0) begin
                pwm_out <= 1'b0;
            end else if (duty_cycle_actual > PWM_PERIOD) begin
                pwm_out <= 1'b1;  // 100% duty cycle
            end else begin
                pwm_out <= (pwm_counter < duty_cycle_actual) ? 1'b1 : 1'b0;
            end
        end
    end
    
endmodule
//==============================================================================
// File: display_controller.v
// Description: 7-segment display controller with multiplexing support
// Author: IC Design Team
// Date: 2024-12-19
// Target: SKY130 PDK
//==============================================================================

`timescale 1ns / 1ps

module display_controller (
    // System signals
    input  wire        clk,         // System clock (10 MHz)
    input  wire        rst_n,       // Active-low reset
    input  wire        clk_100hz,   // 100 Hz clock enable
    
    // Data interface
    input  wire [15:0] value,       // Value to display (Q8.8 format)
    input  wire [1:0]  decimal_pt,  // Decimal point position
    input  wire        blink,       // Blink enable
    
    // Display outputs
    output reg  [6:0]  seven_seg,   // 7-segment display (a-g)
    output reg  [3:0]  digit_sel    // Digit select (active low)
);

    //==========================================================================
    // Parameters
    //==========================================================================
    
    // 7-segment patterns for digits 0-9 and special characters
    // Segment order: gfedcba
    parameter SEG_0     = 7'b0111111;  // 0
    parameter SEG_1     = 7'b0000110;  // 1
    parameter SEG_2     = 7'b1011011;  // 2
    parameter SEG_3     = 7'b1001111;  // 3
    parameter SEG_4     = 7'b1100110;  // 4
    parameter SEG_5     = 7'b1101101;  // 5
    parameter SEG_6     = 7'b1111101;  // 6
    parameter SEG_7     = 7'b0000111;  // 7
    parameter SEG_8     = 7'b1111111;  // 8
    parameter SEG_9     = 7'b1101111;  // 9
    parameter SEG_MINUS = 7'b1000000;  // -
    parameter SEG_E     = 7'b1111001;  // E
    parameter SEG_BLANK = 7'b0000000;  // Blank
    parameter SEG_DP    = 7'b10000000; // Decimal point
    
    //==========================================================================
    // Internal signals
    //==========================================================================
    
    reg [1:0]  digit_counter;       // Current digit being displayed
    reg [3:0]  digit_value [0:3];   // BCD values for each digit
    reg        digit_negative;      // Negative sign flag
    reg [15:0] abs_value;           // Absolute value
    reg [6:0]  blink_counter;       // Blink timing counter
    reg        blink_state;         // Current blink state
    
    // BCD conversion signals
    reg [19:0] bcd_result;          // BCD conversion result
    reg [15:0] binary_in;           // Binary input for conversion
    reg [3:0]  bcd_shift_counter;   // Shift counter for BCD
    
    //==========================================================================
    // Digit multiplexing
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            digit_counter <= 2'd0;
        end else if (clk_100hz) begin
            digit_counter <= digit_counter + 1'b1;
        end
    end
    
    //==========================================================================
    // Blink control
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            blink_counter <= 7'd0;
            blink_state   <= 1'b1;
        end else if (clk_100hz) begin
            if (blink_counter == 7'd49) begin  // Toggle every 0.5 seconds
                blink_counter <= 7'd0;
                blink_state   <= ~blink_state;
            end else begin
                blink_counter <= blink_counter + 1'b1;
            end
        end
    end
    
    //==========================================================================
    // Value processing
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            digit_negative <= 1'b0;
            abs_value      <= 16'd0;
        end else begin
            // Check if value is negative
            if (value[15]) begin
                digit_negative <= 1'b1;
                abs_value      <= -value;  // Two's complement
            end else begin
                digit_negative <= 1'b0;
                abs_value      <= value;
            end
        end
    end
    
    //==========================================================================
    // Binary to BCD conversion (Double Dabble algorithm)
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bcd_result       <= 20'd0;
            binary_in        <= 16'd0;
            bcd_shift_counter <= 4'd0;
        end else begin
            if (bcd_shift_counter == 4'd0) begin
                // Start new conversion
                binary_in        <= abs_value;
                bcd_result       <= 20'd0;
                bcd_shift_counter <= 4'd15;
            end else begin
                // Shift and adjust
                bcd_shift_counter <= bcd_shift_counter - 1'b1;
                
                // Adjust BCD digits if >= 5
                if (bcd_result[3:0] >= 4'd5)
                    bcd_result[3:0] <= bcd_result[3:0] + 4'd3;
                if (bcd_result[7:4] >= 4'd5)
                    bcd_result[7:4] <= bcd_result[7:4] + 4'd3;
                if (bcd_result[11:8] >= 4'd5)
                    bcd_result[11:8] <= bcd_result[11:8] + 4'd3;
                if (bcd_result[15:12] >= 4'd5)
                    bcd_result[15:12] <= bcd_result[15:12] + 4'd3;
                
                // Shift left
                {bcd_result, binary_in} <= {bcd_result[18:0], binary_in, 1'b0};
            end
        end
    end
    
    //==========================================================================
    // Extract digits based on Q8.8 format
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            digit_value[0] <= 4'd0;
            digit_value[1] <= 4'd0;
            digit_value[2] <= 4'd0;
            digit_value[3] <= 4'd0;
        end else begin
            // For temperature display in XX.X format
            // Integer part: value[15:8], Fractional part: value[7:0]
            
            // Extract integer part (tens and ones)
            digit_value[3] <= (abs_value[15:8] / 10) % 10;  // Tens
            digit_value[2] <= abs_value[15:8] % 10;         // Ones
            
            // Extract fractional part (tenths)
            // Convert Q0.8 to decimal: multiply by 10 and shift
            digit_value[1] <= (abs_value[7:0] * 10) >> 8;   // Tenths
            digit_value[0] <= 4'd0;                          // Not used
        end
    end
    
    //==========================================================================
    // 7-segment decoder and output multiplexing
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seven_seg <= 7'b0000000;
            digit_sel <= 4'b1111;
        end else begin
            // Default all digits off
            digit_sel <= 4'b1111;
            
            // Handle blinking
            if (blink && !blink_state) begin
                seven_seg <= SEG_BLANK;
            end else begin
                case (digit_counter)
                    2'd0: begin  // Rightmost digit (tenths)
                        digit_sel <= 4'b1110;
                        case (digit_value[1])
                            4'd0: seven_seg <= SEG_0;
                            4'd1: seven_seg <= SEG_1;
                            4'd2: seven_seg <= SEG_2;
                            4'd3: seven_seg <= SEG_3;
                            4'd4: seven_seg <= SEG_4;
                            4'd5: seven_seg <= SEG_5;
                            4'd6: seven_seg <= SEG_6;
                            4'd7: seven_seg <= SEG_7;
                            4'd8: seven_seg <= SEG_8;
                            4'd9: seven_seg <= SEG_9;
                            default: seven_seg <= SEG_BLANK;
                        endcase
                    end
                    
                    2'd1: begin  // Ones digit with decimal point
                        digit_sel <= 4'b1101;
                        case (digit_value[2])
                            4'd0: seven_seg <= SEG_0 | SEG_DP;
                            4'd1: seven_seg <= SEG_1 | SEG_DP;
                            4'd2: seven_seg <= SEG_2 | SEG_DP;
                            4'd3: seven_seg <= SEG_3 | SEG_DP;
                            4'd4: seven_seg <= SEG_4 | SEG_DP;
                            4'd5: seven_seg <= SEG_5 | SEG_DP;
                            4'd6: seven_seg <= SEG_6 | SEG_DP;
                            4'd7: seven_seg <= SEG_7 | SEG_DP;
                            4'd8: seven_seg <= SEG_8 | SEG_DP;
                            4'd9: seven_seg <= SEG_9 | SEG_DP;
                            default: seven_seg <= SEG_BLANK;
                        endcase
                    end
                    
                    2'd2: begin  // Tens digit or minus sign
                        digit_sel <= 4'b1011;
                        if (digit_negative && digit_value[3] == 4'd0) begin
                            seven_seg <= SEG_MINUS;
                        end else if (digit_value[3] != 4'd0) begin
                            case (digit_value[3])
                                4'd0: seven_seg <= SEG_0;
                                4'd1: seven_seg <= SEG_1;
                                4'd2: seven_seg <= SEG_2;
                                4'd3: seven_seg <= SEG_3;
                                4'd4: seven_seg <= SEG_4;
                                4'd5: seven_seg <= SEG_5;
                                4'd6: seven_seg <= SEG_6;
                                4'd7: seven_seg <= SEG_7;
                                4'd8: seven_seg <= SEG_8;
                                4'd9: seven_seg <= SEG_9;
                                default: seven_seg <= SEG_BLANK;
                            endcase
                        end else begin
                            seven_seg <= SEG_BLANK;
                        end
                    end
                    
                    2'd3: begin  // Leftmost digit (minus sign if needed)
                        digit_sel <= 4'b0111;
                        if (digit_negative && digit_value[3] != 4'd0) begin
                            seven_seg <= SEG_MINUS;
                        end else begin
                            seven_seg <= SEG_BLANK;
                        end
                    end
                endcase
            end
        end
    end
    
endmodule
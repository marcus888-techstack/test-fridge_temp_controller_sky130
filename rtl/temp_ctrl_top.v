//==============================================================================
// File: temp_ctrl_top.v
// Description: Top-level module for refrigerator temperature controller
// Author: IC Design Team
// Date: 2024-12-19
// Target: SKY130 PDK
//==============================================================================

`timescale 1ns / 1ps

module temp_ctrl_top (
    // System signals
    input  wire        clk,           // 10 MHz system clock
    input  wire        rst_n,         // Active-low reset
    
    // ADC interface
    input  wire        adc_miso,      // ADC data input
    output wire        adc_mosi,      // ADC data output  
    output wire        adc_sclk,      // ADC clock
    output wire        adc_cs_n,      // ADC chip select
    
    // Control outputs
    output wire        compressor_pwm, // Compressor PWM control
    output wire        defrost_heater, // Defrost heater control
    output wire        alarm,          // Alarm output
    
    // Display interface
    output wire [6:0]  seven_seg,     // 7-segment display segments
    output wire [3:0]  digit_sel,     // Digit select (multiplexed)
    output wire [2:0]  status_led,    // Status LEDs
    
    // User interface
    input  wire        door_sensor,    // Door open sensor
    input  wire        button_up,      // Temperature up button
    input  wire        button_down,    // Temperature down button
    input  wire        button_mode     // Mode selection button
);

    //==========================================================================
    // Parameters
    //==========================================================================
    
    // Temperature limits (Q8.8 fixed-point format)
    parameter signed [15:0] TEMP_MIN      = 16'hEC00;  // -20.0°C
    parameter signed [15:0] TEMP_MAX      = 16'h0A00;  // +10.0°C
    parameter signed [15:0] TEMP_DEFAULT  = 16'h0400;  // +4.0°C
    parameter        [15:0] TEMP_STEP     = 16'h0080;  // 0.5°C
    
    // Timing parameters (in clock cycles)
    parameter [31:0] SAMPLE_PERIOD    = 32'd10_000_000; // 1 second @ 10MHz
    parameter [31:0] DEFROST_PERIOD   = 32'd288_000_000_000; // 8 hours
    parameter [31:0] DEFROST_DURATION = 32'd18_000_000_000;  // 30 minutes
    parameter [31:0] DOOR_ALARM_DELAY = 32'd1_200_000_000;   // 2 minutes
    
    //==========================================================================
    // Internal signals
    //==========================================================================
    
    // Clock and reset
    wire clk_1mhz;
    wire clk_1khz;
    wire clk_100hz;
    reg  rst_sync;
    reg  rst_sync_d;
    
    // Temperature signals
    wire signed [15:0] temp_current;
    reg  signed [15:0] temp_setpoint;
    wire        [11:0] adc_data;
    wire               adc_valid;
    
    // Control signals
    wire signed [15:0] pid_output;
    wire        [9:0]  pwm_duty_cycle;
    reg                compressor_enable;
    reg                defrost_active;
    
    // State machine
    reg  [2:0] current_state;
    reg  [2:0] next_state;
    
    localparam STATE_INIT       = 3'b000;
    localparam STATE_NORMAL     = 3'b001;
    localparam STATE_DEFROST    = 3'b010;
    localparam STATE_DOOR_OPEN  = 3'b011;
    localparam STATE_ALARM      = 3'b100;
    localparam STATE_TEST       = 3'b101;
    
    // Timers
    reg [31:0] sample_timer;
    reg [31:0] defrost_timer;
    reg [31:0] door_timer;
    reg [31:0] compressor_timer;
    
    // User interface
    reg button_up_sync, button_up_prev;
    reg button_down_sync, button_down_prev;
    reg button_mode_sync, button_mode_prev;
    reg door_sensor_sync;
    wire button_up_edge;
    wire button_down_edge;
    wire button_mode_edge;
    
    // Display
    reg [1:0] display_mode;
    reg [15:0] display_value;
    reg display_blink;
    
    //==========================================================================
    // Clock generation
    //==========================================================================
    
    // Clock divider for 1MHz (SPI)
    reg [3:0] clk_div_10;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div_10 <= 4'd0;
        end else begin
            clk_div_10 <= (clk_div_10 == 4'd9) ? 4'd0 : clk_div_10 + 1'b1;
        end
    end
    assign clk_1mhz = (clk_div_10 < 4'd5);
    
    // Clock divider for 1kHz (PWM)
    reg [13:0] clk_div_10k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div_10k <= 14'd0;
        end else begin
            clk_div_10k <= (clk_div_10k == 14'd9999) ? 14'd0 : clk_div_10k + 1'b1;
        end
    end
    assign clk_1khz = (clk_div_10k == 14'd0);
    
    // Clock divider for 100Hz (Display)
    reg [16:0] clk_div_100k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div_100k <= 17'd0;
        end else begin
            clk_div_100k <= (clk_div_100k == 17'd99999) ? 17'd0 : clk_div_100k + 1'b1;
        end
    end
    assign clk_100hz = (clk_div_100k == 17'd0);
    
    //==========================================================================
    // Reset synchronization
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rst_sync   <= 1'b0;
            rst_sync_d <= 1'b0;
        end else begin
            rst_sync   <= 1'b1;
            rst_sync_d <= rst_sync;
        end
    end
    
    //==========================================================================
    // Input synchronization and edge detection
    //==========================================================================
    
    always @(posedge clk or negedge rst_sync_d) begin
        if (!rst_sync_d) begin
            button_up_sync   <= 1'b0;
            button_up_prev   <= 1'b0;
            button_down_sync <= 1'b0;
            button_down_prev <= 1'b0;
            button_mode_sync <= 1'b0;
            button_mode_prev <= 1'b0;
            door_sensor_sync <= 1'b0;
        end else begin
            button_up_sync   <= button_up;
            button_up_prev   <= button_up_sync;
            button_down_sync <= button_down;
            button_down_prev <= button_down_sync;
            button_mode_sync <= button_mode;
            button_mode_prev <= button_mode_sync;
            door_sensor_sync <= door_sensor;
        end
    end
    
    assign button_up_edge   = button_up_sync & ~button_up_prev;
    assign button_down_edge = button_down_sync & ~button_down_prev;
    assign button_mode_edge = button_mode_sync & ~button_mode_prev;
    
    //==========================================================================
    // ADC Interface instantiation
    //==========================================================================
    
    adc_spi_interface u_adc_spi (
        .clk        (clk),
        .rst_n      (rst_sync_d),
        .clk_1mhz   (clk_1mhz),
        .start      (sample_timer == 32'd0),
        .channel    (3'd0),      // Channel 0 for temperature
        .adc_data   (adc_data),
        .adc_valid  (adc_valid),
        .spi_miso   (adc_miso),
        .spi_mosi   (adc_mosi),
        .spi_sclk   (adc_sclk),
        .spi_cs_n   (adc_cs_n)
    );
    
    //==========================================================================
    // Temperature conversion
    //==========================================================================
    
    // Convert ADC value to temperature in Q8.8 format
    // Temperature(°C) = (ADC_Value × Vref / 4096 - 0.5) × 100
    // Simplified for fixed-point: temp = (adc_data * 82 - 2048) >> 2
    
    wire signed [19:0] temp_calc = $signed({8'd0, adc_data}) * 20'd82 - 20'd2048;
    assign temp_current = temp_calc[17:2];  // Q8.8 result
    
    //==========================================================================
    // PID Controller instantiation
    //==========================================================================
    
    pid_controller u_pid (
        .clk        (clk),
        .rst_n      (rst_sync_d),
        .enable     (compressor_enable & adc_valid),
        .setpoint   (temp_setpoint),
        .feedback   (temp_current),
        .kp         (16'h0200),  // Kp = 2.0
        .ki         (16'h001A),  // Ki = 0.1
        .kd         (16'h000D),  // Kd = 0.05
        .output     (pid_output)
    );
    
    //==========================================================================
    // PWM duty cycle calculation
    //==========================================================================
    
    // Convert PID output to PWM duty cycle (0-1023)
    // Saturate to valid range
    wire signed [15:0] pwm_temp = pid_output + 16'h0200;  // Add offset
    assign pwm_duty_cycle = (pwm_temp < 0) ? 10'd0 :
                           (pwm_temp > 16'h03FF) ? 10'd1023 :
                           pwm_temp[9:0];
    
    //==========================================================================
    // PWM Generator instantiation
    //==========================================================================
    
    pwm_generator u_pwm (
        .clk        (clk),
        .rst_n      (rst_sync_d),
        .clk_1khz   (clk_1khz),
        .enable     (compressor_enable),
        .duty_cycle (pwm_duty_cycle),
        .soft_start (1'b1),
        .pwm_out    (compressor_pwm)
    );
    
    //==========================================================================
    // State Machine
    //==========================================================================
    
    // State register
    always @(posedge clk or negedge rst_sync_d) begin
        if (!rst_sync_d) begin
            current_state <= STATE_INIT;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = current_state;
        
        case (current_state)
            STATE_INIT: begin
                if (sample_timer > 32'd10_000_000)  // 1 second initialization
                    next_state = STATE_NORMAL;
            end
            
            STATE_NORMAL: begin
                if (door_sensor_sync)
                    next_state = STATE_DOOR_OPEN;
                else if (defrost_timer == 32'd0)
                    next_state = STATE_DEFROST;
                else if ((temp_current > 16'h0A00) || (temp_current < 16'hE700))
                    next_state = STATE_ALARM;
            end
            
            STATE_DOOR_OPEN: begin
                if (!door_sensor_sync)
                    next_state = STATE_NORMAL;
                else if (door_timer == 32'd0)
                    next_state = STATE_ALARM;
            end
            
            STATE_DEFROST: begin
                if (defrost_timer == 32'd0)
                    next_state = STATE_NORMAL;
            end
            
            STATE_ALARM: begin
                if (button_mode_edge)
                    next_state = STATE_NORMAL;
            end
            
            STATE_TEST: begin
                if (button_mode_edge)
                    next_state = STATE_NORMAL;
            end
            
            default: next_state = STATE_INIT;
        endcase
    end
    
    //==========================================================================
    // Control logic
    //==========================================================================
    
    always @(posedge clk or negedge rst_sync_d) begin
        if (!rst_sync_d) begin
            compressor_enable <= 1'b0;
            defrost_active    <= 1'b0;
        end else begin
            case (current_state)
                STATE_INIT: begin
                    compressor_enable <= 1'b0;
                    defrost_active    <= 1'b0;
                end
                
                STATE_NORMAL: begin
                    compressor_enable <= (compressor_timer == 32'd0);
                    defrost_active    <= 1'b0;
                end
                
                STATE_DOOR_OPEN: begin
                    // Keep current state
                end
                
                STATE_DEFROST: begin
                    compressor_enable <= 1'b0;
                    defrost_active    <= 1'b1;
                end
                
                STATE_ALARM: begin
                    compressor_enable <= 1'b0;
                    defrost_active    <= 1'b0;
                end
                
                default: begin
                    compressor_enable <= 1'b0;
                    defrost_active    <= 1'b0;
                end
            endcase
        end
    end
    
    assign defrost_heater = defrost_active;
    assign alarm = (current_state == STATE_ALARM);
    
    //==========================================================================
    // Timer management
    //==========================================================================
    
    always @(posedge clk or negedge rst_sync_d) begin
        if (!rst_sync_d) begin
            sample_timer     <= 32'd0;
            defrost_timer    <= DEFROST_PERIOD;
            door_timer       <= DOOR_ALARM_DELAY;
            compressor_timer <= 32'd30_000_000;  // 3 seconds initial delay
        end else begin
            // Sample timer (1 second period)
            if (sample_timer == 32'd0)
                sample_timer <= SAMPLE_PERIOD - 1;
            else
                sample_timer <= sample_timer - 1'b1;
            
            // Defrost timer
            if (current_state == STATE_DEFROST) begin
                if (defrost_timer > 32'd0)
                    defrost_timer <= defrost_timer - 1'b1;
                else
                    defrost_timer <= DEFROST_PERIOD;
            end else if (current_state == STATE_NORMAL) begin
                if (defrost_timer > 32'd0)
                    defrost_timer <= defrost_timer - 1'b1;
            end
            
            // Door timer
            if (current_state == STATE_DOOR_OPEN) begin
                if (door_timer > 32'd0)
                    door_timer <= door_timer - 1'b1;
            end else begin
                door_timer <= DOOR_ALARM_DELAY;
            end
            
            // Compressor protection timer
            if (!compressor_enable && (compressor_timer > 32'd0))
                compressor_timer <= compressor_timer - 1'b1;
            else if (compressor_enable)
                compressor_timer <= 32'd30_000_000;  // 3 seconds minimum off time
        end
    end
    
    //==========================================================================
    // Temperature setpoint adjustment
    //==========================================================================
    
    always @(posedge clk or negedge rst_sync_d) begin
        if (!rst_sync_d) begin
            temp_setpoint <= TEMP_DEFAULT;
        end else begin
            if (button_up_edge && (temp_setpoint < TEMP_MAX - TEMP_STEP))
                temp_setpoint <= temp_setpoint + TEMP_STEP;
            else if (button_down_edge && (temp_setpoint > TEMP_MIN + TEMP_STEP))
                temp_setpoint <= temp_setpoint - TEMP_STEP;
        end
    end
    
    //==========================================================================
    // Display control
    //==========================================================================
    
    always @(posedge clk or negedge rst_sync_d) begin
        if (!rst_sync_d) begin
            display_mode  <= 2'b00;
            display_value <= 16'd0;
            display_blink <= 1'b0;
        end else begin
            // Mode selection
            if (button_mode_edge)
                display_mode <= display_mode + 1'b1;
            
            // Select display value
            case (display_mode)
                2'b00: display_value <= temp_current;     // Current temperature
                2'b01: display_value <= temp_setpoint;    // Set temperature
                2'b10: display_value <= {6'd0, pwm_duty_cycle}; // PWM duty
                2'b11: display_value <= {13'd0, current_state}; // State
            endcase
            
            // Blink control for setpoint mode
            display_blink <= (display_mode == 2'b01);
        end
    end
    
    //==========================================================================
    // Display controller instantiation
    //==========================================================================
    
    display_controller u_display (
        .clk        (clk),
        .rst_n      (rst_sync_d),
        .clk_100hz  (clk_100hz),
        .value      (display_value),
        .decimal_pt (2'b01),      // XX.X format
        .blink      (display_blink),
        .seven_seg  (seven_seg),
        .digit_sel  (digit_sel)
    );
    
    //==========================================================================
    // Status LED assignment
    //==========================================================================
    
    assign status_led[0] = (current_state == STATE_NORMAL);   // Green - Normal
    assign status_led[1] = (current_state == STATE_DEFROST);  // Yellow - Defrost
    assign status_led[2] = (current_state == STATE_ALARM);    // Red - Alarm
    
endmodule
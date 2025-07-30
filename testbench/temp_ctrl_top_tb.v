//==============================================================================
// File: temp_ctrl_top_tb.v
// Description: Testbench for temperature controller top module
// Author: IC Design Team
// Date: 2024-12-19
//==============================================================================

`timescale 1ns / 1ps

module temp_ctrl_top_tb;

    //==========================================================================
    // Parameters
    //==========================================================================
    
    parameter CLK_PERIOD = 100;  // 10 MHz clock (100 ns period)
    parameter SIM_TIME = 100_000_000;  // 100 ms simulation time
    
    //==========================================================================
    // Signal declarations
    //==========================================================================
    
    // System signals
    reg         clk;
    reg         rst_n;
    
    // ADC interface
    reg         adc_miso;
    wire        adc_mosi;
    wire        adc_sclk;
    wire        adc_cs_n;
    
    // Control outputs
    wire        compressor_pwm;
    wire        defrost_heater;
    wire        alarm;
    
    // Display interface
    wire [6:0]  seven_seg;
    wire [3:0]  digit_sel;
    wire [2:0]  status_led;
    
    // User interface
    reg         door_sensor;
    reg         button_up;
    reg         button_down;
    reg         button_mode;
    
    // Test variables
    reg  [11:0] adc_value;
    reg  [15:0] test_temperature;
    real        temperature_celsius;
    integer     test_case;
    integer     error_count;
    
    //==========================================================================
    // DUT instantiation
    //==========================================================================
    
    temp_ctrl_top DUT (
        // System signals
        .clk            (clk),
        .rst_n          (rst_n),
        
        // ADC interface
        .adc_miso       (adc_miso),
        .adc_mosi       (adc_mosi),
        .adc_sclk       (adc_sclk),
        .adc_cs_n       (adc_cs_n),
        
        // Control outputs
        .compressor_pwm (compressor_pwm),
        .defrost_heater (defrost_heater),
        .alarm          (alarm),
        
        // Display interface
        .seven_seg      (seven_seg),
        .digit_sel      (digit_sel),
        .status_led     (status_led),
        
        // User interface
        .door_sensor    (door_sensor),
        .button_up      (button_up),
        .button_down    (button_down),
        .button_mode    (button_mode)
    );
    
    //==========================================================================
    // Clock generation
    //==========================================================================
    
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //==========================================================================
    // ADC model (simplified)
    //==========================================================================
    
    reg [15:0] spi_shift_reg;
    reg [4:0]  spi_bit_count;
    
    always @(posedge adc_sclk or posedge adc_cs_n) begin
        if (adc_cs_n) begin
            spi_bit_count <= 5'd0;
            spi_shift_reg <= 16'd0;
        end else begin
            spi_bit_count <= spi_bit_count + 1'b1;
            spi_shift_reg <= {spi_shift_reg[14:0], adc_mosi};
        end
    end
    
    // ADC outputs data on falling edge of SCLK for sampling on next rising edge
    always @(negedge adc_sclk or posedge adc_cs_n) begin
        if (adc_cs_n) begin
            adc_miso <= 1'b0;
        end else begin
            // ADC128S022 outputs data MSB first starting from bit 11
            case (spi_bit_count)
                5'd4:  adc_miso <= adc_value[11];
                5'd5:  adc_miso <= adc_value[10];
                5'd6:  adc_miso <= adc_value[9];
                5'd7:  adc_miso <= adc_value[8];
                5'd8:  adc_miso <= adc_value[7];
                5'd9:  adc_miso <= adc_value[6];
                5'd10: adc_miso <= adc_value[5];
                5'd11: adc_miso <= adc_value[4];
                5'd12: adc_miso <= adc_value[3];
                5'd13: adc_miso <= adc_value[2];
                5'd14: adc_miso <= adc_value[1];
                5'd15: adc_miso <= adc_value[0];
                default: adc_miso <= 1'b0;
            endcase
        end
    end
    
    //==========================================================================
    // Temperature to ADC conversion
    //==========================================================================
    
    // Convert temperature to ADC value
    // ADC_value = (Temperature + 50) * 4096 / 100
    task set_temperature;
        input real temp_c;
        begin
            temperature_celsius = temp_c;
            adc_value = $rtoi((temp_c + 50.0) * 4096.0 / 100.0);
            $display("Setting temperature: %.1f°C (ADC: %d)", temp_c, adc_value);
        end
    endtask
    
    //==========================================================================
    // Button press tasks
    //==========================================================================
    
    task press_button;
        input [1:0] button_type;  // 0: up, 1: down, 2: mode
        begin
            case (button_type)
                2'd0: begin
                    button_up = 1'b1;
                    #(CLK_PERIOD * 100);
                    button_up = 1'b0;
                end
                2'd1: begin
                    button_down = 1'b1;
                    #(CLK_PERIOD * 100);
                    button_down = 1'b0;
                end
                2'd2: begin
                    button_mode = 1'b1;
                    #(CLK_PERIOD * 100);
                    button_mode = 1'b0;
                end
            endcase
            #(CLK_PERIOD * 100);
        end
    endtask
    
    //==========================================================================
    // Monitor tasks
    //==========================================================================
    
    // Monitor temperature and control signals
    always @(posedge clk) begin
        if (DUT.adc_valid) begin
            $display("Time: %0t | Temp: %.1f°C | PWM: %4d | State: %s", 
                     $time, 
                     temperature_celsius,
                     DUT.pwm_duty_cycle,
                     get_state_name(DUT.current_state));
        end
    end
    
    // Monitor PID controller signals
    always @(posedge clk) begin
        if (rst_n && DUT.u_pid.enable) begin
            $display("PID ENABLED at %0t: comp_en=%b, data_rdy=%b, timer=%d, PID_out=%04X", 
                     $time,
                     DUT.compressor_enable,
                     DUT.temp_data_ready,
                     DUT.compressor_timer,
                     DUT.u_pid.pid_out);
        end
    end
    
    // Monitor compressor timer expiration
    reg timer_was_nonzero;
    always @(posedge clk) begin
        if (rst_n) begin
            if (timer_was_nonzero && DUT.compressor_timer == 0) begin
                $display("COMPRESSOR TIMER EXPIRED at %0t", $time);
            end
            timer_was_nonzero <= (DUT.compressor_timer != 0);
        end
    end
    
    // Monitor state changes
    reg [2:0] prev_state;
    always @(posedge clk) begin
        if (rst_n) begin
            if (DUT.current_state != prev_state) begin
                $display("STATE CHANGE at %0t: %s -> %s", 
                         $time,
                         get_state_name(prev_state),
                         get_state_name(DUT.current_state));
                if (DUT.current_state == 3'b100) begin  // ALARM
                    $display("  ALARM triggered! temp_latched=0x%04X (%0.1f°C), defrost_timer=%d",
                             DUT.temp_current_latched,
                             $itor($signed(DUT.temp_current_latched))/256.0,
                             DUT.defrost_timer);
                    $display("  Checking: 0x%04X > 0x0A00? %b", 
                             DUT.temp_current_latched, 
                             (DUT.temp_current_latched > 16'h0A00));
                    $display("  Checking: 0x%04X < 0xE700? %b (signed comparison)", 
                             DUT.temp_current_latched,
                             ($signed(DUT.temp_current_latched) < $signed(16'hE700)));
                end
            end
            prev_state <= DUT.current_state;
        end
    end
    
    // Get state name for display
    function [79:0] get_state_name;
        input [2:0] state;
        begin
            case (state)
                3'b000: get_state_name = "INIT     ";
                3'b001: get_state_name = "NORMAL   ";
                3'b010: get_state_name = "DEFROST  ";
                3'b011: get_state_name = "DOOR_OPEN";
                3'b100: get_state_name = "ALARM    ";
                3'b101: get_state_name = "TEST     ";
                default: get_state_name = "UNKNOWN  ";
            endcase
        end
    endfunction
    
    //==========================================================================
    // Test stimulus
    //==========================================================================
    
    initial begin
        // Initialize signals
        rst_n = 1'b0;
        door_sensor = 1'b0;
        button_up = 1'b0;
        button_down = 1'b0;
        button_mode = 1'b0;
        adc_value = 12'd2211;  // 4°C initially (matches default setpoint)
        test_case = 0;
        error_count = 0;
        
        // Setup waveform dump
        $dumpfile("temp_ctrl_top_tb.vcd");
        $dumpvars(0, temp_ctrl_top_tb);
        // Explicitly add key signals for debugging
        $dumpvars(0, DUT.compressor_enable);
        $dumpvars(0, DUT.compressor_timer);
        $dumpvars(0, DUT.temp_data_ready);
        $dumpvars(0, DUT.u_pid);
        
        // Display header
        $display("\n=====================================");
        $display("Temperature Controller Testbench");
        $display("=====================================\n");
        
        // Reset sequence
        #(CLK_PERIOD * 10);
        rst_n = 1'b1;
        #(CLK_PERIOD * 10);
        
        // Check initial state
        $display("Initial state after reset: %s", get_state_name(DUT.current_state));
        $display("Initial temp_current_latched: 0x%04X (%0.1f°C)", 
                 DUT.temp_current_latched, $itor($signed(DUT.temp_current_latched))/256.0);
        
        // Wait for system to exit INIT state
        wait(DUT.current_state != 3'b000);
        $display("System exited INIT state at time %0t, new state: %s", 
                 $time, get_state_name(DUT.current_state));
        #(CLK_PERIOD * 100);  // Small additional delay
        
        //======================================================================
        // Test Case 1: Basic temperature control
        //======================================================================
        test_case = 1;
        $display("\n--- Test Case %0d: Basic Temperature Control ---", test_case);
        
        // Set initial temperature above setpoint
        set_temperature(8.0);
        
        // Wait for first ADC reading
        @(posedge DUT.adc_valid);  // First reading
        #(CLK_PERIOD * 100_000);  // Wait 10ms
        
        // Debug display
        $display("\nDEBUG at time %0t:", $time);
        $display("  Temperature: latched=0x%04X (%0.1f°C), setpoint=0x%04X (%0.1f°C)", 
                 DUT.temp_current_latched, $itor($signed(DUT.temp_current_latched))/256.0,
                 DUT.temp_setpoint, $itor($signed(DUT.temp_setpoint))/256.0);
        $display("  Compressor: enable=%b, timer=%d, pwm_duty=%d", 
                 DUT.compressor_enable, DUT.compressor_timer, DUT.pwm_duty_cycle);
        $display("  State: current=0x%x (%s)", 
                 DUT.current_state, get_state_name(DUT.current_state));
        $display("  Conditions for compressor ON:");
        $display("    - In NORMAL state? %b", (DUT.current_state == 3'b001));
        $display("    - Timer expired? %b (timer=%d)", (DUT.compressor_timer == 0), DUT.compressor_timer);
        $display("    - Temp > setpoint? %b (0x%04X > 0x%04X)", 
                 (DUT.temp_current_latched > DUT.temp_setpoint),
                 DUT.temp_current_latched, DUT.temp_setpoint);
        $display("    - Data ready? %b", DUT.temp_data_ready);
        
        // Temperature should trigger cooling
        if (DUT.pwm_duty_cycle == 0) begin
            $display("ERROR: Compressor should be ON when temp > setpoint (PWM duty = 0)");
            error_count = error_count + 1;
        end
        
        // Cool down to below setpoint
        set_temperature(2.0);
        #(CLK_PERIOD * 20_000);
        
        //======================================================================
        // Test Case 2: Button controls
        //======================================================================
        test_case = 2;
        $display("\n--- Test Case %0d: Button Controls ---", test_case);
        
        // Test temperature up button
        press_button(2'd0);  // UP
        #(CLK_PERIOD * 1000);
        press_button(2'd0);  // UP
        #(CLK_PERIOD * 1000);
        
        // Test temperature down button
        press_button(2'd1);  // DOWN
        #(CLK_PERIOD * 1000);
        
        // Test mode button
        press_button(2'd2);  // MODE
        #(CLK_PERIOD * 1000);
        
        //======================================================================
        // Test Case 3: Door open alarm
        //======================================================================
        test_case = 3;
        $display("\n--- Test Case %0d: Door Open Alarm ---", test_case);
        
        // Open door
        door_sensor = 1'b1;
        $display("Door opened");
        #(CLK_PERIOD * 10_000);
        
        // Check state transition
        if (DUT.current_state != 3'b011) begin
            $display("ERROR: Should be in DOOR_OPEN state");
            error_count = error_count + 1;
        end
        
        // Close door
        door_sensor = 1'b0;
        $display("Door closed");
        #(CLK_PERIOD * 10_000);
        
        //======================================================================
        // Test Case 4: Temperature extremes
        //======================================================================
        test_case = 4;
        $display("\n--- Test Case %0d: Temperature Extremes ---", test_case);
        
        // First add PID debug test
        $display("\n--- PID Controller Debug ---");
        // Show PID coefficients
        $display("PID Coefficients: Kp=0x%04X, Ki=0x%04X, Kd=0x%04X", 
                 DUT.u_pid.kp, DUT.u_pid.ki, DUT.u_pid.kd);
        // Set temperature for PID testing
        set_temperature(8.0);  // Above setpoint to trigger cooling
        $display("Waiting for compressor timer to expire...");
        // Wait for timer and show status
        wait(DUT.compressor_timer == 0);
        $display("Timer expired. Compressor status:");
        $display("  compressor_enable=%b", DUT.compressor_enable);
        $display("  temp_data_ready=%b", DUT.temp_data_ready);
        $display("  PID enable=%b", DUT.u_pid.enable);
        $display("  PID output=0x%04X", DUT.u_pid.pid_out);
        
        // Wait a bit more to see PID action
        #(CLK_PERIOD * 100_000);
        
        // Test high temperature alarm
        set_temperature(15.0);
        @(posedge DUT.adc_valid);  // Wait for ADC reading
        #(CLK_PERIOD * 1000);      // Small delay
        
        if (alarm != 1'b1) begin
            $display("ERROR: High temperature alarm not triggered");
            $display("  Current state: %s", get_state_name(DUT.current_state));
            $display("  Temp: 0x%04X (%0.1f°C)", 
                     DUT.temp_current_latched, $itor($signed(DUT.temp_current_latched))/256.0);
            error_count = error_count + 1;
        end
        
        // Clear alarm
        press_button(2'd2);  // MODE to clear alarm
        #(CLK_PERIOD * 10_000);
        
        // Test low temperature
        set_temperature(-25.0);
        @(posedge DUT.adc_valid);  // Wait for ADC reading
        #(CLK_PERIOD * 1000);      // Small delay
        
        if (alarm != 1'b1) begin
            $display("ERROR: Low temperature alarm not triggered");
            $display("  Current state: %s", get_state_name(DUT.current_state));
            $display("  Temp: 0x%04X (%0.1f°C)", 
                     DUT.temp_current_latched, $itor($signed(DUT.temp_current_latched))/256.0);
            error_count = error_count + 1;
        end
        
        //======================================================================
        // Test Case 5: PWM soft start
        //======================================================================
        test_case = 5;
        $display("\n--- Test Case %0d: PWM Soft Start ---", test_case);
        
        // Reset to normal temperature
        set_temperature(4.0);
        press_button(2'd2);  // Clear any alarms
        #(CLK_PERIOD * 10_000);
        
        // Trigger cooling need
        set_temperature(10.0);
        
        // Monitor PWM ramp up
        repeat(100) begin
            #(CLK_PERIOD * 1000);
            $display("PWM duty cycle: %d", DUT.pwm_duty_cycle);
        end
        
        //======================================================================
        // Test summary
        //======================================================================
        #(CLK_PERIOD * 10_000);
        
        $display("\n=====================================");
        $display("Test Summary");
        $display("=====================================");
        $display("Total test cases: %0d", test_case);
        $display("Errors found: %0d", error_count);
        
        if (error_count == 0) begin
            $display("Result: PASSED");
        end else begin
            $display("Result: FAILED");
        end
        
        $display("=====================================\n");
        
        $finish;
    end
    
    //==========================================================================
    // Timeout watchdog
    //==========================================================================
    
    initial begin
        #SIM_TIME;
        $display("\nERROR: Simulation timeout!");
        $finish;
    end
    
endmodule
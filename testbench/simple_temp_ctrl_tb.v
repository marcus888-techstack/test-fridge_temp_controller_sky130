//==============================================================================
// Simplified Temperature Controller Testbench
// Purpose: Easy-to-understand testbench for learning
//==============================================================================

`timescale 1ns / 1ps

module simple_temp_ctrl_tb;

    //==========================================================================
    // 1. BASIC SETUP
    //==========================================================================
    
    // Clock and Reset
    reg  clk;
    reg  rst_n;
    
    // Temperature Control
    reg  [11:0] adc_temperature;    // Temperature from sensor
    wire        compressor_on;       // Is compressor running?
    
    // User Buttons
    reg  button_up;                  // Increase temperature
    reg  button_down;                // Decrease temperature
    
    // Door Sensor
    reg  door_open;                  // Is door open?
    wire alarm;                      // Alarm output
    
    //==========================================================================
    // 2. CONNECT TO DESIGN (DUT = Device Under Test)
    //==========================================================================
    
    temp_ctrl_top DUT (
        // Basic connections
        .clk            (clk),
        .rst_n          (rst_n),
        
        // Temperature sensor (simplified - we'll handle SPI separately)
        .adc_miso       (1'b0),     // We'll simplify SPI for now
        .adc_mosi       (),
        .adc_sclk       (),
        .adc_cs_n       (),
        
        // Outputs we care about
        .compressor_pwm (compressor_on),
        .alarm          (alarm),
        
        // User inputs
        .door_sensor    (door_open),
        .button_up      (button_up),
        .button_down    (button_down),
        .button_mode    (1'b0),      // Not used in simple test
        
        // Display (we'll ignore for now)
        .seven_seg      (),
        .digit_sel      (),
        .status_led     (),
        .defrost_heater ()
    );
    
    //==========================================================================
    // 3. CREATE CLOCK (10 MHz)
    //==========================================================================
    
    initial begin
        clk = 0;
        forever #50 clk = ~clk;  // Toggle every 50ns = 10MHz
    end
    
    //==========================================================================
    // 4. HELPER TASKS (Easy-to-use functions)
    //==========================================================================
    
    // Task: Reset the system
    task reset_system;
        begin
            $display("\n[RESET] Resetting system...");
            rst_n = 0;
            #1000;           // Wait 1 microsecond
            rst_n = 1;
            #1000;
            $display("[RESET] System reset complete\n");
        end
    endtask
    
    // Task: Set temperature (in Celsius)
    task set_temperature;
        input real temp_celsius;
        begin
            // Convert Celsius to ADC value
            // Formula: ADC = (temp + 50) * 4096 / 100
            adc_temperature = (temp_celsius + 50) * 40.96;
            $display("[TEMP] Setting temperature to %.1f°C", temp_celsius);
        end
    endtask
    
    // Task: Press a button
    task press_button_up;
        begin
            $display("[BUTTON] Pressing UP button");
            button_up = 1;
            #10000;          // Hold for 10 microseconds
            button_up = 0;
            #10000;          // Wait after release
        end
    endtask
    
    task press_button_down;
        begin
            $display("[BUTTON] Pressing DOWN button");
            button_down = 1;
            #10000;
            button_down = 0;
            #10000;
        end
    endtask
    
    // Task: Open/Close door
    task open_door;
        begin
            $display("[DOOR] Opening door");
            door_open = 1;
        end
    endtask
    
    task close_door;
        begin
            $display("[DOOR] Closing door");
            door_open = 0;
        end
    endtask
    
    // Task: Wait and check status
    task wait_and_check;
        input integer wait_time;
        begin
            #wait_time;
            $display("[STATUS] Time=%0t, Compressor=%s, Alarm=%s", 
                     $time,
                     compressor_on ? "ON" : "OFF",
                     alarm ? "ACTIVE" : "OFF");
        end
    endtask
    
    //==========================================================================
    // 5. MAIN TEST SEQUENCE
    //==========================================================================
    
    initial begin
        // Setup waveform file
        $dumpfile("simple_temp_ctrl.vcd");
        $dumpvars(0, simple_temp_ctrl_tb);
        
        // Print header
        $display("\n========================================");
        $display("  SIMPLE TEMPERATURE CONTROLLER TEST");
        $display("========================================");
        
        // Initialize everything
        button_up = 0;
        button_down = 0;
        door_open = 0;
        adc_temperature = 2048;  // 0°C default
        
        // Run tests
        reset_system();
        
        //--------------------------------------------------
        // TEST 1: Basic Temperature Control
        //--------------------------------------------------
        $display("\n>>> TEST 1: Basic Temperature Control");
        $display("Default setpoint should be 4°C");
        
        // Set temp above setpoint
        set_temperature(8.0);    // 8°C (hot)
        wait_and_check(100000);  // Wait 100us
        
        if (compressor_on)
            $display("[PASS] Compressor turned ON when hot");
        else
            $display("[FAIL] Compressor should be ON!");
        
        // Set temp below setpoint
        set_temperature(2.0);    // 2°C (cold)
        wait_and_check(100000);
        
        if (!compressor_on)
            $display("[PASS] Compressor turned OFF when cold");
        else
            $display("[FAIL] Compressor should be OFF!");
        
        //--------------------------------------------------
        // TEST 2: Button Control
        //--------------------------------------------------
        $display("\n>>> TEST 2: Button Control");
        
        press_button_up();       // Increase setpoint
        $display("Setpoint increased");
        wait_and_check(50000);
        
        press_button_down();     // Decrease setpoint
        press_button_down();     // Decrease again
        $display("Setpoint decreased twice");
        wait_and_check(50000);
        
        //--------------------------------------------------
        // TEST 3: Door Alarm
        //--------------------------------------------------
        $display("\n>>> TEST 3: Door Alarm Test");
        
        open_door();
        wait_and_check(50000);
        $display("Waiting for door alarm (2 minutes)...");
        
        // In real test, wait 2 minutes. For demo, just check
        #1000000;  // Wait 1ms (shortened for demo)
        
        if (alarm)
            $display("[PASS] Door alarm activated");
        else
            $display("[FAIL] Door alarm should be active!");
        
        close_door();
        wait_and_check(50000);
        
        //--------------------------------------------------
        // TEST 4: Temperature Extremes
        //--------------------------------------------------
        $display("\n>>> TEST 4: Temperature Extreme Test");
        
        set_temperature(15.0);   // Very hot!
        wait_and_check(100000);
        
        if (alarm)
            $display("[PASS] High temperature alarm active");
        else
            $display("[FAIL] Should have temperature alarm!");
        
        set_temperature(4.0);    // Back to normal
        wait_and_check(100000);
        
        //--------------------------------------------------
        // End of tests
        //--------------------------------------------------
        $display("\n========================================");
        $display("        TEST COMPLETE");
        $display("========================================\n");
        
        #100000;
        $finish;
    end
    
    //==========================================================================
    // 6. SIMPLE MONITOR (Optional - shows what's happening)
    //==========================================================================
    
    always @(posedge clk) begin
        // Every 1ms, show current state
        if ($time % 1000000 == 0 && $time > 0) begin
            $display("[MONITOR] Time=%0t ms, Temp=%.1f°C, Compressor=%s", 
                     $time/1000000,
                     (adc_temperature / 40.96) - 50,  // Convert back to Celsius
                     compressor_on ? "ON" : "OFF");
        end
    end

endmodule
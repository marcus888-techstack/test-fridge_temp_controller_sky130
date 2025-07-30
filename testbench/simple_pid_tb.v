//==============================================================================
// Simple PID Controller Testbench
// Purpose: Understand how PID control works
//==============================================================================

`timescale 1ns / 1ps

module simple_pid_tb;

    //==========================================================================
    // 1. SIGNALS
    //==========================================================================
    
    reg  clk;
    reg  rst_n;
    reg  enable;
    
    // Temperature values (using real numbers for clarity)
    real target_temp;        // What we want (setpoint)
    real current_temp;       // What we have (feedback)
    real control_output;     // PID output
    
    // PID gains
    real Kp = 2.0;          // Proportional gain
    real Ki = 0.1;          // Integral gain  
    real Kd = 0.05;         // Derivative gain
    
    // Fixed-point versions (Q8.8 format)
    reg  signed [15:0] setpoint;
    reg  signed [15:0] feedback;
    reg  signed [15:0] kp_fixed;
    reg  signed [15:0] ki_fixed;
    reg  signed [15:0] kd_fixed;
    wire signed [15:0] pid_out;
    
    //==========================================================================
    // 2. CONNECT PID CONTROLLER
    //==========================================================================
    
    pid_controller DUT (
        .clk        (clk),
        .rst_n      (rst_n),
        .enable     (enable),
        .setpoint   (setpoint),
        .feedback   (feedback),
        .kp         (kp_fixed),
        .ki         (ki_fixed),
        .kd         (kd_fixed),
        .pid_out    (pid_out)
    );
    
    //==========================================================================
    // 3. CLOCK
    //==========================================================================
    
    initial begin
        clk = 0;
        forever #50 clk = ~clk;  // 10MHz
    end
    
    //==========================================================================
    // 4. CONVERSION HELPERS
    //==========================================================================
    
    // Convert real number to Q8.8 fixed-point
    function [15:0] to_fixed;
        input real value;
        begin
            to_fixed = value * 256;  // Multiply by 2^8
        end
    endfunction
    
    // Convert Q8.8 fixed-point to real
    function real to_real;
        input signed [15:0] value;
        begin
            to_real = value / 256.0;  // Divide by 2^8
        end
    endfunction
    
    //==========================================================================
    // 5. TEST HELPERS
    //==========================================================================
    
    // Update PID inputs
    task update_pid;
        begin
            setpoint = to_fixed(target_temp);
            feedback = to_fixed(current_temp);
            control_output = to_real(pid_out);
        end
    endtask
    
    // Simulate temperature change (simple model)
    task simulate_temperature;
        begin
            // Simple model: temperature moves towards control output
            // Like: new_temp = old_temp + (control * 0.01)
            current_temp = current_temp + (control_output * 0.01);
            
            // Add some thermal loss (room temperature effect)
            current_temp = current_temp * 0.99 + 20.0 * 0.01;
        end
    endtask
    
    //==========================================================================
    // 6. MAIN TEST
    //==========================================================================
    
    initial begin
        // Setup
        $dumpfile("simple_pid.vcd");
        $dumpvars(0, simple_pid_tb);
        
        $display("\n====================================");
        $display("    SIMPLE PID CONTROLLER TEST");
        $display("====================================\n");
        
        // Initialize
        rst_n = 0;
        enable = 0;
        target_temp = 4.0;    // Target: 4°C (typical fridge)
        current_temp = 20.0;  // Start: 20°C (room temp)
        
        // Set PID gains
        kp_fixed = to_fixed(Kp);
        ki_fixed = to_fixed(Ki);
        kd_fixed = to_fixed(Kd);
        
        // Reset
        #1000;
        rst_n = 1;
        enable = 1;
        #1000;
        
        //--------------------------------------------------
        // TEST: Cool Down from 20°C to 4°C
        //--------------------------------------------------
        $display("TEST: Cooling from 20°C to 4°C");
        $display("Time(ms) | Target | Current | Error | PID_Out");
        $display("---------|--------|---------|-------|--------");
        
        // Run simulation for 100 steps
        repeat(100) begin
            // Update PID
            update_pid();
            
            // Wait for PID to calculate
            #1000;  // 1 microsecond
            
            // Get new control output
            control_output = to_real(pid_out);
            
            // Simulate temperature response
            simulate_temperature();
            
            // Display every 10 steps
            if ($time % 10000 == 0) begin
                $display("  %3.1f   |  %4.1f  |  %5.1f  | %5.1f | %6.1f",
                         $time/1000000.0,  // Convert to ms
                         target_temp,
                         current_temp,
                         target_temp - current_temp,
                         control_output);
            end
            
            // Wait before next update
            #9000;  // Total 10us per loop
        end
        
        //--------------------------------------------------
        // TEST 2: Handle Disturbance (door opened)
        //--------------------------------------------------
        $display("\n\nTEST 2: Door Opened (temperature rises)");
        
        // Simulate door open - temperature rises
        current_temp = current_temp + 5.0;
        $display("DISTURBANCE: Temp jumped to %.1f°C", current_temp);
        
        // Run PID to recover
        repeat(50) begin
            update_pid();
            #1000;
            control_output = to_real(pid_out);
            simulate_temperature();
            
            if ($time % 10000 == 0) begin
                $display("  %3.1f   |  %4.1f  |  %5.1f  | %5.1f | %6.1f",
                         $time/1000000.0,
                         target_temp,
                         current_temp,
                         target_temp - current_temp,
                         control_output);
            end
            #9000;
        end
        
        //--------------------------------------------------
        // Show final results
        //--------------------------------------------------
        $display("\n====================================");
        $display("Final Temperature: %.2f°C", current_temp);
        $display("Target was: %.1f°C", target_temp);
        $display("Final Error: %.2f°C", target_temp - current_temp);
        $display("====================================\n");
        
        #10000;
        $finish;
    end
    
    //==========================================================================
    // 7. PID INTERNALS MONITOR (Educational)
    //==========================================================================
    
    always @(posedge clk) begin
        if (enable && $time % 50000 == 0 && $time > 0) begin
            $display("\n[PID Debug] P=%.2f, I=%.2f, D=%.2f, Total=%.2f",
                     to_real(DUT.p_term),
                     to_real(DUT.i_term),
                     to_real(DUT.d_term),
                     to_real(DUT.pid_out));
        end
    end

endmodule
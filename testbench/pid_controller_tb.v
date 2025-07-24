//==============================================================================
// File: pid_controller_tb.v
// Description: Testbench for PID controller module
// Author: IC Design Team
// Date: 2024-12-19
//==============================================================================

`timescale 1ns / 1ps

module pid_controller_tb;

    //==========================================================================
    // Parameters
    //==========================================================================
    
    parameter CLK_PERIOD = 100;     // 10 MHz clock
    parameter Q8_8_SCALE = 256.0;   // Q8.8 scaling factor
    
    //==========================================================================
    // Signal declarations
    //==========================================================================
    
    reg                clk;
    reg                rst_n;
    reg                enable;
    reg  signed [15:0] setpoint;
    reg  signed [15:0] feedback;
    reg  signed [15:0] kp;
    reg  signed [15:0] ki;
    reg  signed [15:0] kd;
    wire signed [15:0] output_pid;
    
    // Test variables
    real setpoint_real;
    real feedback_real;
    real output_real;
    real error_real;
    integer test_case;
    integer i;
    
    //==========================================================================
    // DUT instantiation
    //==========================================================================
    
    pid_controller DUT (
        .clk      (clk),
        .rst_n    (rst_n),
        .enable   (enable),
        .setpoint (setpoint),
        .feedback (feedback),
        .kp       (kp),
        .ki       (ki),
        .kd       (kd),
        .output   (output_pid)
    );
    
    //==========================================================================
    // Clock generation
    //==========================================================================
    
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //==========================================================================
    // Real number conversion functions
    //==========================================================================
    
    // Convert real to Q8.8
    function signed [15:0] real_to_q8_8;
        input real value;
        begin
            real_to_q8_8 = $rtoi(value * Q8_8_SCALE);
        end
    endfunction
    
    // Convert Q8.8 to real
    function real q8_8_to_real;
        input signed [15:0] value;
        begin
            q8_8_to_real = $itor(value) / Q8_8_SCALE;
        end
    endfunction
    
    //==========================================================================
    // Test stimulus
    //==========================================================================
    
    initial begin
        // Initialize signals
        rst_n = 1'b0;
        enable = 1'b0;
        setpoint = 16'd0;
        feedback = 16'd0;
        kp = real_to_q8_8(2.0);    // Kp = 2.0
        ki = real_to_q8_8(0.1);    // Ki = 0.1
        kd = real_to_q8_8(0.05);   // Kd = 0.05
        test_case = 0;
        
        // Setup waveform dump
        $dumpfile("pid_controller_tb.vcd");
        $dumpvars(0, pid_controller_tb);
        
        // Display header
        $display("\n=====================================");
        $display("PID Controller Testbench");
        $display("=====================================");
        $display("Kp = %.2f, Ki = %.2f, Kd = %.2f\n", 
                 q8_8_to_real(kp), q8_8_to_real(ki), q8_8_to_real(kd));
        
        // Reset sequence
        #(CLK_PERIOD * 10);
        rst_n = 1'b1;
        #(CLK_PERIOD * 10);
        
        //======================================================================
        // Test Case 1: Step response
        //======================================================================
        test_case = 1;
        $display("--- Test Case %0d: Step Response ---", test_case);
        
        setpoint_real = 5.0;  // 5°C setpoint
        feedback_real = 0.0;  // Starting at 0°C
        setpoint = real_to_q8_8(setpoint_real);
        feedback = real_to_q8_8(feedback_real);
        
        enable = 1'b1;
        
        // Simulate for 50 samples
        for (i = 0; i < 50; i = i + 1) begin
            @(posedge clk);
            
            // Display current values
            error_real = q8_8_to_real(setpoint - feedback);
            output_real = q8_8_to_real(output_pid);
            
            $display("Sample %3d: SP=%.2f, FB=%.2f, Error=%.2f, Output=%.2f",
                     i, setpoint_real, feedback_real, error_real, output_real);
            
            // Simple plant model: feedback approaches setpoint
            feedback_real = feedback_real + output_real * 0.01;
            feedback = real_to_q8_8(feedback_real);
            
            #(CLK_PERIOD * 9);
        end
        
        enable = 1'b0;
        #(CLK_PERIOD * 10);
        
        //======================================================================
        // Test Case 2: Disturbance rejection
        //======================================================================
        test_case = 2;
        $display("\n--- Test Case %0d: Disturbance Rejection ---", test_case);
        
        setpoint_real = 4.0;
        feedback_real = 4.0;  // Start at setpoint
        setpoint = real_to_q8_8(setpoint_real);
        feedback = real_to_q8_8(feedback_real);
        
        enable = 1'b1;
        
        // Let it settle
        repeat(10) @(posedge clk);
        
        // Apply disturbance
        $display("Applying disturbance...");
        feedback_real = 6.0;  // Sudden temperature rise
        feedback = real_to_q8_8(feedback_real);
        
        // Monitor recovery
        for (i = 0; i < 30; i = i + 1) begin
            @(posedge clk);
            
            error_real = q8_8_to_real(setpoint - feedback);
            output_real = q8_8_to_real(output_pid);
            
            $display("Sample %3d: SP=%.2f, FB=%.2f, Error=%.2f, Output=%.2f",
                     i, setpoint_real, feedback_real, error_real, output_real);
            
            feedback_real = feedback_real + output_real * 0.01;
            feedback = real_to_q8_8(feedback_real);
            
            #(CLK_PERIOD * 9);
        end
        
        enable = 1'b0;
        #(CLK_PERIOD * 10);
        
        //======================================================================
        // Test Case 3: Parameter change
        //======================================================================
        test_case = 3;
        $display("\n--- Test Case %0d: Parameter Change ---", test_case);
        
        // Change PID parameters
        kp = real_to_q8_8(1.0);    // Reduce Kp
        ki = real_to_q8_8(0.2);    // Increase Ki
        kd = real_to_q8_8(0.02);   // Reduce Kd
        
        $display("New parameters: Kp = %.2f, Ki = %.2f, Kd = %.2f", 
                 q8_8_to_real(kp), q8_8_to_real(ki), q8_8_to_real(kd));
        
        setpoint_real = 0.0;
        feedback_real = 5.0;
        setpoint = real_to_q8_8(setpoint_real);
        feedback = real_to_q8_8(feedback_real);
        
        enable = 1'b1;
        
        // Monitor response with new parameters
        for (i = 0; i < 40; i = i + 1) begin
            @(posedge clk);
            
            error_real = q8_8_to_real(setpoint - feedback);
            output_real = q8_8_to_real(output_pid);
            
            if (i % 5 == 0) begin  // Display every 5th sample
                $display("Sample %3d: SP=%.2f, FB=%.2f, Error=%.2f, Output=%.2f",
                         i, setpoint_real, feedback_real, error_real, output_real);
            end
            
            feedback_real = feedback_real + output_real * 0.01;
            feedback = real_to_q8_8(feedback_real);
            
            #(CLK_PERIOD * 9);
        end
        
        enable = 1'b0;
        #(CLK_PERIOD * 10);
        
        //======================================================================
        // Test Case 4: Integral windup test
        //======================================================================
        test_case = 4;
        $display("\n--- Test Case %0d: Integral Windup Test ---", test_case);
        
        kp = real_to_q8_8(0.5);
        ki = real_to_q8_8(0.5);    // High Ki for windup test
        kd = real_to_q8_8(0.0);
        
        setpoint_real = 10.0;
        feedback_real = 0.0;
        setpoint = real_to_q8_8(setpoint_real);
        feedback = real_to_q8_8(feedback_real);
        
        enable = 1'b1;
        
        // Let integral build up
        repeat(20) @(posedge clk);
        
        // Check integral accumulator (should be saturated)
        $display("Integral accumulator: %h", DUT.integral_acc);
        
        // Reverse setpoint
        setpoint_real = -10.0;
        setpoint = real_to_q8_8(setpoint_real);
        
        // Monitor unwinding
        for (i = 0; i < 20; i = i + 1) begin
            @(posedge clk);
            
            error_real = q8_8_to_real(setpoint - feedback);
            output_real = q8_8_to_real(output_pid);
            
            if (i % 5 == 0) begin
                $display("Sample %3d: Error=%.2f, Output=%.2f, Integral=%h",
                         i, error_real, output_real, DUT.integral_acc);
            end
            
            #(CLK_PERIOD * 9);
        end
        
        enable = 1'b0;
        #(CLK_PERIOD * 10);
        
        //======================================================================
        // Test summary
        //======================================================================
        $display("\n=====================================");
        $display("PID Controller Test Complete");
        $display("=====================================\n");
        
        $finish;
    end
    
    //==========================================================================
    // Timeout watchdog
    //==========================================================================
    
    initial begin
        #(CLK_PERIOD * 10000);
        $display("\nERROR: Simulation timeout!");
        $finish;
    end
    
endmodule
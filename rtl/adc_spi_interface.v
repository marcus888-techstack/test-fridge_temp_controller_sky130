//==============================================================================
// File: adc_spi_interface.v
// Description: SPI interface for ADC128S022 compatible 12-bit ADC
// Author: IC Design Team
// Date: 2024-12-19
// Target: SKY130 PDK
//==============================================================================

`timescale 1ns / 1ps

module adc_spi_interface (
    // System signals
    input  wire        clk,         // System clock (10 MHz)
    input  wire        rst_n,       // Active-low reset
    input  wire        clk_1mhz,    // 1 MHz clock for SPI
    
    // Control interface
    input  wire        start,       // Start conversion
    input  wire [2:0]  channel,     // ADC channel select (0-7)
    output reg  [11:0] adc_data,    // 12-bit ADC result
    output reg         adc_valid,   // Data valid flag
    
    // SPI interface
    input  wire        spi_miso,    // Master In Slave Out
    output reg         spi_mosi,    // Master Out Slave In
    output reg         spi_sclk,    // SPI clock
    output reg         spi_cs_n     // Chip select (active low)
);

    //==========================================================================
    // State machine definitions
    //==========================================================================
    
    localparam STATE_IDLE       = 3'b000;
    localparam STATE_CS_LOW     = 3'b001;
    localparam STATE_XFER_HIGH  = 3'b010;
    localparam STATE_XFER_LOW   = 3'b011;
    localparam STATE_CS_HIGH    = 3'b100;
    localparam STATE_DONE       = 3'b101;
    
    reg [2:0] current_state;
    reg [2:0] next_state;
    
    //==========================================================================
    // Internal signals
    //==========================================================================
    
    reg [4:0]  bit_counter;      // Counts bits (0-15)
    reg [15:0] tx_shift_reg;     // Transmit shift register
    reg [15:0] rx_shift_reg;     // Receive shift register
    reg        clk_1mhz_prev;    // Previous clock for edge detection
    wire       clk_1mhz_posedge; // Rising edge of 1MHz clock
    wire       clk_1mhz_negedge; // Falling edge of 1MHz clock
    reg [3:0]  cs_delay_counter; // CS setup/hold delay
    
    //==========================================================================
    // Clock edge detection
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_1mhz_prev <= 1'b0;
        end else begin
            clk_1mhz_prev <= clk_1mhz;
        end
    end
    
    assign clk_1mhz_posedge = clk_1mhz & ~clk_1mhz_prev;
    assign clk_1mhz_negedge = ~clk_1mhz & clk_1mhz_prev;
    
    //==========================================================================
    // State machine - sequential logic
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    //==========================================================================
    // State machine - combinational logic
    //==========================================================================
    
    always @(*) begin
        next_state = current_state;
        
        case (current_state)
            STATE_IDLE: begin
                if (start)
                    next_state = STATE_CS_LOW;
            end
            
            STATE_CS_LOW: begin
                if (cs_delay_counter == 4'd0)
                    next_state = STATE_XFER_HIGH;
            end
            
            STATE_XFER_HIGH: begin
                if (clk_1mhz_negedge)
                    next_state = STATE_XFER_LOW;
            end
            
            STATE_XFER_LOW: begin
                if (clk_1mhz_posedge) begin
                    if (bit_counter == 5'd15)
                        next_state = STATE_CS_HIGH;
                    else
                        next_state = STATE_XFER_HIGH;
                end
            end
            
            STATE_CS_HIGH: begin
                if (cs_delay_counter == 4'd0)
                    next_state = STATE_DONE;
            end
            
            STATE_DONE: begin
                next_state = STATE_IDLE;
            end
            
            default: next_state = STATE_IDLE;
        endcase
    end
    
    //==========================================================================
    // Control logic
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_cs_n         <= 1'b1;
            spi_sclk         <= 1'b0;
            spi_mosi         <= 1'b0;
            bit_counter      <= 5'd0;
            tx_shift_reg     <= 16'd0;
            rx_shift_reg     <= 16'd0;
            adc_data         <= 12'd0;
            adc_valid        <= 1'b0;
            cs_delay_counter <= 4'd0;
        end else begin
            // Default values
            adc_valid <= 1'b0;
            
            case (current_state)
                STATE_IDLE: begin
                    spi_cs_n     <= 1'b1;
                    spi_sclk     <= 1'b0;
                    spi_mosi     <= 1'b0;
                    bit_counter  <= 5'd0;
                    // Prepare transmit data: channel selection in bits 13:11
                    tx_shift_reg <= {2'b00, channel, 11'b0};
                end
                
                STATE_CS_LOW: begin
                    spi_cs_n <= 1'b0;
                    // Wait for CS setup time (4 clock cycles)
                    if (cs_delay_counter < 4'd3)
                        cs_delay_counter <= cs_delay_counter + 1'b1;
                    else
                        cs_delay_counter <= 4'd0;
                end
                
                STATE_XFER_HIGH: begin
                    if (clk_1mhz_negedge) begin
                        spi_sclk <= 1'b1;
                        // Sample MISO on rising edge
                        rx_shift_reg <= {rx_shift_reg[14:0], spi_miso};
                    end
                end
                
                STATE_XFER_LOW: begin
                    if (clk_1mhz_posedge) begin
                        spi_sclk <= 1'b0;
                        // Update MOSI on falling edge
                        spi_mosi <= tx_shift_reg[15];
                        tx_shift_reg <= {tx_shift_reg[14:0], 1'b0};
                        bit_counter <= bit_counter + 1'b1;
                    end
                end
                
                STATE_CS_HIGH: begin
                    spi_cs_n <= 1'b1;
                    spi_sclk <= 1'b0;
                    // Wait for CS hold time (4 clock cycles)
                    if (cs_delay_counter < 4'd3)
                        cs_delay_counter <= cs_delay_counter + 1'b1;
                    else
                        cs_delay_counter <= 4'd0;
                end
                
                STATE_DONE: begin
                    // Extract 12-bit ADC result from bits 11:0
                    adc_data  <= rx_shift_reg[11:0];
                    adc_valid <= 1'b1;
                end
                
                default: begin
                    spi_cs_n <= 1'b1;
                    spi_sclk <= 1'b0;
                    spi_mosi <= 1'b0;
                end
            endcase
        end
    end
    
endmodule
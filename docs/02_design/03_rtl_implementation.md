# RTL 實作細節文件

## 目錄

1. [RTL 設計概述](#1-rtl-設計概述)
2. [模組介面詳細說明](#2-模組介面詳細說明)
3. [時序設計與分析](#3-時序設計與分析)
4. [關鍵實作技術](#4-關鍵實作技術)
5. [資源使用估算](#5-資源使用估算)
6. [編碼風格指南](#6-編碼風格指南)
7. [常見陷阱與最佳實踐](#7-常見陷阱與最佳實踐)
8. [調試技巧](#8-調試技巧)

## 1. RTL 設計概述

### 1.1 設計層次結構

```
temp_ctrl_top (頂層)
├── clk_rst_manager    (時脈與重置管理)
├── adc_spi_interface  (ADC SPI 介面)
├── pid_controller     (PID 控制器)
├── pwm_generator      (PWM 產生器)
├── display_controller (顯示控制器)
├── ctrl_fsm          (主控狀態機)
├── timer_ctrl        (計時器模組)
└── reg_bank          (暫存器組)
```

### 1.2 信號命名規範

```verilog
// 輸入信號：_i 後綴
input wire data_i;

// 輸出信號：_o 後綴
output reg result_o;

// 內部信號：描述性名稱
wire adc_data_valid;
reg [15:0] temperature_current;

// 暫存器：_r 後綴
reg [7:0] counter_r;

// 下一狀態：_next 後綴
reg [2:0] state_next;

// 低電平有效：_n 後綴
input wire rst_n;
output wire cs_n;
```

## 2. 模組介面詳細說明

### 2.1 頂層模組介面 (temp_ctrl_top)

```verilog
module temp_ctrl_top #(
    // 參數定義
    parameter CLOCK_FREQ    = 10_000_000,  // 系統時脈頻率
    parameter SPI_FREQ      = 1_000_000,   // SPI 時脈頻率
    parameter PWM_FREQ      = 1_000,       // PWM 頻率
    parameter TEMP_MIN      = -16'h1400,   // -20.0°C in Q8.8
    parameter TEMP_MAX      = 16'h0A00     // +10.0°C in Q8.8
)(
    // 系統介面
    input  wire        clk,
    input  wire        rst_n,
    
    // SPI ADC 介面
    input  wire        adc_miso,
    output wire        adc_mosi,
    output wire        adc_sclk,
    output wire        adc_cs_n,
    
    // 控制輸出
    output wire        compressor_pwm,
    output wire        defrost_heater,
    output wire        alarm,
    
    // 顯示介面
    output wire [6:0]  seven_seg,
    output wire [3:0]  digit_sel,
    output wire [2:0]  status_led,
    
    // 使用者介面
    input  wire        door_sensor,
    input  wire        button_up,
    input  wire        button_down,
    input  wire        button_mode
);
```

### 2.2 ADC SPI 介面詳細設計

```verilog
module adc_spi_interface #(
    parameter CLK_DIV = 10  // 10MHz / 10 = 1MHz SPI
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // 控制介面
    input  wire        start_conversion,
    input  wire [2:0]  channel_select,
    output reg         conversion_done,
    output reg  [11:0] adc_data,
    output reg         data_valid,
    
    // SPI 介面
    input  wire        miso,
    output reg         mosi,
    output reg         sclk,
    output reg         cs_n
);

    // 狀態機定義
    localparam IDLE      = 3'b000;
    localparam CS_ASSERT = 3'b001;
    localparam SEND_CMD  = 3'b010;
    localparam READ_DATA = 3'b011;
    localparam CS_DEASSERT = 3'b100;
    
    reg [2:0] state, state_next;
    reg [4:0] bit_counter;
    reg [15:0] shift_reg;
    
    // SPI 時序控制
    reg [3:0] clk_div_cnt;
    wire spi_clk_en = (clk_div_cnt == 4'd0);
```

#### SPI 協議時序圖

```
CS_N    ‾‾‾‾‾‾‾\_________________________/‾‾‾‾‾‾‾‾‾
SCLK    ________/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\________
MOSI    ----<START><  CH[2:0]  ><   X    >---------
MISO    ---------<X><    ADC_DATA[11:0]   >--------
        |<- Tcss->|<---- 16 clock cycles ---->|<-Tcsh->|

Tcss: CS setup time = 100ns
Tcsh: CS hold time = 100ns
```

### 2.3 PID 控制器內部結構

```verilog
// PID 運算管線
//
// Stage 1: Error calculation
// ┌─────────────┐
// │ e = sp - fb │
// └──────┬──────┘
//        │
// Stage 2: P, I, D terms
// ┌──────▼──────┐ ┌─────────────┐ ┌─────────────┐
// │   P = Kp*e  │ │ I = Ki*Σe   │ │ D = Kd*Δe   │
// └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
//        │               │               │
// Stage 3: Summation and saturation
// ┌──────▼───────────────▼───────────────▼──────┐
// │           output = sat(P + I + D)            │
// └──────────────────────────────────────────────┘

// 定點數運算示例
// Q8.8 × Q8.8 = Q16.16
wire [31:0] p_term_32 = $signed(kp) * $signed(error);
wire [15:0] p_term = p_term_32[23:8]; // 取 Q8.8 結果
```

### 2.4 PWM 產生器詳細實現

```verilog
module pwm_generator #(
    parameter PWM_BITS = 10,  // 10-bit resolution
    parameter SOFT_START_CYCLES = 10000  // 1 second @ 10kHz
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [9:0]  duty_cycle,    // 0-1023
    input  wire        soft_start_en,
    output reg         pwm_out
);

    reg [9:0] counter;
    reg [9:0] effective_duty;
    reg [15:0] soft_start_cnt;
    
    // Soft start implementation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            soft_start_cnt <= 16'd0;
            effective_duty <= 10'd0;
        end else if (enable && soft_start_en) begin
            if (soft_start_cnt < SOFT_START_CYCLES) begin
                soft_start_cnt <= soft_start_cnt + 1'b1;
                // Linear ramp: duty = target * cnt / cycles
                effective_duty <= (duty_cycle * soft_start_cnt) / SOFT_START_CYCLES;
            end else begin
                effective_duty <= duty_cycle;
            end
        end else if (!enable) begin
            soft_start_cnt <= 16'd0;
            effective_duty <= 10'd0;
        end
    end
```

## 3. 時序設計與分析

### 3.1 關鍵路徑分析

```verilog
// 關鍵路徑 1: PID 運算路徑
// temp_current -> error -> P/I/D terms -> output -> pwm_duty
// 估計延遲: 15ns (組合邏輯) + 5ns (路由) = 20ns

// 關鍵路徑 2: ADC 資料處理
// adc_data -> temperature conversion -> register update
// 估計延遲: 10ns (組合邏輯) + 5ns (路由) = 15ns

// 時序約束設置 (SDC)
create_clock -period 100 [get_ports clk]  # 10MHz
set_input_delay -clock clk -max 20 [all_inputs]
set_output_delay -clock clk -max 20 [all_outputs]
```

### 3.2 跨時脈域處理

```verilog
// 異步輸入同步化
module sync_2ff (
    input  wire clk,
    input  wire rst_n,
    input  wire async_in,
    output wire sync_out
);
    reg [1:0] sync_r;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sync_r <= 2'b00;
        else
            sync_r <= {sync_r[0], async_in};
    end
    
    assign sync_out = sync_r[1];
endmodule

// 使用示例
sync_2ff sync_door (
    .clk(clk),
    .rst_n(rst_n),
    .async_in(door_sensor),
    .sync_out(door_sensor_sync)
);
```

### 3.3 時序違規修復技術

```verilog
// 技術 1: 管線化長組合邏輯
// 原始代碼（時序違規）
assign result = (a * b + c * d) / e;

// 管線化版本
reg [31:0] mult_ab, mult_cd;
reg [31:0] sum;
reg [31:0] result;

always @(posedge clk) begin
    // Stage 1
    mult_ab <= a * b;
    mult_cd <= c * d;
    // Stage 2
    sum <= mult_ab + mult_cd;
    // Stage 3
    result <= sum / e;
end

// 技術 2: 邏輯複製減少扇出
// 原始（高扇出）
assign enable_all = global_enable;  // 驅動 100+ 個暫存器

// 複製後
assign enable_group1 = global_enable;
assign enable_group2 = global_enable;
assign enable_group3 = global_enable;
```

## 4. 關鍵實作技術

### 4.1 狀態機設計模式

```verilog
// 三段式狀態機（推薦）
module ctrl_fsm (
    input  wire clk,
    input  wire rst_n,
    // ... other inputs
    output reg [2:0] current_state
);

    // 狀態編碼（格雷碼減少切換）
    localparam IDLE     = 3'b000;
    localparam NORMAL   = 3'b001;
    localparam DEFROST  = 3'b011;
    localparam DOOR_OPEN = 3'b010;
    localparam ALARM    = 3'b110;
    
    reg [2:0] state, state_next;
    
    // 第一段：狀態暫存器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= state_next;
    end
    
    // 第二段：次態邏輯
    always @(*) begin
        state_next = state;  // 預設保持
        
        case (state)
            IDLE: begin
                if (init_done)
                    state_next = NORMAL;
            end
            
            NORMAL: begin
                if (door_open)
                    state_next = DOOR_OPEN;
                else if (defrost_timer_expired)
                    state_next = DEFROST;
                else if (alarm_condition)
                    state_next = ALARM;
            end
            // ... other states
        endcase
    end
    
    // 第三段：輸出邏輯
    always @(*) begin
        // 預設輸出
        compressor_en = 1'b0;
        defrost_en = 1'b0;
        alarm_out = 1'b0;
        
        case (state)
            NORMAL: begin
                compressor_en = pid_enable;
            end
            
            DEFROST: begin
                defrost_en = 1'b1;
                compressor_en = 1'b0;  // 除霜時關閉壓縮機
            end
            
            ALARM: begin
                alarm_out = 1'b1;
                compressor_en = 1'b0;  // 安全考量
            end
            // ... other outputs
        endcase
    end
endmodule
```

### 4.2 資源共享技術

```verilog
// 乘法器共享示例
module shared_multiplier (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [1:0]  sel,        // 選擇操作數
    input  wire [15:0] a, b, c, d,
    output reg  [31:0] result
);

    reg [15:0] op1, op2;
    
    // 多工器選擇操作數
    always @(*) begin
        case (sel)
            2'b00: begin op1 = a; op2 = b; end
            2'b01: begin op1 = c; op2 = d; end
            2'b10: begin op1 = a; op2 = c; end
            2'b11: begin op1 = b; op2 = d; end
        endcase
    end
    
    // 共享的乘法器
    always @(posedge clk) begin
        result <= op1 * op2;
    end
endmodule
```

### 4.3 記憶體推斷技術

```verilog
// 推斷單埠 RAM
module spram_inferred (
    input  wire        clk,
    input  wire        we,
    input  wire [7:0]  addr,
    input  wire [15:0] din,
    output reg  [15:0] dout
);

    reg [15:0] mem [0:255];
    
    always @(posedge clk) begin
        if (we)
            mem[addr] <= din;
        dout <= mem[addr];
    end
endmodule

// 推斷雙埠 RAM
module dpram_inferred (
    input  wire        clk,
    // Port A
    input  wire        we_a,
    input  wire [7:0]  addr_a,
    input  wire [15:0] din_a,
    output reg  [15:0] dout_a,
    // Port B
    input  wire [7:0]  addr_b,
    output reg  [15:0] dout_b
);

    reg [15:0] mem [0:255];
    
    // Port A - Read/Write
    always @(posedge clk) begin
        if (we_a)
            mem[addr_a] <= din_a;
        dout_a <= mem[addr_a];
    end
    
    // Port B - Read only
    always @(posedge clk) begin
        dout_b <= mem[addr_b];
    end
endmodule
```

## 5. 資源使用估算

### 5.1 邏輯資源估算

```
模組名稱              | LUTs | FFs  | DSPs | BRAM |
---------------------|------|------|------|------|
temp_ctrl_top        | 2500 | 1800 |   2  |   0  |
├─ adc_spi_interface |  150 |  100 |   0  |   0  |
├─ pid_controller    |  800 |  400 |   2  |   0  |
├─ pwm_generator     |  200 |  150 |   0  |   0  |
├─ display_controller|  500 |  300 |   0  |   0  |
├─ ctrl_fsm          |  300 |  200 |   0  |   0  |
├─ timer_ctrl        |  350 |  400 |   0  |   0  |
└─ reg_bank          |  200 |  250 |   0  |   0  |

總計估算：
- 組合邏輯: ~2500 LUTs
- 時序邏輯: ~1800 FFs
- 算術單元: 2 DSP blocks (用於 PID 乘法)
- 記憶體: 0 BRAM (暫存器實現)
```

### 5.2 時序資源分析

```verilog
// 計算各模組的時序裕度
module timing_analysis;
    // PID 路徑: 70ns < 100ns (30% margin)
    // ADC 路徑: 50ns < 100ns (50% margin)
    // PWM 路徑: 30ns < 100ns (70% margin)
    // FSM 路徑: 40ns < 100ns (60% margin)
    
    // 最差路徑: PID 運算
    // 改善方法: 增加管線級數或降低運算複雜度
endmodule
```

## 6. 編碼風格指南

### 6.1 模組結構模板

```verilog
//==============================================================================
// Module: module_name
// Description: Brief description of module functionality
// Author: Your name
// Date: YYYY-MM-DD
//==============================================================================

`timescale 1ns / 1ps

module module_name #(
    // Parameters
    parameter PARAM1 = 8,
    parameter PARAM2 = 16
)(
    // Clocks and resets
    input  wire                 clk,
    input  wire                 rst_n,
    
    // Input signals (grouped by function)
    input  wire [PARAM1-1:0]    data_in,
    input  wire                 valid_in,
    
    // Output signals (grouped by function)
    output reg  [PARAM2-1:0]    data_out,
    output reg                  valid_out
);

    //==========================================================================
    // Local parameters
    //==========================================================================
    localparam STATE_IDLE = 2'b00;
    localparam STATE_BUSY = 2'b01;
    
    //==========================================================================
    // Internal signals
    //==========================================================================
    reg [1:0] state, state_next;
    wire condition;
    
    //==========================================================================
    // Continuous assignments
    //==========================================================================
    assign condition = (state == STATE_IDLE) && valid_in;
    
    //==========================================================================
    // Sequential logic
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            data_out <= {PARAM2{1'b0}};
        end else begin
            state <= state_next;
            // Other sequential logic
        end
    end
    
    //==========================================================================
    // Combinational logic
    //==========================================================================
    always @(*) begin
        state_next = state;
        
        case (state)
            STATE_IDLE: begin
                if (condition)
                    state_next = STATE_BUSY;
            end
            
            STATE_BUSY: begin
                // State logic
            end
            
            default: begin
                state_next = STATE_IDLE;
            end
        endcase
    end
    
endmodule
```

### 6.2 信號宣告最佳實踐

```verilog
// Good: 明確的位寬宣告
wire [7:0] byte_data;
reg  [15:0] word_data;

// Bad: 隱含的位寬
wire data;  // 容易造成誤解

// Good: 使用參數定義位寬
parameter DATA_WIDTH = 16;
wire [DATA_WIDTH-1:0] data_bus;

// Bad: 魔術數字
wire [15:0] data_bus;  // 16 是什麼？

// Good: 陣列宣告清晰
reg [7:0] memory [0:255];  // 256 個 8-bit 暫存器

// Bad: 容易混淆的宣告
reg [0:255] memory [7:0];  // 順序相反，容易出錯
```

### 6.3 always 區塊使用規範

```verilog
// Good: 分離組合與時序邏輯
always @(posedge clk) begin  // 時序邏輯
    q <= d;
end

always @(*) begin  // 組合邏輯
    next_state = current_state;
    // ...
end

// Bad: 混合邏輯類型
always @(posedge clk or negedge rst_n or a or b) begin
    // 混亂且容易出錯
end

// Good: 完整的敏感列表
always @(*) begin  // 或 always_comb (SystemVerilog)
    case (sel)
        2'b00: out = a;
        2'b01: out = b;
        2'b10: out = c;
        2'b11: out = d;
    endcase
end

// Bad: 不完整的敏感列表
always @(sel) begin  // 缺少 a, b, c, d
    // 模擬與合成不匹配
end
```

## 7. 常見陷阱與最佳實踐

### 7.1 避免鎖存器推斷

```verilog
// Bad: 會產生鎖存器
always @(*) begin
    if (enable)
        q = d;  // else 分支缺失
end

// Good: 完整的條件覆蓋
always @(*) begin
    if (enable)
        q = d;
    else
        q = q_prev;  // 明確指定
end

// Better: 預設值方法
always @(*) begin
    q = q_prev;  // 預設值
    if (enable)
        q = d;
end
```

### 7.2 阻塞與非阻塞賦值

```verilog
// 規則：時序邏輯用非阻塞賦值
always @(posedge clk) begin
    a <= b;  // Good: 非阻塞
    b <= c;  // Good: 非阻塞
end

// 規則：組合邏輯用阻塞賦值
always @(*) begin
    temp = a + b;    // Good: 阻塞
    result = temp * c;  // Good: 阻塞
end

// Bad: 混用賦值類型
always @(posedge clk) begin
    a = b;   // Bad: 時序邏輯中用阻塞
    c <= d;  // 混用導致競爭條件
end
```

### 7.3 複位設計最佳實踐

```verilog
// Good: 同步重置（SKY130 推薦）
always @(posedge clk) begin
    if (!rst_n) begin
        counter <= 8'd0;
        state <= IDLE;
    end else begin
        // Normal operation
    end
end

// Alternative: 非同步重置（需要時序檢查）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset logic
    end else begin
        // Normal operation
    end
end

// Best: 非同步斷言，同步釋放
reg rst_sync1, rst_sync2;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rst_sync1 <= 1'b0;
        rst_sync2 <= 1'b0;
    end else begin
        rst_sync1 <= 1'b1;
        rst_sync2 <= rst_sync1;
    end
end
wire rst_sync = rst_sync2;
```

### 7.4 時脈閘控實現

```verilog
// Bad: 手動閘控（易出現毛刺）
assign gated_clk = clk & enable;  // 危險！

// Good: 使用整合時脈閘控單元 (ICG)
// 綜合工具會自動推斷
always @(posedge clk) begin
    if (enable) begin  // 工具識別為時脈閘控
        data <= data_in;
    end
end

// Better: 明確實例化 ICG（如果 PDK 提供）
sky130_fd_sc_hd__icgtp_1 u_icg (
    .CLK(clk),
    .E(enable),
    .TE(test_enable),
    .Q(gated_clk)
);
```

## 8. 調試技巧

### 8.1 內建調試功能

```verilog
// 調試計數器
`ifdef DEBUG
reg [31:0] debug_counters [0:7];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        debug_counters[0] <= 32'd0;
    end else begin
        // 計數狀態轉換
        if (state != state_next)
            debug_counters[0] <= debug_counters[0] + 1'b1;
    end
end
`endif

// 斷言檢查
`ifdef ASSERTIONS
always @(posedge clk) begin
    // 檢查狀態機不會進入非法狀態
    assert(state <= 3'b100) else
        $error("Invalid state: %b", state);
    
    // 檢查 FIFO 不會上溢/下溢
    assert(!(push && full)) else
        $error("FIFO overflow");
end
`endif
```

### 8.2 波形調試技巧

```verilog
// 產生觸發信號
reg trigger;
always @(posedge clk) begin
    trigger <= (state == TARGET_STATE) && (counter == 32'd1000);
end

// 標記重要事件
reg [7:0] event_marker;
always @(posedge clk) begin
    event_marker <= 8'd0;  // 預設
    
    if (fsm_state_change)
        event_marker <= 8'd1;
    else if (error_detected)
        event_marker <= 8'd2;
    else if (operation_complete)
        event_marker <= 8'd3;
end

// 建立調試匯流排
wire [63:0] debug_bus = {
    state,           // [63:61]
    error_flags,     // [60:53]
    counter[15:0],   // [52:37]
    data_valid,      // [36]
    {3{1'b0}},      // [35:33] reserved
    address[7:0],    // [32:25]
    data[23:0]       // [24:0]
};
```

### 8.3 形式驗證友好設計

```verilog
// 添加形式驗證屬性
// SVA (SystemVerilog Assertions) 示例

// 屬性：請求必須在 10 個週期內得到回應
property req_ack_timing;
    @(posedge clk) disable iff (!rst_n)
    req |-> ##[1:10] ack;
endproperty
assert property (req_ack_timing);

// 覆蓋點：確保所有狀態都被訪問
covergroup state_coverage @(posedge clk);
    coverpoint state {
        bins idle = {IDLE};
        bins active = {ACTIVE};
        bins done = {DONE};
        bins error = {ERROR};
    }
endcovergroup
```

## 9. 性能優化技術

### 9.1 關鍵路徑優化

```verilog
// 原始：長組合路徑
assign result = (a * b + c * d) >> 2;

// 優化 1：平衡樹結構
wire [31:0] prod1 = a * b;
wire [31:0] prod2 = c * d;
wire [32:0] sum = prod1 + prod2;
assign result = sum >> 2;

// 優化 2：管線化
reg [31:0] prod1_r, prod2_r;
reg [32:0] sum_r;
always @(posedge clk) begin
    prod1_r <= a * b;
    prod2_r <= c * d;
    sum_r <= prod1_r + prod2_r;
    result <= sum_r >> 2;
end
```

### 9.2 資源優化

```verilog
// 共享昂貴資源（如乘法器）
module resource_sharing (
    input clk,
    input [1:0] mode,
    input [15:0] a, b, c, d,
    output reg [31:0] result
);

    reg [15:0] op1, op2;
    
    // 輸入多工
    always @(*) begin
        case (mode)
            2'b00: begin op1 = a; op2 = b; end
            2'b01: begin op1 = c; op2 = d; end
            2'b10: begin op1 = a; op2 = d; end
            2'b11: begin op1 = b; op2 = c; end
        endcase
    end
    
    // 共享乘法器
    always @(posedge clk) begin
        result <= op1 * op2;
    end
endmodule
```

## 10. 測試平台整合

### 10.1 模組級測試介面

```verilog
interface pid_test_if;
    logic clk;
    logic rst_n;
    logic enable;
    logic signed [15:0] setpoint;
    logic signed [15:0] feedback;
    logic signed [15:0] kp, ki, kd;
    logic signed [15:0] output;
    
    // 測試任務
    task automatic set_params(
        input real kp_val,
        input real ki_val,
        input real kd_val
    );
        kp = $rtoi(kp_val * 256);  // Convert to Q8.8
        ki = $rtoi(ki_val * 256);
        kd = $rtoi(kd_val * 256);
    endtask
    
    task automatic set_temperature(
        input real temp_val
    );
        setpoint = $rtoi(temp_val * 256);
    endtask
endinterface
```

### 10.2 自檢測試模式

```verilog
module built_in_self_test (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       test_enable,
    output reg        test_done,
    output reg        test_pass,
    output reg [7:0]  test_code
);

    // 測試序列
    localparam TEST_IDLE = 0;
    localparam TEST_RAM  = 1;
    localparam TEST_ALU  = 2;
    localparam TEST_FSM  = 3;
    localparam TEST_IO   = 4;
    
    reg [2:0] test_state;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            test_state <= TEST_IDLE;
            test_done <= 1'b0;
            test_pass <= 1'b0;
        end else if (test_enable) begin
            case (test_state)
                TEST_IDLE: begin
                    test_state <= TEST_RAM;
                end
                
                TEST_RAM: begin
                    // RAM 測試邏輯
                    if (ram_test_complete) begin
                        test_code[0] <= ram_test_pass;
                        test_state <= TEST_ALU;
                    end
                end
                
                // ... 其他測試
            endcase
        end
    end
endmodule
```

---

文件版本：1.0  
最後更新：2024-12-19  
作者：IC 設計團隊  
下一份文件：[驗證策略與測試覆蓋率](../03_verification/01_verification_strategy.md)
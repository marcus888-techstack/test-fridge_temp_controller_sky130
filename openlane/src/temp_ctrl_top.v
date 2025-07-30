//==============================================================================
// File: temp_ctrl_top.v
// Description: Top-level module for refrigerator temperature controller
// Author: IC Design Team
// Date: 2024-12-19
// Target: SKY130 PDK
//==============================================================================
//
// 系統架構圖：
// ┌─────────────────────────────────────────────────────────────────────┐
// │                      冰箱溫度控制器頂層模組                            │
// │                                                                       │
// │  ┌─────────┐    ┌──────────┐    ┌─────────┐    ┌──────────┐      │
// │  │   ADC   │───▶│溫度轉換器│───▶│   PID   │───▶│   PWM    │───▶ 壓縮機
// │  │ SPI介面 │    │ Q8.8格式 │    │ 控制器  │    │  產生器  │      │
// │  └─────────┘    └──────────┘    └─────────┘    └──────────┘      │
// │       ▲                               │                              │
// │       │                               │                              │
// │  溫度感測器                           ▼                              │
// │                                ┌─────────────┐                       │
// │  ┌─────────┐                  │  狀態機控制  │                       │
// │  │使用者界面│◀───────────────▶│   NORMAL    │                       │
// │  │ 按鈕輸入 │                  │   DEFROST   │                       │
// │  └─────────┘                  │   ALARM     │                       │
// │                                └─────────────┘                       │
// │  ┌─────────┐                         │                              │
// │  │七段顯示器│◀───────────────────────┘                              │
// │  │ 控制器  │                                                        │
// │  └─────────┘                                                        │
// └─────────────────────────────────────────────────────────────────────┘

`timescale 1ns / 1ps

module temp_ctrl_top (
    // System signals
    input  wire        clk,           // 10 MHz system clock - 選擇10MHz是為了方便產生各種時鐘頻率
    input  wire        rst_n,         // Active-low reset - 低電平有效重置，符合業界標準
    
    // ADC interface - 使用SPI協議與外部ADC通訊
    input  wire        adc_miso,      // ADC data input - Master In Slave Out
    output wire        adc_mosi,      // ADC data output - Master Out Slave In  
    output wire        adc_sclk,      // ADC clock - SPI時鐘，1MHz
    output wire        adc_cs_n,      // ADC chip select - 片選信號，低電平有效
    
    // Control outputs - 控制輸出信號
    output wire        compressor_pwm, // Compressor PWM control - 壓縮機PWM控制，用於調節製冷功率
    output wire        defrost_heater, // Defrost heater control - 除霜加熱器控制
    output wire        alarm,          // Alarm output - 警報輸出（溫度異常或門開太久）
    
    // Display interface - 顯示介面
    output wire [6:0]  seven_seg,     // 7-segment display segments - 七段顯示器段選（a-g）
    output wire [3:0]  digit_sel,     // Digit select (multiplexed) - 位選信號，時分複用
    output wire [2:0]  status_led,    // Status LEDs - 狀態指示燈[綠/黃/紅]
    
    // User interface - 使用者介面
    input  wire        door_sensor,    // Door open sensor - 門開感測器，高電平表示門開
    input  wire        button_up,      // Temperature up button - 溫度調高按鈕
    input  wire        button_down,    // Temperature down button - 溫度調低按鈕
    input  wire        button_mode     // Mode selection button - 模式選擇按鈕
);

    //==========================================================================
    // Parameters - 系統參數定義
    //==========================================================================
    
    // Temperature limits (Q8.8 fixed-point format)
    // Q8.8 格式說明：16位元定點數，高8位為整數部分，低8位為小數部分
    // 例如：0x0400 = 4.0°C (0000_0100.0000_0000)
    // 選擇Q8.8格式的原因：
    // 1. 提供足夠的精度（1/256 ≈ 0.004°C）
    // 2. 避免浮點運算的硬體成本
    // 3. 運算簡單，適合嵌入式系統
    parameter signed [15:0] TEMP_MIN      = 16'hEC00;  // -20.0°C = 1110_1100.0000_0000
    parameter signed [15:0] TEMP_MAX      = 16'h0A00;  // +10.0°C = 0000_1010.0000_0000
    parameter signed [15:0] TEMP_DEFAULT  = 16'h0400;  // +4.0°C  = 0000_0100.0000_0000（冰箱典型設定溫度）
    parameter        [15:0] TEMP_STEP     = 16'h0080;  // 0.5°C   = 0000_0000.1000_0000（調節步進值）
    
    // Timing parameters (in clock cycles)
    // 所有計時參數都以時鐘週期為單位，便於精確控制
    parameter [31:0] SAMPLE_PERIOD    = 32'd100_000;         // 10ms @ 10MHz (reduced for testing)
    parameter [31:0] DEFROST_PERIOD   = 32'd600_000_000; // 1 minute for simulation (was 8 hours)
    parameter [31:0] DEFROST_DURATION = 32'd18_000_000;  // 30 minutes @ 10MHz (simplified for sim)
    parameter [31:0] DOOR_ALARM_DELAY = 32'd1_200_000_000;   // 2 minutes - 門開警報延遲
    
    //==========================================================================
    // Internal signals - 內部信號定義
    //==========================================================================
    
    // Clock and reset - 時鐘與重置信號
    wire clk_1mhz;      // 1MHz時鐘 - 用於SPI通訊
    wire clk_1khz;      // 1kHz時鐘使能 - 用於PWM產生
    wire clk_100hz;     // 100Hz時鐘使能 - 用於顯示掃描
    reg  rst_sync;      // 同步重置信號第一級
    reg  rst_sync_d;    // 同步重置信號第二級（用於消除亞穩態）
    
    // Temperature signals - 溫度相關信號
    wire signed [15:0] temp_current;    // 當前溫度（Q8.8格式）
    reg  signed [15:0] temp_current_latched; // 鎖存的當前溫度
    reg  signed [15:0] temp_setpoint;   // 設定溫度（Q8.8格式）
    wire        [11:0] adc_data;        // ADC原始數據（12位元）
    wire               adc_valid;       // ADC數據有效標誌
    reg                temp_data_ready; // 溫度數據準備好標誌
    
    // Control signals - 控制信號
    wire signed [15:0] pid_output;      // PID控制器輸出
    wire        [9:0]  pwm_duty_cycle;  // PWM占空比（0-1023）
    reg                compressor_enable;    // 壓縮機使能
    reg                defrost_active;       // 除霜激活
    
    // State machine - 狀態機
    reg  [2:0] current_state;           // 當前狀態
    reg  [2:0] next_state;              // 下一狀態
    
    // 狀態定義 - 使用獨熱碼便於綜合優化
    localparam STATE_INIT       = 3'b000;  // 初始化狀態
    localparam STATE_NORMAL     = 3'b001;  // 正常運行狀態
    localparam STATE_DEFROST    = 3'b010;  // 除霜狀態
    localparam STATE_DOOR_OPEN  = 3'b011;  // 門開狀態
    localparam STATE_ALARM      = 3'b100;  // 警報狀態
    localparam STATE_TEST       = 3'b101;  // 測試狀態（保留）
    
    // Timers - 定時器
    reg [31:0] sample_timer;        // 採樣定時器
    reg [31:0] defrost_timer;       // 除霜定時器
    reg [31:0] door_timer;          // 門開定時器
    reg [31:0] compressor_timer;    // 壓縮機保護定時器（防止頻繁啟停）
    reg        sample_trigger;      // ADC採樣觸發信號
    
    // User interface - 使用者介面信號
    reg button_up_sync, button_up_prev;      // 按鈕同步和邊緣檢測
    reg button_down_sync, button_down_prev;
    reg button_mode_sync, button_mode_prev;
    reg door_sensor_sync;                    // 門感測器同步
    wire button_up_edge;                     // 按鈕上升沿
    wire button_down_edge;
    wire button_mode_edge;
    
    // Display - 顯示相關
    reg [1:0] display_mode;     // 顯示模式：00-當前溫度，01-設定溫度，10-PWM值，11-狀態
    reg [15:0] display_value;   // 顯示數值
    reg display_blink;          // 閃爍控制
    
    //==========================================================================
    // Clock generation - 時鐘產生
    // 從10MHz系統時鐘產生各種所需頻率
    //==========================================================================
    
    // Clock divider for 1MHz (SPI)
    // 為什麼需要1MHz：ADC的SPI介面典型工作頻率，確保可靠通訊
    reg [3:0] clk_div_10;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div_10 <= 4'd0;
        end else begin
            clk_div_10 <= (clk_div_10 == 4'd9) ? 4'd0 : clk_div_10 + 1'b1;
        end
    end
    assign clk_1mhz = (clk_div_10 < 4'd5);  // 產生50%占空比的1MHz時鐘
    
    // Clock divider for 1kHz (PWM)
    // 為什麼需要1kHz：PWM頻率選擇考量
    // 1. 高於人耳聽覺範圍，避免噪音
    // 2. 低於功率器件開關損耗過大的頻率
    // 3. 提供足夠的調節精度（10位元 = 1024級）
    reg [13:0] clk_div_10k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div_10k <= 14'd0;
        end else begin
            clk_div_10k <= (clk_div_10k == 14'd9999) ? 14'd0 : clk_div_10k + 1'b1;
        end
    end
    assign clk_1khz = (clk_div_10k == 14'd0);  // 產生時鐘使能脈衝
    
    // Clock divider for 100Hz (Display)
    // 為什麼需要100Hz：顯示掃描頻率選擇
    // 1. 高於人眼閃爍感知頻率（>50Hz）
    // 2. 4位數顯示，每位25Hz刷新率
    // 3. 避免過高頻率造成EMI干擾
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
    // Reset synchronization - 重置同步
    // 使用兩級觸發器消除異步重置可能造成的亞穩態
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rst_sync   <= 1'b0;
            rst_sync_d <= 1'b0;
        end else begin
            rst_sync   <= 1'b1;      // 第一級同步
            rst_sync_d <= rst_sync;  // 第二級同步，用作內部重置信號
        end
    end
    
    //==========================================================================
    // Temperature latching - 溫度鎖存
    // 當ADC數據有效時鎖存溫度值
    //==========================================================================
    
    always @(posedge clk or negedge rst_sync_d) begin
        if (!rst_sync_d) begin
            temp_current_latched <= 16'h0400;  // 默認4°C
            temp_data_ready <= 1'b0;
        end else begin
            if (adc_valid) begin
                temp_current_latched <= temp_current;
                temp_data_ready <= 1'b1;
            end
        end
    end
    
    //==========================================================================
    // Input synchronization and edge detection - 輸入同步與邊緣檢測
    // 防止按鈕抖動和亞穩態問題
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
            // 兩級同步消除亞穩態
            button_up_sync   <= button_up;
            button_up_prev   <= button_up_sync;
            button_down_sync <= button_down;
            button_down_prev <= button_down_sync;
            button_mode_sync <= button_mode;
            button_mode_prev <= button_mode_sync;
            door_sensor_sync <= door_sensor;
        end
    end
    
    // 邊緣檢測 - 只在按鈕按下瞬間響應一次
    assign button_up_edge   = button_up_sync & ~button_up_prev;
    assign button_down_edge = button_down_sync & ~button_down_prev;
    assign button_mode_edge = button_mode_sync & ~button_mode_prev;
    
    //==========================================================================
    // ADC Interface instantiation - ADC介面實例化
    //==========================================================================
    
    adc_spi_interface u_adc_spi (
        .clk        (clk),
        .rst_n      (rst_sync_d),
        .clk_1mhz   (clk_1mhz),
        .start      (sample_trigger),             // ADC採樣觸發脈衝
        .channel    (3'd0),                       // 使用通道0讀取溫度
        .adc_data   (adc_data),                   // 12位元ADC結果
        .adc_valid  (adc_valid),                  // 數據有效標誌
        .spi_miso   (adc_miso),
        .spi_mosi   (adc_mosi),
        .spi_sclk   (adc_sclk),
        .spi_cs_n   (adc_cs_n)
    );
    
    //==========================================================================
    // Temperature conversion - 溫度轉換
    // ADC值轉換為溫度的公式推導：
    // 1. ADC輸入範圍：0-3.3V對應0-4095
    // 2. 溫度感測器輸出：0.5V @ -50°C, 2.5V @ +50°C (20mV/°C)
    // 3. 溫度(°C) = (ADC_Value × 3.3 / 4096 - 0.5) × 50
    // 4. 簡化為定點運算：temp = (adc_data × 82 - 2048) >> 2
    //==========================================================================
    
    // Match testbench formula: temp_c = (adc_value * 100 / 4096) - 50
    // In Q8.8: temp = ((adc * 100 * 256) / 4096) - (50 * 256)
    // Simplify: temp = (adc * 25600 / 4096) - 12800 = (adc * 6.25) - 12800
    wire signed [19:0] temp_calc = ($signed({8'd0, adc_data}) * 20'd25) - 20'd51200;
    assign temp_current = temp_calc[17:2];  // Divide by 4 to get Q8.8
    
    //==========================================================================
    // PID Controller instantiation - PID控制器實例化
    // PID參數選擇說明：
    // Kp = 2.0：比例增益，決定響應速度
    // Ki = 0.1：積分增益，消除穩態誤差
    // Kd = 0.05：微分增益，減少超調
    //==========================================================================
    
    pid_controller u_pid (
        .clk        (clk),
        .rst_n      (rst_sync_d),
        .enable     (compressor_enable & temp_data_ready),  // 只在壓縮機允許運行且有數據時更新
        .setpoint   (temp_setpoint),                        // 設定溫度
        .feedback   (temp_current_latched),                 // 鎖存的當前溫度
        .kp         (16'h0200),  // Kp = 2.0 (Q8.8格式)
        .ki         (16'h001A),  // Ki = 0.1 (Q8.8格式)
        .kd         (16'h000D),  // Kd = 0.05 (Q8.8格式)
        .pid_out    (pid_output)                      // PID輸出
    );
    
    //==========================================================================
    // PWM duty cycle calculation - PWM占空比計算
    // 將PID輸出（可正可負）轉換為PWM占空比（0-1023）
    //==========================================================================
    
    wire signed [15:0] pwm_temp = pid_output + 16'h0200;  // 加偏移量使其為正值
    assign pwm_duty_cycle = (pwm_temp < 0) ? 10'd0 :                    // 飽和到0
                           (pwm_temp > 16'h03FF) ? 10'd1023 :          // 飽和到最大值
                           pwm_temp[9:0];                               // 取低10位
    
    //==========================================================================
    // PWM Generator instantiation - PWM產生器實例化
    //==========================================================================
    
    pwm_generator u_pwm (
        .clk        (clk),
        .rst_n      (rst_sync_d),
        .clk_1khz   (clk_1khz),
        .enable     (compressor_enable),
        .duty_cycle (pwm_duty_cycle),
        .soft_start (1'b1),             // 啟用軟啟動，保護壓縮機
        .pwm_out    (compressor_pwm)
    );
    
    //==========================================================================
    // State Machine - 狀態機
    // 控制系統的運行模式，確保安全可靠的操作
    //==========================================================================
    
    // State register - 狀態寄存器
    always @(posedge clk or negedge rst_sync_d) begin
        if (!rst_sync_d) begin
            current_state <= STATE_INIT;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Next state logic - 下一狀態邏輯
    always @(*) begin
        next_state = current_state;
        
        case (current_state)
            STATE_INIT: begin
                // 初始化狀態：等待系統穩定
                if (sample_timer < 32'd9_000_000)  // 1秒後進入正常狀態 (timer counts down from 10M)
                    next_state = STATE_NORMAL;
            end
            
            STATE_NORMAL: begin
                // 正常運行狀態：監控各種條件
                if (door_sensor_sync)
                    next_state = STATE_DOOR_OPEN;          // 門開優先處理
                else if (defrost_timer == 32'd0)
                    next_state = STATE_DEFROST;            // 定時除霜
                else if (temp_data_ready && ((temp_current_latched > $signed(16'h0A00)) || (temp_current_latched < $signed(16'hE700))))
                    next_state = STATE_ALARM;              // 溫度超出範圍（>10°C或<-25°C）- 需要有效數據
            end
            
            STATE_DOOR_OPEN: begin
                // 門開狀態：監控門的關閉和超時
                if (!door_sensor_sync)
                    next_state = STATE_NORMAL;             // 門關閉，返回正常
                else if (door_timer == 32'd0)
                    next_state = STATE_ALARM;              // 門開太久，觸發警報
            end
            
            STATE_DEFROST: begin
                // 除霜狀態：等待除霜完成
                if (defrost_timer == 32'd0)
                    next_state = STATE_NORMAL;             // 除霜完成
            end
            
            STATE_ALARM: begin
                // 警報狀態：等待用戶確認
                if (button_mode_edge)
                    next_state = STATE_NORMAL;             // 按模式鍵解除警報
            end
            
            STATE_TEST: begin
                // 測試狀態：保留用於診斷
                if (button_mode_edge)
                    next_state = STATE_NORMAL;
            end
            
            default: next_state = STATE_INIT;
        endcase
    end
    
    //==========================================================================
    // Control logic - 控制邏輯
    // 根據狀態決定壓縮機和除霜加熱器的操作
    //==========================================================================
    
    always @(posedge clk or negedge rst_sync_d) begin
        if (!rst_sync_d) begin
            compressor_enable <= 1'b0;
            defrost_active    <= 1'b0;
        end else begin
            case (current_state)
                STATE_INIT: begin
                    compressor_enable <= 1'b0;      // 初始化時關閉所有輸出
                    defrost_active    <= 1'b0;
                end
                
                STATE_NORMAL: begin
                    // 正常狀態：壓縮機根據溫度和保護定時器決定是否運行
                    if (compressor_timer == 32'd0) begin
                        // Protection timer expired, control based on temperature
                        compressor_enable <= temp_data_ready && (temp_current_latched > temp_setpoint);
                    end
                    // else keep current state (don't change during protection period)
                    defrost_active    <= 1'b0;
                end
                
                STATE_DOOR_OPEN: begin
                    // 門開狀態：保持當前控制狀態
                    // 不立即關閉壓縮機，避免頻繁啟停
                end
                
                STATE_DEFROST: begin
                    compressor_enable <= 1'b0;      // 除霜時必須關閉壓縮機
                    defrost_active    <= 1'b1;      // 開啟除霜加熱器
                end
                
                STATE_ALARM: begin
                    compressor_enable <= 1'b0;      // 警報時關閉所有輸出
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
    // Timer management - 定時器管理
    // 各種定時器的功能：
    // 1. sample_timer：控制溫度採樣週期
    // 2. defrost_timer：控制除霜週期和持續時間
    // 3. door_timer：檢測門開超時
    // 4. compressor_timer：壓縮機最小關閉時間（保護）
    //==========================================================================
    
    always @(posedge clk or negedge rst_sync_d) begin
        if (!rst_sync_d) begin
            sample_timer     <= 32'd0;
            defrost_timer    <= DEFROST_PERIOD;
            door_timer       <= DOOR_ALARM_DELAY;
            compressor_timer <= 32'd100_000;     // 10ms初始延遲 (reduced for testing)
            sample_trigger   <= 1'b0;
        end else begin
            // Sample timer (1 second period) - 溫度採樣定時器
            if (sample_timer == 32'd0) begin
                sample_timer <= SAMPLE_PERIOD - 1;
                sample_trigger <= 1'b1;  // Generate trigger pulse
            end else begin
                sample_timer <= sample_timer - 1'b1;
                sample_trigger <= 1'b0;  // Clear trigger
            end
            
            // Defrost timer - 除霜定時器
            if (current_state == STATE_DEFROST) begin
                // 除霜狀態：倒計時除霜持續時間
                if (defrost_timer > 32'd0)
                    defrost_timer <= defrost_timer - 1'b1;
                else
                    defrost_timer <= DEFROST_PERIOD;  // 除霜完成，重置週期
            end else if (current_state == STATE_NORMAL) begin
                // 正常狀態：倒計時到下次除霜
                if (defrost_timer > 32'd0)
                    defrost_timer <= defrost_timer - 1'b1;
            end
            
            // Door timer - 門開定時器
            if (current_state == STATE_DOOR_OPEN) begin
                if (door_timer > 32'd0)
                    door_timer <= door_timer - 1'b1;
            end else begin
                door_timer <= DOOR_ALARM_DELAY;       // 門關閉時重置
            end
            
            // Compressor protection timer - 壓縮機保護定時器
            // 防止壓縮機頻繁啟停，延長使用壽命
            if (compressor_timer > 32'd0)
                compressor_timer <= compressor_timer - 1'b1;
            // Reset timer when compressor turns OFF (not when running)
            else if (compressor_enable && temp_data_ready && (temp_current_latched < temp_setpoint))
                compressor_timer <= 32'd100_000;      // 10ms protection (reduced for testing)
        end
    end
    
    //==========================================================================
    // Temperature setpoint adjustment - 溫度設定點調節
    // 允許用戶通過按鈕調節目標溫度
    //==========================================================================
    
    always @(posedge clk or negedge rst_sync_d) begin
        if (!rst_sync_d) begin
            temp_setpoint <= TEMP_DEFAULT;            // 上電默認4°C
        end else begin
            // 溫度調高（每次0.5°C）
            if (button_up_edge && (temp_setpoint < TEMP_MAX - TEMP_STEP))
                temp_setpoint <= temp_setpoint + TEMP_STEP;
            // 溫度調低（每次0.5°C）
            else if (button_down_edge && (temp_setpoint > TEMP_MIN + TEMP_STEP))
                temp_setpoint <= temp_setpoint - TEMP_STEP;
        end
    end
    
    //==========================================================================
    // Display control - 顯示控制
    // 管理顯示內容和模式切換
    //==========================================================================
    
    always @(posedge clk or negedge rst_sync_d) begin
        if (!rst_sync_d) begin
            display_mode  <= 2'b00;
            display_value <= 16'd0;
            display_blink <= 1'b0;
        end else begin
            // Mode selection - 模式選擇（循環切換）
            if (button_mode_edge)
                display_mode <= display_mode + 1'b1;
            
            // Select display value - 選擇顯示內容
            case (display_mode)
                2'b00: display_value <= temp_current_latched;      // 當前溫度
                2'b01: display_value <= temp_setpoint;             // 設定溫度
                2'b10: display_value <= {6'd0, pwm_duty_cycle};    // PWM占空比
                2'b11: display_value <= {13'd0, current_state};    // 當前狀態
            endcase
            
            // Blink control for setpoint mode - 設定模式時閃爍提示
            display_blink <= (display_mode == 2'b01);
        end
    end
    
    //==========================================================================
    // Display controller instantiation - 顯示控制器實例化
    //==========================================================================
    
    display_controller u_display (
        .clk        (clk),
        .rst_n      (rst_sync_d),
        .clk_100hz  (clk_100hz),
        .value      (display_value),
        .decimal_pt (2'b01),      // XX.X format - 小數點在第二位
        .blink      (display_blink),
        .seven_seg  (seven_seg),
        .digit_sel  (digit_sel)
    );
    
    //==========================================================================
    // Status LED assignment - 狀態LED分配
    // 提供直觀的系統狀態指示
    //==========================================================================
    
    assign status_led[0] = (current_state == STATE_NORMAL);   // Green - 綠燈：正常運行
    assign status_led[1] = (current_state == STATE_DEFROST);  // Yellow - 黃燈：除霜中
    assign status_led[2] = (current_state == STATE_ALARM);    // Red - 紅燈：警報

endmodule
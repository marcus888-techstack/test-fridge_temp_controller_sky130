//==============================================================================
// File: display_controller.v
// Description: 7-segment display controller with multiplexing support
// Author: IC Design Team
// Date: 2024-12-19
// Target: SKY130 PDK
//==============================================================================
//
// 七段顯示器段定義：
//         aaa
//        f   b
//        f   b
//         ggg
//        e   c
//        e   c
//         ddd  dp
//
// 段編碼格式：{dp, g, f, e, d, c, b, a}
// 例如：顯示 "8" = 0111_1111 (所有段都亮)
//       顯示 "1" = 0000_0110 (只有b和c段亮)
//
// 4位數顯示器多工掃描原理：
// 
// 時間 →
// Digit 0: ─ON──OFF─OFF─OFF─│─ON──OFF─OFF─OFF─│─ON──OFF─OFF─OFF─
// Digit 1: ─OFF─ON──OFF─OFF─│─OFF─ON──OFF─OFF─│─OFF─ON──OFF─OFF─
// Digit 2: ─OFF─OFF─ON──OFF─│─OFF─OFF─ON──OFF─│─OFF─OFF─ON──OFF─
// Digit 3: ─OFF─OFF─OFF─ON──│─OFF─OFF─OFF─ON──│─OFF─OFF─OFF─ON──
//          └────────────────┘└────────────────┘
//           一個完整掃描週期     下一個掃描週期
//           (40ms @ 100Hz)
//
// 每個數位顯示時間 = 10ms (100Hz / 4)
// 刷新率 = 25Hz（每個數位）> 人眼閃爍感知頻率
//
// 溫度顯示格式範例：
// -12.5°C → [－][1][2.][5]
//  04.0°C → [ ][0][4.][0]
//  23.8°C → [2][3.][8][ ]
//
// Double Dabble BCD轉換演算法：
// 將二進制數轉換為BCD（Binary Coded Decimal）
// 原理：重複左移和調整，直到所有位都處理完
// 
// 例：將二進制 11111111 (255) 轉換為BCD：
// 步驟1: 如果任何BCD位 >= 5，則加3
// 步驟2: 左移整個數字（包括BCD部分）
// 重複直到處理完所有位

`timescale 1ns / 1ps

module display_controller (
    // System signals
    input  wire        clk,         // System clock (10 MHz) - 系統時鐘
    input  wire        rst_n,       // Active-low reset - 低電平有效重置
    input  wire        clk_100hz,   // 100 Hz clock enable - 100Hz時鐘使能
    
    // Data interface - 數據介面
    input  wire [15:0] value,       // Value to display (Q8.8 format) - 要顯示的值（Q8.8格式）
    input  wire [1:0]  decimal_pt,  // Decimal point position - 小數點位置
    input  wire        blink,       // Blink enable - 閃爍使能
    
    // Display outputs - 顯示輸出
    output reg  [6:0]  seven_seg,   // 7-segment display (a-g) - 七段顯示器（a-g）
    output reg  [3:0]  digit_sel    // Digit select (active low) - 位選（低電平有效）
);

    //==========================================================================
    // Parameters - 參數定義
    //==========================================================================
    
    // 7-segment patterns for digits 0-9 and special characters
    // 七段顯示器編碼表
    // Segment order: gfedcba - 段順序：gfedcba
    parameter SEG_0     = 7'b0111111;  // 0 - 顯示數字0
    parameter SEG_1     = 7'b0000110;  // 1 - 顯示數字1
    parameter SEG_2     = 7'b1011011;  // 2 - 顯示數字2
    parameter SEG_3     = 7'b1001111;  // 3 - 顯示數字3
    parameter SEG_4     = 7'b1100110;  // 4 - 顯示數字4
    parameter SEG_5     = 7'b1101101;  // 5 - 顯示數字5
    parameter SEG_6     = 7'b1111101;  // 6 - 顯示數字6
    parameter SEG_7     = 7'b0000111;  // 7 - 顯示數字7
    parameter SEG_8     = 7'b1111111;  // 8 - 顯示數字8
    parameter SEG_9     = 7'b1101111;  // 9 - 顯示數字9
    parameter SEG_MINUS = 7'b1000000;  // - - 顯示負號
    parameter SEG_E     = 7'b1111001;  // E - 顯示錯誤
    parameter SEG_BLANK = 7'b0000000;  // Blank - 熄滅
    parameter SEG_DP    = 7'b1000000;  // Decimal point - 小數點 (actually just segment g)
    
    //==========================================================================
    // Internal signals - 內部信號
    //==========================================================================
    
    reg [1:0]  digit_counter;       // Current digit being displayed - 當前顯示的位
    reg [3:0]  digit_value [0:3];   // BCD values for each digit - 每位的BCD值
    reg        digit_negative;      // Negative sign flag - 負數標誌
    reg [15:0] abs_value;           // Absolute value - 絕對值
    reg [6:0]  blink_counter;       // Blink timing counter - 閃爍計時器
    reg        blink_state;         // Current blink state - 當前閃爍狀態
    
    // BCD conversion signals - BCD轉換信號
    reg [19:0] bcd_result;          // BCD conversion result - BCD轉換結果
    reg [15:0] binary_in;           // Binary input for conversion - 待轉換的二進制輸入
    reg [3:0]  bcd_shift_counter;   // Shift counter for BCD - BCD移位計數器
    
    //==========================================================================
    // Digit multiplexing - 位多工掃描
    // 功能說明：
    // 1. 100Hz時鐘下，每10ms切換一位
    // 2. 4位循環掃描，每位刷新率25Hz
    // 3. 避免人眼察覺閃爍（>24Hz）
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            digit_counter <= 2'd0;
        end else if (clk_100hz) begin
            digit_counter <= digit_counter + 1'b1;  // 循環計數0-3
        end
    end
    
    //==========================================================================
    // Blink control - 閃爍控制
    // 功能說明：
    // 1. 閃爍週期：1秒（0.5秒亮，0.5秒滅）
    // 2. 用於提示用戶當前處於設定模式
    // 3. 100Hz時鐘下計數到49切換狀態
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            blink_counter <= 7'd0;
            blink_state   <= 1'b1;  // 初始為顯示狀態
        end else if (clk_100hz) begin
            if (blink_counter == 7'd49) begin  // Toggle every 0.5 seconds
                blink_counter <= 7'd0;
                blink_state   <= ~blink_state;  // 切換顯示/熄滅
            end else begin
                blink_counter <= blink_counter + 1'b1;
            end
        end
    end
    
    //==========================================================================
    // Value processing - 數值處理
    // 功能說明：
    // 1. 檢查輸入值的符號
    // 2. 負數取絕對值（二補數轉換）
    // 3. 保存符號標誌用於顯示
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            digit_negative <= 1'b0;
            abs_value      <= 16'd0;
        end else begin
            // Check if value is negative - 檢查是否為負數
            if (value[15]) begin
                digit_negative <= 1'b1;
                abs_value      <= -value;  // Two's complement - 二補數轉換
            end else begin
                digit_negative <= 1'b0;
                abs_value      <= value;
            end
        end
    end
    
    //==========================================================================
    // Binary to BCD conversion (Double Dabble algorithm)
    // 二進制轉BCD（Double Dabble演算法）
    // 
    // 為什麼需要BCD轉換：
    // 1. 七段顯示器顯示十進制數字
    // 2. 需要將二進制值轉換為各個十進制位
    // 3. Double Dabble是硬體友好的轉換算法
    //
    // 演算法步驟：
    // 1. 初始化：BCD=0，二進制數在右側
    // 2. 檢查每個BCD位，如果>=5則加3
    // 3. 左移整個數（BCD和二進制部分）
    // 4. 重複步驟2-3，共16次（16位輸入）
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bcd_result       <= 20'd0;
            binary_in        <= 16'd0;
            bcd_shift_counter <= 4'd0;
        end else begin
            if (bcd_shift_counter == 4'd0) begin
                // Start new conversion - 開始新的轉換
                binary_in        <= abs_value;
                bcd_result       <= 20'd0;
                bcd_shift_counter <= 4'd15;  // 需要15次移位
            end else begin
                // Shift and adjust - 移位和調整
                bcd_shift_counter <= bcd_shift_counter - 1'b1;
                
                // Adjust BCD digits if >= 5 - 如果BCD位>=5則加3
                // 這是Double Dabble算法的核心
                if (bcd_result[3:0] >= 4'd5)
                    bcd_result[3:0] <= bcd_result[3:0] + 4'd3;
                if (bcd_result[7:4] >= 4'd5)
                    bcd_result[7:4] <= bcd_result[7:4] + 4'd3;
                if (bcd_result[11:8] >= 4'd5)
                    bcd_result[11:8] <= bcd_result[11:8] + 4'd3;
                if (bcd_result[15:12] >= 4'd5)
                    bcd_result[15:12] <= bcd_result[15:12] + 4'd3;
                
                // Shift left - 左移一位
                {bcd_result, binary_in} <= {bcd_result[18:0], binary_in, 1'b0};
            end
        end
    end
    
    //==========================================================================
    // Extract digits based on Q8.8 format
    // 基於Q8.8格式提取數位
    // 
    // Q8.8格式說明：
    // - 高8位：整數部分（-128到+127）
    // - 低8位：小數部分（0到0.996）
    // 
    // 顯示格式：XX.X°C
    // - digit_value[3]：十位
    // - digit_value[2]：個位
    // - digit_value[1]：十分位（小數點後一位）
    // - digit_value[0]：未使用
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            digit_value[0] <= 4'd0;
            digit_value[1] <= 4'd0;
            digit_value[2] <= 4'd0;
            digit_value[3] <= 4'd0;
        end else begin
            // For temperature display in XX.X format
            // 溫度顯示格式XX.X
            
            // Extract integer part (tens and ones)
            // 提取整數部分（十位和個位）
            digit_value[3] <= (abs_value[15:8] / 10) % 10;  // Tens - 十位
            digit_value[2] <= abs_value[15:8] % 10;         // Ones - 個位
            
            // Extract fractional part (tenths)
            // 提取小數部分（十分位）
            // Convert Q0.8 to decimal: multiply by 10 and shift
            // Q0.8轉十進制：乘以10再右移8位
            // 例：0.5 = 0x80 → 0x80*10=0x500 → 0x500>>8=5
            digit_value[1] <= (abs_value[7:0] * 10) >> 8;   // Tenths - 十分位
            digit_value[0] <= 4'd0;                          // Not used - 未使用
        end
    end
    
    //==========================================================================
    // 7-segment decoder and output multiplexing
    // 七段解碼器和輸出多工
    // 
    // 功能說明：
    // 1. 根據當前掃描位選擇要顯示的數字
    // 2. 將BCD碼轉換為七段顯示碼
    // 3. 處理負號、小數點和空白顯示
    // 4. 實現閃爍功能
    //==========================================================================
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seven_seg <= 7'b0000000;
            digit_sel <= 4'b1111;  // 所有位都不選中（高電平）
        end else begin
            // Default all digits off - 默認所有位關閉
            digit_sel <= 4'b1111;
            
            // Handle blinking - 處理閃爍
            if (blink && !blink_state) begin
                seven_seg <= SEG_BLANK;  // 閃爍時熄滅
            end else begin
                case (digit_counter)
                    2'd0: begin  // Rightmost digit (tenths) - 最右位（十分位）
                        digit_sel <= 4'b1110;  // 選中第0位（低電平有效）
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
                    
                    2'd1: begin  // Ones digit with decimal point - 個位（帶小數點）
                        digit_sel <= 4'b1101;  // 選中第1位
                        case (digit_value[2])
                            4'd0: seven_seg <= SEG_0 | SEG_DP;  // 顯示0和小數點
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
                    
                    2'd2: begin  // Tens digit or minus sign - 十位或負號
                        digit_sel <= 4'b1011;  // 選中第2位
                        if (digit_negative && digit_value[3] == 4'd0) begin
                            // 負數且十位為0時顯示負號
                            seven_seg <= SEG_MINUS;
                        end else if (digit_value[3] != 4'd0) begin
                            // 十位不為0時顯示數字
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
                            seven_seg <= SEG_BLANK;  // 十位為0且非負數時熄滅
                        end
                    end
                    
                    2'd3: begin  // Leftmost digit (minus sign if needed) - 最左位（需要時顯示負號）
                        digit_sel <= 4'b0111;  // 選中第3位
                        if (digit_negative && digit_value[3] != 4'd0) begin
                            // 負數且十位不為0時，在最左位顯示負號
                            seven_seg <= SEG_MINUS;
                        end else begin
                            seven_seg <= SEG_BLANK;  // 否則熄滅
                        end
                    end
                endcase
            end
        end
    end
    
    //==========================================================================
    // 設計考量說明：
    //
    // 1. 為什麼使用多工掃描：
    //    - 減少I/O引腳數量（4位只需11個引腳而非28個）
    //    - 降低功耗（同時只有一位點亮）
    //    - 簡化PCB佈線
    //
    // 2. 掃描頻率選擇（100Hz）：
    //    - 每位刷新率25Hz，高於人眼閃爍感知頻率
    //    - 避免過高頻率造成EMI問題
    //    - 與系統其他時序配合良好
    //
    // 3. Double Dabble算法優勢：
    //    - 純組合邏輯實現，無需除法器
    //    - 固定延遲，時序可預測
    //    - 硬體資源消耗少
    //
    // 4. 顯示格式設計：
    //    - XX.X格式適合溫度顯示（-20.0到+10.0°C）
    //    - 自動處理前導零和負號位置
    //    - 小數點固定在第二位，簡化邏輯
    //==========================================================================
    
endmodule
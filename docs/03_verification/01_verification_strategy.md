# 驗證策略與測試覆蓋率文件

> 💡 **初學者提示**：如果您是第一次進行 IC 驗證，建議先閱讀 [GTKWave 與 Testbench 使用指南](02_gtkwave_testbench_guide.md) 了解基本概念和工具使用。

## 目錄

1. [驗證總覽](#1-驗證總覽)
2. [驗證計畫](#2-驗證計畫)
3. [單元測試策略](#3-單元測試策略)
4. [整合測試場景](#4-整合測試場景)
5. [覆蓋率目標與方法](#5-覆蓋率目標與方法)
6. [形式驗證](#6-形式驗證)
7. [回歸測試策略](#7-回歸測試策略)
8. [性能驗證](#8-性能驗證)
9. [驗證環境架構](#9-驗證環境架構)
10. [結果分析與報告](#10-結果分析與報告)

## 1. 驗證總覽

### 1.1 驗證目標

```
主要目標：
1. 功能正確性：100% 規格符合
2. 代碼覆蓋率：> 95%
3. 功能覆蓋率：> 98%
4. 斷言覆蓋率：100%
5. 零關鍵錯誤 (Critical Bugs)
```

### 1.2 驗證層次

```
┌─────────────────────────────────────┐
│         System Level Tests          │
├─────────────────────────────────────┤
│      Integration Tests              │
├─────────────────────────────────────┤
│        Module Tests                 │
├─────────────────────────────────────┤
│         Unit Tests                  │
└─────────────────────────────────────┘
```

### 1.3 驗證方法論

- **模擬驗證**：功能與時序驗證
- **形式驗證**：屬性檢查與等價性驗證
- **硬體仿真**：FPGA 原型驗證
- **靜態分析**：Lint 與 CDC 檢查

## 2. 驗證計畫

### 2.1 驗證矩陣

| 功能項目 | 單元測試 | 整合測試 | 系統測試 | 形式驗證 | 優先級 |
|---------|---------|---------|---------|---------|--------|
| ADC 介面 | ✓ | ✓ | ✓ | ✓ | 高 |
| PID 控制 | ✓ | ✓ | ✓ | ✓ | 高 |
| PWM 產生 | ✓ | ✓ | ✓ | - | 高 |
| 狀態機 | ✓ | ✓ | ✓ | ✓ | 高 |
| 顯示控制 | ✓ | ✓ | ✓ | - | 中 |
| 計時器 | ✓ | ✓ | ✓ | - | 中 |
| 使用者介面 | ✓ | ✓ | ✓ | - | 中 |
| 錯誤處理 | ✓ | ✓ | ✓ | ✓ | 高 |

### 2.2 測試進度追蹤

```python
# 測試進度定義
test_phases = {
    "Phase 1": {
        "duration": "2 weeks",
        "focus": "Unit tests for all modules",
        "target_coverage": "80%"
    },
    "Phase 2": {
        "duration": "2 weeks", 
        "focus": "Integration tests",
        "target_coverage": "90%"
    },
    "Phase 3": {
        "duration": "1 week",
        "focus": "System tests & corner cases",
        "target_coverage": "95%"
    },
    "Phase 4": {
        "duration": "1 week",
        "focus": "Regression & sign-off",
        "target_coverage": ">95%"
    }
}
```

## 3. 單元測試策略

### 3.1 ADC SPI 介面測試

```verilog
// ADC SPI 介面測試平台
module adc_spi_tb;
    // 時脈產生
    reg clk = 0;
    always #50 clk = ~clk;  // 10MHz
    
    // DUT 實例化
    reg rst_n;
    reg start_conversion;
    reg [2:0] channel_select;
    wire conversion_done;
    wire [11:0] adc_data;
    wire mosi, sclk, cs_n;
    reg miso;
    
    adc_spi_interface DUT (.*);
    
    // ADC 模型
    reg [11:0] adc_model_data;
    always @(negedge sclk) begin
        if (!cs_n) begin
            // 模擬 ADC 響應
            miso <= adc_model_data[11];
            adc_model_data <= {adc_model_data[10:0], 1'b0};
        end
    end
    
    // 測試案例
    initial begin
        // 測試 1: 基本轉換
        test_basic_conversion();
        
        // 測試 2: 所有通道掃描
        test_channel_scan();
        
        // 測試 3: 連續轉換
        test_continuous_conversion();
        
        // 測試 4: 錯誤注入
        test_error_injection();
        
        // 測試 5: 時序邊界
        test_timing_boundaries();
        
        $finish;
    end
    
    // 測試任務定義
    task test_basic_conversion;
        begin
            $display("Test: Basic Conversion");
            adc_model_data = 12'h555;  // 測試數據
            
            @(posedge clk);
            start_conversion = 1'b1;
            channel_select = 3'b000;
            
            @(posedge clk);
            start_conversion = 1'b0;
            
            // 等待轉換完成
            @(posedge conversion_done);
            
            // 檢查結果
            if (adc_data == 12'h555)
                $display("PASS: Data match");
            else
                $display("FAIL: Expected %h, got %h", 12'h555, adc_data);
        end
    endtask
    
    // 覆蓋率收集
    covergroup adc_coverage @(posedge clk);
        channel_cp: coverpoint channel_select {
            bins channels[] = {[0:7]};
        }
        
        data_cp: coverpoint adc_data {
            bins zero = {0};
            bins low = {[1:1023]};
            bins mid = {[1024:3071]};
            bins high = {[3072:4094]};
            bins max = {4095};
        }
        
        cross_cp: cross channel_cp, data_cp;
    endgroup
    
    adc_coverage adc_cov = new();
endmodule
```

### 3.2 PID 控制器測試

```verilog
module pid_controller_tb;
    // 測試環境設置
    real temperature_actual = 5.0;
    real temperature_setpoint = 2.0;
    real kp_real = 2.0;
    real ki_real = 0.1;
    real kd_real = 0.05;
    
    // 轉換函數
    function [15:0] real_to_q8_8(input real value);
        real_to_q8_8 = $rtoi(value * 256);
    endfunction
    
    function real q8_8_to_real(input [15:0] value);
        q8_8_to_real = $itor($signed(value)) / 256.0;
    endfunction
    
    // DUT 連接
    reg clk = 0;
    reg rst_n;
    reg enable;
    reg signed [15:0] setpoint, feedback;
    reg signed [15:0] kp, ki, kd;
    wire signed [15:0] pid_output;
    
    pid_controller DUT (.*);
    
    // 時脈產生
    always #50 clk = ~clk;
    
    // 測試場景
    initial begin
        // 初始化
        rst_n = 0;
        enable = 0;
        setpoint = real_to_q8_8(temperature_setpoint);
        feedback = real_to_q8_8(temperature_actual);
        kp = real_to_q8_8(kp_real);
        ki = real_to_q8_8(ki_real);
        kd = real_to_q8_8(kd_real);
        
        #200 rst_n = 1;
        #100 enable = 1;
        
        // 測試 1: 階躍響應
        test_step_response();
        
        // 測試 2: 穩態誤差
        test_steady_state_error();
        
        // 測試 3: 抗積分飽和
        test_anti_windup();
        
        // 測試 4: 參數變化
        test_parameter_change();
        
        // 測試 5: 邊界條件
        test_boundary_conditions();
    end
    
    // 階躍響應測試
    task test_step_response;
        integer i;
        real output_real;
        real error_prev = 0;
        real settling_time;
        begin
            $display("\n=== Step Response Test ===");
            
            // 記錄響應
            for (i = 0; i < 1000; i = i + 1) begin
                @(posedge clk);
                output_real = q8_8_to_real(pid_output);
                
                // 模擬系統響應
                temperature_actual = temperature_actual + output_real * 0.01;
                feedback = real_to_q8_8(temperature_actual);
                
                if (i % 10 == 0) begin
                    $display("Time: %d, Temp: %.2f, Output: %.2f", 
                             i, temperature_actual, output_real);
                end
                
                // 檢查收斂
                if ($abs(temperature_actual - temperature_setpoint) < 0.1) begin
                    settling_time = i * 0.1;  // 假設 100ns per cycle
                    $display("Settling time: %.1f seconds", settling_time);
                    break;
                end
            end
        end
    endtask
    
    // 覆蓋率定義
    covergroup pid_coverage @(posedge clk);
        // 誤差覆蓋
        error_cp: coverpoint (setpoint - feedback) {
            bins neg_large = {[$:-1000]};
            bins neg_small = {[-999:-1]};
            bins zero = {0};
            bins pos_small = {[1:999]};
            bins pos_large = {[1000:$]};
        }
        
        // 輸出覆蓋
        output_cp: coverpoint pid_output {
            bins neg_sat = {16'h8000};
            bins neg_normal = {[16'h8001:16'hFF00]};
            bins zero_region = {[16'hFF01:16'h00FF]};
            bins pos_normal = {[16'h0100:16'h7FFE]};
            bins pos_sat = {16'h7FFF};
        }
        
        // 參數覆蓋
        kp_cp: coverpoint kp {
            bins low = {[0:255]};      // 0-1.0
            bins medium = {[256:767]};  // 1.0-3.0
            bins high = {[768:$]};      // >3.0
        }
    endgroup
    
    pid_coverage pid_cov = new();
endmodule
```

### 3.3 PWM 產生器測試

```verilog
module pwm_generator_tb;
    // 測試參數
    parameter CLK_FREQ = 10_000_000;
    parameter PWM_FREQ = 1_000;
    parameter PWM_PERIOD = CLK_FREQ / PWM_FREQ;
    
    // DUT 介面
    reg clk = 0;
    reg rst_n;
    reg enable;
    reg [9:0] duty_cycle;
    reg soft_start_en;
    wire pwm_out;
    
    pwm_generator DUT (.*);
    
    // 時脈
    always #50 clk = ~clk;
    
    // PWM 測量
    integer high_time, low_time, period;
    real measured_duty;
    
    task measure_pwm;
        begin
            // 等待上升邊緣
            @(posedge pwm_out);
            high_time = 0;
            
            // 測量高電平時間
            while (pwm_out) begin
                @(posedge clk);
                high_time = high_time + 1;
            end
            
            // 測量低電平時間
            low_time = 0;
            while (!pwm_out && low_time < PWM_PERIOD) begin
                @(posedge clk);
                low_time = low_time + 1;
            end
            
            period = high_time + low_time;
            measured_duty = (real'(high_time) / real'(period)) * 100.0;
            
            $display("Duty cycle: Set=%d/1024 (%.1f%%), Measured=%.1f%%", 
                     duty_cycle, (real'(duty_cycle)/1024.0)*100.0, measured_duty);
        end
    endtask
    
    // 測試案例
    initial begin
        // 初始化
        rst_n = 0;
        enable = 0;
        duty_cycle = 0;
        soft_start_en = 0;
        
        #200 rst_n = 1;
        
        // 測試 1: 各種佔空比
        test_duty_cycles();
        
        // 測試 2: 軟啟動
        test_soft_start();
        
        // 測試 3: 動態變化
        test_dynamic_change();
        
        // 測試 4: 邊界條件
        test_boundaries();
        
        $finish;
    end
    
    // 佔空比測試
    task test_duty_cycles;
        integer i;
        begin
            $display("\n=== Duty Cycle Test ===");
            enable = 1;
            
            for (i = 0; i <= 1024; i = i + 128) begin
                duty_cycle = i[9:0];
                repeat(3) measure_pwm();  // 測量3個週期
            end
        end
    endtask
    
    // 斷言檢查
    // 檢查 PWM 頻率
    property pwm_frequency_check;
        @(posedge clk) disable iff (!rst_n || !enable)
        $rose(pwm_out) |-> ##[PWM_PERIOD-10:PWM_PERIOD+10] $rose(pwm_out);
    endproperty
    assert property (pwm_frequency_check) else
        $error("PWM frequency violation");
    
    // 檢查佔空比範圍
    property duty_cycle_range;
        @(posedge clk) disable iff (!rst_n)
        duty_cycle <= 1024;
    endproperty
    assert property (duty_cycle_range);
endmodule
```

## 4. 整合測試場景

### 4.1 溫度控制迴路測試

```verilog
module temp_control_integration_tb;
    // 系統參數
    parameter real AMBIENT_TEMP = 25.0;
    parameter real COOLING_RATE = 0.5;  // °C/秒 at 100% PWM
    parameter real HEAT_LEAK_RATE = 0.1;  // °C/秒
    
    // 系統模型
    real fridge_temp = 10.0;
    real compressor_power = 0.0;
    
    // DUT 介面
    reg clk = 0;
    reg rst_n;
    // ... 其他信號
    
    temp_ctrl_top DUT (.*);
    
    // 溫度模型
    always @(posedge clk) begin
        if (rst_n) begin
            // 計算溫度變化
            real cooling_effect = compressor_power * COOLING_RATE * 0.0001;
            real heating_effect = (AMBIENT_TEMP - fridge_temp) * HEAT_LEAK_RATE * 0.0001;
            
            fridge_temp = fridge_temp - cooling_effect + heating_effect;
            
            // 更新 ADC 模擬值
            update_adc_value(fridge_temp);
        end
    end
    
    // 測試場景
    initial begin
        // 場景 1: 冷卻到設定溫度
        test_cooling_to_setpoint();
        
        // 場景 2: 門開啟干擾
        test_door_disturbance();
        
        // 場景 3: 除霜週期
        test_defrost_cycle();
        
        // 場景 4: 電源故障恢復
        test_power_failure_recovery();
        
        // 場景 5: 極端溫度
        test_extreme_temperatures();
    end
    
    // 冷卻測試
    task test_cooling_to_setpoint;
        begin
            $display("\n=== Cooling to Setpoint Test ===");
            
            // 設定目標溫度
            set_temperature(2.0);
            
            // 監控冷卻過程
            fork
                begin
                    while (fridge_temp > 2.5) begin
                        @(posedge clk);
                        if ($time % 1_000_000 == 0) begin  // 每秒報告
                            $display("Time: %0t, Temp: %.1f°C, PWM: %d%%", 
                                     $time, fridge_temp, compressor_power);
                        end
                    end
                    $display("Target temperature reached!");
                end
                
                begin
                    // 超時檢查
                    #(300_000_000);  // 300秒超時
                    $display("ERROR: Cooling timeout!");
                    $finish;
                end
            join_any
            disable fork;
        end
    endtask
endmodule
```

### 4.2 系統狀態轉換測試

```verilog
module system_state_test;
    // 狀態轉換覆蓋
    typedef enum {
        IDLE, NORMAL, DEFROST, DOOR_OPEN, ALARM
    } state_t;
    
    // 轉換矩陣
    bit [4:0][4:0] transition_matrix;
    
    // 記錄狀態轉換
    always @(posedge clk) begin
        if (state != state_prev) begin
            transition_matrix[state_prev][state] = 1'b1;
            $display("State transition: %s -> %s", 
                     state_prev.name(), state.name());
        end
    end
    
    // 檢查所有合法轉換
    task check_all_transitions;
        begin
            // 定義合法轉換
            bit [4:0][4:0] legal_transitions = '{
                '{0,1,0,0,0},  // IDLE -> NORMAL
                '{0,0,1,1,1},  // NORMAL -> DEFROST/DOOR/ALARM
                '{0,1,0,0,0},  // DEFROST -> NORMAL
                '{0,1,0,0,1},  // DOOR -> NORMAL/ALARM
                '{1,1,0,0,0}   // ALARM -> IDLE/NORMAL
            };
            
            // 檢查覆蓋
            for (int i = 0; i < 5; i++) begin
                for (int j = 0; j < 5; j++) begin
                    if (legal_transitions[i][j] && !transition_matrix[i][j]) begin
                        $display("Missing transition: %s -> %s", 
                                state_t'(i).name(), state_t'(j).name());
                    end
                end
            end
        end
    endtask
endmodule
```

## 5. 覆蓋率目標與方法

### 5.1 代碼覆蓋率

```systemverilog
// 覆蓋率目標
class coverage_goals;
    // 行覆蓋率
    real line_coverage_target = 95.0;
    real line_coverage_achieved;
    
    // 分支覆蓋率
    real branch_coverage_target = 90.0;
    real branch_coverage_achieved;
    
    // 條件覆蓋率
    real condition_coverage_target = 85.0;
    real condition_coverage_achieved;
    
    // FSM 覆蓋率
    real fsm_coverage_target = 100.0;
    real fsm_coverage_achieved;
    
    // 檢查是否達標
    function bit check_goals();
        return (line_coverage_achieved >= line_coverage_target) &&
               (branch_coverage_achieved >= branch_coverage_target) &&
               (condition_coverage_achieved >= condition_coverage_target) &&
               (fsm_coverage_achieved >= fsm_coverage_target);
    endfunction
endclass
```

### 5.2 功能覆蓋率定義

```systemverilog
// 系統級功能覆蓋
covergroup system_functional_coverage @(posedge clk);
    // 溫度範圍覆蓋
    temperature_cp: coverpoint current_temperature {
        bins extreme_cold = {[$:-20]};
        bins cold = {[-19:-10]};
        bins normal = {[-9:5]};
        bins warm = {[6:10]};
        bins extreme_warm = {[11:$]};
    }
    
    // 設定點覆蓋
    setpoint_cp: coverpoint temperature_setpoint {
        bins low = {[-20:-15]};
        bins medium = {[-14:-5]};
        bins high = {[-4:10]};
    }
    
    // 錯誤狀態覆蓋
    error_cp: coverpoint error_code {
        bins no_error = {0};
        bins sensor_fault = {1};
        bins over_temp = {2};
        bins under_temp = {3};
        bins door_alarm = {4};
        bins compressor_fault = {5};
    }
    
    // 交叉覆蓋
    temp_x_state: cross temperature_cp, current_state;
    error_x_state: cross error_cp, current_state;
endgroup
```

### 5.3 覆蓋率收集策略

```verilog
// 覆蓋率收集器
module coverage_collector;
    // 實例化所有覆蓋組
    system_functional_coverage sys_cov = new();
    
    // 覆蓋率報告
    final begin
        $display("\n=== Coverage Report ===");
        $display("System Coverage: %.2f%%", sys_cov.get_coverage());
        
        // 詳細報告
        foreach (sys_cov.temperature_cp.bins[i]) begin
            $display("Temperature bin %s: %d hits", 
                     i.name(), i.count());
        end
    end
    
    // 覆蓋率斷言
    property coverage_target_met;
        @(posedge clk)
        $coverage() >= 95.0;
    endproperty
    
    final begin
        assert property (coverage_target_met) else
            $error("Coverage target not met: %.2f%%", $coverage());
    end
endmodule
```

## 6. 形式驗證

### 6.1 屬性定義

```systemverilog
// 安全屬性
module safety_properties;
    // 屬性 1: 溫度永不超過安全範圍
    property temperature_safety;
        @(posedge clk) disable iff (!rst_n)
        (current_temperature > -25) && (current_temperature < 15);
    endproperty
    assert property (temperature_safety) else
        $error("Temperature out of safe range!");
    
    // 屬性 2: 壓縮機最小開/關時間
    property compressor_min_time;
        @(posedge clk) disable iff (!rst_n)
        $rose(compressor_pwm) |-> 
            compressor_pwm[*180_000_000];  // 3分鐘 = 180秒
    endproperty
    assert property (compressor_min_time);
    
    // 屬性 3: 狀態機無死鎖
    property no_deadlock;
        @(posedge clk) disable iff (!rst_n)
        (state == IDLE) |-> ##[1:1000] (state != IDLE);
    endproperty
    assert property (no_deadlock);
endmodule
```

### 6.2 等價性檢查

```tcl
# Formality script for equivalence checking
set_app_var synopsys_auto_setup true

# Read golden RTL
read_verilog -golden rtl/temp_ctrl_top.v
read_verilog -golden rtl/pid_controller.v
# ... other modules

# Read revised netlist
read_verilog -revised synthesis/temp_ctrl_top_synth.v

# Match compare points
match

# Verify
verify

# Report results
report_failing_points
report_passing_points
report_unmatched_points
```

### 6.3 模型檢查

```
// Symbolic model checking properties
MODULE main
    VAR
        state : {IDLE, NORMAL, DEFROST, DOOR_OPEN, ALARM};
        temperature : -20..15;
        door_open : boolean;
        
    ASSIGN
        init(state) := IDLE;
        
        next(state) := case
            state = IDLE & init_done : NORMAL;
            state = NORMAL & door_open : DOOR_OPEN;
            state = NORMAL & defrost_time : DEFROST;
            state = DOOR_OPEN & !door_open : NORMAL;
            TRUE : state;
        esac;
        
    -- 活性屬性：系統最終會達到正常狀態
    LTLSPEC G (state = IDLE -> F (state = NORMAL))
    
    -- 安全屬性：不會同時除霜和製冷
    LTLSPEC G !(defrost_heater & compressor_on)
```

## 7. 回歸測試策略

### 7.1 測試套件組織

```makefile
# Makefile for regression tests
TESTS = unit_tests integration_tests system_tests corner_tests

.PHONY: all $(TESTS)

all: $(TESTS)
	@echo "All tests completed"
	@$(MAKE) coverage_report

unit_tests:
	@echo "Running unit tests..."
	vsim -c -do "run_unit_tests.do"

integration_tests: unit_tests
	@echo "Running integration tests..."
	vsim -c -do "run_integration_tests.do"

system_tests: integration_tests
	@echo "Running system tests..."
	vsim -c -do "run_system_tests.do"

corner_tests:
	@echo "Running corner case tests..."
	vsim -c -do "run_corner_tests.do"

coverage_report:
	@echo "Generating coverage report..."
	vcover merge coverage.ucdb unit_cov.ucdb int_cov.ucdb sys_cov.ucdb
	vcover report -html coverage.ucdb
```

### 7.2 持續整合設置

```yaml
# .gitlab-ci.yml
stages:
  - lint
  - compile
  - test
  - coverage
  - report

lint_check:
  stage: lint
  script:
    - verilator --lint-only rtl/*.v
    - slang --lint-only rtl/*.sv

compile_rtl:
  stage: compile
  script:
    - vlog -work work rtl/*.v
    - vlog -work work testbench/*.sv

run_regression:
  stage: test
  script:
    - make -f regression.mk all
  artifacts:
    paths:
      - logs/
      - coverage/

coverage_analysis:
  stage: coverage
  script:
    - vcover merge total.ucdb coverage/*.ucdb
    - vcover report -html total.ucdb
  coverage: '/Total Coverage: (\d+\.\d+)%/'
```

### 7.3 測試選擇策略

```python
# 智能測試選擇腳本
import json
import subprocess

class SmartTestSelector:
    def __init__(self, change_list):
        self.changes = change_list
        self.test_map = self.load_test_mapping()
    
    def load_test_mapping(self):
        with open('test_mapping.json', 'r') as f:
            return json.load(f)
    
    def select_tests(self):
        selected_tests = set()
        
        for file in self.changes:
            module = self.extract_module(file)
            if module in self.test_map:
                selected_tests.update(self.test_map[module])
        
        # 總是運行關鍵測試
        selected_tests.update(self.test_map['critical'])
        
        return list(selected_tests)
    
    def run_selected_tests(self, tests):
        for test in tests:
            print(f"Running {test}...")
            result = subprocess.run(['make', f'run_{test}'])
            if result.returncode != 0:
                print(f"Test {test} failed!")
                return False
        return True
```

## 8. 性能驗證

### 8.1 時序性能測試

```verilog
module timing_performance_tb;
    // 測量關鍵路徑延遲
    time start_time, end_time;
    real path_delay;
    
    // 測試不同頻率
    task test_frequency_sweep;
        real test_freq;
        integer errors;
        begin
            for (test_freq = 1e6; test_freq <= 20e6; test_freq += 1e6) begin
                errors = 0;
                set_clock_frequency(test_freq);
                
                // 運行測試向量
                repeat(1000) begin
                    apply_random_vectors();
                    if (check_outputs() == 0) errors++;
                end
                
                $display("Frequency: %.1f MHz, Errors: %d", 
                         test_freq/1e6, errors);
                
                if (errors > 0) begin
                    $display("Maximum frequency: %.1f MHz", 
                             (test_freq-1e6)/1e6);
                    break;
                end
            end
        end
    endtask
endmodule
```

### 8.2 功耗性能測試

```verilog
module power_performance_tb;
    // 功耗監控
    real total_power, dynamic_power, leakage_power;
    
    // 活動因子測量
    integer toggle_count [string];
    
    always @(posedge clk) begin
        // 記錄信號切換
        foreach (DUT.signal[i]) begin
            if (DUT.signal[i] !== DUT.signal_prev[i])
                toggle_count[i]++;
        end
    end
    
    // 功耗分析
    task analyze_power;
        real activity_factor;
        begin
            // 計算活動因子
            activity_factor = real'(toggle_count.sum()) / 
                              (simulation_cycles * signal_count);
            
            // 估算功耗
            dynamic_power = CAPACITANCE * VDD * VDD * 
                           FREQUENCY * activity_factor;
            
            $display("Activity Factor: %.3f", activity_factor);
            $display("Dynamic Power: %.2f mW", dynamic_power * 1000);
        end
    endtask
endmodule
```

## 9. 驗證環境架構

### 9.1 UVM 測試平台架構

```systemverilog
// UVM 基礎測試平台
class temp_ctrl_env extends uvm_env;
    `uvm_component_utils(temp_ctrl_env)
    
    // 組件
    adc_agent       adc_agt;
    button_agent    btn_agt;
    pwm_monitor     pwm_mon;
    display_monitor disp_mon;
    scoreboard      scb;
    coverage        cov;
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        adc_agt = adc_agent::type_id::create("adc_agt", this);
        btn_agt = button_agent::type_id::create("btn_agt", this);
        pwm_mon = pwm_monitor::type_id::create("pwm_mon", this);
        disp_mon = display_monitor::type_id::create("disp_mon", this);
        scb = scoreboard::type_id::create("scb", this);
        cov = coverage::type_id::create("cov", this);
    endfunction
    
    function void connect_phase(uvm_phase phase);
        // 連接 TLM 端口
        adc_agt.monitor.item_collected_port.connect(scb.adc_fifo.analysis_export);
        pwm_mon.item_collected_port.connect(scb.pwm_fifo.analysis_export);
        // ... 其他連接
    endfunction
endclass
```

### 9.2 測試案例結構

```systemverilog
// 基礎測試類
class base_test extends uvm_test;
    `uvm_component_utils(base_test)
    
    temp_ctrl_env env;
    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = temp_ctrl_env::type_id::create("env", this);
    endfunction
    
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        
        // 基本初始化
        reset_dut();
        configure_dut();
        
        // 運行測試序列
        run_test_sequence();
        
        // 等待完成
        #1000ns;
        
        phase.drop_objection(this);
    endtask
    
    virtual task reset_dut();
        // 重置序列
    endtask
    
    virtual task configure_dut();
        // 基本配置
    endtask
    
    virtual task run_test_sequence();
        // 在派生類中覆寫
    endtask
endclass

// 具體測試案例
class normal_operation_test extends base_test;
    `uvm_component_utils(normal_operation_test)
    
    virtual task run_test_sequence();
        normal_sequence seq;
        seq = normal_sequence::type_id::create("seq");
        seq.start(env.adc_agt.sequencer);
    endtask
endclass
```

## 10. 結果分析與報告

### 10.1 自動化結果分析

```python
# 測試結果分析腳本
import re
import pandas as pd
import matplotlib.pyplot as plt

class TestResultAnalyzer:
    def __init__(self, log_dir):
        self.log_dir = log_dir
        self.results = []
    
    def parse_logs(self):
        """解析測試日誌"""
        for log_file in glob.glob(f"{self.log_dir}/*.log"):
            with open(log_file, 'r') as f:
                content = f.read()
                
                # 提取測試結果
                test_name = re.search(r'Test: (\w+)', content).group(1)
                passed = len(re.findall(r'PASS:', content))
                failed = len(re.findall(r'FAIL:', content))
                coverage = float(re.search(r'Coverage: ([\d.]+)%', content).group(1))
                
                self.results.append({
                    'test': test_name,
                    'passed': passed,
                    'failed': failed,
                    'coverage': coverage
                })
    
    def generate_report(self):
        """生成測試報告"""
        df = pd.DataFrame(self.results)
        
        # 計算統計
        total_tests = df['passed'].sum() + df['failed'].sum()
        pass_rate = df['passed'].sum() / total_tests * 100
        avg_coverage = df['coverage'].mean()
        
        # 生成報告
        with open('test_report.html', 'w') as f:
            f.write(f"""
            <html>
            <head><title>Test Report</title></head>
            <body>
                <h1>Verification Report</h1>
                <h2>Summary</h2>
                <ul>
                    <li>Total Tests: {total_tests}</li>
                    <li>Pass Rate: {pass_rate:.1f}%</li>
                    <li>Average Coverage: {avg_coverage:.1f}%</li>
                </ul>
                <h2>Detailed Results</h2>
                {df.to_html()}
            </body>
            </html>
            """)
        
        # 生成圖表
        self.plot_results(df)
    
    def plot_results(self, df):
        """生成結果圖表"""
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))
        
        # 測試結果餅圖
        pass_fail = [df['passed'].sum(), df['failed'].sum()]
        ax1.pie(pass_fail, labels=['Passed', 'Failed'], 
                autopct='%1.1f%%', colors=['green', 'red'])
        ax1.set_title('Test Results')
        
        # 覆蓋率柱狀圖
        ax2.bar(df['test'], df['coverage'])
        ax2.set_xlabel('Test')
        ax2.set_ylabel('Coverage %')
        ax2.set_title('Coverage by Test')
        ax2.axhline(y=95, color='r', linestyle='--', label='Target')
        
        plt.tight_layout()
        plt.savefig('test_results.png')
```

### 10.2 覆蓋率報告模板

```html
<!-- coverage_report_template.html -->
<!DOCTYPE html>
<html>
<head>
    <title>Coverage Report - Temperature Controller IC</title>
    <style>
        .good { background-color: #90EE90; }
        .warning { background-color: #FFD700; }
        .bad { background-color: #FFA07A; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
    </style>
</head>
<body>
    <h1>Coverage Report</h1>
    <h2>Summary</h2>
    <table>
        <tr>
            <th>Metric</th>
            <th>Target</th>
            <th>Achieved</th>
            <th>Status</th>
        </tr>
        <tr>
            <td>Line Coverage</td>
            <td>95%</td>
            <td class="good">96.3%</td>
            <td>✓ PASS</td>
        </tr>
        <tr>
            <td>Branch Coverage</td>
            <td>90%</td>
            <td class="good">92.1%</td>
            <td>✓ PASS</td>
        </tr>
        <tr>
            <td>Functional Coverage</td>
            <td>98%</td>
            <td class="warning">95.7%</td>
            <td>⚠ NEAR</td>
        </tr>
    </table>
    
    <h2>Module Breakdown</h2>
    <!-- 詳細模組覆蓋率 -->
    
    <h2>Uncovered Code</h2>
    <!-- 未覆蓋代碼列表 -->
    
    <h2>Recommendations</h2>
    <ul>
        <li>Add corner case tests for PID overflow conditions</li>
        <li>Increase random testing iterations for FSM transitions</li>
        <li>Add directed tests for error injection scenarios</li>
    </ul>
</body>
</html>
```

### 10.3 錯誤追蹤與管理

```python
# 錯誤追蹤系統
class BugTracker:
    def __init__(self):
        self.bugs = []
        
    def log_bug(self, test_name, description, severity):
        bug = {
            'id': len(self.bugs) + 1,
            'test': test_name,
            'description': description,
            'severity': severity,  # Critical, High, Medium, Low
            'status': 'Open',
            'timestamp': datetime.now()
        }
        self.bugs.append(bug)
        
        # 自動通知
        if severity in ['Critical', 'High']:
            self.send_notification(bug)
    
    def update_status(self, bug_id, new_status):
        for bug in self.bugs:
            if bug['id'] == bug_id:
                bug['status'] = new_status
                bug['updated'] = datetime.now()
                break
    
    def generate_bug_report(self):
        df = pd.DataFrame(self.bugs)
        
        # 按嚴重程度統計
        severity_counts = df.groupby('severity').size()
        
        # 按狀態統計
        status_counts = df.groupby('status').size()
        
        # 生成報告
        report = f"""
        Bug Report Summary
        ==================
        Total Bugs: {len(self.bugs)}
        
        By Severity:
        {severity_counts.to_string()}
        
        By Status:
        {status_counts.to_string()}
        
        Critical/High Priority Open Bugs:
        {df[(df['severity'].isin(['Critical', 'High'])) & 
            (df['status'] == 'Open')].to_string()}
        """
        
        return report
```

## 11. 驗證簽核標準

### 11.1 簽核檢查清單

```
驗證簽核標準：
□ 所有測試案例通過
□ 代碼覆蓋率 > 95%
□ 功能覆蓋率 > 98%
□ 無 Critical/High 優先級錯誤
□ 所有斷言通過
□ 形式驗證完成
□ 回歸測試穩定（連續 5 次）
□ 性能目標達成
□ 文檔完整更新
□ 驗證報告審核通過
```

### 11.2 品質指標

```python
class QualityMetrics:
    def calculate_quality_score(self):
        """計算整體品質分數"""
        weights = {
            'coverage': 0.3,
            'bug_density': 0.2,
            'test_stability': 0.2,
            'performance': 0.2,
            'documentation': 0.1
        }
        
        scores = {
            'coverage': self.get_coverage_score(),
            'bug_density': self.get_bug_density_score(),
            'test_stability': self.get_stability_score(),
            'performance': self.get_performance_score(),
            'documentation': self.get_doc_score()
        }
        
        total_score = sum(scores[k] * weights[k] for k in scores)
        
        return {
            'total_score': total_score,
            'breakdown': scores,
            'recommendation': self.get_recommendation(total_score)
        }
```

---

文件版本：1.0  
最後更新：2024-12-19  
作者：IC 設計團隊  
下一份文件：[物理設計指南與優化技巧](../05_implementation/01_physical_design_guide.md)
# 🧪 Testbench Guide - Easy Understanding

## 📚 What is a Testbench?

A testbench is like a **virtual laboratory** where we test our hardware design:
- **No physical hardware needed**
- **Automated testing**
- **See all internal signals**
- **Repeat tests easily**

## 🎯 Our Two Main Testbenches

### 1. **System Testbench** (`simple_temp_ctrl_tb.v`)
Tests the **complete fridge controller** like a real user would.

```
┌─────────────────────────────────────┐
│         TESTBENCH                   │
│  ┌─────────────────────────────┐   │
│  │   Pretend Temperature: 8°C  │   │ ← We control this
│  └──────────┬──────────────────┘   │
│             │                       │
│  ┌──────────▼──────────────────┐   │
│  │   FRIDGE CONTROLLER (DUT)    │   │ ← Design Under Test
│  └──────────┬──────────────────┘   │
│             │                       │
│  ┌──────────▼──────────────────┐   │
│  │  Compressor: ON/OFF?        │   │ ← We check this
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

### 2. **PID Testbench** (`simple_pid_tb.v`)
Tests just the **PID math** in isolation.

```
Target: 4°C ──┐
              ├──→ [PID Controller] ──→ Control Signal
Current: 8°C ─┘                         (How much cooling?)
```

## 🔧 How Testbenches Work

### Step 1: Create Fake Inputs
```verilog
// Pretend the temperature is 8°C
set_temperature(8.0);

// Pretend someone pressed a button
press_button_up();

// Pretend the door opened
door_open = 1;
```

### Step 2: Wait for Response
```verilog
// Wait 100 microseconds
#100000;

// Or wait 1000 clock cycles
repeat(1000) @(posedge clk);
```

### Step 3: Check Outputs
```verilog
// Is the compressor on?
if (compressor_on)
    $display("PASS: Compressor is cooling");
else
    $display("FAIL: Compressor should be on!");
```

## 📝 Simple Test Flow

```verilog
initial begin
    // 1. Setup
    reset_system();
    
    // 2. Test Hot Temperature
    set_temperature(10.0);    // Hot!
    wait_a_bit();
    check_compressor_on();    // Should cool
    
    // 3. Test Cold Temperature  
    set_temperature(2.0);     // Cold!
    wait_a_bit();
    check_compressor_off();   // Should stop
    
    // 4. Test Safety
    open_door();
    wait_2_minutes();
    check_alarm_on();         // Should alarm!
end
```

## 🎬 Running Tests

### Method 1: Quick Test (Console Only)
```bash
cd testbench
make sim_top              # Run system test
make sim_pid              # Run PID test
```

**You'll see:**
```
[TEMP] Setting temperature to 8.0°C
[STATUS] Compressor=ON, Alarm=OFF
[PASS] Compressor turned ON when hot
```

### Method 2: Visual Debug (With Waveforms)
```bash
make wave_top             # System test + waveforms
make wave_pid             # PID test + waveforms
```

**GTKWave shows:**
- Signal changes over time
- When compressor turns on/off
- State machine transitions

## 🐛 Common Problems & Solutions

### Problem: "Compressor won't turn on"
**Check these signals in GTKWave:**
1. `current_state` - Is it stuck in INIT?
2. `sample_timer` - Is it counting down?
3. `compressor_enable` - Is it blocked?

### Problem: "Test timeout"
**Your test is too long. Either:**
- Reduce wait times
- Increase `SIM_TIME` parameter
- Check for infinite loops

### Problem: "X or Z values"
**Uninitialized signals:**
- Check reset is working
- Make sure all inputs are set
- Look for missing assignments

## 📊 Understanding Waveforms

```
Time →
     0ns   100ns  200ns  300ns  400ns
     │      │      │      │      │
clk  ┘─┐__┌─┘─┐__┌─┘─┐__┌─┘─┐__┌─┘─┐__
         
temp ═════════╗═══════════════════════
     8°C      ║      2°C
              ╚
compressor ───────┐_________________┌───
           OFF    │   ON        OFF │
                  └─────────────────┘
```

## 🎯 Quick Test Commands

```bash
# Just compile (check syntax)
make compile

# Run and see text output
make sim_top

# Run and see waveforms
make wave_top

# Clean up files
make clean
```

## 💡 Tips for Writing Tests

1. **Start Simple**
   - Test one feature at a time
   - Add complexity gradually

2. **Use Meaningful Messages**
   ```verilog
   $display("[TEST] Checking door alarm at %0t", $time);
   ```

3. **Make Tests Automatic**
   ```verilog
   if (result == expected)
       $display("PASS");
   else
       $display("FAIL: Got %d, expected %d", result, expected);
   ```

4. **Test Edge Cases**
   - Maximum temperature
   - Minimum temperature
   - Rapid button presses
   - Power-on reset

## 🔍 What to Look For

### Good Signs ✅
- All tests show "PASS"
- Waveforms show clean transitions
- No X or Z values after reset
- Timing makes sense

### Bad Signs ❌
- Tests show "FAIL" 
- Signals stuck at one value
- X (unknown) or Z (high-impedance)
- Timeout errors

---

Remember: **Testbenches are your friend!** They help you find bugs before building hardware. The more tests you write, the more confident you can be that your design works correctly.
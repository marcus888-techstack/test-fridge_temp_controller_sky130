# GTKWave Debug Guide for Temperature Controller

## Opening GTKWave on macOS

Due to Perl dependency issues with Homebrew's gtkwave, use one of these methods:

```bash
# Method 1: Open with macOS app
open -a gtkwave work/temp_ctrl_top_tb.vcd

# Method 2: Use the wrapper script
../gtkwave_wrapper.sh work/temp_ctrl_top_tb.vcd

# Method 3: Direct app path
/Applications/gtkwave.app/Contents/MacOS/gtkwave work/temp_ctrl_top_tb.vcd
```

## Key Signals to Add for Debugging

### 1. **System Signals**
- `temp_ctrl_top_tb.clk` - System clock
- `temp_ctrl_top_tb.rst_n` - Reset signal
- `temp_ctrl_top_tb.DUT.current_state[2:0]` - State machine

### 2. **Temperature Signals**
- `temp_ctrl_top_tb.DUT.temp_current[15:0]` - Current temperature (Q8.8)
- `temp_ctrl_top_tb.DUT.temp_setpoint[15:0]` - Set point (Q8.8)
- `temp_ctrl_top_tb.adc_value[11:0]` - ADC input value

### 3. **Control Signals**
- `temp_ctrl_top_tb.compressor_pwm` - PWM output
- `temp_ctrl_top_tb.DUT.pwm_duty_cycle[9:0]` - PWM duty cycle
- `temp_ctrl_top_tb.DUT.compressor_enable` - Compressor enable

### 4. **PID Controller**
- `temp_ctrl_top_tb.DUT.u_pid.error[15:0]` - PID error
- `temp_ctrl_top_tb.DUT.u_pid.pid_out[15:0]` - PID output
- `temp_ctrl_top_tb.DUT.u_pid.integral_acc[31:0]` - Integral accumulator

### 5. **User Interface**
- `temp_ctrl_top_tb.door_sensor` - Door sensor
- `temp_ctrl_top_tb.button_up` - Up button
- `temp_ctrl_top_tb.button_down` - Down button

## Adding Signals in GTKWave

1. **SST (Signal Search Tree)** - Left panel
   - Navigate through hierarchy: temp_ctrl_top_tb → DUT → modules
   - Double-click signals to add to wave window

2. **Search for Signals**
   - Ctrl+F (or Cmd+F on Mac) to search
   - Type signal name like "state" or "temp"

3. **Group Related Signals**
   - Select multiple signals
   - Right-click → "Insert Blank" to add separator
   - Right-click → "Insert Comment" to label groups

## Debugging the Test Failures

Based on the simulation output, check these issues:

### 1. **STATE_INIT Timeout**
```
Time: 17650000 | State: INIT
```
- Check `sample_timer` countdown
- Verify state transition condition at line 328-329 of temp_ctrl_top.v

### 2. **Compressor Not Turning ON**
```
ERROR: Compressor should be ON when temp > setpoint
```
- Check `compressor_enable` signal
- Verify `compressor_timer` is reaching 0
- Check PID output values

### 3. **Door State Not Detected**
```
ERROR: Should be in DOOR_OPEN state
```
- Verify `door_sensor_sync` signal
- Check state machine transition at line 334-335

### 4. **Alarm Not Triggering**
```
ERROR: High temperature alarm not triggered
```
- Check temperature comparison at line 338-339
- Verify `TEMP_MAX` parameter value

## Useful GTKWave Features

### Time Navigation
- **Zoom In/Out**: + and - keys
- **Zoom Fit**: Ctrl+0 (Cmd+0 on Mac)
- **Go to Time**: Ctrl+G (Cmd+G on Mac)

### Value Display
- **Binary**: Right-click signal → Data Format → Binary
- **Decimal**: Right-click signal → Data Format → Decimal
- **Hexadecimal**: Right-click signal → Data Format → Hex

### Measurements
- **Measure Time**: Click and drag to measure
- **Add Markers**: Left-click to place marker
- **Named Markers**: B (place named marker)

### Debugging Tips

1. **Find State Transitions**
   - Add `current_state` signal
   - Change format to ASCII or use state names
   - Look for unexpected transitions

2. **Check Timing**
   - Verify clock period is correct (100ns for 10MHz)
   - Check reset duration
   - Verify timer countdowns

3. **Trace Signal Flow**
   - Start from inputs (ADC, buttons)
   - Follow through processing (PID)
   - Check outputs (PWM, display)

## Common Issues and Solutions

### Issue: Signals Show as 'X' or 'Z'
- Check reset sequence
- Verify all inputs are driven
- Look for uninitialized registers

### Issue: No State Changes
- Verify clock is toggling
- Check reset is released
- Verify enable signals

### Issue: Incorrect Values
- Check Q8.8 fixed-point conversions
- Verify ADC scaling calculation
- Check PID gain values

## Saving Your Work

1. **Save Signal List**: File → Write Save File (.gtkw)
2. **Screenshot**: File → Grab to File
3. **Export Data**: File → Write VCD (filtered)
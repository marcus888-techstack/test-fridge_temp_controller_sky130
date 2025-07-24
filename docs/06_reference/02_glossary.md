# 📖 術語表 (Glossary)

本文件整理了冰箱溫度控制器 IC 設計中使用的專業術語。

## A

**ADC (Analog-to-Digital Converter)**  
類比數位轉換器，將連續的類比信號（如電壓）轉換為離散的數位值。

**ASIC (Application-Specific Integrated Circuit)**  
特定應用積體電路，為特定用途設計的客製化晶片。

## C

**CLK (Clock)**  
時脈信號，提供數位電路同步運作的時間基準。

**CTS (Clock Tree Synthesis)**  
時脈樹合成，確保時脈信號能夠同時到達所有暫存器的設計步驟。

## D

**DFF (D Flip-Flop)**  
D 型正反器，基本的儲存元件，用於暫存 1 位元資料。

**DRC (Design Rule Check)**  
設計規則檢查，確保佈局符合製程要求的幾何規則。

## F

**FIFO (First In First Out)**  
先進先出緩衝器，一種資料儲存結構。

**FSM (Finite State Machine)**  
有限狀態機，用於描述系統行為的數學模型。

## G

**GDSII**  
IC 佈局的標準檔案格式，包含所有層次的幾何資訊。

**GND (Ground)**  
接地，電路的參考電位點。

## I

**I2C (Inter-Integrated Circuit)**  
一種串列通訊協定，使用兩條線進行通訊。

## L

**LUT (Look-Up Table)**  
查找表，用於實現組合邏輯功能。

**LVS (Layout vs. Schematic)**  
佈局與電路圖比對，驗證實體佈局與邏輯設計的一致性。

## M

**MISO (Master In Slave Out)**  
SPI 協定中，從設備送資料給主設備的信號線。

**MOSI (Master Out Slave In)**  
SPI 協定中，主設備送資料給從設備的信號線。

## P

**PDK (Process Design Kit)**  
製程設計套件，包含特定製程的所有設計規則和元件庫。

**PID Controller**  
比例-積分-微分控制器，一種常用的回授控制演算法。

**PLL (Phase-Locked Loop)**  
鎖相迴路，用於產生穩定時脈的電路。

**PnR (Place and Route)**  
擺放與繞線，將邏輯閘擺放在晶片上並連接的過程。

**PWM (Pulse Width Modulation)**  
脈寬調變，透過改變脈衝寬度來控制平均功率。

## Q

**Q Format (Fixed-Point)**  
定點數格式，如 Q8.8 表示 8 位整數 + 8 位小數。

## R

**RTL (Register Transfer Level)**  
暫存器傳輸級，描述資料在暫存器間傳輸的抽象層級。

## S

**SCLK (Serial Clock)**  
串列時脈，SPI 通訊中的時脈信號。

**SDK (Software Development Kit)**  
軟體開發套件。

**Setup Time**  
建立時間，資料必須在時脈邊緣前保持穩定的時間。

**SKY130**  
SkyWater 130nm 製程技術節點。

**SoC (System on Chip)**  
系統單晶片，將完整系統整合在單一晶片上。

**SPI (Serial Peripheral Interface)**  
串列周邊介面，一種同步串列通訊協定。

**STA (Static Timing Analysis)**  
靜態時序分析，驗證電路時序的方法。

## T

**Testbench**  
測試平台，用於驗證設計功能的模擬環境。

**Timing Closure**  
時序收斂，滿足所有時序要求的設計狀態。

## V

**VCD (Value Change Dump)**  
數值變化轉儲，記錄信號變化的檔案格式。

**Verilog**  
硬體描述語言，用於描述數位電路。

**VDD**  
電源電壓，正電源供應。

## W

**WNS (Worst Negative Slack)**  
最差負餘裕，時序分析中最嚴重的時序違規。

## 其他

**定點數運算**  
使用固定小數點位置的數值運算方式，適合硬體實現。

**移位暫存器**  
能夠將資料逐位移動的暫存器結構。

**狀態機**  
根據輸入和當前狀態決定下一狀態的邏輯電路。

---

## 相關連結

- [數位設計基礎](../01_getting_started/00_design_introduction_for_beginners.md)
- [SPI 通訊詳解](../04_tutorials/02_understanding_spi.md)

---

[返回參考文件](README.md) | [返回主目錄](../README.md)
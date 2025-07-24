# 🧪 Verification Documentation - 驗證文件

本章節涵蓋完整的驗證策略、測試方法和波形分析技巧。

## 📖 本章節文件

| 文件 | 說明 | 適合對象 |
|------|------|----------|
| [01_verification_strategy.md](01_verification_strategy.md) | 完整驗證計畫與覆蓋率分析 | 驗證工程師 |
| [02_gtkwave_testbench_guide.md](02_gtkwave_testbench_guide.md) | GTKWave 波形分析實戰指南 | 所有人 |

## 🎯 驗證重點

### 驗證策略
- 功能驗證計畫
- 覆蓋率目標設定
- 測試案例設計
- 角落案例處理

### 實用技能
- Icarus Verilog 使用
- GTKWave 波形分析
- Testbench 撰寫技巧
- 自動化測試流程

## 📝 學習路徑

1. **驗證新手**：
   - 先學習 GTKWave 基本操作
   - 運行現有 testbench 觀察結果
   - 嘗試修改測試參數

2. **驗證工程師**：
   - 研究驗證策略文件
   - 設計新的測試案例
   - 提升測試覆蓋率

## 🔧 快速指令

```bash
# 執行 PID 控制器測試
cd testbench
make sim_pid

# 執行系統測試並查看波形
make wave_top

# 執行所有測試
make test_all
```

## 💡 驗證技巧

- 先驗證單元模組，再驗證整合
- 使用 assertions 捕捉異常
- 記錄關鍵信號便於除錯
- 自動化回歸測試

## 🔗 相關資源

- [Testbench 原始碼](../../testbench/) - 測試程式碼
- [設計文件](../02_design/) - 了解待測設計
- [除錯指南](../06_reference/01_troubleshooting.md) - 問題排除

---

[返回主目錄](../README.md)
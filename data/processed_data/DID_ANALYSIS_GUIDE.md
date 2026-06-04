# 原住民族經濟狀況調查 - DID分析準備指南

## 📋 概述

本指南提供原住民族經濟狀況調查（民國91_106年）的跨年度資料整理與DID（差中差法）分析的完整框架。

---

## 🔍 第一步：資料檔案清單

### 核心資料檔案

| 檔案名稱 | 說明 | 用途 |
|---------|------|------|
| **variable_crosswalk.csv** | 全部576個變數的跨年度對應表（修正編碼版） | 了解變數跨年度變化 |
| **core_variables.csv** | 31個核心變數（在4年以上出現） | **推薦用於DID分析** |
| **question_codex_comparison.csv** | 234個問卷題目的詳細重疊對應 | 確認題目一致性 |
| **detailed_year_comparison.csv** | 7個年份間的成對比較（相似度指標） | 評估資料可合併性 |

### 變數分類與架構檔案

| 檔案名稱 | 內容 |
|---------|------|
| **variable_rename_mapping.csv** | 29個核心變數的英文簡潔名稱對應 |
| **did_time_periods.csv** | DID分析的時間區分定義 |
| **observation_level_definition.csv** | 觀測單位層級定義（distinct vs 3-types） |

---

## 🎯 第二步：DID分析框架

### 時間維度
```
Pre-treatment Period (政策實施前)
├── 民國91年第1季 (91_1)
├── 民國91年第2季 (91_2)  
├── 民國95年 (95)
└── 民國99年 (99)

Post-treatment Period (政策實施後)
├── 民國103年 (103)
├── 民國106年 (106, 106)
└── 民國110年 [資料待整理]
```

### 觀測單位層級
- **91_106年**：以鄉鎮市區（county/distinct level）為分析單位
- **110年**：分為三類（3-types）：縣市、城鎮、鄉村

---

## 📊 第三步：變數分類

### 依賴變數（Y - Outcome Variables）
經濟福利與生活消費相關指標：

**收入相關**
- `i3` (income_work)：家人工作收入
- `i4` (income_govt)：政府津貼補助  
- `i1` (others_have_income)：除本人外有固定收入人數

**消費支出**
- `j1` (exp_food)：食品支出
- `j2` (exp_housing)：房屋相關支出
- `j4` (exp_health)：醫療支出
- `j6` (exp_tax_insurance)：稅務保險捐款

**財務狀況**
- `k2` (savings_amount)：個人儲蓄額
- `k1_1` (invest_participation)：投資參與度

### 獨立變數（X - Control Variables）
人口統計、住宅條件與政策認知：

**人口統計**
- `f1` (household_size)：家庭成員數
- `f2` (spouse_indigene)：配偶身分

**住宅條件**
- `g1` (housing_own)：房屋所有權
- `g3` (housing_year)：房屋購建年份
- `g4` (housing_floor_area)：房屋樓地板面積
- `g5` (housing_cost)：房屋購建成本

**其他控制變數**
- `l2` (aware_loan_program)：政策認知度
- `m2` (internet_access)：網際網路使用
- `county` (location_county)：地理位置
- `level` (administrative_level)：行政層級

---

## 🔧 第四步：資料準備清單

在進行DID分析前，建議執行以下步驟：

### 1️⃣ 資料合併
- [ ] 讀取各年份的原始資料檔案
- [ ] 使用 `core_variables.csv` 篩選需要的列
- [ ] 使用 `variable_rename_mapping.csv` 進行列重新命名
- [ ] 檢查各年份的編碼一致性（特別是big5 vs utf-8）

### 2️⃣ 資料清洗
- [ ] 處理遺漏值（NA / -888 等特殊編碼）
- [ ] 驗證變數類型（numeric vs categorical）
- [ ] 檢查離群值（outliers）
- [ ] 對連續變數進行標準化（如需要）

### 3️⃣ 時間變數準備
- [ ] 建立時間指示變數 (0 = Pre, 1 = Post)
- [ ] 建立處理組指示變數（根據政策實施地區）
- [ ] 建立交互項變數 (Time × Treatment)

### 4️⃣ 控制變數選擇
- [ ] 選擇合適的控制變數組合
- [ ] 確保控制變數在各時期可用
- [ ] 考慮多重共線性問題

---

## 📈 第五步：DID模型設置

### 基本DID模型
```
Yit = β₀ + β₁·Treatmenti + β₂·Postt + β₃·(Treatmenti × Postt) + β₄·Xit + εit

其中：
- Yit = 個體 i 在時期 t 的經濟成果
- Treatmenti = 政策處理組指示變數
- Postt = 政策實施後時期指示變數
- (Treatmenti × Postt) = DID估計量（政策效應）
- Xit = 控制變數
```

### 估計方法建議
- 普通最小平方法 (OLS)
- 固定效應模型 (FE)
- 隨機效應模型 (RE)
- 廣義估計方程 (GEE)

### 平行趨勢檢驗
- 檢查pre-treatment期間的平行趨勢假設
- 建議使用事件研究方法（event study）

---

## 🔗 資料品質指標

### 一致性評估
根據 `detailed_year_comparison.csv`：

| 比較 | 一致性比率 | 評估 |
|------|----------|------|
| 91_1 → 91_2 | 92.5% | ✅ 極高 |
| 91_2 → 95 | 10.0% | ⚠️ 低（結構改版） |
| 95 → 99 | 2.0% | ⚠️ 很低（大幅變動） |
| 103 → 106 | 21.8% | ⚠️ 低 |
| 106 → 106 | 100.0% | ✅ 完全相同 |

**建議**：考慮使用 **103-106年** 和 **91_1 to 91_2** 兩個相對一致的時期段進行分離分析。

---

## 💾 檔案使用示例（Python）

```python
import pandas as pd

# 讀取核心變數定義
core_vars = pd.read_csv('core_variables.csv', encoding='utf-8-sig')

# 讀取變數重新命名對照表
rename_map = pd.read_csv('variable_rename_mapping.csv', encoding='utf-8-sig')
rename_dict = dict(zip(rename_map['original_name'], rename_map['new_name']))

# 讀取DID時間定義
did_periods = pd.read_csv('did_time_periods.csv', encoding='utf-8-sig')

# 篩選核心變數
core_var_list = core_vars[core_vars['years_count'] >= 4]['variable'].tolist()

# 重新命名變數
data_renamed = data[core_var_list].rename(columns=rename_dict)
```

---

## 📚 後續建議

### 1. 資料詳查
- 查閱原始問卷文件，確認各時期題目的邏輯等價性
- 了解樣本設計（分層、加權等）
- 確認是否需要使用樣本權重 (`w`, `w1`)

### 2. 政策實施細節
- 確認具體政策實施時點
- 識別潛在的處理組（政策受益群體）
- 識別對照組（未受政策影響群體）

### 3. 敏感性分析
- 嘗試不同的控制變數組合
- 檢驗不同的時間分割點
- 進行動態DID分析（多時期）

### 4. 異質性分析
- 按地區分析（原住民族自治區 vs 一般地區）
- 按人口特徵分析（教育程度、年齡等）
- 按經濟活動類型分析

---

## ✅ 檢查清單

在開始DID分析前：

- [ ] 確認已使用 `utf-8-sig` 編碼讀取所有CSV檔案
- [ ] 驗證 `core_variables.csv` 中31個變數在資料中都可用
- [ ] 檢查依賴變數（Y）沒有過多遺漏值
- [ ] 選定具體的政策實施時點和處理組定義
- [ ] 確認樣本權重的使用方式
- [ ] 建立基準年份對照表

---

**最後更新**: 2026年6月4日  
**資料涵蓋**: 民國91年-106年（2002-2017年）  
**分析單位**: 個人/家庭層級

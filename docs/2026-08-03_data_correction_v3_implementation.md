# 資料修正需求 v3 增補：檢視與實作紀錄

- 日期：2026-08-03
- 基準需求：`資料修正需求_2026-08-03_v3增補.md`
- 測試限制：本機只有 2021 原始個體資料；六波正式輸出未以單波測試結果覆寫。

## 檢視結論與修正

### C1／年齡

六波 AGE 來源均為級距資料，因此採需求所列方案 A：主流程不再建立或摘要 `AGE_RAW`。保留 `AGE_GROUP`、`AGE_GROUP_HARMONIZED` 與 `AGE_MEASURE_TYPE = age_group`。

跨年共同級距為 15–19、20–29、30–39、40–49、50–59、60+。由於共同上限只能到 60+，不能用這個欄位辨識 55+ 或 65+；相關分析應改用家庭原住民族年齡人數欄位。

### C2／支出總額

刪除占位欄 `EXP_TOTAL_SYN`，不再以改名方式將其包裝成 reported total。真正問卷回報的總支出只保留 2002 年 Q23，整合名稱為 `EXP_TOTAL_REPORTED`；2006–2021 明確標為問卷未提供。

各支出項目相加所得總額仍以 `EXP_TOTAL_DERIVED_EXPENDITURE` 與 `EXP_TOTAL_DERIVED_COMPLETE_EXPENDITURE` 表示，避免與問卷回報總額混淆。

### C3／兩段式 indicator

衝突檢查輸出保留 `indicator_label_set`，可直接核對各年「有／沒有」標籤方向。2010、2014、2017、2021 的驗收規則要求每年均能找到明示的「沒有」標籤。

先前 v2 文件記載的 31,921 是計算錯誤；依 v3 說明及逐列口徑，正確筆數為 33,921。這些是 indicator 與金額標籤一致的正常零支出列，不應判定為衝突。

### C4／共同年齡級距限制

`AGE_GROUP_HARMONIZED` 適合六波可比分析，但 60+ 分組不能回答 55+ 或 65+ 家戶人口問題。程式碼已加入同樣限制說明，防止誤用。

### C5／F14 家庭原住民族年齡結構

新增並納入摘要：

- `N_INDI_UNDER6`
- `N_INDI_7_15`
- `N_INDI_16_54`
- `N_INDI_55_64`
- `N_INDI_65PLUS`
- `N_INDI_55PLUS`
- `HAS_INDI_55PLUS`
- `HAS_INDI_65PLUS`

2006–2021 由各波家庭年齡格欄位建立；2002 問卷不具可比欄位，於 structural eligibility 表明確標記 `not_in_questionnaire`，不以零值代替缺少的問題。

## 隔離驗證結果

2021 於 `/private/tmp` 複本執行家庭資料流程，5,409 戶年齡格加總均與 `N_INDI` 一致：

- `HAS_INDI_55PLUS`：3,103 戶
- `HAS_INDI_65PLUS`：1,807 戶
- `N_INDI_55PLUS` 合計：4,362 人

正式六波 `output` 目前仍是修正前攜出版本，可能出現 `EXP_TOTAL_SYN` 舊欄名。這些輸出沒有在本機改寫；待具備完整六波原始資料的離線環境重跑後，才可由新版輸出取代。重跑前必須先封存修正前輸出，作為逐值比較基準。

## 後續完整離線驗收

F8 的 `structural_eligibility.csv` 目前沒有被 `05-01`／`05-02` 消費，行為完成度為 0%；本輪完整重跑將其標為 known-fail，不阻擋 F1 核心修復驗證。

- 重跑六波 03、04、05 階段與 `05-99-validate-offline-pipeline.R`。
- 確認六波 AGE 均為 grouped、正式整合資料不含 `AGE_RAW`。
- 確認 reported expenditure total 只出現在 2002，且沒有 `EXP_TOTAL_SYN`。
- 確認 2006–2021 家庭年齡格加總與 `N_INDI` 一致。
- **先**依日期備份原則封存完整修正前 `output`，確認基準檔可讀且 MD5 已記錄。
- 完成重跑及新舊比較後，才以新版輸出取代正式 `output`。

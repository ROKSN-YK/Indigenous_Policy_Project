# 資料修正需求 v2：檢視與實作紀錄

- 日期：2026-08-03
- 基準需求：`資料修正需求_2026-08-03_v2.md`
- 本機資料限制：僅有 2021 原始個體資料；正式六波基準 RDS（MD5 `c5b892...`）不在本機。

## Review 結論

v2 的 F1/F2 修訂方向通過：indicator 的「沒有」只依標籤語意判斷，衝突以 `explicit_no & usable_amount` 定義，不再硬編碼 `code == 2`。

2021 十個兩段式支出變數實測均為 `conflict_n = 0`。本段先前記載的 31,921 為計算錯誤；依 v3 增補確認，明示「沒有」且金額標籤一致的正確合計為 **33,921**，不應視為衝突。

F3 的「AGE_RAW 六年皆有效」驗收條件不成立：六波均為年齡級距，不能在不製造假精確年齡的情況下產生 `AGE_RAW`。v3 已採方案 A 移除該欄，保留 `AGE_GROUP`、`AGE_GROUP_HARMONIZED` 與 `AGE_MEASURE_TYPE`。

F13 建議的 15–24／25–34 分組無法由 2002 的 20–29 歲等既有粗級距無損推導。本次採所有波次均可支持的最粗共同分組：15–19、20–29、30–39、40–49、50–59、60+；不拆分原始級距。

## 已實作

- F1/F2：移除數值代碼假設，加入可用金額守衛與聚合衝突檢查 `check_two_stage_indicator_conflict.csv`。
- F3：摘要納入 `AGE_GROUP`、`AGE_MEASURE_TYPE`、`AGE_GROUP_HARMONIZED`；v3 已移除 `AGE_RAW`。
- F4：加入 AGE／RENT／RACE 已知格式差異的集中 fallback；拒答、未回答不轉成租金零值。
- F5：RENT unmapped 保留原文並納入金額中點重編；既有 RENT 類別欄不改名。
- F6：頂端開放級距優先使用補充精確金額，新增 `supplement_open_top` 來源。
- F7：新增單一 `family_count_crosswalk.csv`，兩支程式不再各自維護 tribble。
- F9：驗收加入全年份家戶人數關係、數值變異、兩段式衝突、租金有效率與 respondent unit。
- F10：v3 已刪除 `EXP_TOTAL_SYN`；真正回報總支出改以 `EXP_TOTAL_REPORTED` 表示，且只存在於 2002，衍生總額名稱維持不變。
- F11-1/2：混合 labelled／精確金額偵測不再限於 2006；`_2o` 不再作 primary 欄候選。
- F12：加入 `RESPONDENT_UNIT` 與 `RESPONDENT_UNIT_SOURCE`，摘要可將兩欄作為類別變數。
- F13：加入 `AGE_GROUP_HARMONIZED`，保留原 `AGE_GROUP` 供查核。

## 尚待完整離線環境驗證／完成

- F1/F2：2010、2014、2017 必須用原始個體資料重跑；本機不能驗證修正後 2010 的 40,216 個值。
- F4/F5/F6：六波字典有效率與 2014 的 37 筆 RENT 必須在完整環境重跑確認。
- F8：尚未實作。2002 可依 survey tag 判斷；2014 家庭收入則需在整合資料保留 I1 eligibility indicator，不能只靠已經形成的 NA 反推。2010 I1 分布也仍需離線診斷。
- F9：修正前／修正後六波 acceptance 對照須在完整環境執行。
- F11-3：敏感度分析欄位尚未加入；不影響本輪核心錯誤修復。
- F11-4：權數定義未齊，不產生可能誤導的加權摘要。

## 輸出保護

本機測試只用 2021 原始資料。測試後已恢復 `20260802` 攜出的六波聚合輸出，沒有用 2021 單波結果覆蓋正式摘要。測試產生的個體層級 recoded CSV 已移出正式 `output`；正式目錄只保留聚合的 indicator 衝突檢查。

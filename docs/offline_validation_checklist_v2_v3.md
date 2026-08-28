# v2＋v3 完整六波離線驗收清單

用途：在具備六波限制性原始資料的離線環境，完成唯一剩餘工作——完整重跑與新舊驗收。每項須填入結果、證據檔與判定，不得只以「程式成功結束」代替資料品質判定。

## 0. 重跑前保護（必須最先完成）

- [ ] 建立 `archive/YYYY-MM-DD/pre-v2-v3-full-rerun/`。
- [ ] 將修正前正式 `output` **複製或移入上述 archive 後再開始重跑**；不得先覆寫。
- [ ] 保存修正前 `output/summary_statistics/`、`output/checks/`、`output/pipeline_manifest.csv`（若存在）。
- [ ] 對修正前檔案產生路徑、大小、MD5 清單，確認可讀。
- [ ] 確認六波原始資料與 metadata 均存在：2002、2006、2010、2014、2017、2021。
- [ ] 確認 archive 後才執行新版 02→03→04→05→05-99；中途測試輸出不得覆蓋 archive。

通過判準：修正前基準可獨立讀取，且新舊檔案可依 `survey_year × sample_definition × variable` 配對。

## 1. 完整性與基本結構

- [ ] `cross_year_combined_data.rds` 同時包含六年。
- [ ] `ID × DATA_Y` 無重複。
- [ ] `N_INDI <= N_FAMILY` 於所有可比較列成立。
- [ ] `RESPONDENT_UNIT` 與 `RESPONDENT_UNIT_SOURCE` 六波均非全空。
- [ ] 執行 `code/05-99-validate-offline-pipeline.R`，保存 `check_offline_pipeline_acceptance.csv`。

通過判準：上述檢查全數 pass；若有 fail，停止更新正式 output。

## 2. F1／F2 兩段式支出（核心修正）

- [ ] 2010 八個兩段式支出變數逐一檢查 `valid_n > 1`、`sd > 0`、`max > 0`。
- [ ] 2010 `EXP_TOTAL_DERIVED_EXPENDITURE` 平均數不等於 24,820.7（容許浮點誤差 ±0.1）。
- [ ] 2010 修正後兩段式支出有效值不再全部退化為零或 NA。
- [ ] `check_two_stage_indicator_conflict.csv` 包含 `indicator_label_set`。
- [ ] 2010、2014、2017、2021 每年均至少有一個 indicator 標籤符合 `^沒有`。
- [ ] 四波 `conflict_n` 均為 0；如不為 0，先檢查實際標籤，不得硬編碼代碼方向。
- [ ] 回頭對帳 2021 十項 indicator 明示「沒有」且金額欄非空的合計為 **33,921**；這些一致零值不得列為 conflict。
- [ ] 2014、2017、2021 所有支出變數的新舊 `mean`、`median`、`valid_n` 逐值相同。

比對基準：重跑前 archive 中的 `income_expenditure_numeric_summary.csv`。最後一項以 exact equality 比較 `valid_n`，數值統計量使用相同輸出精度或容許誤差 `1e-8`。

## 3. F3／F13 年齡

- [ ] 六波 `AGE_GROUP` 有效率各自 >95%。
- [ ] 六波 `AGE_GROUP_HARMONIZED` 均非全空，組別恰為六組：15–19、20–29、30–39、40–49、50–59、60+。
- [ ] 六波 `AGE_MEASURE_TYPE` 均只出現 `age_group`。
- [ ] 正式整合資料與摘要均不存在 `AGE_RAW`。
- [ ] 資料說明保留「60+ 無法識別 55+/65+；改用 F14」限制。

## 4. F4／F5／F6 字典、租金與開放級距

- [ ] 六波 AGE、RENT、RACE 的 unmapped／manual-review 比例逐年檢查並記錄。
- [ ] 2010 AGE 已知標籤差異可成功映射，AGE 有效率 >95%。
- [ ] 2014 既知 37 筆 RENT 個案逐筆核對：不得因格式差異變成無理由 NA，也不得將拒答／未回答轉為 0。
- [ ] RENT 的「不需要支付租金」轉為精確 0；拒答、未回答維持缺值。
- [ ] 2014、2017、2021 頂端開放級距有補充精確金額時，來源標為 `supplement_open_top` 且採補充值。
- [ ] 每年 eligible RENT 有效率 >90%，或對未達標年份提出逐類原因表。

證據檔：`check_unmapped_demographic_values.csv`、`check_unmapped_income_values.csv`、`check_unmapped_expenditure_values.csv`、`check_rent_imputation.csv`、`check_rent_eligibility_vs_valid.csv`、value-source checks。

## 5. F7／F14 家庭人數與高齡指標

- [ ] 確認所有欄位均逐年由 `family_count_crosswalk.csv` 讀取，沒有用統一 index 推導。
- [ ] 特別確認 2014 `N_INDI = f1_1`，2017 `N_INDI = f1_1_6`，2021 `N_INDI = a2_1_6`。
- [ ] 2006–2021：五個原住民年齡細格加總等於 `N_INDI`，全部可用列成立。
- [ ] 2006–2021：`N_INDI_55PLUS <= N_INDI <= N_FAMILY` 全部成立。
- [ ] 2002 F14 欄位全為 NA，coverage 原因為 `not_in_questionnaire`。
- [ ] 2021 `HAS_INDI_55PLUS = TRUE` 為 3,103 戶。
- [ ] 2021 `HAS_INDI_65PLUS = TRUE` 為 1,807 戶。
- [ ] 2021 `N_INDI_55PLUS` 合計為 4,362 人。

證據檔：`check_family_count_variables.csv`、`check_family_indigenous_age_counts.csv`。五波 `_1`～`_5` 對應已由問卷與欄位結構確認，可視為 E1；仍須以逐列加總作最終資料驗證。

## 6. F8 結構性 eligibility

> **2026-08-04 更新**：`05-01`、`05-02` 已讀取規則表；2002 分卷、2002 F14 與 2014 `i1` 均納入 structural missing 計算。本節現在是必要驗收，不再是 known-fail。

- [ ] `structural_eligibility.csv` 包含 2002 `91_1` 的 `EXP_EDU_BOOKS_COMBINED`（Q23e）與 `EXP_TRAVEL`（Q23f）為 `not_in_questionnaire`；兩題實際只見於 `91_2`。
- [ ] 2002 分卷差異造成的缺值歸類為結構性，不計入一般未回答。
- [ ] `structural_eligibility.csv` 包含 2014 六個家庭收入組成項，規則為 `conditional_on_variable`、條件欄為 `i1`。
- [ ] 離線檢查 2014 `i1` 的實際值與標籤，確認何值進入收入續問。
- [ ] 診斷 2010 `i1` 分布及其與家庭收入缺值的關係；確認後再決定是否加入同類規則。
- [ ] coverage／missingness 摘要實際讀取 eligibility 規則，而非只把規則留在 CSV。
- [ ] 一般與收支 coverage 均滿足 `Valid N + Response Missing N + Structural Missing N = Eligible N`。

目前狀態：2002 與 2014 規則已有 consumer；2010 `i1` 僅保留診斷需求，未在規則尚未確認前推定 eligibility。

## 7. F9 修正前／修正後 acceptance 對照

- [ ] 以 archive 為 before、新輸出為 after，建立逐年逐變數對照表。
- [ ] 對照欄至少含 `valid_n`、`missing_n`、`mean`、`median`、`sd`、`min`、`max`、差值與判定。
- [ ] 對預期不變的 2014/2017/2021 支出欄採逐值相同判準。
- [ ] 對預期改變的 2010 八個兩段式欄，記錄修正前後差異並確認變異恢復。
- [ ] 所有 acceptance fail 均有原因與處置，不得直接略過。

## 8. C2 reported expenditure total

- [ ] crosswalk、正式整合資料與新版 output CSV 均不含 `EXP_TOTAL_SYN`／`EXP_TOTAL_SYN_EXPENDITURE`。
- [ ] 摘要輸出欄名為 `EXP_TOTAL_REPORTED_EXPENDITURE`。
- [ ] 該欄只出現在 2002；2006–2021 不得產生 reported total 列。
- [ ] 2002 `valid_n = 13,097`、`mean ≈ 27,289`（容許 ±1）。
- [ ] recoding table 的 `survey_year × variable × original_value` 無重複。

## 9. 完成與換版

- [ ] 所有必須項已勾選，例外均有書面說明。
- [ ] 保存新版 acceptance、before/after 對照與 pipeline manifest。
- [ ] 確認 archive 中修正前輸出未被修改。
- [ ] 最後才將通過驗收的新版資料與 output 設為正式版本。
- [ ] 將本次重跑日期、程式版本／commit、原始資料版本與 MD5 寫入重跑紀錄。

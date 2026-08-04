# 2026-08-04 離線最終重跑指引

## 適用狀態

本更新適用於第一至六步已完成、原流程在第八步
`04-01-aggregate-cross-year-data.R` 因 `SOURCE_ID` 與 F14 數值欄型別衝突而停止的離線專案。

本版同時修改第七步的兩段式支出與 2014 `i1` eligibility，因此套用後應從第七步開始，
不需重新匯入原始資料，也不需重跑第一至六步。

請使用 `offline_v2_v3_audited_patch_2026-08-04.zip`；不要再使用較早產出的
`offline_v2_v3_final_patch_2026-08-04.zip`。新包只含正式根目錄程式，不含落後的
`code/main/` 或 `code/archive/`。

## 套用前

1. 關閉 RStudio，不儲存 `.RData` 或 `.Rhistory`。
2. 保留 `output_before_v2_v3_20260803/`，不得覆蓋或移除。
3. 將現有 `code/` 備份到 `archive/2026-08-04_before_final_patch/code/`。
4. 只合併更新包中的 `code/`、`data/processed_data/03_crosswalks/` 與 `docs/`。
5. 不得以更新包取代 `data/raw_data/`、`data/processed_data/` 或 `output/`。

## 預檢

在專案根目錄開啟全新的 R session：

```r
source("code/00-02-check-offline-transfer-bundle.R", encoding = "UTF-8")
source("code/00-01-validate-offline-inputs.R", encoding = "UTF-8")
```

兩支程式都必須回到 `>` 且沒有 `Error`。套件 built-version warning 可記錄，但不等同失敗。

## 執行順序

```r
options(indigenous.pipeline.ready = NULL)
source("code/03-04-make-income-expense-data-from-02.R", encoding = "UTF-8")
source("code/04-01-aggregate-cross-year-data.R", encoding = "UTF-8")
source("code/05-01-summary-statistics.R", encoding = "UTF-8")
source("code/05-02-income-expenditure-recode-summary.R", encoding = "UTF-8")
Sys.setenv(OFFLINE_BASELINE_DIR = "output_before_v2_v3_20260803")
source("code/05-99-validate-offline-pipeline.R", encoding = "UTF-8")
```

每一行成功後才執行下一行。任何 `Error` 都停止，不刪除既有中間資料，也不以部分輸出取代正式結果。

## 主要證據檔

- `output/checks/check_two_stage_indicator_conflict.csv`
- `output/checks/check_structural_eligibility_i1.csv`
- `output/checks/check_family_indigenous_age_counts.csv`
- `output/checks/check_family_join_integrity.csv`
- `output/checks/check_income_expenditure_before_after.csv`
- `output/checks/check_offline_pipeline_acceptance.csv`

## 必要通過條件

- 2010 八個兩段式支出均有 `sd > 0`、`max > 0`。
- 2010 derived expenditure mean 不等於 `24,820.7`（容許 ±0.1）。
- 2021 explicit-no 對帳為 `33,921`。
- 2014、2017、2021 預期不變的支出摘要與修正前 baseline 相同。
- 2006 F14 六筆來源特殊碼為缺失，其餘 6,007 筆對帳。
- 2021 F14 基準為 3,103／1,807／4,362。
- 2002 分卷及 2014 `i1` 已套用 structural eligibility。
- `Valid N + Response Missing N + Structural Missing N = Eligible N`。
- `EXP_TOTAL_REPORTED_EXPENDITURE` 只出現在 2002，`valid_n = 13,097`、mean 約 27,289。
- `check_offline_pipeline_acceptance.csv` 不含 `fail`。

## 換版

只有全部必要驗收通過後，才把新版 `output` 設為正式結果。修正前 baseline、驗收表、manifest、
程式版本與重跑日期應一起保留在 archive。更新包及 GitHub 不得包含 `.RData`、`.Rhistory`、個案 RDS
或 respondent-level CSV。

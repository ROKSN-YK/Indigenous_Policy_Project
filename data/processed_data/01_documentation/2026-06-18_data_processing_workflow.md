# 資料整理作業流程說明

更新日期：2026-06-18

## 目的

本文件說明原住民族經濟狀況調查資料自原始檔到跨年度整合檔的整理流程，並記錄目前 `02` 與 `03` 系列程式的角色分工。後續若流程調整，請直接更新本文件的日期與內容。

## 目前流程

1. `01-00-load-packages.R`
   載入各整理腳本共用的 R packages。

2. `02-00-import-cross-year-survey-data.R`
   自動掃描 `data/raw_data` 內的 `data*.dta` 檔案，建立：
   - `data/processed_data/02_metadata/imported_survey_index.csv`
   - `data/processed_data/02_metadata/survey_datasets.rds`

3. `03-00-make-year-survey-meta.R`
   metadata 產製腳本。
   用途：從 `02` 階段已匯入的 survey objects 重新輸出欄位、label、型別。
   輸出路徑統一為：
   - `data/processed_data/02_metadata/survey_meta`

4. `03-00-survey-utils.R`
   新版共用 helper 腳本。
   用途：提供 `03` 系列新流程使用的函數，例如：
   - ID 欄位判定
   - 年度與 survey tag 對照
   - 題號對應到資料欄位
   - `unified_answer_crosswalk_*` 選項整併

5. `03-01` 到 `03-04`
   目前同時存在兩類版本：
   - 舊版：原本直接讀取特定年份與固定路徑
   - 新版 `from-02`：先讀 `02` 的匯入結果，再做各區塊整理

## 新增但不覆蓋舊檔的 03 系列

以下為本次新增、保留舊檔不覆蓋的版本：

- `code/03-01-make-basic-info-from-02.R`
- `code/03-02-make-demographic-data-from-02.R`
- `code/03-03-make-family-data-from-02.R`
- `code/03-04-make-income-expense-data-from-02.R`

對應輸出檔案：

- `data/processed_data/basic_info_from_02.rds`
- `data/processed_data/demographic_data_from_02.rds`
- `data/processed_data/family_data_from_02.rds`
- `data/processed_data/03_income_expense/income_data.rds`
- `data/processed_data/03_income_expense/expenditure_data.rds`
- `data/processed_data/03_income_expense/income_expenditure_data.rds`
- 可選的完整寬表 CSV（預設不輸出，以避免重複儲存及離線環境記憶體壓力）：
  `income_data.csv`、`expenditure_data.csv`、`income_expenditure_data.csv`。
  僅在設定 `EXPORT_INTERMEDIATE_CSV=true` 時建立。

## 是否有納入 unified_answer_crosswalk 的選項整併流程

有，已納入新版 helper 與新版 `03` 整理流程中。

具體作法：

- 使用 `resolve_dataset_variables()`
  - 將 `unified_answer_crosswalk_*` 裡的 `raw_var` 題號，對應到實際 `.dta` 欄位名。

- 使用 `make_unified_label_lookup()`
- 使用 `make_unified_lookup()`
  - 讀取 `unified_answer_crosswalk_basic_info.csv`
  - 讀取 `unified_answer_crosswalk_income.csv`
  - 讀取 `unified_answer_crosswalk_expenditure.csv`
  - 建立「原始選項文字 -> 統一後選項文字」對照表。

- 使用 `harmonize_single_variable()`
  - 先把 labelled 資料轉成選項文字
  - 再依 crosswalk 將不同年度的選項整併成同一套 code / label 分類
  - 可指定 unmapped 時保留 raw 值或轉為 `NA`

補充：

- 若某欄位沒有對應的 `unified_label`，新版流程會先保留原始文字，不會直接丟失資訊。
- 家庭人口數類欄位如 `N_FAMILY`、`N_INDI` 目前仍以年別手動欄位對照為主，因為它們不在現有 `unified_answer_crosswalk_basic_info.csv` 的整併範圍內。

## 目前主線版本

目前建議作為主線的 03 系列如下：

- `code/03-01-make-basic-info-from-02.R`
- `code/03-02-make-demographic-data-from-02.R`
- `code/03-03-make-family-data-from-02.R`
- `code/03-04-make-income-expense-data-from-02.R`
- `code/03-00-survey-utils.R`

非 `from-02` 版本保留作為 legacy 對照，不再視為主線。

## 自動輸出的人工確認清單

主線流程執行後，會自動輸出到 `output/checks/`：

- `check_male_mapping.csv`
- `check_unmapped_demographic_values.csv`
- `check_rent_imputation.csv`
- `check_missing_variables_by_year.csv`
- `check_income_variable_mapping.csv`
- `check_expenditure_variable_mapping.csv`
- `check_income_distribution.csv`
- `check_expenditure_distribution.csv`
- `check_unmapped_income_values.csv`
- `check_unmapped_expenditure_values.csv`

目前已納入的檢查重點：

- `MALE` 只允許 `男性`、`非男性`、`NA`
- `ID + DATA_Y` 不可重複
- 每年筆數需與 02 匯入資料一致
- metadata 對欄位的解析結果需明確標記 `ok / missing_in_metadata / missing_in_dataset`
- 收支區塊的 `CODE` 欄位需落在 crosswalk 定義的 `unified_code` 範圍內
- `check_unmapped_*` 若僅剩表頭，表示目前該區塊沒有未對應值

## 收支區塊補充說明

`code/03-04-make-income-expense-data-from-02.R` 為目前收支主線流程，資料來源一律為 `02` 階段已匯入的中繼資料，不直接改寫 raw data。

此流程目前使用：

- `data/processed_data/03_crosswalks/unified_answer_crosswalk_income.csv`
- `data/processed_data/03_crosswalks/unified_answer_crosswalk_expenditure.csv`

主要整理步驟如下：

1. 由 `resolve_dataset_variables()` 將 crosswalk 的 `raw_var` 對應到實際 `.dta` 欄位名。
2. 由 `make_unified_lookup()` 建立原始選項到 `unified_code` / `unified_label` 的查表。
3. 針對收入與支出分別產出 analysis-ready 區塊資料。
4. 最後以 `ID` 與 `DATA_Y` 合併為 `income_expenditure_data`。

## 收支 crosswalk 維護紀錄

2026-06-18 已完成以下調整：

- 補列 2021 年收支區塊缺少的統一級距對照，包含：
  - `INC_PERS_GOV`
  - `INC_PERS_TRANSFER`
  - `INC_FAM_OTHER`
  - `EXP_CLEANING`
  - 多個 `H7-*` 支出題型的金額級距
- 清理 `unified_answer_crosswalk_income.csv` 與 `unified_answer_crosswalk_expenditure.csv` 的 CSV 欄位格式：
  - 修正含逗號值未加引號的列
  - 移除測試過程中留下的重複壞列
  - 確認 `readr::problems()` 兩份檔案皆為 `0` 筆
- 重新執行 `code/03-04-make-income-expense-data-from-02.R` 後：
  - `check_unmapped_income_values.csv` 僅剩表頭
  - `check_unmapped_expenditure_values.csv` 僅剩表頭

後續若新增年度、題項或級距，請優先補在 crosswalk，並重新檢查：

- `output/checks/check_income_variable_mapping.csv`
- `output/checks/check_expenditure_variable_mapping.csv`
- `output/checks/check_unmapped_income_values.csv`
- `output/checks/check_unmapped_expenditure_values.csv`

## 03-00 是否有重複疑慮

有命名上的混淆風險，但功能上不算重複。

- `03-00-make-year-survey-meta.R`
  - 是一支會產出 metadata 的流程腳本。

- `03-00-survey-utils.R`
  - 是一支提供函數的 helper 腳本，不直接代表完整產製流程。

因此：

- 功能上：不重複
- 命名上：容易讓人誤以為兩支都是「03-00 的主流程」

建議後續可考慮改名：

- `03-00-make-year-survey-meta.R`
- `03-00-shared-survey-utils.R`

本次先不改名，以免影響既有引用。

## 建議執行順序

1. 若新增原始年度檔案到 `data/raw_data`
2. 執行 `code/02-00-import-cross-year-survey-data.R`
3. 依區塊執行：
   - `code/03-01-make-basic-info-from-02.R`
   - `code/03-02-make-demographic-data-from-02.R`
   - `code/03-03-make-family-data-from-02.R`
   - `code/03-04-make-income-expense-data-from-02.R`

## 目前已知限制

- 目前 workspace 內實際可直接驗證的原始 `.dta` 主要為 `110` 年資料。
- 較早年度若放入 `data/raw_data` 後，建議逐年檢查：
  - metadata 編碼
  - 題號與欄位名稱對應
  - `unified_answer_crosswalk` 是否有需要補列的題項

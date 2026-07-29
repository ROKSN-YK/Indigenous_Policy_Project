# 遠端原始資料離線處理程序與配套檔案稽核

稽核日期：2026-07-26

## 結論

離線處理已有單一正式入口，處理順序、主要 crosswalk、問卷選項表及輸出
acceptance checks 均已接通。同步清單共 26 個必要檔案，目前全部存在並可產生
MD5。

本機目前只能找到 `data110.dta`，因此不能在本機完成 2002–2021 的全流程資料
驗證。2002–2017 的實際欄位名稱、Stata value label、未標籤數值與開放填答值，
仍須把本次修正後的程式及配套檔案帶到遠端離線環境後重跑，才能完成最終放行。

## 正式執行順序

正式入口：

```bash
Rscript code/00-00-run-remote-pipeline.R /path/to/offline_raw_data
```

執行順序如下：

1. 檢查必要 R 套件。
2. 檢查七個 raw DTA 是否各存在一次，並拒絕額外 `data*.dta`。
3. 執行 `00-01-validate-offline-inputs.R`，在覆寫資料前驗證問卷選項與 crosswalk。
4. `02-00-import-cross-year-survey-data.R` 匯入 DTA，保留 haven labelled 資訊。
5. `03-00-make-year-survey-meta.R` 重建各年度欄位 metadata。
6. `03-01` 建立基本 ID 與年度。
7. `03-02` 建立人口、教育、族別及地理欄位。
8. `03-03` 建立家庭結構與住宅欄位。
9. `03-04` 建立收入、支出、value source 與 unmapped/schema 檢核。
10. `04-01` 合併跨年資料並檢查 join 筆數。
11. `05-01`、`05-02` 建立一般摘要與收支數值摘要。
12. `05-99` 執行 release acceptance checks，並建立全輸出 MD5 manifest。

## 必要 raw data

離線 raw 目錄必須同時包含：

- `data91_1.dta`
- `data91_2.dta`
- `data95.dta`
- `data99.dta`
- `data103.dta`
- `data106.dta`
- `data110.dta`

2002–2017 檔案由遠端取得；2021 檔案須由目前本機資料複製進同一離線 raw
目錄。程式現在會在匯入前阻擋缺檔、同名重複檔與額外年度。

## 配套檔案

### R 程式

`00-02-check-offline-transfer-bundle.R` 所列 14 個正式 R 程式都必須同步。
遠端不需要執行 Python。

### 問卷選項

必須同步七個檔案：

- `question_options_91_1.csv`
- `question_options_91_2.csv`
- `question_options_95.csv`
- `question_options_99.csv`
- `question_options_103.csv`
- `question_options_106.csv`
- `question_options_110.csv`

### Crosswalk

必須同步：

- `unified_answer_crosswalk_basic_info.csv`
- `unified_answer_crosswalk_income.csv`
- `unified_answer_crosswalk_expenditure.csv`
- `variable_crosswalk.csv`
- `question_codex_comparison.csv`

前三個用於實際 harmonization；後兩個用於摘要表的跨年 coverage 判定。

### R 套件

- `haven`
- `dplyr`
- `data.table`
- `purrr`
- `readr`
- `stringr`
- `tidyr`
- `tibble`

## 已修正並可在同步前驗證的規則

- 2002：兩版問卷的家庭收入與家庭支出級距已依原頁建立；`91_1` 不會錯誤繼承
  `91_2` 才有的 23-5、23-6。
- 2006：C10 已移除頁尾污染；labelled code 與未標籤 exact amount 依 Stata
  label code set 分流。
- 2010：J7-1 至 J7-8 已建立 1–11 金額選項。
- 2014：H2/H3 已拆回 11、12、13；J7-1 至 J7-10 已建立 1–11 金額選項；
  N4 的 7–9 均正確映射為專科以上。
- 2017：M7-1 至 M7-10 已建立 1–11 金額選項；indicator 沒有才是確定零，
  選填空白本身不再自動當零。
- 2021：H7-1 至 H7-10 使用相同兩段式規則，並作為目前可取得 raw 的結構參考。

## 遠端重跑後必須覆核

下列事項無法只靠本機問卷與 2021 raw 完成：

1. 七個 DTA 的實際欄位是否都能由題號解析到。
2. 2002–2017 每個 money 欄位的 storage class 與 value-label code set。
3. 2006 未標籤數字是否確實為開放填答金額。
4. 2010/2014/2017 的 indicator、amount、open amount companion 欄是否齊全。
5. 所有 unmapped raw values 是否為合法缺失、拒答或新值。
6. 2017 M7 indicator 為有但 amount 空白的筆數與原始值樣本。
7. 各年合併筆數、家庭人數關係、收入支出分布與缺失率。

必須以這些輸出覆核：

- `check_source_field_schema.csv`
- `check_income_value_sources.csv`
- `check_expenditure_value_sources.csv`
- `check_missing_variables_by_year.csv`
- `check_unmapped_income_values.csv`
- `check_unmapped_expenditure_values.csv`
- `check_offline_pipeline_acceptance.csv`
- `pipeline_manifest.csv`

## 本次本機驗證結果

- 問卷與 crosswalk Python 測試：通過。
- R money parsing 與 sample rule 測試：通過。
- 離線 metadata/crosswalk 前置驗證：通過。
- 26 個同步必要檔案完整性與 MD5 建表：通過。
- 主要 R 程式語法解析：通過。
- CSV 欄數一致性檢查：通過。
- 全年度 raw pipeline：未執行，因本機只有 2021 raw。

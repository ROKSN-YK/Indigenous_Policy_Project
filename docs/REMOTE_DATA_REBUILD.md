# 110 年以前調查資料遠端重建

## 前置條件

- 將各年度 Stata 檔放在同一個 raw data 根目錄下；檔名須為 `data91_1.dta`、`data91_2.dta`、`data95.dta`、`data99.dta`、`data103.dta`、`data106.dta` 或 `data110.dta`。
- 問卷 PDF 放在 `docs/codebooks/`，使用既有的 `ques*.pdf` 檔名。
- 遠端僅需安裝 R 專案所需套件。本機已產出的問卷選項 CSV 與 crosswalk 必須一併同步到遠端。

## 執行

在專案根目錄執行：

```bash
Rscript code/00-00-run-remote-pipeline.R /path/to/raw_data
```

程式會依序重新匯入 raw data、建立 metadata、讀取本機已重建的 crosswalk、整理各資料區塊、整併跨年度資料並重算摘要。遠端流程不需要 Python。

若日後問卷 PDF 有更新，才需在本機執行：

```bash
python3 -m pip install -r requirements-questionnaire.txt
python3 code/extract_question_options.py
python3 code/build_income_expenditure_crosswalk.py
```

## 必查輸出

- `output/checks/check_question_option_extraction.csv`：PDF 選項疑似缺字或未拆分。
- `output/checks/check_questionnaire_pdf_render.csv`：PDF 視覺預覽是否成功產生。
- `output/checks/check_missing_variables_by_year.csv`：crosswalk 題號找不到 raw 欄位。
- `output/checks/check_unmapped_income_values.csv`：收入原始值無法 mapping。
- `output/checks/check_unmapped_expenditure_values.csv`：支出原始值無法 mapping。
- `output/checks/check_income_distribution.csv`、`check_expenditure_distribution.csv`：各年轉換後分布。
- `output/summary_statistics/coverage_summary.csv`：一般缺失與結構缺失。
- `output/summary_statistics/income_expenditure_recoded/`：金額級距轉換表與數值摘要。

遠端正式輸出前，以上三個 `missing/unmapped` 清單應逐項說明；不得只因程式成功結束就視為通過。

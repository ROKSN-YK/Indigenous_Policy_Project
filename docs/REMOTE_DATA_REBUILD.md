# 110 年以前調查資料遠端重建

## 前置條件

- 將遠端的 2002–2017 原始檔與本機可取得的 2021 原始檔放在同一個離線 raw data 根目錄或其年度子資料夾。七個 survey tag 必須分別為 `data91_1`、`data91_2`、`data95`、`data99`、`data103`、`data106`、`data110`；副檔名可為 `.dta` 或 `.sav`。
- 七個檔案必須各出現一次；同一來源不可同時存在 `.dta` 與 `.sav`，避免讀到錯誤版本。
- `archive` 子資料夾不會掃描；舊的 `data91.dta` 合併檔不屬於七個正式來源，會提示後略過。
- 舊 `merge_91_data.do` 顯示 `data91.dta` 是將兩份 91 年 `.dta` 直向
  append，並把第二份 ID 加上第一份最大 ID 後產生。新版流程應保留
  `data91_1`、`data91_2` 為兩個來源，分別套用版本 crosswalk，不使用這個
  已改號的舊合併檔。
- 問卷 PDF 只供本機維護選項表時使用，遠端 R 重建不需要 PDF，也不需要 Python。
- 遠端僅需安裝 R 專案所需套件。本機已產出的問卷選項 CSV 與 crosswalk 必須一併同步到遠端。
- 必要 R 套件為 `haven`、`dplyr`、`data.table`、`purrr`、`readr`、`stringr`、`tidyr`、`tibble`。

同步前先在本機執行：

```bash
Rscript code/00-02-check-offline-transfer-bundle.R
```

結果位於 `output/checks/check_offline_transfer_bundle.csv`，列出必要檔案、大小與 MD5。複製到離線環境後可再執行一次，核對檔案是否完整且未被換版。

## 執行

在專案根目錄執行：

```bash
Rscript code/00-00-run-remote-pipeline.R /path/to/raw_data
```

`00-00` 是離線原始資料的完整重建入口，不是安裝程式。本機沒有七個 raw
`.dta` 時不需要、也無法完整執行 `00-00`；仍可分別執行不讀 raw data 的
`00-01-validate-offline-inputs.R` 與 `00-02-check-offline-transfer-bundle.R`。
若在 RStudio 使用 `source()`，可先設定
`Sys.setenv(RAW_DATA_DIR = "/完整路徑/raw_data")`。

程式會依序：

1. 確認七個 `.dta` 全部存在；少一個就會在覆寫任何跨年產物前停止。
2. 驗證離線攜入的問卷選項與 crosswalk，包括 2002 收支級距、2006 C10、2010/2014/2017/2021 兩段式支出、2014 H2/H3 與 N4。
3. 匯入 raw data 並重建 metadata。
4. 依序建立 basic、demographic、family、income/expenditure。
5. 合併跨年資料，並檢查 join 前後筆數及家戶人數有效筆數。
6. 建立一般摘要及收支金額摘要。
7. 執行正式 acceptance checks 並輸出檔案 manifest。

2002 年包含 `91_1`、`91_2` 兩份來源，兩份原始樣本編號可能相同。03
系列會統一產生 `SURVEY_TAG::SOURCE_ID` 格式的跨來源唯一 `ID`；basic
輸出另保留 `SOURCE_ID` 與 `SURVEY_TAG` 供覆核。不可用
`distinct(ID, DATA_Y)` 直接刪除碰撞資料。

遠端流程不需要 Python。Python 只在本機問卷 PDF 或 crosswalk 規則改變時使用；
更新後須把 `question_options/`、`03_crosswalks/` 與 R/Python 程式一起同步到遠端。

若日後問卷 PDF 有更新，才需在本機執行：

```bash
python3 -m pip install -r requirements-questionnaire.txt
python3 code/extract_question_options.py
python3 code/build_income_expenditure_crosswalk.py
```

目前已確認的問卷規則：

- 2002 兩版問卷的家庭收入與家庭支出級距已依各自 PDF 原頁建立；`91_1` 不得出現只屬於 `91_2` 的 23-5、23-6。
- 2006 C10 僅能是男性、女性，不得包含頁尾訪談結語。
- 2010 J7、2014 J7、2017 M7、2021 H7 的金額選項均為 1–11；有無 indicator 是另一個 raw companion 欄位。
- 2014 H2/H3 的 11、12、13 分別為 20,000–29,999、30,000 以上開放填答、沒有這項收入。
- 2014 N4 代碼 7（專科）、8（大學）、9（研究所及以上）均映射為「專科以上」。
- 2014/2017/2021 的兩段式支出題，indicator 明確為「沒有」時，金額為確定 0。
- `_2o` 開放金額大於 0 時優先於最高級距中點，並記錄 `VALUE_SOURCE = open_amount`。
- 2006 labelled 欄位中，值若屬 Stata value-label code set，按級距代碼處理；不屬於
  code set 的數字才保留為候選實填金額。不可只因外觀看起來是數字就直接當元。

## 必查輸出

- `output/checks/check_question_option_extraction.csv`：PDF 選項疑似缺字或未拆分。
- `output/checks/check_questionnaire_pdf_render.csv`：PDF 視覺預覽是否成功產生。
- `output/checks/check_source_field_schema.csv`：每個來源欄位的型態、標籤數、有效值數，以及 indicator/open amount companion 是否存在。
- `output/checks/check_income_value_sources.csv`、`check_expenditure_value_sources.csv`：每年每題的級距、確定零、開放金額、未標籤精確金額及缺失筆數與樣本值。
- `output/checks/check_missing_variables_by_year.csv`：crosswalk 題號找不到 raw 欄位。
- `output/checks/check_unmapped_income_values.csv`：收入原始值無法 mapping。
- `output/checks/check_unmapped_expenditure_values.csv`：支出原始值無法 mapping。
- `output/checks/check_income_distribution.csv`、`check_expenditure_distribution.csv`：各年轉換後分布。
- `output/summary_statistics/coverage_summary.csv`：一般缺失與結構缺失。
- `output/summary_statistics/income_expenditure_recoded/`：金額級距轉換表與數值摘要。
- `output/checks/check_offline_pipeline_acceptance.csv`：P0/P1 放行檢核；任一 fail 時主程式以錯誤狀態結束。
- `output/pipeline_manifest.csv`：本次所有 processed/output 檔案的大小、修改時間與 MD5。

遠端正式輸出前，以上三個 `missing/unmapped` 清單應逐項說明；不得只因程式成功結束就視為通過。

## 2006 開放填答的覆核方式

重跑後篩選：

```r
library(readr)
library(dplyr)

read_csv("output/checks/check_income_value_sources.csv") %>%
  filter(data_year == 2006, value_source == "unlabelled_numeric_exact_amount")

read_csv("output/checks/check_expenditure_value_sources.csv") %>%
  filter(data_year == 2006, value_source == "unlabelled_numeric_exact_amount")
```

若 `34166`、`50000`、`1e+05` 等出現在此類，表示其底層值不屬於 Stata
value-label code set，程式會保留為 exact amount。`1`、`3`、`4` 若是合法標籤代碼，
會留在 `source_question`，不會被誤認為 1、3、4 元。

# 遠端離線資料重建操作手冊（初學者版）

本手冊適用於不熟悉 R 程式的人員。正式作業只需要執行一個入口：
`code/00-00-run-remote-pipeline.R`。它會自動依序執行 01、02、03、04、05
系列，不必逐支開啟或「安裝」R 程式。

## 一、作業前不要直接覆蓋舊專案

1. 關閉正在使用這個專案的 RStudio。
2. 將整個 `Indigenous_Policy_Project` 資料夾複製一份備份，資料夾名稱加上日期。
3. 新版 `code/`、問卷選項 CSV 與 crosswalk 必須整組更新，不要只複製單一
   `03-01`。
4. raw data 不需要搬動，也不要修改原始檔。

## 二、確認 raw data 位置與檔案

截圖中的根目錄是：

```text
C:\Users\SRDAR052025002\Desktop\Indigenous_Policy_Project\data\raw_data\economic_survey
```

程式會向下搜尋年度子資料夾，所以 `91年`、`95年`、`99年`、`103年`、
`106年`、`110年` 的結構可以保留。

Windows 檔案總管請先開啟「檢視 → 副檔名」，確認以下七個來源各只有一個：

```text
data91_1.sav 或 data91_1.dta
data91_2.sav 或 data91_2.dta
data95.dta 或 data95.sav
data99.dta 或 data99.sav
data103.dta 或 data103.sav
data106.dta 或 data106.sav
data110.dta 或 data110.sav
```

同一個來源不可同時放 `.dta` 與 `.sav`。`archive` 資料夾會被排除。
`data91.dta` 是舊的 91 年合併檔，本流程不讀取，會以訊息提示後略過。

91 年建議採以下配置：

```text
91年/
├─ data91_1.dta       ← 正式來源
├─ data91_2.dta       ← 正式來源
├─ ques91_1.pdf
├─ ques91_2.pdf
└─ archive/
   ├─ data91.dta      ← 舊流程產生的合併檔
   ├─ data91_1.sav    ← 替代格式備份
   └─ data91_2.sav    ← 替代格式備份
```

若經資料管理單位確認 `.sav` 才是正式來源，也可以反過來把兩份 `.sav` 放在
上一層、兩份 `.dta` 留在 archive；重點是每個 survey tag 只能選定一種正式
格式。依本專案留存的舊 Stata 合併程式，過去的 `data91.dta` 是先讀取兩份
`.dta` 後追加產生，因此在沒有其他版本證據時，優先使用兩份 `.dta`。

新版流程不先建立 `data91.dta`。02 階段分別匯入 `91_1`、`91_2`；每支 03
程式在套用各版本的問卷選項與 crosswalk 後，再將兩版資料直向彙整；04 階段
依新版唯一 `ID` 與年度，把基本、人口、家庭、收支資料橫向合併。

## 三、打開正確的 RStudio 專案

1. 進入 `Indigenous_Policy_Project`。
2. 雙擊 `Indigenous_Policy_Project.Rproj`。
3. 在 RStudio Console 輸入：

```r
getwd()
```

顯示結果的最後一段必須是 `Indigenous_Policy_Project`。如果不是，停止作業，
重新用 `.Rproj` 開啟。

## 四、第一次使用時檢查 R 套件

在 Console 貼上：

```r
required <- c(
  "haven", "dplyr", "data.table", "purrr",
  "readr", "stringr", "tidyr", "tibble"
)
setdiff(required, rownames(installed.packages()))
```

若結果是 `character(0)`，代表套件齊全。若顯示套件名稱，請由具權限的管理者
在可安裝套件的環境補齊；離線電腦不能直接從網路下載時，不要反覆執行
`install.packages()`。

## 五、更新檔案後先做配套檢查

若程式曾在遠端手動修改，先檢查主要 R 檔案是否有缺引號、括號或多餘文字：

```r
code_files <- c(
  "code/00-00-run-remote-pipeline.R",
  "code/00-01-validate-offline-inputs.R",
  "code/00-02-check-offline-transfer-bundle.R",
  "code/01-00-load-packages.R",
  "code/02-00-import-cross-year-survey-data.R",
  "code/03-00-survey-utils.R",
  "code/03-00-make-year-survey-meta.R",
  "code/03-01-make-basic-info-from-02.R",
  "code/03-02-make-demographic-data-from-02.R",
  "code/03-03-make-family-data-from-02.R",
  "code/03-04-make-income-expense-data-from-02.R",
  "code/04-01-aggregate-cross-year-data.R",
  "code/05-01-summary-statistics.R",
  "code/05-02-income-expenditure-recode-summary.R",
  "code/05-99-validate-offline-pipeline.R"
)

invisible(lapply(code_files, parse))
```

若 Console 沒有出現 Error，才繼續。若出現 `unexpected string constant`、
`unexpected symbol` 或 `unexpected end of input`，代表遠端程式檔在複製或
手動修改時已破損；應先用正式版本覆蓋該檔，不要繼續執行資料流程。

在 Console 執行：

```r
source("code/00-02-check-offline-transfer-bundle.R")
```

看到 `Offline transfer bundle passed` 才繼續。這一步不讀 raw data。

接著執行：

```r
source("code/00-01-validate-offline-inputs.R")
```

看到 `Offline metadata and crosswalk inputs passed validation` 才繼續。

## 六、執行完整流程

在 Console 完整貼上以下兩行：

```r
Sys.setenv(
  RAW_DATA_DIR = "C:/Users/SRDAR052025002/Desktop/Indigenous_Policy_Project/data/raw_data/economic_survey"
)
source("code/00-00-run-remote-pipeline.R")
```

Windows 路徑請使用 `/`，不要直接貼單一反斜線 `\`。

`00-00` 會自動執行：

```text
檢查套件及七份 raw data
→ 00-01 配套資料檢查
→ 02 匯入
→ 03 建立 metadata 與清理資料
→ 04 跨年合併
→ 05 摘要與最終驗證
```

不需要另外從 01 開始逐支執行，也不要把 R 程式理解成需要逐一安裝。

資料階段的實際順序固定為 `01 → 02 → 03 → 04 → 05`。檔名
`03-00-survey-utils.R` 雖然屬於 03 系列，但它只是多支程式共同載入的函數庫，
不是必須在 02 前人工執行的資料步驟。不要逐行選取 03-04 執行，應由
`source()` 或 `00-00` 在乾淨的 R session 中完整執行。

03-04 的正式中繼產物是三份 `.rds`。為降低離線電腦記憶體與 I/O 負擔，
預設不再另外輸出內容重疊的三份寬表 CSV。若確有人工檢視完整 CSV 的需求，
才在執行前設定：

```r
Sys.setenv(EXPORT_INTERMEDIATE_CSV = "true")
```

一般正式重建請維持預設，不需設定此變數。

## 七、判斷是否完成

Console 最後必須看到：

```text
Remote pipeline completed for years: 2002, 2006, 2010, 2014, 2017, 2021
```

並檢查：

1. `output/checks/check_offline_pipeline_acceptance.csv` 不得有 fail。
2. `output/pipeline_manifest.csv` 已更新。
3. `data/processed_data/04_analysis_ready/cross_year_combined_data.rds` 已更新。
4. `output/checks/` 中 missing/unmapped 清單均已逐項覆核。

## 八、失敗時的處理原則

1. 不要刪除 raw data。
2. 不要用 `distinct()` 或「移除重複」處理 2002 ID 問題。
3. 複製 Console 從第一行 `Error` 到最後一行的完整文字。
4. 記錄執行日期、操作者、新版檔案來源及是否曾手動修改。
5. 修正後重新從 `00-00` 執行；它會依正確順序重建產物。

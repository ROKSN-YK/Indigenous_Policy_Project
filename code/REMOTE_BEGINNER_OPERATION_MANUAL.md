# 遠端離線資料重建操作手冊（初學者版）

本手冊適用於不熟悉 R 程式的人員。正式作業只需要執行一個入口：
`code/00-00-run-remote-pipeline.R`。它會自動依序執行 01、02、03、04、05
系列，不必逐支開啟或「安裝」R 程式。

## 一、先備份，再更新現有專案（不必建立空白新專案）

假設目前使用中的資料夾叫 `Indigenous_Policy_Project`：

1. 關閉 RStudio。
2. 複製整個現有資料夾，將「複本」改名為
   `Indigenous_Policy_Project_backup_2026-07-29`。這份只供回復，不在裡面執行。
3. 原本的 `Indigenous_Policy_Project` 繼續作為正式作業資料夾；不必先建立一個
   空白的新專案。
4. 將新版配套檔案複製進正式作業資料夾，選擇取代同名檔案。三組必須來自
   同一版，不能只更新其中一支 R 程式：

```text
Indigenous_Policy_Project/
├─ code/                                      ← 更新整個新版 code 資料夾
└─ data/processed_data/
   ├─ 02_metadata/question_options/           ← 更新下列 7 個 CSV
   │  ├─ question_options_91_1.csv
   │  ├─ question_options_91_2.csv
   │  ├─ question_options_95.csv
   │  ├─ question_options_99.csv
   │  ├─ question_options_103.csv
   │  ├─ question_options_106.csv
   │  └─ question_options_110.csv
   └─ 03_crosswalks/                          ← 更新下列 5 個 CSV
      ├─ unified_answer_crosswalk_basic_info.csv
      ├─ unified_answer_crosswalk_income.csv
      ├─ unified_answer_crosswalk_expenditure.csv
      ├─ variable_crosswalk.csv
      └─ question_codex_comparison.csv
```

`question_options` 是「每一年度問卷的題目與選項整理表」；`crosswalk` 是
「不同年度原始欄位／答案如何轉成共同欄位」的對照表。raw data 不必搬動，
也不要修改。

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

在 Console 執行：

```r
source("code/00-02-check-offline-transfer-bundle.R", encoding = "UTF-8")
```

看到 `Offline transfer bundle passed` 才繼續。這一步不讀 raw data。

接著執行：

```r
source("code/00-01-validate-offline-inputs.R", encoding = "UTF-8")
```

看到 `Offline metadata and crosswalk inputs passed validation` 才繼續。

## 六、執行完整流程

在 Console 完整貼上以下兩行：

```r
Sys.setenv(
  RAW_DATA_DIR = "C:/Users/SRDAR052025002/Desktop/Indigenous_Policy_Project/data/raw_data/economic_survey"
)
source("code/00-00-run-remote-pipeline.R", encoding = "UTF-8")
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
請勿開啟 `03-04` 後將整支程式反白逐段 Run；這會把大型中間物件留在
Global Environment，增加 `R Session Aborted` 的風險。

正常流程只保留下游需要的壓縮 `.rds` 與檢查／摘要 CSV，不再預設輸出大型
中間 CSV。若確實需要 CSV 副本，才在執行前設定：

```r
Sys.setenv(EXPORT_INTERMEDIATE_CSV = "true")
```

## 七、判斷是否完成

Console 最後必須看到：

```text
完整流程成功完成；資料年度：2002, 2006, 2010, 2014, 2017, 2021
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

# 程式順序（唯一正式流程）

日常重建只執行：

```r
Sys.setenv(RAW_DATA_DIR = "原始資料資料夾")
source("code/00-00-run-remote-pipeline.R", encoding = "UTF-8")
```

`00-00` 是執行入口，不是安裝程式。它會先檢查套件，再按照下列固定順序執行；
請勿逐支選取程式碼 Run，也不需要逐支「安裝」：

1. `00-01`：檢查離線 metadata 與 crosswalk
2. `02-00`：檢查七份 raw data 並匯入
3. `03-00-make-year-survey-meta`：建立各年欄位 metadata
4. `03-01`：基本資料與唯一 ID
5. `03-02`：人口資料
6. `03-03`：家庭資料
7. `03-04`：所得與支出資料
8. `04-01`：跨年合併與分析資料
9. `05-01`：描述統計
10. `05-02`：所得／支出重編摘要
11. `05-99`：最終驗證與 manifest

`01-00`（套件）與 `03-00-survey-utils`（共用函式）由入口各載入一次，不是
資料處理步驟。所有 `source()` 均指定 UTF-8，避免 Windows 中文環境下整支執行
出現亂碼。入口也會自動切到專案根目錄。

## 檔案角色

- `00-00-run-remote-pipeline.R`：唯一正式入口。
- `00-02-check-offline-transfer-bundle.R`：傳送到離線電腦前，單獨盤點檔案。
- `extract_question_options.py`：問卷 PDF 或擷取規則改變時，才在本機執行。
- `build_income_expenditure_crosswalk.py`：問卷選項改變後，才在本機執行。
- `archive/`：歷史程式，不屬於正式流程。

Python 兩支維護工具不在遠端 R 流程內；遠端只需 R、CSV 配套資料及七份 raw
data。

## 編號原則

`00` 控制與檢查、`01` 套件、`02` 匯入、`03` 清理、`04` 分析資料、
`05` 摘要與驗證；未列在上述 11 步者不會由正式入口執行。

# 離線環境故障排除與安全檢視手冊

本手冊供無法連線 AI 的離線電腦使用。原則是先保存錯誤、只做唯讀檢查，
不要直接刪除 raw data、不要用 `distinct()` 消除受訪者，也不要覆寫正式 RDS。

## 一、每次開始前

關閉舊 RStudio；若詢問是否儲存 workspace，選擇 `Don't Save`。重新開啟
`Indigenous_Policy_Project.Rproj`，選擇 `Session → Restart R`，再執行：

```r
rm(list = ls(all.names = TRUE))
invisible(gc())
stopifnot(basename(getwd()) == "Indigenous_Policy_Project")
ls(all.names = TRUE)
```

最後一行應顯示 `character(0)`。

## 二、先做三項基本檢查

### 1. 套件

```r
required <- c(
  "haven", "dplyr", "data.table", "purrr",
  "readr", "stringr", "tidyr", "tibble"
)
missing_packages <- setdiff(required, rownames(installed.packages()))
print(missing_packages)
```

`character(0)` 代表套件齊全。缺套件時停止，不要在離線電腦反覆執行
`install.packages()`。

### 2. 傳輸檔案

```r
source(
  "code/00-02-check-offline-transfer-bundle.R",
  encoding = "UTF-8"
)
```

應顯示 `Offline transfer bundle passed`。

### 3. Metadata 與 crosswalk

```r
source(
  "code/00-01-validate-offline-inputs.R",
  encoding = "UTF-8"
)
```

應顯示 `Offline metadata and crosswalk inputs passed validation`。

## 三、保存錯誤資訊

錯誤發生後，不要立刻關閉 RStudio。依序執行：

```r
traceback()
warnings()
sessionInfo()
```

將 Console 從第一行 `Error` 到最後一行全部複製。另記錄：

- 停在 `[xx/11]` 的哪一步
- 執行日期與時間
- 使用的傳輸包名稱與 MD5
- 是否曾手動修改 R 程式
- 是否從舊 R Session 接續執行

可將基本環境資訊寫成文字檔：

```r
dir.create("output/diagnostics", recursive = TRUE, showWarnings = FALSE)
diagnostic_lines <- c(
  paste("time:", Sys.time()),
  paste("working_directory:", getwd()),
  paste("R_version:", R.version.string),
  paste("RAW_DATA_DIR:", Sys.getenv("RAW_DATA_DIR")),
  paste("objects_in_memory:", paste(ls(all.names = TRUE), collapse = ";"))
)
writeLines(
  diagnostic_lines,
  "output/diagnostics/offline_environment.txt",
  useBytes = TRUE
)
```

## 四、檢查程式是否因編碼或傳輸損壞

```r
r_files <- list.files(
  "code",
  pattern = "\\.R$",
  full.names = TRUE
)

parse_results <- lapply(r_files, function(path) {
  tryCatch(
    {
      parse(path, encoding = "UTF-8")
      data.frame(file = path, status = "pass", error = "")
    },
    error = function(e) {
      data.frame(
        file = path,
        status = "fail",
        error = conditionMessage(e)
      )
    }
  )
})

parse_results <- do.call(rbind, parse_results)
print(parse_results)
```

有任何 `fail` 時，整組重新複製最新版 `code/`；不要逐字修改亂碼行。

## 五、檢查 raw data 重複或缺少

先設定正確且不要過大的根目錄：

```r
raw_dir <- paste0(
  "C:/Users/SRDAR052025002/Desktop/",
  "Indigenous_Policy_Project/data/raw_data/economic_survey"
)
```

檢查正式來源：

```r
raw_files <- list.files(
  raw_dir,
  pattern = "^data\\d+(?:_\\d+)?\\.(?:dta|sav)$",
  recursive = TRUE,
  full.names = TRUE,
  ignore.case = TRUE
)

normalized <- gsub("\\\\", "/", raw_files)
raw_files <- raw_files[
  !grepl("(^|/)archive(/|$)", normalized, ignore.case = TRUE)
]

raw_audit <- data.frame(
  path = raw_files,
  survey = tolower(tools::file_path_sans_ext(basename(raw_files))),
  extension = tolower(tools::file_ext(raw_files))
)

print(raw_audit)
print(table(raw_audit$survey))
```

以下七個來源各應恰好一份：

```r
required_surveys <- c(
  "data91_1", "data91_2", "data95", "data99",
  "data103", "data106", "data110"
)

setdiff(required_surveys, raw_audit$survey)
names(which(table(raw_audit$survey) > 1L))
```

第一行與第二行都應是 `character(0)`。不要刪除重複檔；先移到該年度的
`archive/`，並保留 `.dta` 或 `.sav` 其中一種正式來源。

## 六、完整流程

```r
Sys.setenv(RAW_DATA_DIR = raw_dir)
source(
  "code/00-00-run-remote-pipeline.R",
  encoding = "UTF-8"
)
```

不要逐支反白 Run。修正後一律從 `00-00` 重跑，讓依賴產物依序重建。

## 七、R Session Aborted

`R Session Aborted` 是整個 R 程序崩潰，不是普通語法錯誤。處理順序：

1. 重新啟動 RStudio，不儲存 workspace。
2. `Session → Restart R`。
3. 確認 Global Environment 為空。
4. 不設定 `EXPORT_INTERMEDIATE_CSV=true`。
5. 從 `00-00` 執行，不要反白執行 03-04。
6. 重新執行前查看 R 記憶體使用：

```r
gc()
```

若總是在同一步 aborted，記錄該步驟與當時 Console 最後 30 行。

## 八、檢查第 8 步分析資料

```r
analysis_path <- paste0(
  "data/processed_data/04_analysis_ready/",
  "cross_year_combined_data.rds"
)
stopifnot(file.exists(analysis_path))
analysis_data <- as.data.frame(readRDS(analysis_path))

dim(analysis_data)
table(analysis_data$DATA_Y, useNA = "ifany")
```

檢查 ID 與年度重複：

```r
key_count <- aggregate(
  rep(1L, nrow(analysis_data)),
  by = list(ID = analysis_data$ID, DATA_Y = analysis_data$DATA_Y),
  FUN = sum
)
names(key_count)[3] <- "n"
subset(key_count, n > 1L)
```

正確結果應為 0 列。不要用 `distinct()` 刪除重複；應回頭檢查 ID 建構。

## 九、檢查 missing 與 unmapped

```r
check_files <- list.files(
  "output/checks",
  pattern = "\\.csv$",
  full.names = TRUE
)
print(check_files)
```

優先檢查：

```text
check_missing_variables_by_year.csv
check_unmapped_income_values.csv
check_unmapped_expenditure_values.csv
check_unknown_variable_presence.csv
check_unknown_income_expenditure_presence.csv
check_income_expenditure_manual_review.csv
```

快速列出非空檢查檔：

```r
check_sizes <- data.frame(
  file = check_files,
  bytes = file.info(check_files)$size
)
check_sizes[order(check_sizes$bytes, decreasing = TRUE), ]
```

非空不一定代表錯誤；需依 `status`、`frequency`、`needs_manual_review` 判讀。

## 十、第 10 步教育支出互斥

```r
education_check <- read.csv(
  "output/checks/check_education_component_exclusivity.csv",
  check.names = FALSE
)
print(education_check)
```

預期規則：

- 2002–2010：只有 `EXP_EDU_BOOKS_COMBINED_EXPENDITURE` 有有效值
- 2014–2021：只有 `EXP_EDU_TUITION_EXPENDITURE` 與
  `EXP_BOOKS_EXPENDITURE` 有有效值

若 2002 的 combined 為 0，先確認使用 7 月 30 日以後版本，不要註解掉驗證。

## 十一、檢視指定欄位

搜尋醫療、就業、所得欄位：

```r
grep(
  "MEDICAL|HEALTH|EMPLOY|WORK|INCOME",
  names(analysis_data),
  value = TRUE,
  ignore.case = TRUE
)
```

逐年有效筆數：

```r
inspect_variable <- function(data, variable) {
  stopifnot(variable %in% names(data))
  aggregate(
    !is.na(data[[variable]]),
    by = list(DATA_Y = data$DATA_Y),
    FUN = sum
  )
}

# 將欄位名稱替換成實際名稱
# inspect_variable(analysis_data, "EXP_MEDICAL_EXPENDITURE")
```

## 十二、緊急探索版（不得當成正式資料）

只有在無法立即套用 hotfix、且研究不使用教育、旅遊與總支出時才使用：

```r
affected <- grep(
  "^EXP_(EDU_BOOKS_COMBINED|TRAVEL|TOTAL)",
  names(analysis_data),
  value = TRUE
)

emergency_data <- analysis_data[
  ,
  !names(analysis_data) %in% affected,
  drop = FALSE
]

emergency_data$DATA_VERSION <- "EMERGENCY_EXPLORATORY_NOT_FINAL"
saveRDS(
  emergency_data,
  paste0(
    "data/processed_data/04_analysis_ready/",
    "cross_year_exploratory_emergency.rds"
  )
)
```

不得覆寫 `cross_year_combined_data.rds`，不得用緊急版產出正式研究結果。

## 十三、禁止事項

- 不要修改或刪除 raw data。
- 不要用 `distinct()`、刪除重複列或只留第一筆來修正 ID。
- 不要把 `.dta` 與 `.sav` 同時放在正式搜尋範圍。
- 不要略過 `00-01`、`00-02` 或 `05-99` 後宣稱正式完成。
- 不要註解 validation 只為了讓流程顯示成功。
- 不要覆寫正式 RDS 建立探索資料。
- 不要在含有舊大型物件的 Global Environment 執行 03-04。
- 不要在 UTF-8 亂碼後逐行手改；整組重新複製最新版。

## 十四、何時可判定完成

Console 最後應顯示：

```text
完整流程成功完成；資料年度：2002, 2006, 2010, 2014, 2017, 2021
```

且：

- `output/checks/check_offline_pipeline_acceptance.csv` 沒有 fail
- `output/pipeline_manifest.csv` 已更新
- `cross_year_combined_data.rds` 已更新
- missing、unmapped、manual review 檔案均已人工覆核

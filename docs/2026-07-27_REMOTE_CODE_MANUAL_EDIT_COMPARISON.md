# 2026-07-27 遠端程式手動調整比對表

若能整組同步新版 `code/`，應優先整組同步。只有在遠端傳檔限制明確、且操作者
能精確核對行數時，才建議手動修改。修改前必須備份原檔。

| 檔案 | 必要性 | 原本行為 | 調整後行為 | 手動調整難度 |
|---|---|---|---|---|
| `03-00-survey-utils.R` | 必要 | 只取原始 `id/no` | 新增 `build_survey_keys()`，產生 `SURVEY_TAG::SOURCE_ID` | 中 |
| `03-01-make-basic-info-from-02.R` | 必要 | `ID = dataset[[id_var]]` | 呼叫共用鍵函數，並保留 `SOURCE_ID`、`SURVEY_TAG` | 低 |
| `03-02-make-demographic-data-from-02.R` | 必要 | 使用原始 ID | 使用共用唯一 ID | 低 |
| `03-03-make-family-data-from-02.R` | 必要 | 使用原始 ID | 使用共用唯一 ID | 低 |
| `03-04-make-income-expense-data-from-02.R` | 必要 | 使用原始 ID | 使用共用唯一 ID | 低 |
| `02-00-import-cross-year-survey-data.R` | 依截圖必要 | 只搜尋/讀取 `.dta`，也會掃 archive | 接受 `.dta/.sav`、依格式讀取、排除 archive、略過 `data91.dta` | 中 |
| `00-00-run-remote-pipeline.R` | 建議且依截圖必要 | 只驗證 `.dta`，會掃 archive | 接受 `.dta/.sav`、排除 archive、顯示較清楚的路徑提示 | 中 |

## A. 2002 ID 修正

在 `03-00-survey-utils.R` 的 `get_survey_id_var()` 後加入
`build_survey_keys()`。完整內容應直接以本機新版同名函數為準。

四支 03 輸出程式的核心替換規則如下：

```r
# 舊
id_var <- get_survey_id_var(dataset, data_year, survey_tag)
ID = dataset[[id_var]]

# 新
survey_keys <- build_survey_keys(dataset, data_year, survey_tag)
ID = survey_keys$ID
DATA_Y = survey_keys$DATA_Y
```

`03-01` 應直接使用：

```r
out <- build_survey_keys(dataset, data_year, survey_tag)
```

不可只改 `03-01`；若 03-02～03-04 仍使用舊 ID，04 階段將無法正確合併。

## B. raw data 格式與搜尋修正

搜尋式由：

```r
pattern = "^data\\d+(?:_\\d+)?\\.dta$"
```

改為：

```r
pattern = "^data\\d+(?:_\\d+)?\\.(?:dta|sav)$"
```

並加入：

```r
ignore.case = TRUE
```

讀檔由固定的：

```r
read_dta(file_path)
```

改為依副檔名選擇：

```r
extension <- stringr::str_to_lower(tools::file_ext(file_path))
switch(
  extension,
  dta = haven::read_dta(file_path),
  sav = haven::read_sav(file_path)
)
```

此外必須排除路徑中名為 `archive` 的資料夾，否則備份檔可能被判定為重複。

## C. 手動修改後的最低測試

先在 RStudio Console 執行：

```r
invisible(lapply(
  c(
    "code/00-00-run-remote-pipeline.R",
    "code/02-00-import-cross-year-survey-data.R",
    "code/03-00-survey-utils.R",
    "code/03-01-make-basic-info-from-02.R",
    "code/03-02-make-demographic-data-from-02.R",
    "code/03-03-make-family-data-from-02.R",
    "code/03-04-make-income-expense-data-from-02.R"
  ),
  parse
))
```

沒有 Error 才執行 `00-00`。完成後必須確認：

```r
x <- readRDS("data/processed_data/basic_info_from_02.rds")
anyDuplicated(x[c("ID", "DATA_Y")])
table(x$SURVEY_TAG, useNA = "ifany")
```

第一個結果必須為 `0`；第二個結果必須包含 `91_1` 與 `91_2`。


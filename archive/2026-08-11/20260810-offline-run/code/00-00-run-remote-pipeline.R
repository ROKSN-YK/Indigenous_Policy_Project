find_project_root <- function() {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  command_file <- if (length(file_arg) > 0L) sub("^--file=", "", file_arg[[1]]) else ""
  script_file <- tryCatch(
    normalizePath(sys.frame(1)$ofile, winslash = "/", mustWork = FALSE),
    error = function(e) ""
  )
  candidates <- unique(c(
    getwd(),
    if (nzchar(script_file)) dirname(dirname(script_file)) else character(),
    if (nzchar(command_file)) dirname(dirname(normalizePath(
      command_file, winslash = "/", mustWork = FALSE
    ))) else character()
  ))
  matched <- candidates[
    file.exists(file.path(candidates, "code", "00-00-run-remote-pipeline.R"))
  ]
  if (length(matched) == 0L) {
    stop("找不到專案根目錄；請從 Indigenous_Policy_Project 專案內執行。", call. = FALSE)
  }
  normalizePath(matched[[1]], winslash = "/", mustWork = TRUE)
}

project_root <- find_project_root()
if (!identical(normalizePath(getwd(), winslash = "/"), project_root)) {
  setwd(project_root)
}

source_utf8 <- function(path, local = globalenv()) {
  source(path, local = local, encoding = "UTF-8", chdir = FALSE)
}

pipeline_steps <- c(
  "檢查離線配套資料" = "code/00-01-validate-offline-inputs.R",
  "匯入跨年原始資料" = "code/02-00-import-cross-year-survey-data.R",
  "建立各年欄位 metadata" = "code/03-00-make-year-survey-meta.R",
  "整理基本資料" = "code/03-01-make-basic-info-from-02.R",
  "整理人口資料" = "code/03-02-make-demographic-data-from-02.R",
  "整理家庭資料" = "code/03-03-make-family-data-from-02.R",
  "整理收支資料" = "code/03-04-make-income-expense-data-from-02.R",
  "建立文健站鄉鎮年度暴露表" = "code/03-05-build-care-station-town-year-panel.R",
  "建立跨年分析資料" = "code/04-01-aggregate-cross-year-data.R",
  "整併文健站暴露至個體資料" = "code/04-02-merge-care-station-exposure.R",
  "產生描述統計" = "code/05-01-summary-statistics.R",
  "產生收支重編摘要" = "code/05-02-income-expenditure-recode-summary.R",
  "執行最終驗證" = "code/05-99-validate-offline-pipeline.R"
)

preflight_files <- c(
  "code/01-00-load-packages.R",
  "code/03-00-survey-utils.R",
  unname(pipeline_steps)
)
for (path in preflight_files) {
  tryCatch(
    parse(path, encoding = "UTF-8"),
    error = function(e) {
      stop(
        "程式檔無法解析，可能在傳輸或手動編輯時損壞：", path, "\n",
        conditionMessage(e),
        call. = FALSE
      )
    }
  )
}

source_utf8("code/01-00-load-packages.R")
source_utf8("code/03-00-survey-utils.R")
options(indigenous.pipeline.ready = TRUE)

args <- commandArgs(trailingOnly = TRUE)
raw_data_dir <- if (length(args) >= 1L) args[[1]] else
  Sys.getenv("RAW_DATA_DIR", unset = "data/raw_data")
raw_data_dir <- normalizePath(raw_data_dir, winslash = "/", mustWork = FALSE)
Sys.setenv(RAW_DATA_DIR = raw_data_dir)

for (i in seq_along(pipeline_steps)) {
  label <- names(pipeline_steps)[[i]]
  path <- unname(pipeline_steps[[i]])
  message(sprintf("[%02d/%02d] %s", i, length(pipeline_steps), label))
  started_at <- proc.time()[["elapsed"]]
  tryCatch(
    source_utf8(path, local = new.env(parent = globalenv())),
    error = function(e) {
      stop(
        sprintf("流程在第 %d 步「%s」失敗（%s）：\n%s", i, label, path, conditionMessage(e)),
        call. = FALSE
      )
    }
  )
  message(sprintf("         完成（%.1f 秒）", proc.time()[["elapsed"]] - started_at))
  invisible(gc(verbose = FALSE))
}

expected_years <- sort(unique(readr::read_csv(
  "data/processed_data/02_metadata/imported_survey_index.csv",
  show_col_types = FALSE
)$data_year))
combined <- readRDS("data/processed_data/04_analysis_ready/cross_year_combined_data.rds")
missing_years <- setdiff(expected_years, sort(unique(combined$DATA_Y)))
if (length(missing_years) > 0) {
  stop("Combined output is missing imported survey years: ", paste(missing_years, collapse = ", "))
}

message("完整流程成功完成；資料年度：", paste(expected_years, collapse = ", "))

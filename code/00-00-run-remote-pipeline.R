source("code/01-00-load-packages.R")

args <- commandArgs(trailingOnly = TRUE)
raw_data_dir <- if (length(args) >= 1) args[[1]] else "data/raw_data"
Sys.setenv(RAW_DATA_DIR = raw_data_dir)

required_dta <- list.files(
  raw_data_dir,
  pattern = "^data\\d+(?:_\\d+)?\\.dta$",
  recursive = TRUE,
  full.names = TRUE
)
if (length(required_dta) == 0) {
  stop("No data*.dta files found below: ", raw_data_dir)
}

message("[1/9] Import raw survey files")
source("code/02-00-import-cross-year-survey-data.R", local = new.env(parent = globalenv()))

message("[2/9] Build survey metadata")
source("code/03-00-make-year-survey-meta.R", local = new.env(parent = globalenv()))

scripts <- c(
  "code/03-01-make-basic-info-from-02.R",
  "code/03-02-make-demographic-data-from-02.R",
  "code/03-03-make-family-data-from-02.R",
  "code/03-04-make-income-expense-data-from-02.R",
  "code/04-01-aggregate-cross-year-data.R",
  "code/05-01-summary-statistics.R",
  "code/05-02-income-expenditure-recode-summary.R"
)

for (i in seq_along(scripts)) {
  message("[", i + 2L, "/9] ", scripts[[i]])
  source(scripts[[i]], local = new.env(parent = globalenv()))
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

message("Remote pipeline completed for years: ", paste(expected_years, collapse = ", "))

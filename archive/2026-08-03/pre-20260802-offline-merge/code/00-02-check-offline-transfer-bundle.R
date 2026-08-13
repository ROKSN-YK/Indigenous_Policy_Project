if (!isTRUE(getOption("indigenous.pipeline.ready"))) {
  source("code/01-00-load-packages.R", encoding = "UTF-8")
}

pipeline_files <- c(
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

support_files <- c(
  "code/README_pipeline-sequence.md",
  "code/REMOTE_BEGINNER_OPERATION_MANUAL.md",
  "code/OFFLINE_TROUBLESHOOTING_GUIDE.md"
)

question_option_files <- file.path(
  "data/processed_data/02_metadata/question_options",
  paste0(
    "question_options_",
    c("91_1", "91_2", "95", "99", "103", "106", "110"),
    ".csv"
  )
)

crosswalk_files <- file.path(
  "data/processed_data/03_crosswalks",
  c(
    "unified_answer_crosswalk_basic_info.csv",
    "unified_answer_crosswalk_income.csv",
    "unified_answer_crosswalk_expenditure.csv",
    "variable_crosswalk.csv",
    "question_codex_comparison.csv"
  )
)

bundle_files <- c(
  pipeline_files,
  support_files,
  question_option_files,
  crosswalk_files
)
bundle_check <- tibble(
  file_role = c(
    rep("pipeline_code", length(pipeline_files)),
    rep("documentation", length(support_files)),
    rep("question_options", length(question_option_files)),
    rep("crosswalk", length(crosswalk_files))
  ),
  path = bundle_files,
  exists = file.exists(bundle_files),
  bytes = ifelse(file.exists(bundle_files), file.info(bundle_files)$size, NA_real_),
  md5 = ifelse(
    file.exists(bundle_files),
    unname(tools::md5sum(bundle_files)),
    NA_character_
  ),
  status = ifelse(file.exists(bundle_files), "pass", "fail")
)

dir.create("output/checks", recursive = TRUE, showWarnings = FALSE)
write_csv(
  bundle_check,
  "output/checks/check_offline_transfer_bundle.csv"
)

missing <- bundle_check %>% filter(status == "fail")
if (nrow(missing) > 0L) {
  stop(
    "Offline transfer bundle is incomplete: ",
    paste(missing$path, collapse = ", ")
  )
}

message(
  "Offline transfer bundle passed: ",
  nrow(bundle_check),
  " files checked."
)

if (!isTRUE(getOption("indigenous.pipeline.ready"))) {
  source("code/01-00-load-packages.R", encoding = "UTF-8")
}

pipeline_files <- c(
  "code/00-00-run-remote-pipeline.R",
  "code/00-01-validate-offline-inputs.R",
  "code/00-02-check-offline-transfer-bundle.R",
  "code/00-03-archive-output-before-rerun.R",
  "code/01-00-load-packages.R",
  "code/02-00-import-cross-year-survey-data.R",
  "code/03-00-survey-utils.R",
  "code/03-00-make-year-survey-meta.R",
  "code/03-01-make-basic-info-from-02.R",
  "code/03-02-make-demographic-data-from-02.R",
  "code/03-03-make-family-data-from-02.R",
  "code/03-04-make-income-expense-data-from-02.R",
  "code/03-05-build-care-station-town-year-panel.R",
  "code/04-01-aggregate-cross-year-data.R",
  "code/04-02-merge-care-station-exposure.R",
  "code/05-01-summary-statistics.R",
  "code/05-02-income-expenditure-recode-summary.R",
  "code/05-99-validate-offline-pipeline.R"
)

support_files <- c(
  "OFFLINE_UPDATE_README_2026-08-06.md",
  "OFFLINE_UPDATE_FILE_INDEX_2026-08-06.csv",
  "code/README_pipeline-sequence.md",
  "code/REMOTE_BEGINNER_OPERATION_MANUAL.md",
  "code/OFFLINE_TROUBLESHOOTING_GUIDE.md",
  "docs/OFFLINE_CORRECTION_AND_CARE_STATION_GUIDE_2026-08-06.md",
  "docs/OFFLINE_PACKAGE_AUDIT_2026-08-06.md"
)

test_files <- c(
  "code/tests/test-questionnaire-crosswalk.py",
  "code/tests/test-summary-rules.R",
  "code/tests/test-downstream-synthetic.R"
  ,"code/tests/test-care-station-and-overrides.R"
)

generator_files <- c(
  "code/build_income_expenditure_crosswalk.py",
  "code/extract_question_options.py"
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
    "family_count_crosswalk.csv",
    "structural_eligibility.csv",
    "dataset_variable_overrides.csv",
    "two_stage_indicator_overrides.csv",
    "expenditure_crosswalk_103base.csv",
    "variable_crosswalk.csv",
    "question_codex_comparison.csv"
  )
)

bundle_files <- c(
  pipeline_files,
  support_files,
  test_files,
  generator_files,
  question_option_files,
  crosswalk_files,
  "data/raw_data/114年文健站營運單位清冊.csv",
  "data/processed_data/05_reference/care_station_town_year_panel_long.csv"
)
bundle_check <- tibble(
  file_role = c(
    rep("pipeline_code", length(pipeline_files)),
    rep("documentation", length(support_files)),
    rep("test", length(test_files)),
    rep("generator", length(generator_files)),
    rep("question_options", length(question_option_files)),
    rep("crosswalk", length(crosswalk_files)),
    "care_station_roster",
    "care_station_panel"
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

# Inspect only files that the manifest actually sends. Files elsewhere in the
# working project (for example an authorised local .RData used for diagnosis)
# are not part of the transfer package and must not create a false failure.
transfer_candidates <- bundle_files[file.exists(bundle_files)]
prohibited_transfer_files <- transfer_candidates[
  basename(transfer_candidates) %in% c(".RData", ".Rhistory") |
    str_detect(str_to_lower(transfer_candidates), "[.]rds$")
]
if (length(prohibited_transfer_files) > 0L) {
  stop(
    "Offline transfer bundle contains prohibited session or data files: ",
    paste(prohibited_transfer_files, collapse = ", ")
  )
}

message(
  "Offline transfer bundle passed: ",
  nrow(bundle_check),
  " files checked."
)

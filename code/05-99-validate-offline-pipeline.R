if (!isTRUE(getOption("indigenous.pipeline.ready"))) {
  source("code/01-00-load-packages.R", encoding = "UTF-8")
  source("code/03-00-survey-utils.R", encoding = "UTF-8")
}

expected_years <- c(2002L, 2006L, 2010L, 2014L, 2017L, 2021L)
validation_rows <- tibble(
  check_id = character(),
  status = character(),
  observed = character(),
  expected = character(),
  detail = character()
)

add_validation <- function(check_id, passed, observed, expected, detail = "") {
  validation_rows <<- bind_rows(
    validation_rows,
    tibble(
      check_id,
      status = ifelse(isTRUE(passed), "pass", "fail"),
      observed = as.character(observed),
      expected = as.character(expected),
      detail
    )
  )
}

combined <- readRDS("data/processed_data/04_analysis_ready/cross_year_combined_data.rds") %>%
  as_tibble()
actual_years <- sort(unique(combined$DATA_Y))
add_validation(
  "all_survey_years_present",
  identical(actual_years, expected_years),
  paste(actual_years, collapse = ";"),
  paste(expected_years, collapse = ";")
)

duplicate_keys <- combined %>% count(ID, DATA_Y) %>% filter(n > 1L) %>% nrow()
add_validation("id_year_unique", duplicate_keys == 0L, duplicate_keys, "0")

sample_audit <- read_csv(
  "output/checks/check_analysis_sample_exclusions.csv",
  show_col_types = FALSE
)
direct_race_counts <- combined %>%
  filter(DATA_Y %in% c(2014L, 2017L, 2021L)) %>%
  group_by(DATA_Y) %>%
  summarise(
    direct_non_indigenous_n = sum(RACE == "非原住民族", na.rm = TRUE),
    direct_missing_race_n = sum(is.na(RACE)),
    .groups = "drop"
  )
sample_compare <- sample_audit %>%
  inner_join(direct_race_counts, by = "DATA_Y") %>%
  mutate(
    matched = excluded_non_indigenous_n == direct_non_indigenous_n &
      excluded_missing_race_n == direct_missing_race_n
  )
add_validation(
  "analysis_sample_exclusion_matches_race",
  nrow(sample_compare) == 3L && all(sample_compare$matched),
  paste(sample_compare$DATA_Y[sample_compare$matched], collapse = ";"),
  "2014;2017;2021"
)

family_valid <- combined %>%
  filter(DATA_Y %in% c(2014L, 2017L)) %>%
  group_by(DATA_Y) %>%
  summarise(
    n = n(),
    n_family_valid = sum(!is.na(N_FAMILY)),
    n_indi_valid = sum(!is.na(N_INDI)),
    invalid_relation_n = sum(N_INDI > N_FAMILY, na.rm = TRUE),
    .groups = "drop"
  )
add_validation(
  "family_counts_complete_2014_2017",
  nrow(family_valid) == 2L &&
    all(family_valid$n_family_valid == family_valid$n) &&
    all(family_valid$n_indi_valid == family_valid$n) &&
    all(family_valid$invalid_relation_n == 0L),
  paste(
    family_valid$DATA_Y,
    family_valid$n_family_valid,
    family_valid$n_indi_valid,
    sep = ":",
    collapse = ";"
  ),
  "valid counts equal yearly N and N_INDI <= N_FAMILY"
)

recoding <- read_csv(
  "output/summary_statistics/income_expenditure_recoded/income_expenditure_recoding_table.csv",
  show_col_types = FALSE
)
bad_2002_money <- recoding %>%
  filter(
    survey_year == 2002L,
    str_detect(original_label, "萬"),
    needs_manual_review | is.na(recoded_midpoint)
  )
add_validation(
  "money_labels_2002_parsed",
  nrow(bad_2002_money) == 0L,
  nrow(bad_2002_money),
  "0",
  "All observed 2002 labels containing 萬 must parse."
)

bad_zero_or_missing <- recoding %>%
  filter(
    original_label %in% c("無此消費", "無此收入") &
      (recoded_midpoint != 0 | recode_note != "exact_zero_none")
  )
add_validation(
  "zero_labels_are_exact_zero",
  nrow(bad_zero_or_missing) == 0L,
  nrow(bad_zero_or_missing),
  "0"
)

coverage <- read_csv(
  "output/summary_statistics/coverage_summary.csv",
  show_col_types = FALSE
)
bad_2021_presence <- coverage %>%
  filter(
    `Survey Year` == 2021L,
    Variable %in% c("EDU", "MALE", "N_FAMILY", "N_INDI", "RACE", "RENT", "HOUSE_BELONG"),
    presence_status == "review_required"
  )
add_validation(
  "coverage_2021_resolved",
  nrow(bad_2021_presence) == 0L,
  nrow(bad_2021_presence),
  "0"
)

numeric_income_expenditure <- read_csv(
  "output/summary_statistics/income_expenditure_recoded/income_expenditure_numeric_summary.csv",
  show_col_types = FALSE
)
care_2017 <- numeric_income_expenditure %>%
  filter(
    sample_definition == "full_sample",
    survey_year == 2017L,
    variable == "EXP_CARE_EXPENDITURE"
  )
add_validation(
  "care_expenditure_2017_usable",
  nrow(care_2017) == 1L && care_2017$missing_pct <= 0.10,
  ifelse(nrow(care_2017) == 1L, care_2017$missing_pct, "missing"),
  "<= 0.10",
  "Indicator=no must be included as exact zero."
)

income_2014 <- numeric_income_expenditure %>%
  filter(
    sample_definition == "full_sample",
    survey_year == 2014L,
    str_detect(variable, "^INC_FAM_")
  )
add_validation(
  "family_income_2014_common_missingness_resolved",
  nrow(income_2014) > 0L && max(income_2014$missing_pct, na.rm = TRUE) <= 0.10,
  ifelse(nrow(income_2014) > 0L, max(income_2014$missing_pct, na.rm = TRUE), "missing"),
  "<= 0.10 or documented questionnaire-based exception"
)

write_check_file(
  validation_rows,
  "check_offline_pipeline_acceptance.csv"
)

manifest_paths <- c(
  list.files("data/processed_data", recursive = TRUE, full.names = TRUE),
  list.files("output", recursive = TRUE, full.names = TRUE)
)
manifest_paths <- manifest_paths[file.info(manifest_paths)$isdir %in% FALSE]
manifest <- tibble(
  path = manifest_paths,
  bytes = file.info(manifest_paths)$size,
  modified_at = format(file.info(manifest_paths)$mtime, "%Y-%m-%dT%H:%M:%S%z"),
  md5 = unname(tools::md5sum(manifest_paths))
) %>%
  arrange(path)
write_csv(manifest, "output/pipeline_manifest.csv")

failed <- validation_rows %>% filter(status == "fail")
if (nrow(failed) > 0L) {
  stop(
    "Offline pipeline acceptance failed: ",
    paste(failed$check_id, collapse = ", "),
    ". Review output/checks/check_offline_pipeline_acceptance.csv."
  )
}

message("Offline pipeline validation passed.")

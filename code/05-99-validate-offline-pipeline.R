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

add_validation <- function(check_id, passed, observed, expected, detail = "", status_override = NULL) {
  validation_rows <<- bind_rows(
    validation_rows,
    tibble(
      check_id,
      status = if (!is.null(status_override)) status_override else ifelse(isTRUE(passed), "pass", "fail"),
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
  group_by(DATA_Y) %>%
  summarise(
    n = n(),
    n_family_valid = sum(!is.na(N_FAMILY)),
    n_indi_valid = sum(!is.na(N_INDI)),
    invalid_relation_n = sum(N_INDI > N_FAMILY, na.rm = TRUE),
    .groups = "drop"
  )
add_validation(
  "family_counts_valid_all_years",
  identical(sort(family_valid$DATA_Y), expected_years) &&
    all(family_valid$invalid_relation_n == 0L),
  paste(
    family_valid$DATA_Y,
    family_valid$n_family_valid,
    family_valid$n_indi_valid,
    sep = ":",
    collapse = ";"
  ),
  "all six years satisfy N_INDI <= N_FAMILY wherever both values exist"
)

respondent_unit_ok <- all(c("RESPONDENT_UNIT", "RESPONDENT_UNIT_SOURCE") %in% names(combined)) &&
  all(!is.na(combined$RESPONDENT_UNIT)) && all(!is.na(combined$RESPONDENT_UNIT_SOURCE))
add_validation(
  "respondent_unit_present",
  respondent_unit_ok,
  ifelse(respondent_unit_ok, paste(sort(unique(combined$RESPONDENT_UNIT)), collapse = ";"), "missing"),
  "six years non-missing"
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

unmapped_path <- file.path(CHECKS_DIR, "check_unmapped_demographic_values.csv")
categorical_unmapped <- if (file.exists(unmapped_path)) {
  read_csv(unmapped_path, show_col_types = FALSE) %>%
    group_by(data_year, integrated_var) %>%
    summarise(unmapped_n = sum(frequency, na.rm = TRUE), .groups = "drop") %>%
    left_join(combined %>% count(DATA_Y, name = "sample_n"), by = c("data_year" = "DATA_Y")) %>%
    mutate(unmapped_rate = unmapped_n / sample_n)
} else tibble()
bad_categorical_unmapped <- categorical_unmapped %>% filter(unmapped_rate >= 0.05)
add_validation(
  "categorical_unmapped_rate",
  file.exists(unmapped_path) && nrow(bad_categorical_unmapped) == 0L,
  ifelse(
    file.exists(unmapped_path),
    paste(paste(bad_categorical_unmapped$data_year, bad_categorical_unmapped$integrated_var,
      round(bad_categorical_unmapped$unmapped_rate, 4), sep = ":"), collapse = ";"),
    "missing check"
  ),
  "each observed categorical variable-year has unmapped rate < 5%"
)

summary_expected_vars <- unique(c(
  "MALE", "AGE_GROUP", "AGE_GROUP_HARMONIZED", "AGE_MEASURE_TYPE", "EDU", "RACE",
  "N_FAMILY", "N_INDI", "N_INDI_UNDER6", "N_INDI_7_15", "N_INDI_16_54",
  "N_INDI_55_64", "N_INDI_65PLUS", "N_INDI_55PLUS", "HAS_INDI_55PLUS",
  "HAS_INDI_65PLUS", "HOUSE_BELONG", "RENT", "RESPONDENT_UNIT",
  "RESPONDENT_UNIT_SOURCE",
  names(combined)[str_detect(names(combined), "(_INCOME|_EXPENDITURE)$")]
))
summary_observed_vars <- unique(coverage$Variable)
missing_summary_vars <- setdiff(summary_expected_vars, summary_observed_vars)
add_validation(
  "summary_covers_all_integrated_vars",
  length(missing_summary_vars) == 0L,
  paste(missing_summary_vars, collapse = ";"),
  "all analysis variables and integrated income/expenditure fields appear in coverage_summary.csv"
)

recoded_coverage <- read_csv(
  "output/summary_statistics/income_expenditure_recoded/income_expenditure_coverage_summary.csv",
  show_col_types = FALSE
)
coverage_identity_ok <- coverage %>%
  filter(Present == 1L) %>%
  mutate(
    accounted_n = `Valid N` + `Response Missing N` + `Structural Missing N`,
    matched = accounted_n == `Eligible N`
  ) %>%
  summarise(ok = all(matched, na.rm = TRUE)) %>%
  pull(ok)
recoded_identity_ok <- recoded_coverage %>%
  mutate(
    accounted_n = `Valid N` + `Response Missing N` + `Structural Missing N`,
    matched = accounted_n == `Eligible N`
  ) %>%
  summarise(ok = all(matched, na.rm = TRUE)) %>%
  pull(ok)
structural_rows_present <- any(
  coverage$`Survey Year` == 2002L &
    coverage$Variable %in% c(
      "EXP_EDU_BOOKS_COMBINED_EXPENDITURE", "EXP_TRAVEL_EXPENDITURE",
      "N_INDI_UNDER6", "N_INDI_65PLUS"
    ) & coverage$`Structural Missing N` > 0L
) && any(
  coverage$`Survey Year` == 2014L &
    str_detect(coverage$Variable, "^INC_FAM_") &
    coverage$`Structural Missing N` > 0L
)
add_validation(
  "structural_eligibility_applied_to_coverage",
  isTRUE(coverage_identity_ok) && isTRUE(recoded_identity_ok) && structural_rows_present &&
    all(recoded_coverage$structural_missing_status == "evaluated_from_structural_eligibility"),
  paste0(
    "coverage_identity=", coverage_identity_ok,
    "; recoded_identity=", recoded_identity_ok,
    "; structural_rows=", structural_rows_present
  ),
  "2002 split-form, 2014 i1 and F14 rules applied; valid + response missing + structural missing = eligible"
)

numeric_income_expenditure <- read_csv(
  "output/summary_statistics/income_expenditure_recoded/income_expenditure_numeric_summary.csv",
  show_col_types = FALSE
)

baseline_candidates <- c(
  Sys.getenv("OFFLINE_BASELINE_DIR", unset = ""),
  "output_before_v2_v3_20260803",
  "offline_baseline/pre_v2_v3_output"
)
baseline_candidates <- baseline_candidates[baseline_candidates != ""]
baseline_summary_candidates <- file.path(
  baseline_candidates,
  "summary_statistics/income_expenditure_recoded/income_expenditure_numeric_summary.csv"
)
baseline_summary_path <- baseline_summary_candidates[file.exists(baseline_summary_candidates)][1]
if (is.na(baseline_summary_path)) {
  stop(
    "Cannot find the pre-rerun numeric summary. Checked: ",
    paste(baseline_summary_candidates, collapse = ", "),
    ". Set OFFLINE_BASELINE_DIR to the archived output directory."
  )
}
baseline_numeric_income_expenditure <- read_csv(
  baseline_summary_path,
  show_col_types = FALSE
)

metric_equal <- function(before, after, tolerance = 1e-8) {
  (is.na(before) & is.na(after)) |
    (!is.na(before) & !is.na(after) & abs(before - after) <= tolerance)
}

before_after <- baseline_numeric_income_expenditure %>%
  inner_join(
    numeric_income_expenditure,
    by = c("sample_definition", "survey_year", "variable"),
    suffix = c("_before", "_after")
  ) %>%
  mutate(
    valid_n_equal = valid_n_before == valid_n_after,
    mean_equal = metric_equal(mean_before, mean_after),
    median_equal = metric_equal(median_before, median_after),
    sd_equal = metric_equal(sd_before, sd_after),
    mean_delta = mean_after - mean_before,
    median_delta = median_after - median_before,
    expected_unchanged = survey_year %in% c(2014L, 2017L, 2021L) &
      str_starts(variable, "EXP_") &
      !str_detect(variable, "TOTAL_(DERIVED|REPORTED)")
  )
write_check_file(
  before_after %>% arrange(sample_definition, survey_year, variable),
  "check_income_expenditure_before_after.csv"
)
unexpected_changes <- before_after %>%
  filter(
    expected_unchanged,
    !valid_n_equal | !mean_equal | !median_equal
  )
add_validation(
  "unchanged_expenditure_matches_baseline",
  nrow(unexpected_changes) == 0L,
  paste(
    paste(
      unexpected_changes$sample_definition,
      unexpected_changes$survey_year,
      unexpected_changes$variable,
      sep = ":"
    ),
    collapse = ";"
  ),
  "2014/2017/2021 non-total expenditure valid_n, mean and median equal the archived pre-rerun baseline"
)

two_stage_2010_vars <- paste0(
  c(
    "EXP_CARE", "EXP_CLEANING", "EXP_CLOTHING", "EXP_EDU_BOOKS_COMBINED",
    "EXP_FURNITURE", "EXP_LOAN_INTEREST", "EXP_OTHER", "EXP_TRAVEL"
  ),
  "_EXPENDITURE"
)
zero_variation <- numeric_income_expenditure %>%
  filter(
    sample_definition == "full_sample",
    survey_year == 2010L,
    variable %in% two_stage_2010_vars
  ) %>%
  filter(is.na(sd) | sd <= 0 | is.na(max) | max <= 0)
add_validation(
  "numeric_variable_has_variation",
  nrow(zero_variation) == 0L &&
    n_distinct(
      numeric_income_expenditure$variable[
        numeric_income_expenditure$sample_definition == "full_sample" &
          numeric_income_expenditure$survey_year == 2010L &
          numeric_income_expenditure$variable %in% two_stage_2010_vars
      ]
    ) == length(two_stage_2010_vars),
  paste(paste(zero_variation$survey_year, zero_variation$variable, sep = ":"), collapse = ";"),
  "all eight 2010 two-stage expenditure variables are present with sd > 0 and max > 0"
)

derived_2010 <- numeric_income_expenditure %>%
  filter(
    sample_definition == "full_sample",
    survey_year == 2010L,
    variable == "EXP_TOTAL_DERIVED_EXPENDITURE"
  )
add_validation(
  "derived_expenditure_2010_not_old_six_component_mean",
  nrow(derived_2010) == 1L && abs(derived_2010$mean - 24820.7) > 0.1,
  ifelse(nrow(derived_2010) == 1L, round(derived_2010$mean, 4), "missing"),
  "not 24820.7 (+/- 0.1)"
)

conflict_path <- file.path(CHECKS_DIR, "check_two_stage_indicator_conflict.csv")
indicator_conflicts <- if (file.exists(conflict_path)) {
  read_csv(conflict_path, show_col_types = FALSE) %>% filter(conflict_n > 0L)
} else tibble()
add_validation(
  "two_stage_indicator_amount_consistent",
  file.exists(conflict_path) && nrow(indicator_conflicts) == 0L,
  ifelse(file.exists(conflict_path), sum(indicator_conflicts$conflict_n, na.rm = TRUE), "missing check"),
  "0 conflicts"
)

indicator_directions <- if (file.exists(conflict_path)) {
  read_csv(conflict_path, show_col_types = FALSE) %>%
    mutate(
      has_explicit_no_label = str_detect(indicator_label_set, "(^|;)\\d+=(沒有|無)($|;)"),
      is_single_code_checkbox = str_detect(indicator_label_set, "^1=有$")
    )
} else tibble()
add_validation(
  "two_stage_indicator_label_direction",
  identical(sort(unique(indicator_directions$data_year)), c(2010L, 2014L, 2017L, 2021L)) &&
    all(indicator_directions$has_explicit_no_label | indicator_directions$is_single_code_checkbox),
  paste(
    paste(
      indicator_directions$data_year,
      indicator_directions$integrated_var,
      indicator_directions$has_explicit_no_label,
      indicator_directions$is_single_code_checkbox,
      sep = ":"
    ),
    collapse = ";"
  ),
  "each indicator has an explicit 沒有/無 label or is documented as a single-code checkbox"
)

indicator_check <- if (file.exists(conflict_path)) {
  read_csv(conflict_path, show_col_types = FALSE)
} else tibble()
explicit_no_2021 <- if ("explicit_no_n" %in% names(indicator_check)) {
  indicator_check %>%
    filter(data_year == 2021L) %>%
    summarise(n = sum(explicit_no_n, na.rm = TRUE)) %>%
    pull(n)
} else NA_real_
add_validation(
  "two_stage_indicator_2021_zero_reconciliation",
  identical(as.numeric(explicit_no_2021), 33921),
  explicit_no_2021,
  "33921"
)

rent_audit <- read_csv(file.path(CHECKS_DIR, "check_rent_eligibility_vs_valid.csv"), show_col_types = FALSE) %>%
  mutate(valid_rate = ifelse(rent_eligible_n > 0L, 1 - eligible_but_missing_rent_n / rent_eligible_n, NA_real_))
add_validation(
  "rent_valid_rate_by_year",
  nrow(rent_audit) == length(expected_years) && all(rent_audit$valid_rate > 0.90, na.rm = TRUE),
  paste(paste(rent_audit$DATA_Y, round(rent_audit$valid_rate, 4), sep = ":"), collapse = ";"),
  "> 0.90 each year"
)

age_group_audit <- combined %>%
  group_by(DATA_Y) %>%
  summarise(
    age_group_valid_rate = mean(!is.na(AGE_GROUP)),
    harmonized_valid_n = sum(!is.na(AGE_GROUP_HARMONIZED)),
    measure_types = paste(sort(unique(na.omit(AGE_MEASURE_TYPE))), collapse = ";"),
    .groups = "drop"
  )
add_validation(
  "age_group_harmonization_valid",
  nrow(age_group_audit) == length(expected_years) &&
    all(age_group_audit$age_group_valid_rate > 0.95) &&
    all(age_group_audit$harmonized_valid_n > 0L) &&
    all(age_group_audit$measure_types == "age_group") &&
    !"AGE_RAW" %in% names(combined),
  paste(paste(age_group_audit$DATA_Y, round(age_group_audit$age_group_valid_rate, 4), age_group_audit$measure_types, sep = ":"), collapse = ";"),
  "AGE_GROUP >95%, harmonized non-empty, measure type age_group, AGE_RAW absent"
)

family_age_path <- file.path(CHECKS_DIR, "check_family_indigenous_age_counts.csv")
family_age_audit <- if (file.exists(family_age_path)) read_csv(family_age_path, show_col_types = FALSE) else tibble()
add_validation(
  "family_indigenous_age_counts_valid",
  nrow(family_age_audit) == length(expected_years) &&
    all(family_age_audit$age_cells_mismatch_n[family_age_audit$DATA_Y >= 2006L] == 0L) &&
    all(family_age_audit$invalid_55plus_relation_n[family_age_audit$DATA_Y >= 2006L] == 0L) &&
    any(family_age_audit$DATA_Y == 2021L & family_age_audit$has_indi_55plus_n == 3103L &
      family_age_audit$has_indi_65plus_n == 1807L & family_age_audit$indi_55plus_total == 4362),
  ifelse(nrow(family_age_audit), paste(paste(family_age_audit$DATA_Y, family_age_audit$age_cells_mismatch_n, sep = ":"), collapse = ";"), "missing check"),
  "2006-2021 cell sums match N_INDI; 2021 55+/65+ benchmarks match"
)

reported_summary <- numeric_income_expenditure %>%
  filter(sample_definition == "full_sample", variable == "EXP_TOTAL_REPORTED_EXPENDITURE")
reported_recoding <- recoding %>% filter(variable == "EXP_TOTAL_REPORTED_EXPENDITURE")
add_validation(
  "reported_expenditure_total_only_2002",
  nrow(reported_summary) == 1L && reported_summary$survey_year == 2002L &&
    reported_summary$valid_n == 13097L && abs(reported_summary$mean - 27289) < 1 &&
    !anyDuplicated(reported_recoding[c("survey_year", "variable", "original_value")]),
  paste(paste(reported_summary$survey_year, reported_summary$valid_n, round(reported_summary$mean, 2), sep = ":"), collapse = ";"),
  "2002 only; valid_n=13097; mean approximately 27289; no duplicate original values"
)

income_2014 <- numeric_income_expenditure %>%
  filter(
    sample_definition == "indigenous_analysis_sample",
    survey_year == 2014L,
    str_detect(variable, "^INC_FAM_")
  )
add_validation(
  "family_income_2014_common_missingness_resolved",
  nrow(income_2014) > 0L &&
    n_distinct(income_2014$valid_n) == 1L &&
    n_distinct(income_2014$missing_n) == 1L &&
    all(income_2014$valid_n > 0L),
  paste0(
    "valid_n=",
    paste(unique(income_2014$valid_n), collapse = ";"),
    "; missing_n=",
    paste(unique(income_2014$missing_n), collapse = ";")
  ),
  "one documented common missingness pattern with valid observations",
  "2014 household-income compnents share the same questionnaire-based missingness pattern; missing valuesremain NA."
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

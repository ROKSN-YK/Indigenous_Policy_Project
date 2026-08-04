source("code/01-00-load-packages.R")
source("code/03-00-survey-utils.R")

expressions <- parse("code/05-02-income-expenditure-recode-summary.R")
helper_names <- c(
  "clean_missing_text",
  "normalize_money_label",
  "parse_money_number",
  "parse_money_range"
)

for (expr in expressions) {
  if (
    is.call(expr) &&
      identical(expr[[1]], as.name("<-")) &&
      as.character(expr[[2]]) %in% helper_names
  ) {
    eval(expr, envir = globalenv())
  }
}

indicator_expressions <- parse("code/03-04-make-income-expense-data-from-02.R")
for (expr in indicator_expressions) {
  if (
    is.call(expr) &&
      identical(expr[[1]], as.name("<-")) &&
      identical(as.character(expr[[2]]), "classify_two_stage_values")
  ) {
    eval(expr, envir = globalenv())
  }
}

expect_equal <- function(actual, expected, label) {
  if (!isTRUE(all.equal(actual, expected, check.attributes = FALSE))) {
    stop(label, ": expected ", expected, ", got ", actual)
  }
}

expect_equal(parse_money_number("15萬元"), 150000, "15萬元")
expect_equal(parse_money_number("1萬5千元"), 15000, "1萬5千元")
expect_equal(parse_money_range("1萬~未滿1萬5千元")$midpoint, 12500, "mixed-unit range 1")
expect_equal(parse_money_range("1萬5千~未滿2萬元")$midpoint, 17500, "mixed-unit range 2")
expect_equal(parse_money_range("無此消費")$midpoint, 0, "zero expenditure")
expect_equal(parse_money_range("無此收入")$midpoint, 0, "zero income")
expect_equal(parse_money_range("未回答")$recode_note, "response_missing", "response missing")
expect_equal(parse_money_range("不知道/拒答")$recode_note, "response_missing", "refusal")
expect_equal(parse_money_range("15萬元以上")$lower, 150000, "upper-open lower bound")
expect_equal(parse_money_range("34166")$midpoint, 34166, "exact numeric amount")
expect_equal(parse_money_range("1e+05")$midpoint, 100000, "scientific exact amount")
expect_equal(parse_money_range("140,000元")$midpoint, 140000, "formatted exact amount")
expect_equal(parse_money_range("不需要支付租金")$midpoint, 0, "zero rent")

indicator_cases <- classify_two_stage_values(
  c("沒有", "無", "有", "未回答", NA_character_),
  c("", "沒有這項支出", "1,000-1,999 元", "", "")
)
expect_equal(indicator_cases$explicit_no, c(TRUE, TRUE, FALSE, FALSE, FALSE), "explicit no labels")
expect_equal(indicator_cases$zero_from_indicator, c(TRUE, TRUE, FALSE, FALSE, FALSE), "indicator zero guard")
expect_equal(indicator_cases$usable_amount, c(FALSE, FALSE, TRUE, FALSE, FALSE), "usable amount guard")
expect_equal(indicator_cases$indicator_missing, c(FALSE, FALSE, FALSE, TRUE, TRUE), "indicator missing labels")

age_fallback <- known_label_fallback(2010L, "AGE", "35 - 39 歲")
expect_equal(age_fallback$label, "30-39歲", "2010 age label fallback")
rent_fallback <- known_label_fallback(2017L, "RENT", "15,000元~未滿20,000元")
expect_equal(rent_fallback$label, "10,000-19,999元", "2017 rent label fallback")
race_fallback <- known_label_fallback(2010L, "RACE", "雅美族達悟")
expect_equal(race_fallback$label, "雅美族/達悟族", "race label fallback")

sample_data <- tibble(
  ID = 1:6,
  DATA_Y = c(2014L, 2014L, 2017L, 2017L, 2021L, 2021L),
  RACE = c("阿美族", "非原住民族", "泰雅族", "非原住民族", "排灣族", "非原住民族")
)
sample_result <- build_analysis_samples(sample_data)
expected_n <- c(`2014` = 1L, `2017` = 1L, `2021` = 1L)
actual_n <- sample_result$audit$indigenous_analysis_sample_n
names(actual_n) <- sample_result$audit$DATA_Y
expect_equal(actual_n, expected_n, "race filtering years")

# A duplicated source code is allowed only when the label text disambiguates it.
# Numeric-code fallback must not guess between two different answers.
ambiguous_code_lookup <- tibble(
  data_year = 2006L,
  integrated_var = "AGE",
  raw_var = "c2",
  raw_option_text_std = c("60-64歲", "65歲及以上"),
  raw_option_code_std = c("6", "6"),
  unified_code = c(6L, 7L),
  unified_label = c("60-64歲", "65歲及以上")
)
ambiguous_code_result <- harmonize_single_variable(
  dataset = tibble(c2 = 6),
  dataset_var = "c2",
  data_year = 2006L,
  integrated_var = "AGE",
  raw_var = "c2",
  label_lookup = ambiguous_code_lookup,
  output = c("label", "code"),
  unmapped = "na"
)
expect_equal(ambiguous_code_result$mapped, FALSE, "ambiguous numeric option code")

conflicting_crosswalk_path <- tempfile(fileext = ".csv")
write_csv(
  tibble(
    data_year = c(2014L, 2014L),
    integrated_var = c("TEST", "TEST"),
    raw_var = c("x", "x"),
    raw_option_order = c(NA_character_, NA_character_),
    raw_option_code = c("1", "1"),
    raw_option_text = c("同一選項", "同一選項"),
    unified_code = c(1L, 2L),
    unified_label = c("甲", "乙")
  ),
  conflicting_crosswalk_path
)
conflict_error <- tryCatch(
  {
    make_unified_lookup(conflicting_crosswalk_path)
    NULL
  },
  error = identity
)
if (is.null(conflict_error) ||
    !str_detect(conditionMessage(conflict_error), "Ambiguous raw option mappings")) {
  stop("Conflicting crosswalk mappings must stop the pipeline.")
}

# The 2002 survey has two source versions. A variable available only in 91_2
# must be resolved against meta_91_2.csv, never against the first 2002 file.
meta_dir <- tempfile("survey-meta-")
dir.create(meta_dir)
write_csv(
  tibble(variable = "id", label = "respondent id"),
  file.path(meta_dir, "meta_91_1.csv")
)
write_csv(
  tibble(variable = "x23_5", label = "23-5.education and books"),
  file.path(meta_dir, "meta_91_2.csv")
)
crosswalk_path <- tempfile(fileext = ".csv")
write_csv(
  tibble(
    data_year = c(2002L, 2002L),
    option_year = c("91_1", "91_2"),
    integrated_var = "EXP_EDU_BOOKS_COMBINED",
    raw_var = c(NA_character_, "23-5")
  ),
  crosswalk_path
)
resolved_2002 <- resolve_dataset_variables(
  crosswalk_path = crosswalk_path,
  import_index = tibble(
    data_year = c(2002L, 2002L),
    survey_tag = c("91_1", "91_2")
  ),
  survey_datasets = list(
    `91_1` = tibble(id = 1),
    `91_2` = tibble(id = 1, x23_5 = 1)
  ),
  meta_dir = meta_dir
)
expect_equal(
  resolved_2002 %>%
    filter(survey_tag == "91_2", raw_var == "23-5") %>%
    pull(dataset_var),
  "x23_5",
  "2002 survey-version-specific metadata"
)

active_age_paths <- c(
  "code/03-02-make-demographic-data-from-02.R",
  "code/04-01-aggregate-cross-year-data.R",
  "code/05-01-summary-statistics.R"
)
active_age_code <- paste(
  unlist(lapply(active_age_paths, readLines, warn = FALSE), use.names = FALSE),
  collapse = "\n"
)
# The aggregator may mention AGE_RAW only to remove a stale field from an old
# intermediate file. The current pipeline must never create or summarize it.
if (str_detect(active_age_code, "AGE_RAW\\s*(=|<-)|numeric_vars\\s*<-.*AGE_RAW")) {
  stop("AGE_RAW must not be created or summarized by the active pipeline.")
}

expenditure_crosswalk <- read_csv(
  "data/processed_data/03_crosswalks/unified_answer_crosswalk_expenditure.csv",
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
) %>% mutate(data_year = as.integer(data_year))
if (any(expenditure_crosswalk$integrated_var == "EXP_TOTAL_SYN")) {
  stop("EXP_TOTAL_SYN must be removed from the expenditure crosswalk.")
}
reported_years <- expenditure_crosswalk %>%
  filter(integrated_var == "EXP_TOTAL_REPORTED", !is.na(raw_var), raw_var != "") %>%
  pull(data_year) %>% unique()
expect_equal(reported_years, 2002L, "reported expenditure total year")

family_count_crosswalk <- read_csv(
  "data/processed_data/03_crosswalks/family_count_crosswalk.csv",
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
)
required_family_fields <- c(
  "n_indi_under6_var", "n_indi_7_15_var", "n_indi_16_54_var",
  "n_indi_55_64_var", "n_indi_65plus_var"
)
if (!all(required_family_fields %in% names(family_count_crosswalk))) {
  stop("F14 family age-cell mappings are incomplete.")
}

indicator_code <- paste(readLines("code/03-04-make-income-expense-data-from-02.R", warn = FALSE), collapse = "\n")
if (!str_detect(indicator_code, "indicator_label_set")) {
  stop("indicator_label_set is missing from the two-stage conflict implementation.")
}
if (!str_detect(indicator_code, 'c\\("沒有", "無"\\)')) {
  stop("Two-stage indicators must recognize both 沒有 and 無 as explicit no labels.")
}

acceptance_code <- paste(
  readLines("code/05-99-validate-offline-pipeline.R", warn = FALSE),
  collapse = "\n"
)
if (str_detect(acceptance_code, "Known limitation: F8 has 0%")) {
  stop("F8 must be behaviorally evaluated, not retained as a known-fail placeholder.")
}
if (!str_detect(acceptance_code, "33921")) {
  stop("The C3 reconciliation benchmark 33,921 is missing.")
}
conflict_path <- "output/checks/check_two_stage_indicator_conflict.csv"
if (file.exists(conflict_path)) {
  conflict_check <- read_csv(conflict_path, show_col_types = FALSE)
  if (!"indicator_label_set" %in% names(conflict_check)) {
    stop("indicator_label_set is missing from the generated two-stage conflict check.")
  }
}

message("Summary rule tests passed.")

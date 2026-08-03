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
conflict_path <- "output/checks/check_two_stage_indicator_conflict.csv"
if (file.exists(conflict_path)) {
  conflict_check <- read_csv(conflict_path, show_col_types = FALSE)
  if (!"indicator_label_set" %in% names(conflict_check)) {
    stop("indicator_label_set is missing from the generated two-stage conflict check.")
  }
}

message("Summary rule tests passed.")

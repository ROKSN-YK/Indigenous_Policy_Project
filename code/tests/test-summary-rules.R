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

message("Summary rule tests passed.")

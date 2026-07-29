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

message("Summary rule tests passed.")

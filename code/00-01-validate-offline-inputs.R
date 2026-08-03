if (!isTRUE(getOption("indigenous.pipeline.ready"))) {
  source("code/01-00-load-packages.R", encoding = "UTF-8")
  source("code/03-00-survey-utils.R", encoding = "UTF-8")
}

required_inputs <- c(
  "data/processed_data/02_metadata/question_options/question_options_91_1.csv",
  "data/processed_data/02_metadata/question_options/question_options_91_2.csv",
  "data/processed_data/02_metadata/question_options/question_options_95.csv",
  "data/processed_data/02_metadata/question_options/question_options_99.csv",
  "data/processed_data/02_metadata/question_options/question_options_103.csv",
  "data/processed_data/02_metadata/question_options/question_options_106.csv",
  "data/processed_data/02_metadata/question_options/question_options_110.csv",
  "data/processed_data/03_crosswalks/unified_answer_crosswalk_basic_info.csv",
  "data/processed_data/03_crosswalks/unified_answer_crosswalk_income.csv",
  "data/processed_data/03_crosswalks/unified_answer_crosswalk_expenditure.csv",
  "data/processed_data/03_crosswalks/family_count_crosswalk.csv",
  "data/processed_data/03_crosswalks/structural_eligibility.csv",
  "data/processed_data/03_crosswalks/expenditure_crosswalk_103base.csv",
  "data/processed_data/03_crosswalks/variable_crosswalk.csv",
  "data/processed_data/03_crosswalks/question_codex_comparison.csv"
)
missing_inputs <- required_inputs[!file.exists(required_inputs)]
if (length(missing_inputs) > 0L) {
  stop("Missing offline metadata/crosswalk inputs: ", paste(missing_inputs, collapse = ", "))
}

read_question_options <- function(year_tag) {
  read_csv(
    paste0(
      "data/processed_data/02_metadata/question_options/question_options_",
      year_tag,
      ".csv"
    ),
    show_col_types = FALSE
  )
}

validate_option_codes <- function(options, question_id, expected_codes, label) {
  actual <- options %>%
    filter(.data$question_id == !!question_id) %>%
    mutate(option_code = suppressWarnings(as.integer(option_code))) %>%
    arrange(option_code) %>%
    pull(option_code)
  if (!identical(actual, as.integer(expected_codes))) {
    stop(label, " option codes are incomplete or out of order.")
  }
}

question_91_1 <- read_question_options("91_1")
question_91_2 <- read_question_options("91_2")
validate_option_codes(question_91_1, "21", 1:8, "2002 version 91_1 question 21")
validate_option_codes(question_91_2, "21", 1:8, "2002 version 91_2 question 21")
validate_option_codes(question_91_2, "23-5", 1:7, "2002 version 91_2 question 23-5")
validate_option_codes(question_91_2, "23-6", 1:7, "2002 version 91_2 question 23-6")
if (any(question_91_1$question_id %in% c("23-5", "23-6"))) {
  stop("2002 version 91_1 must not inherit version-specific 23-5/23-6 questions.")
}

question_95 <- read_question_options("95")
c10 <- question_95 %>% filter(question_id == "C10") %>% arrange(option_code)
if (!identical(c10$option_text, c("男性", "女性"))) {
  stop("2006 C10 contains footer contamination or incorrect sex options.")
}

question_99 <- read_question_options("99")
for (qid in paste0("J7-", 1:8)) {
  validate_option_codes(question_99, qid, 1:11, paste("2010", qid))
}

question_103 <- read_question_options("103")
n4_codes <- question_103 %>%
  filter(question_id == "N4") %>%
  mutate(option_code = suppressWarnings(as.integer(option_code))) %>%
  filter(option_code %in% 7:9) %>%
  arrange(option_code)
if (!identical(n4_codes$option_code, 7:9) ||
    !identical(n4_codes$option_text, c("專科", "大學", "研究所及以上"))) {
  stop("2014 N4 questionnaire options 7-9 are incomplete or incorrect.")
}

for (qid in c("H2", "H3")) {
  validate_option_codes(question_103, qid, 1:13, paste("2014", qid))
  tail_options <- question_103 %>%
    filter(question_id == qid) %>%
    mutate(option_code = suppressWarnings(as.integer(option_code))) %>%
    filter(option_code %in% 11:13) %>%
    arrange(option_code)
  if (!identical(
    tail_options$option_text,
    c(
      "20,000-29,999 元",
      "30,000 元及以上，請記錄________元",
      "沒有這項收入"
    )
  )) {
    stop("2014 ", qid, " options 11-13 are incorrect.")
  }
}
for (qid in paste0("J7-", 1:10)) {
  validate_option_codes(question_103, qid, 1:11, paste("2014", qid))
}

for (spec in list(c("106", "M7"), c("110", "H7"))) {
  options <- read_question_options(spec[[1]])
  for (qid in paste0(spec[[2]], "-", 1:10)) {
    validate_option_codes(options, qid, 1:11, paste(spec[[1]], qid))
  }
}

basic_crosswalk <- read_csv(
  "data/processed_data/03_crosswalks/unified_answer_crosswalk_basic_info.csv",
  show_col_types = FALSE
)
n4_mapping <- basic_crosswalk %>%
  filter(data_year == 2014L, integrated_var == "EDU", str_to_lower(raw_var) == "n4") %>%
  mutate(raw_option_code = suppressWarnings(as.integer(raw_option_code))) %>%
  filter(raw_option_code %in% 7:9) %>%
  arrange(raw_option_code)
if (!identical(n4_mapping$raw_option_code, 7:9) ||
    !all(n4_mapping$unified_label == "專科以上")) {
  stop("2014 N4 codes 7-9 must all map to 專科以上.")
}

income_crosswalk <- read_csv(
  "data/processed_data/03_crosswalks/unified_answer_crosswalk_income.csv",
  show_col_types = FALSE
)
for (qid in c("H2", "H3")) {
  tail_mapping <- income_crosswalk %>%
    filter(data_year == 2014L, matched_question_id == qid) %>%
    mutate(raw_option_code = suppressWarnings(as.integer(raw_option_code))) %>%
    filter(raw_option_code %in% 11:13) %>%
    arrange(raw_option_code)
  if (!identical(tail_mapping$raw_option_code, 11:13) ||
      !identical(
        tail_mapping$mapping_rule,
        c("exact_range", "exact_open_upper", "exact_none")
      )) {
    stop("2014 ", qid, " crosswalk options 11-13 are incorrect.")
  }
}

invisible(make_unified_lookup(
  "data/processed_data/03_crosswalks/unified_answer_crosswalk_basic_info.csv"
))
invisible(make_unified_lookup(
  "data/processed_data/03_crosswalks/unified_answer_crosswalk_income.csv"
))
invisible(make_unified_lookup(
  "data/processed_data/03_crosswalks/unified_answer_crosswalk_expenditure.csv"
))

required_crosswalk_columns <- c(
  "data_year", "integrated_var", "raw_var", "raw_option_code",
  "raw_option_text", "unified_code", "unified_label"
)
for (path in c(
  "data/processed_data/03_crosswalks/unified_answer_crosswalk_basic_info.csv",
  "data/processed_data/03_crosswalks/unified_answer_crosswalk_income.csv",
  "data/processed_data/03_crosswalks/unified_answer_crosswalk_expenditure.csv"
)) {
  columns <- names(read_csv(path, n_max = 0, show_col_types = FALSE))
  missing_columns <- setdiff(required_crosswalk_columns, columns)
  if (length(missing_columns) > 0L) {
    stop(
      basename(path), " is missing required columns: ",
      paste(missing_columns, collapse = ", ")
    )
  }
}

message("Offline metadata and crosswalk inputs passed validation.")

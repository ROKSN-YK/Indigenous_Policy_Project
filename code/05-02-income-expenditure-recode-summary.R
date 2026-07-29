if (!isTRUE(getOption("indigenous.pipeline.ready"))) {
  source("code/01-00-load-packages.R", encoding = "UTF-8")
  source("code/03-00-survey-utils.R", encoding = "UTF-8")
}

# 00. Assumptions ----------------------------------------------------------
# This script adds a numeric recoding layer for INC_* and EXP_* variables.
# Assumptions:
# 1. The combined dataset stores harmonized response labels for income and
#    expenditure variables, and these labels are the primary source used to
#    parse money intervals.
# 2. variable_crosswalk.csv and question_codex_comparison.csv are used to
#    identify whether a source question is present by year; they do not
#    contain a full harmonized answer-option dictionary, so recoding relies on
#    the observed harmonized labels in the combined dataset.
# 3. "沒有這項收入" / "沒有這項支出" are treated as exact zero.
# 4. Lower-open intervals such as "未滿10,000元" or "9,999元及以下" use
#    upper_bound / 2 as the representative value.
# 5. Upper-open intervals such as "100,000元以上" use
#    lower_bound + previous_interval_width / 2 when a previous closed interval
#    exists for the same variable; otherwise the value is set to NA_real_ and
#    flagged for manual review.
# 6. Labels that cannot be stably parsed are not guessed; they are set to
#    NA_real_ and flagged with needs_manual_review = TRUE.

# 01. Read Inputs ----------------------------------------------------------
# Read the combined dataset and crosswalk files needed for variable coverage.

ensure_main_output_dirs()

recoded_output_dir <- "output/summary_statistics/income_expenditure_recoded"
ensure_dir(recoded_output_dir)

combined_data <- readRDS("data/processed_data/04_analysis_ready/cross_year_combined_data.rds") %>%
  as_tibble()

variable_crosswalk <- read_csv(
  "data/processed_data/03_crosswalks/variable_crosswalk.csv",
  show_col_types = FALSE
)

question_comparison <- read_csv(
  "data/processed_data/03_crosswalks/question_codex_comparison.csv",
  show_col_types = FALSE
)

# 02. Define Helpers -------------------------------------------------------
# Define reusable parsing, recoding, and summary helper functions.

clean_missing_text <- function(x) {
  x_chr <- as.character(x)
  x_chr <- str_trim(x_chr)
  x_chr[x_chr %in% c("", "NA", "N/A", "NULL", "null")] <- NA_character_
  x_chr
}

normalize_present_value <- function(x) {
  case_when(
    is.na(x) ~ NA_integer_,
    as.character(x) %in% c("1", "Yes", "YES", "yes", "TRUE", "True", "true") ~ 1L,
    as.character(x) %in% c("0", "No", "NO", "no", "FALSE", "False", "false") ~ 0L,
    TRUE ~ suppressWarnings(as.integer(as.character(x)))
  )
}

build_present_lookup <- function(crosswalk_df) {
  present_cols <- names(crosswalk_df)[str_detect(names(crosswalk_df), "_present$")]

  year_lookup <- tibble(
    present_col = present_cols,
    survey_year = case_when(
      present_col %in% c("91-1_present", "91-2_present") ~ 2002L,
      present_col == "95_present" ~ 2006L,
      present_col == "99_present" ~ 2010L,
      present_col == "103_present" ~ 2014L,
      present_col %in% c("106_present", "106-_present") ~ 2017L,
      present_col == "110_present" ~ 2021L,
      TRUE ~ NA_integer_
    )
  ) %>%
    filter(!is.na(survey_year))

  crosswalk_df %>%
    rename(raw_var = variable) %>%
    pivot_longer(
      cols = all_of(year_lookup$present_col),
      names_to = "present_col",
      values_to = "present_value"
    ) %>%
    left_join(year_lookup, by = "present_col") %>%
    transmute(
      raw_var = str_to_lower(raw_var),
      survey_year,
      present = normalize_present_value(present_value)
    ) %>%
    group_by(raw_var, survey_year) %>%
    summarise(
      present = max(present, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(present = ifelse(is.infinite(present), NA_integer_, present))
}

normalize_money_label <- function(label) {
  label %>%
    clean_missing_text() %>%
    str_replace_all("，", ",") %>%
    str_replace_all("－|–|—|~|～|至", "-") %>%
    str_replace_all("\\s+", "") %>%
    str_replace_all("萬餘元|萬多元", "萬元")
}

parse_money_number <- function(token) {
  token <- clean_missing_text(token)

  if (is.na(token)) {
    return(NA_real_)
  }

  token <- token %>%
    str_replace_all(",", "") %>%
    str_replace_all("元", "") %>%
    str_replace_all("以上|以下|及以上|及以下|未滿|約|大約|請記錄.*$", "")

  if (token == "") {
    return(NA_real_)
  }

  if (str_detect(token, "萬|千")) {
    ten_thousands <- str_match(token, "^([0-9.]+)萬")[, 2]
    thousands <- str_match(token, "(?:萬)?([0-9.]+)千")[, 2]
    remainder <- str_match(token, "(?:萬|千)([0-9.]+)$")[, 2]
    parsed <- coalesce(suppressWarnings(as.numeric(ten_thousands)), 0) * 10000 +
      coalesce(suppressWarnings(as.numeric(thousands)), 0) * 1000
    if (!is.na(remainder) && is.na(thousands)) {
      parsed <- parsed + suppressWarnings(as.numeric(remainder))
    }
    return(ifelse(parsed > 0, parsed, NA_real_))
  }

  suppressWarnings(as.numeric(token))
}

parse_money_range <- function(label) {
  normalized_label <- normalize_money_label(label)

  if (is.na(normalized_label)) {
    return(tibble(
      lower = NA_real_,
      upper = NA_real_,
      midpoint = NA_real_,
      recode_note = "missing_label",
      needs_manual_review = TRUE
    ))
  }

  zero_labels <- c(
    "沒有這項收入", "沒有這項支出", "無此項收入", "無此項支出",
    "無此收入", "無此消費", "無收入", "無支出", "無"
  )

  response_missing_labels <- c("未回答", "不知道/拒答", "不知道", "拒答")
  if (normalized_label %in% response_missing_labels) {
    return(tibble(
      lower = NA_real_,
      upper = NA_real_,
      midpoint = NA_real_,
      recode_note = "response_missing",
      needs_manual_review = FALSE
    ))
  }

  if (str_detect(normalized_label, "^[0-9,.]+(?:[eE][+-]?[0-9]+)?元?$")) {
    exact_amount <- parse_money_number(normalized_label)
    return(tibble(
      lower = exact_amount,
      upper = exact_amount,
      midpoint = exact_amount,
      recode_note = ifelse(is.na(exact_amount), "manual_review_unparsed_exact_amount", "exact_reported_amount"),
      needs_manual_review = is.na(exact_amount)
    ))
  }

  if (normalized_label %in% zero_labels) {
    return(tibble(
      lower = 0,
      upper = 0,
      midpoint = 0,
      recode_note = "exact_zero_none",
      needs_manual_review = FALSE
    ))
  }

  if (str_detect(normalized_label, "^未滿")) {
    upper_token <- str_remove(normalized_label, "^未滿")
    upper_bound <- parse_money_number(upper_token)

    return(tibble(
      lower = 0,
      upper = upper_bound,
      midpoint = ifelse(is.na(upper_bound), NA_real_, upper_bound / 2),
      recode_note = ifelse(is.na(upper_bound), "manual_review_unparsed_lower_open", "lower_open_half_upper"),
      needs_manual_review = is.na(upper_bound)
    ))
  }

  if (str_detect(normalized_label, "及以下|以下$")) {
    upper_token <- str_remove(normalized_label, "及以下|以下$")
    upper_bound <- parse_money_number(upper_token)

    return(tibble(
      lower = 0,
      upper = upper_bound,
      midpoint = ifelse(is.na(upper_bound), NA_real_, upper_bound / 2),
      recode_note = ifelse(is.na(upper_bound), "manual_review_unparsed_lower_open", "lower_open_half_upper"),
      needs_manual_review = is.na(upper_bound)
    ))
  }

  if (str_detect(normalized_label, "-")) {
    lower_token <- str_split(normalized_label, "-", simplify = TRUE)[1]
    upper_token <- str_split(normalized_label, "-", simplify = TRUE)[2]
    lower_bound <- parse_money_number(lower_token)
    upper_bound <- parse_money_number(str_remove(upper_token, "^未滿"))

    # "A元-未滿B元" represents A through B-1.  Using B as a continuous
    # boundary gives the same midpoint and avoids depending on integer units.

    return(tibble(
      lower = lower_bound,
      upper = upper_bound,
      midpoint = ifelse(
        is.na(lower_bound) | is.na(upper_bound),
        NA_real_,
        (lower_bound + upper_bound) / 2
      ),
      recode_note = ifelse(
        is.na(lower_bound) | is.na(upper_bound),
        "manual_review_unparsed_closed_range",
        "closed_range_midpoint"
      ),
      needs_manual_review = is.na(lower_bound) | is.na(upper_bound)
    ))
  }

  if (str_detect(normalized_label, "以上|及以上")) {
    lower_token <- str_remove(normalized_label, "及以上|以上$")
    lower_bound <- parse_money_number(lower_token)

    return(tibble(
      lower = lower_bound,
      upper = NA_real_,
      midpoint = NA_real_,
      recode_note = ifelse(is.na(lower_bound), "manual_review_unparsed_upper_open", "upper_open_pending_previous_width"),
      needs_manual_review = is.na(lower_bound)
    ))
  }

  tibble(
    lower = NA_real_,
    upper = NA_real_,
    midpoint = NA_real_,
    recode_note = "manual_review_unrecognized_label",
    needs_manual_review = TRUE
  )
}

resolve_upper_open_midpoints <- function(recoding_table) {
  recoding_table %>%
    group_by(variable, survey_year) %>%
    arrange(lower, upper, .by_group = TRUE) %>%
    mutate(
      interval_width = ifelse(!is.na(lower) & !is.na(upper), upper - lower, NA_real_),
      previous_width = lag(interval_width),
      recoded_midpoint = case_when(
        recode_note == "upper_open_pending_previous_width" & !is.na(lower) & !is.na(previous_width) ~ lower + previous_width / 2,
        TRUE ~ recoded_midpoint
      ),
      recode_note = case_when(
        recode_note == "upper_open_pending_previous_width" & !is.na(recoded_midpoint) ~ "upper_open_previous_width_half",
        recode_note == "upper_open_pending_previous_width" & is.na(recoded_midpoint) ~ "manual_review_missing_previous_width",
        TRUE ~ recode_note
      ),
      needs_manual_review = case_when(
        recode_note == "manual_review_missing_previous_width" ~ TRUE,
        recode_note == "upper_open_previous_width_half" ~ FALSE,
        TRUE ~ needs_manual_review
      )
    ) %>%
    ungroup() %>%
    select(-interval_width, -previous_width)
}

build_recoding_table <- function(data, target_vars) {
  long_data <- map_dfr(target_vars, function(one_var) {
    code_var <- paste0(one_var, "_CODE")

    tibble(
      survey_year = data$DATA_Y,
      variable = one_var,
      original_value = if (code_var %in% names(data)) as.character(data[[code_var]]) else NA_character_,
      original_label = if (paste0(one_var, "_RAW") %in% names(data)) {
        clean_missing_text(data[[paste0(one_var, "_RAW")]])
      } else {
        clean_missing_text(data[[one_var]])
      }
    )
  }) %>%
    filter(!is.na(original_label)) %>%
    distinct()

  parsed_table <- long_data %>%
    mutate(parsed = map(original_label, parse_money_range)) %>%
    unnest(parsed) %>%
    rename(recoded_midpoint = midpoint)

  resolve_upper_open_midpoints(parsed_table) %>%
    transmute(
      survey_year,
      variable,
      original_value,
      original_label,
      recoded_midpoint,
      recode_note,
      needs_manual_review
    ) %>%
    arrange(variable, survey_year, suppressWarnings(as.numeric(original_value)), original_label)
}

apply_recoding <- function(data, recoding_table, target_vars) {
  long_data <- map_dfr(target_vars, function(one_var) {
    code_var <- paste0(one_var, "_CODE")

    tibble(
      sample_definition = data$sample_definition,
      DATA_Y = data$DATA_Y,
      ID = if ("ID" %in% names(data)) data$ID else NA,
      variable = one_var,
      original_value = if (code_var %in% names(data)) as.character(data[[code_var]]) else NA_character_,
      original_label = if (paste0(one_var, "_RAW") %in% names(data)) {
        clean_missing_text(data[[paste0(one_var, "_RAW")]])
      } else {
        clean_missing_text(data[[one_var]])
      }
    )
  })

  long_data %>%
    left_join(
      recoding_table,
      by = c(
        "DATA_Y" = "survey_year",
        "variable",
        "original_value",
        "original_label"
      )
    ) %>%
    transmute(
      sample_definition,
      DATA_Y,
      ID,
      variable,
      original_value,
      recoded_midpoint
    )
}

append_derived_totals <- function(recoded_data) {
  total_specs <- list(
    INC_FAM_TOTAL_INCOME = c(
      "INC_FAM_WORK_INCOME", "INC_FAM_GOV_INCOME", "INC_FAM_TRANSFER_INCOME",
      "INC_FAM_INTEREST_INCOME", "INC_FAM_RENT_INCOME", "INC_FAM_OTHER_INCOME"
    ),
    EXP_TOTAL_SYN_EXPENDITURE = c(
      "EXP_FOOD_EXPENDITURE", "EXP_HOUSING_UTIL_EXPENDITURE",
      "EXP_FURNITURE_EXPENDITURE", "EXP_MEDICAL_EXPENDITURE",
      "EXP_TRANSPORT_COMM_EXPENDITURE", "EXP_CLOTHING_EXPENDITURE",
      "EXP_EDU_BOOKS_COMBINED_EXPENDITURE", "EXP_EDU_TUITION_EXPENDITURE",
      "EXP_BOOKS_EXPENDITURE",
      "EXP_TRAVEL_EXPENDITURE", "EXP_DINING_LODGING_EXPENDITURE",
      "EXP_ALCOHOL_EXPENDITURE", "EXP_CLEANING_EXPENDITURE",
      "EXP_LOAN_INTEREST_EXPENDITURE", "EXP_TAX_INS_GIFT_EXPENDITURE",
      "EXP_CARE_EXPENDITURE", "EXP_OTHER_EXPENDITURE"
    )
  )

  reported_names <- c(
    INC_FAM_TOTAL_INCOME = "INC_FAM_TOTAL_REPORTED_INCOME",
    EXP_TOTAL_SYN_EXPENDITURE = "EXP_TOTAL_REPORTED_EXPENDITURE"
  )
  derived_names <- c(
    INC_FAM_TOTAL_INCOME = "INC_FAM_TOTAL_DERIVED_INCOME",
    EXP_TOTAL_SYN_EXPENDITURE = "EXP_TOTAL_DERIVED_EXPENDITURE"
  )
  complete_names <- c(
    INC_FAM_TOTAL_INCOME = "INC_FAM_TOTAL_DERIVED_COMPLETE_INCOME",
    EXP_TOTAL_SYN_EXPENDITURE = "EXP_TOTAL_DERIVED_COMPLETE_EXPENDITURE"
  )

  base_data <- recoded_data %>%
    mutate(
      variable = recode(variable, !!!reported_names),
      component_expected_n = NA_integer_,
      component_valid_n = NA_integer_,
      component_complete = NA
    )

  derived <- map_dfr(sort(unique(recoded_data$DATA_Y)), function(one_year) {
    imap_dfr(total_specs, function(components, total_var) {
      if (total_var == "EXP_TOTAL_SYN_EXPENDITURE") {
        components <- if (one_year <= 2010L) {
          setdiff(components, c("EXP_EDU_TUITION_EXPENDITURE", "EXP_BOOKS_EXPENDITURE"))
        } else {
          setdiff(components, "EXP_EDU_BOOKS_COMBINED_EXPENDITURE")
        }
      }

      expected_components <- intersect(
        components,
        recoded_data %>% filter(DATA_Y == one_year) %>% pull(variable) %>% unique()
      )
      expected_n <- length(expected_components)
      if (expected_n == 0L) {
        return(tibble())
      }

      component_sums <- recoded_data %>%
        filter(DATA_Y == one_year, variable %in% expected_components) %>%
        group_by(sample_definition, DATA_Y, ID) %>%
        summarise(
          component_expected_n = expected_n,
          component_valid_n = sum(!is.na(recoded_midpoint)),
          component_complete = component_valid_n == component_expected_n,
          available_sum = ifelse(
            component_valid_n == 0L,
            NA_real_,
            sum(recoded_midpoint, na.rm = TRUE)
          ),
          complete_sum = ifelse(component_complete, available_sum, NA_real_),
          .groups = "drop"
        )

      bind_rows(
        component_sums %>%
          transmute(
            sample_definition, DATA_Y, ID,
            variable = unname(derived_names[[total_var]]),
            original_value = NA_character_,
            recoded_midpoint = available_sum,
            component_expected_n, component_valid_n, component_complete
          ),
        component_sums %>%
          transmute(
            sample_definition, DATA_Y, ID,
            variable = unname(complete_names[[total_var]]),
            original_value = NA_character_,
            recoded_midpoint = complete_sum,
            component_expected_n, component_valid_n, component_complete
          )
      )
    })
  })

  bind_rows(base_data, derived)
}

assert_education_component_exclusivity <- function(recoded_data) {
  audit <- recoded_data %>%
    filter(variable %in% c(
      "EXP_EDU_BOOKS_COMBINED_EXPENDITURE",
      "EXP_EDU_TUITION_EXPENDITURE",
      "EXP_BOOKS_EXPENDITURE"
    )) %>%
    group_by(DATA_Y, variable) %>%
    summarise(valid_n = sum(!is.na(recoded_midpoint)), .groups = "drop") %>%
    complete(
      DATA_Y = sort(unique(recoded_data$DATA_Y)),
      variable = c(
        "EXP_EDU_BOOKS_COMBINED_EXPENDITURE",
        "EXP_EDU_TUITION_EXPENDITURE",
        "EXP_BOOKS_EXPENDITURE"
      ),
      fill = list(valid_n = 0L)
    )

  invalid <- audit %>%
    pivot_wider(names_from = variable, values_from = valid_n, values_fill = 0L) %>%
    transmute(
      DATA_Y,
      combined_n = EXP_EDU_BOOKS_COMBINED_EXPENDITURE,
      tuition_n = EXP_EDU_TUITION_EXPENDITURE,
      books_n = EXP_BOOKS_EXPENDITURE,
      invalid = ifelse(
        DATA_Y <= 2010L,
        combined_n == 0L | tuition_n > 0L | books_n > 0L,
        combined_n > 0L
      )
    ) %>%
    filter(invalid)

  write_check_file(audit, "check_education_component_exclusivity.csv")
  if (nrow(invalid) > 0L) {
    stop(
      "Education/books component exclusivity failed for year(s): ",
      paste(invalid$DATA_Y, collapse = ", "),
      ". Check that 2002-2010 use COMBINED only and 2014+ use TUITION/BOOKS only."
    )
  }
}

summarise_recoded_numeric <- function(recoded_data) {
  recoded_data %>%
    group_by(sample_definition, DATA_Y, variable) %>%
    summarise(
      valid_n = sum(!is.na(recoded_midpoint)),
      missing_n = sum(is.na(recoded_midpoint)),
      missing_pct = missing_n / n(),
      mean = ifelse(valid_n > 0, mean(recoded_midpoint, na.rm = TRUE), NA_real_),
      median = ifelse(valid_n > 0, median(recoded_midpoint, na.rm = TRUE), NA_real_),
      sd = ifelse(valid_n > 1, sd(recoded_midpoint, na.rm = TRUE), NA_real_),
      min = ifelse(valid_n > 0, min(recoded_midpoint, na.rm = TRUE), NA_real_),
      max = ifelse(valid_n > 0, max(recoded_midpoint, na.rm = TRUE), NA_real_),
      .groups = "drop"
    ) %>%
    rename(survey_year = DATA_Y)
}

build_recoded_coverage <- function(recoded_data) {
  recoded_data %>%
    group_by(sample_definition, DATA_Y, variable) %>%
    summarise(
      Present = as.integer(
        str_detect(first(variable), "_DERIVED(_COMPLETE)?_") |
          any(!is.na(original_value)) | any(!is.na(recoded_midpoint))
      ),
      `Eligible N` = n(),
      `Valid N` = sum(!is.na(recoded_midpoint)),
      `Response Missing N` = sum(is.na(recoded_midpoint)),
      `Response Missing %` = `Response Missing N` / `Eligible N`,
      `Structural Missing N` = NA_integer_,
      `Structural Missing %` = NA_real_,
      `Structural Missing` = NA,
      structural_missing_status = "not_evaluated_in_recoded_coverage",
      coverage_basis = "recoded_midpoint",
      .groups = "drop"
    ) %>%
    rename(`Survey Year` = DATA_Y, Variable = variable)
}

# 03. Define Target Variables ----------------------------------------------
# Identify income and expenditure variables using crosswalk presence flags.

present_lookup <- bind_rows(
  build_present_lookup(variable_crosswalk),
  build_present_lookup(question_comparison)
) %>%
  group_by(raw_var, survey_year) %>%
  summarise(
    present = max(present, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(present = ifelse(is.infinite(present), NA_integer_, present))

target_vars <- names(combined_data)[str_detect(names(combined_data), "^(INC_|EXP_)")] %>%
  keep(~ !str_detect(.x, "(_RAW|_CODE|_VALUE_SOURCE)$"))

observed_var_years <- map_dfr(target_vars, function(one_var) {
  raw_var <- paste0(one_var, "_RAW")
  value <- if (raw_var %in% names(combined_data)) combined_data[[raw_var]] else combined_data[[one_var]]
  tibble(survey_year = combined_data$DATA_Y, variable = one_var, observed = !is.na(value)) %>%
    group_by(survey_year, variable) %>%
    summarise(observed_n = sum(observed), .groups = "drop")
})

target_var_years <- expand_grid(
  variable = target_vars,
  survey_year = sort(unique(combined_data$DATA_Y))
) %>%
  mutate(raw_var = str_to_lower(str_remove(variable, "(_INCOME|_EXPENDITURE)$"))) %>%
  left_join(present_lookup, by = c("raw_var", "survey_year")) %>%
  left_join(observed_var_years, by = c("variable", "survey_year")) %>%
  mutate(
    present = case_when(
      present %in% c(0L, 1L) ~ present,
      coalesce(observed_n, 0L) > 0L ~ 1L,
      TRUE ~ NA_integer_
    )
  )

write_check_file(
  target_var_years %>%
    filter(is.na(present)) %>%
    select(variable, survey_year, raw_var, observed_n) %>%
    arrange(variable, survey_year),
  "check_unknown_income_expenditure_presence.csv"
)

target_var_years <- target_var_years %>%
  filter(present == 1L) %>%
  select(variable, survey_year)

sample_result <- build_analysis_samples(combined_data)
combined_samples <- sample_result$data
write_check_file(sample_result$audit, "check_analysis_sample_exclusions.csv")

analysis_data <- combined_samples %>%
  select(any_of(c(
    "sample_definition", "ID", "DATA_Y", target_vars,
    paste0(target_vars, "_RAW"), paste0(target_vars, "_CODE")
  )))

# 04. Build Recoding Table -------------------------------------------------
# Build a variable-by-label lookup from observed income and expenditure values.

recoding_table <- build_recoding_table(analysis_data, target_vars) %>%
  semi_join(
    target_var_years,
    by = c("variable", "survey_year")
  )

# 05. Apply Recoding -------------------------------------------------------
# Apply the recoding lookup to respondent-level income and expenditure data.

recoded_base_dataset <- apply_recoding(analysis_data, recoding_table, target_vars) %>%
  semi_join(
    target_var_years %>% rename(DATA_Y = survey_year),
    by = c("variable", "DATA_Y")
  )

assert_education_component_exclusivity(recoded_base_dataset)
recoded_dataset <- append_derived_totals(recoded_base_dataset)

# 06. Summarise Numeric Outputs --------------------------------------------
# Produce yearly numeric summaries on recoded midpoint values.

income_expenditure_numeric_summary <- summarise_recoded_numeric(recoded_dataset)
income_expenditure_coverage_summary <- build_recoded_coverage(recoded_dataset)

# 07. Export Results -------------------------------------------------------
# Write recoding outputs to an isolated output directory.

write_csv(
  recoding_table,
  file.path(recoded_output_dir, "income_expenditure_recoding_table.csv")
)

write_check_file(
  recoding_table %>%
    filter(needs_manual_review) %>%
    arrange(survey_year, variable, original_value, original_label),
  "check_income_expenditure_manual_review.csv"
)

write_csv(
  recoded_dataset,
  file.path(recoded_output_dir, "income_expenditure_recoded_values.csv")
)

write_check_file(
  recoded_dataset %>%
    filter(str_detect(variable, "TOTAL_(REPORTED|DERIVED)")) %>%
    group_by(sample_definition, DATA_Y, variable) %>%
    summarise(
      valid_n = sum(!is.na(recoded_midpoint)),
      mean = ifelse(valid_n > 0L, mean(recoded_midpoint, na.rm = TRUE), NA_real_),
      complete_n = sum(component_complete %in% TRUE, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    arrange(sample_definition, DATA_Y, variable),
  "check_total_construction.csv"
)

write_csv(
  income_expenditure_numeric_summary,
  file.path(recoded_output_dir, "income_expenditure_numeric_summary.csv")
)

write_csv(
  income_expenditure_coverage_summary,
  file.path(recoded_output_dir, "income_expenditure_coverage_summary.csv")
)

coverage_path <- "output/summary_statistics/coverage_summary.csv"
if (file.exists(coverage_path)) {
  existing_coverage <- read_csv(coverage_path, show_col_types = FALSE)
  if (!"Valid N" %in% names(existing_coverage)) {
    existing_coverage <- existing_coverage %>%
      mutate(`Valid N` = NA_integer_)
  }
  existing_coverage <- existing_coverage %>%
    mutate(coverage_basis = "harmonized_label")

  updated_coverage <- existing_coverage %>%
    anti_join(
      income_expenditure_coverage_summary,
      by = c("sample_definition", "Survey Year", "Variable")
    ) %>%
    bind_rows(income_expenditure_coverage_summary) %>%
    arrange(sample_definition, Variable, `Survey Year`)

  write_csv(updated_coverage, coverage_path)
}

source("code/01-00-load-packages.R")
source("code/03-00-survey-utils.R")

ensure_main_output_dirs()
ensure_dir("data/processed_data/04_analysis_ready")
ensure_dir("data/processed_data/05_reference")

basic_info_path <- "data/processed_data/basic_info_from_02.rds"
demographic_path <- "data/processed_data/demographic_data_from_02.rds"
family_path <- "data/processed_data/family_data_from_02.rds"
income_expenditure_path <- "data/processed_data/03_income_expense/income_expenditure_data.rds"

required_paths <- c(
  basic_info_path,
  demographic_path,
  family_path,
  income_expenditure_path
)

missing_paths <- required_paths[!file.exists(required_paths)]

if (length(missing_paths) > 0) {
  stop(
    "Missing required harmonized files. Please run 03-01 to 03-04 from-02 scripts first:\n",
    paste(missing_paths, collapse = "\n")
  )
}

basic_info <- as_tibble(readRDS(basic_info_path))
demographic <- as_tibble(readRDS(demographic_path))
family <- as_tibble(readRDS(family_path))
income_expenditure <- as_tibble(readRDS(income_expenditure_path))

combined_data <- basic_info %>%
  left_join(demographic, by = c("ID", "DATA_Y")) %>%
  left_join(family, by = c("ID", "DATA_Y")) %>%
  left_join(income_expenditure, by = c("ID", "DATA_Y"))

validate_output_keys(combined_data, "cross_year_combined_data")

clean_missing_text <- function(x) {
  x_chr <- as.character(x)
  x_chr <- str_trim(x_chr)
  x_chr[x_chr %in% c("", "NA", "N/A", "NULL", "null")] <- NA_character_
  x_chr
}

coerce_numeric_text <- function(x) {
  x_chr <- clean_missing_text(x)
  x_chr <- str_replace_all(x_chr, ",", "")
  suppressWarnings(as.numeric(x_chr))
}

numeric_summary <- function(data, group_vars, value_vars) {
  value_vars <- setdiff(value_vars, group_vars)

  if (length(value_vars) == 0) {
    return(tibble())
  }

  data %>%
    select(all_of(c(group_vars, value_vars))) %>%
    pivot_longer(
      cols = all_of(value_vars),
      names_to = "variable",
      values_to = "value"
    ) %>%
    mutate(value = as.numeric(value)) %>%
    group_by(across(all_of(group_vars)), variable) %>%
    summarise(
      non_missing_n = sum(!is.na(value)),
      mean = ifelse(non_missing_n > 0, mean(value, na.rm = TRUE), NA_real_),
      median = ifelse(non_missing_n > 0, median(value, na.rm = TRUE), NA_real_),
      sd = ifelse(non_missing_n > 1, sd(value, na.rm = TRUE), NA_real_),
      min = ifelse(non_missing_n > 0, min(value, na.rm = TRUE), NA_real_),
      max = ifelse(non_missing_n > 0, max(value, na.rm = TRUE), NA_real_),
      .groups = "drop"
    )
}

categorical_summary <- function(data, group_vars, value_vars) {
  value_vars <- setdiff(value_vars, group_vars)

  if (length(value_vars) == 0) {
    return(tibble())
  }

  data %>%
    select(all_of(c(group_vars, value_vars))) %>%
    pivot_longer(
      cols = all_of(value_vars),
      names_to = "variable",
      values_to = "category"
    ) %>%
    mutate(category = clean_missing_text(category)) %>%
    filter(!is.na(category)) %>%
    group_by(across(all_of(group_vars)), variable, category) %>%
    summarise(n = n(), .groups = "drop_last") %>%
    mutate(share = n / sum(n)) %>%
    ungroup()
}

numeric_candidates <- combined_data %>%
  transmute(
    DATA_Y = DATA_Y,
    AGE_RAW = AGE_RAW,
    N_FAMILY = coerce_numeric_text(N_FAMILY),
    N_INDI = coerce_numeric_text(N_INDI)
  )

combined_with_numeric <- combined_data %>%
  select(-any_of(c("AGE_RAW", "N_FAMILY", "N_INDI"))) %>%
  bind_cols(numeric_candidates %>% select(-DATA_Y))

numeric_vars <- c("AGE_RAW", "N_FAMILY", "N_INDI")

categorical_vars <- names(combined_with_numeric) %>%
  keep(~ !.x %in% c("ID", "DATA_Y", "AGE_RAW", "N_FAMILY", "N_INDI")) %>%
  keep(~ !str_ends(.x, "_RAW")) %>%
  keep(~ !str_ends(.x, "_CODE"))

summary_by_year <- combined_with_numeric %>%
  count(DATA_Y, name = "n_records")

summary_by_year_region <- combined_with_numeric %>%
  mutate(
    CITY = coalesce(clean_missing_text(CITY), "未知地區"),
    COUNTY = coalesce(clean_missing_text(COUNTY), "未知地區")
  ) %>%
  count(DATA_Y, CITY, COUNTY, name = "n_records")

numeric_by_year <- numeric_summary(
  data = combined_with_numeric,
  group_vars = "DATA_Y",
  value_vars = numeric_vars
)

numeric_by_year_region <- numeric_summary(
  data = combined_with_numeric %>%
    mutate(
      CITY = coalesce(clean_missing_text(CITY), "未知地區"),
      COUNTY = coalesce(clean_missing_text(COUNTY), "未知地區")
    ),
  group_vars = c("DATA_Y", "CITY", "COUNTY"),
  value_vars = numeric_vars
)

categorical_by_year <- categorical_summary(
  data = combined_with_numeric,
  group_vars = "DATA_Y",
  value_vars = categorical_vars
)

categorical_by_year_region <- categorical_summary(
  data = combined_with_numeric %>%
    mutate(
      CITY = coalesce(clean_missing_text(CITY), "未知地區"),
      COUNTY = coalesce(clean_missing_text(COUNTY), "未知地區")
    ),
  group_vars = c("DATA_Y", "CITY", "COUNTY"),
  value_vars = categorical_vars
)

saveRDS(
  as.data.table(combined_with_numeric),
  "data/processed_data/04_analysis_ready/cross_year_combined_data.rds"
)

write_csv(
  combined_with_numeric,
  "data/processed_data/04_analysis_ready/cross_year_combined_data.csv"
)

write_csv(summary_by_year, "data/processed_data/05_reference/cross_year_summary_by_year.csv")
write_csv(summary_by_year_region, "data/processed_data/05_reference/cross_year_summary_by_year_region.csv")
write_csv(numeric_by_year, "data/processed_data/05_reference/cross_year_numeric_by_year.csv")
write_csv(numeric_by_year_region, "data/processed_data/05_reference/cross_year_numeric_by_year_region.csv")
write_csv(categorical_by_year, "data/processed_data/05_reference/cross_year_categorical_by_year.csv")
write_csv(categorical_by_year_region, "data/processed_data/05_reference/cross_year_categorical_by_year_region.csv")

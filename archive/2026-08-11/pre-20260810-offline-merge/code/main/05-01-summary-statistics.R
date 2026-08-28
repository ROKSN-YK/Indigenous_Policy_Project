source("code/01-00-load-packages.R")
source("code/03-00-survey-utils.R")

# 00. Read Crosswalk -------------------------------------------------------
# Read crosswalk files used to define target variables and yearly coverage.

ensure_main_output_dirs()

summary_output_dir <- "output/summary_statistics"
ensure_dir(summary_output_dir)

variable_crosswalk <- read_csv(
  "data/processed_data/03_crosswalks/variable_crosswalk.csv",
  show_col_types = FALSE
)

question_comparison <- read_csv(
  "data/processed_data/03_crosswalks/question_codex_comparison.csv",
  show_col_types = FALSE
)

basic_crosswalk <- read_csv(
  "data/processed_data/03_crosswalks/unified_answer_crosswalk_basic_info.csv",
  show_col_types = FALSE
)

income_crosswalk <- read_csv(
  "data/processed_data/03_crosswalks/unified_answer_crosswalk_income.csv",
  show_col_types = FALSE
)

expenditure_crosswalk <- read_csv(
  "data/processed_data/03_crosswalks/unified_answer_crosswalk_expenditure.csv",
  show_col_types = FALSE
)

# 01. Load Packages --------------------------------------------------------
# Package loading is centralized in code/01-00-load-packages.R.

# 02. Read Combined Dataset ------------------------------------------------
# Read the aggregated cross-year dataset produced by the existing pipeline.

combined_data <- readRDS("data/processed_data/04_analysis_ready/cross_year_combined_data.rds") %>%
  as_tibble()

# 03. Define Variables -----------------------------------------------------
# Build reusable metadata for main analysis variables only.

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

normalize_present_value <- function(x) {
  case_when(
    is.na(x) ~ NA_integer_,
    as.character(x) %in% c("1", "Yes", "YES", "yes", "TRUE", "True", "true") ~ 1L,
    as.character(x) %in% c("0", "No", "NO", "no", "FALSE", "False", "false") ~ 0L,
    TRUE ~ suppressWarnings(as.integer(as.character(x)))
  )
}

build_present_lookup <- function(crosswalk_df, source_name) {
  present_cols <- names(crosswalk_df)[str_detect(names(crosswalk_df), "_present$")]

  year_lookup <- tibble(
    present_col = present_cols,
    survey_year = case_when(
      present_col %in% c("91-1_present", "91-2_present") ~ 2002L,
      present_col == "95_present" ~ 2006L,
      present_col == "99_present" ~ 2010L,
      present_col == "103_present" ~ 2014L,
      present_col %in% c("106_present", "106-_present") ~ 2017L,
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
    mutate(
      raw_var = str_to_lower(raw_var),
      present = normalize_present_value(present_value),
      source = source_name
    ) %>%
    group_by(raw_var, survey_year) %>%
    summarise(
      present = max(present, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(present = ifelse(is.infinite(present), NA_integer_, present))
}

present_lookup <- bind_rows(
  build_present_lookup(variable_crosswalk, "variable_crosswalk"),
  build_present_lookup(question_comparison, "question_codex_comparison")
) %>%
  group_by(raw_var, survey_year) %>%
  summarise(
    present = max(present, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(present = ifelse(is.infinite(present), NA_integer_, present))

basic_var_map <- basic_crosswalk %>%
  filter(integrated_var %in% c("MALE", "EDU", "RACE", "HOUSE_BELONG", "RENT")) %>%
  transmute(
    variable = case_when(
      integrated_var == "MALE" ~ "MALE",
      integrated_var == "EDU" ~ "EDU",
      integrated_var == "RACE" ~ "RACE",
      TRUE ~ integrated_var
    ),
    survey_year = as.integer(data_year),
    raw_var = str_to_lower(raw_var)
  ) %>%
  distinct()

family_var_map <- tribble(
  ~variable, ~survey_year, ~raw_var,
  "N_FAMILY", 2002L, "q7a",
  "N_INDI", 2002L, "q7b",
  "N_FAMILY", 2006L, "c5",
  "N_INDI", 2006L, "c51",
  "N_FAMILY", 2010L, "f2",
  "N_INDI", 2010L, "f2_1",
  "N_FAMILY", 2014L, "f1",
  "N_INDI", 2014L, "f1_1",
  "N_FAMILY", 2017L, "f1",
  "N_INDI", 2017L, "f1_1_6",
  "N_FAMILY", 2021L, "a2",
  "N_INDI", 2021L, "a2_1_6"
)

income_var_map <- income_crosswalk %>%
  filter(
    integrated_var %in% c(
      "INC_FAM_TOTAL",
      "INC_FAM_WORK",
      "INC_FAM_GOV",
      "INC_FAM_TRANSFER",
      "INC_FAM_INTEREST",
      "INC_FAM_RENT",
      "INC_FAM_OTHER",
      "INC_PERS_WORK",
      "INC_PERS_GOV",
      "INC_PERS_TRANSFER",
      "INC_PERS_INTEREST",
      "INC_PERS_RENT",
      "INC_PERS_OTHER"
    )
  ) %>%
  transmute(
    variable = paste0(integrated_var, "_INCOME"),
    survey_year = as.integer(data_year),
    raw_var = str_to_lower(raw_var)
  ) %>%
  distinct()

expenditure_var_map <- expenditure_crosswalk %>%
  filter(str_starts(integrated_var, "EXP_")) %>%
  transmute(
    variable = paste0(integrated_var, "_EXPENDITURE"),
    survey_year = as.integer(data_year),
    raw_var = str_to_lower(raw_var)
  ) %>%
  distinct()

selected_var_map <- bind_rows(
  basic_var_map,
  family_var_map,
  income_var_map,
  expenditure_var_map
) %>%
  distinct() %>%
  left_join(present_lookup, by = c("raw_var", "survey_year")) %>%
  mutate(present = coalesce(present, 1L))

numeric_vars <- selected_var_map %>%
  filter(variable %in% c("N_FAMILY", "N_INDI")) %>%
  pull(variable) %>%
  unique()

categorical_vars <- selected_var_map %>%
  filter(variable %in% names(combined_data), !variable %in% numeric_vars) %>%
  pull(variable) %>%
  unique()

selected_vars <- c(numeric_vars, categorical_vars)

analysis_data <- combined_data %>%
  select(any_of(c("ID", "DATA_Y", "CITY", "COUNTY", selected_vars))) %>%
  mutate(
    across(any_of(c(categorical_vars, "CITY", "COUNTY")), clean_missing_text),
    across(any_of(numeric_vars), coerce_numeric_text)
  )

build_numeric_summary <- function(data, vars) {
  if (length(vars) == 0) {
    return(tibble())
  }

  data %>%
    select(DATA_Y, all_of(vars)) %>%
    pivot_longer(
      cols = all_of(vars),
      names_to = "Variable",
      values_to = "Value"
    ) %>%
    group_by(DATA_Y, Variable) %>%
    summarise(
      `Valid N` = sum(!is.na(Value)),
      Mean = ifelse(`Valid N` > 0, mean(Value, na.rm = TRUE), NA_real_),
      Median = ifelse(`Valid N` > 0, median(Value, na.rm = TRUE), NA_real_),
      SD = ifelse(`Valid N` > 1, sd(Value, na.rm = TRUE), NA_real_),
      Min = ifelse(`Valid N` > 0, min(Value, na.rm = TRUE), NA_real_),
      Max = ifelse(`Valid N` > 0, max(Value, na.rm = TRUE), NA_real_),
      `Missing N` = sum(is.na(Value)),
      `Missing %` = `Missing N` / n(),
      .groups = "drop"
    ) %>%
    rename(`Survey Year` = DATA_Y)
}

build_categorical_summary <- function(data, vars) {
  if (length(vars) == 0) {
    return(tibble())
  }

  counts <- data %>%
    select(DATA_Y, all_of(vars)) %>%
    pivot_longer(
      cols = all_of(vars),
      names_to = "Variable",
      values_to = "Category"
    ) %>%
    group_by(DATA_Y, Variable) %>%
    mutate(
      missing_n = sum(is.na(Category)),
      missing_pct = missing_n / n()
    ) %>%
    ungroup() %>%
    filter(!is.na(Category)) %>%
    group_by(DATA_Y, Variable, Category, missing_n, missing_pct) %>%
    summarise(Count = n(), .groups = "drop") %>%
    group_by(DATA_Y, Variable) %>%
    mutate(Percentage = Count / sum(Count)) %>%
    ungroup()

  counts %>%
    transmute(
      `Survey Year` = DATA_Y,
      Variable,
      Category,
      Count,
      Percentage,
      `Missing N` = missing_n,
      `Missing %` = missing_pct
    )
}

build_coverage_summary <- function(data, var_map) {
  eligible_base <- data %>%
    count(DATA_Y, name = "Eligible N") %>%
    rename(`Survey Year` = DATA_Y)

  var_year_grid <- tidyr::crossing(
    Variable = unique(var_map$variable),
    `Survey Year` = sort(unique(data$DATA_Y))
  )

  present_by_var_year <- var_map %>%
    group_by(variable, survey_year) %>%
    summarise(
      Present = as.integer(any(present == 1L)),
      .groups = "drop"
    ) %>%
    rename(
      Variable = variable,
      `Survey Year` = survey_year
    )

  response_missing <- data %>%
    select(DATA_Y, any_of(unique(var_map$variable))) %>%
    mutate(across(-DATA_Y, as.character)) %>%
    pivot_longer(
      cols = -DATA_Y,
      names_to = "Variable",
      values_to = "Value"
    ) %>%
    group_by(DATA_Y, Variable) %>%
    summarise(
      `Response Missing N` = sum(is.na(Value)),
      .groups = "drop"
    ) %>%
    rename(`Survey Year` = DATA_Y)

  var_year_grid %>%
    left_join(present_by_var_year, by = c("Variable", "Survey Year")) %>%
    left_join(eligible_base, by = "Survey Year") %>%
    left_join(response_missing, by = c("Variable", "Survey Year")) %>%
    mutate(
      Present = coalesce(Present, 0L),
      `Eligible N` = coalesce(`Eligible N`, 0L),
      `Response Missing N` = ifelse(Present == 1L, coalesce(`Response Missing N`, `Eligible N`), NA_integer_),
      `Response Missing %` = ifelse(
        Present == 1L & `Eligible N` > 0,
        `Response Missing N` / `Eligible N`,
        NA_real_
      ),
      `Structural Missing` = Present == 0L
    ) %>%
    arrange(Variable, `Survey Year`)
}

# 04. Sample Summary -------------------------------------------------------
# Produce sample counts by survey year and geography.

sample_by_year <- analysis_data %>%
  count(DATA_Y, name = "Sample N") %>%
  rename(`Survey Year` = DATA_Y)

sample_by_city <- analysis_data %>%
  mutate(CITY = coalesce(CITY, "未知地區")) %>%
  count(DATA_Y, CITY, name = "Sample N") %>%
  rename(`Survey Year` = DATA_Y, City = CITY)

sample_by_county <- analysis_data %>%
  mutate(COUNTY = coalesce(COUNTY, "未知地區")) %>%
  count(DATA_Y, COUNTY, name = "Sample N") %>%
  rename(`Survey Year` = DATA_Y, County = COUNTY)

# 05. Numeric Summary ------------------------------------------------------
# Summarise selected numeric variables by survey year.

numeric_summary <- build_numeric_summary(analysis_data, numeric_vars)

# 06. Categorical Summary --------------------------------------------------
# Summarise selected categorical variables by survey year.

categorical_summary <- build_categorical_summary(analysis_data, categorical_vars)

# 07. Coverage & Missing Summary -------------------------------------------
# Separate structural missing from response missing using present flags.

coverage_summary <- build_coverage_summary(analysis_data, selected_var_map)

# 08. Export Results -------------------------------------------------------
# Export all summary tables to one dedicated output folder.

write_csv(sample_by_year, file.path(summary_output_dir, "sample_by_year.csv"))
write_csv(sample_by_city, file.path(summary_output_dir, "sample_by_city.csv"))
write_csv(sample_by_county, file.path(summary_output_dir, "sample_by_county.csv"))
write_csv(numeric_summary, file.path(summary_output_dir, "numeric_summary.csv"))
write_csv(categorical_summary, file.path(summary_output_dir, "categorical_summary.csv"))
write_csv(coverage_summary, file.path(summary_output_dir, "coverage_summary.csv"))

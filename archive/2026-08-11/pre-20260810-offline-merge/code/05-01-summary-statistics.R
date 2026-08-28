if (!isTRUE(getOption("indigenous.pipeline.ready"))) {
  source("code/01-00-load-packages.R", encoding = "UTF-8")
  source("code/03-00-survey-utils.R", encoding = "UTF-8")
}

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

structural_eligibility <- read_csv(
  "data/processed_data/03_crosswalks/structural_eligibility.csv",
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
) %>%
  transmute(
    `Survey Year` = as.integer(data_year),
    SURVEY_TAG = as.character(survey_tag),
    Variable = case_when(
      str_starts(integrated_var, "INC_") ~ paste0(integrated_var, "_INCOME"),
      str_starts(integrated_var, "EXP_") ~ paste0(integrated_var, "_EXPENDITURE"),
      TRUE ~ integrated_var
    ),
    eligibility_rule,
    eligibility_variable,
    rule_detail
  ) %>%
  distinct()

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
  x_chr[str_detect(x_chr, "^沒有.*○11")] <- "沒有"
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

basic_var_map <- bind_rows(
  basic_crosswalk %>%
    filter(integrated_var %in% c("MALE", "EDU", "RACE", "HOUSE_BELONG", "RENT")) %>%
    transmute(variable = integrated_var, survey_year = as.integer(data_year), raw_var = str_to_lower(raw_var)),
  basic_crosswalk %>%
    filter(integrated_var == "AGE") %>%
    transmute(variable = "AGE_GROUP", survey_year = as.integer(data_year), raw_var = str_to_lower(raw_var)),
  basic_crosswalk %>%
    filter(integrated_var == "AGE") %>%
    transmute(variable = "AGE_MEASURE_TYPE", survey_year = as.integer(data_year), raw_var = str_to_lower(raw_var)),
  basic_crosswalk %>%
    filter(integrated_var == "AGE") %>%
    transmute(variable = "AGE_GROUP_HARMONIZED", survey_year = as.integer(data_year), raw_var = str_to_lower(raw_var))
) %>% distinct()

respondent_var_map <- tidyr::crossing(
  variable = c("RESPONDENT_UNIT", "RESPONDENT_UNIT_SOURCE"),
  survey_year = c(2002L, 2006L, 2010L, 2014L, 2017L, 2021L)
) %>% mutate(raw_var = variable)

family_var_map <- read_csv(
  "data/processed_data/03_crosswalks/family_count_crosswalk.csv",
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
) %>%
  transmute(
    survey_year = as.integer(data_year),
    N_FAMILY = str_to_lower(n_family_var),
    N_INDI = str_to_lower(n_indi_var)
  ) %>%
  pivot_longer(c(N_FAMILY, N_INDI), names_to = "variable", values_to = "raw_var")

family_age_var_map <- read_csv(
  "data/processed_data/03_crosswalks/family_count_crosswalk.csv",
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
) %>%
  transmute(
    survey_year = as.integer(data_year),
    N_INDI_UNDER6 = str_to_lower(n_indi_under6_var),
    N_INDI_7_15 = str_to_lower(n_indi_7_15_var),
    N_INDI_16_54 = str_to_lower(n_indi_16_54_var),
    N_INDI_55_64 = str_to_lower(n_indi_55_64_var),
    N_INDI_65PLUS = str_to_lower(n_indi_65plus_var)
  ) %>%
  pivot_longer(-survey_year, names_to = "variable", values_to = "raw_var") %>%
  bind_rows(
    tidyr::crossing(
      survey_year = c(2006L, 2010L, 2014L, 2017L, 2021L),
      variable = c("N_INDI_55PLUS", "HAS_INDI_55PLUS", "HAS_INDI_65PLUS")
    ) %>% mutate(raw_var = "derived_from_family_age_cells")
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
  family_age_var_map,
  respondent_var_map,
  income_var_map,
  expenditure_var_map
) %>%
  distinct() %>%
  left_join(present_lookup, by = c("raw_var", "survey_year"))

observed_var_years <- map_dfr(
  intersect(unique(selected_var_map$variable), names(combined_data)),
  function(one_var) {
    tibble(
      variable = one_var,
      survey_year = combined_data$DATA_Y,
      observed = !is.na(combined_data[[one_var]])
    ) %>%
      group_by(variable, survey_year) %>%
      summarise(observed_n = sum(observed), .groups = "drop")
  }
)

selected_var_map <- selected_var_map %>%
  left_join(observed_var_years, by = c("variable", "survey_year")) %>%
  mutate(
    present = case_when(
      present %in% c(0L, 1L) ~ present,
      coalesce(observed_n, 0L) > 0L ~ 1L,
      TRUE ~ NA_integer_
    )
  )

write_check_file(
  selected_var_map %>%
    filter(is.na(present)) %>%
    distinct(variable, survey_year, raw_var) %>%
    arrange(variable, survey_year),
  "check_unknown_variable_presence.csv"
)

numeric_vars <- selected_var_map %>%
  filter(variable %in% c(
    "N_FAMILY", "N_INDI", "N_INDI_UNDER6", "N_INDI_7_15", "N_INDI_16_54",
    "N_INDI_55_64", "N_INDI_65PLUS", "N_INDI_55PLUS"
  )) %>%
  pull(variable) %>%
  unique()

categorical_vars <- selected_var_map %>%
  filter(variable %in% names(combined_data), !variable %in% numeric_vars) %>%
  pull(variable) %>%
  unique()

selected_vars <- c(numeric_vars, categorical_vars)

analysis_data <- combined_data %>%
  select(any_of(c(
    "ID", "DATA_Y", "SURVEY_TAG", "CITY", "COUNTY",
    "ELIG_INC_FAM_COMPONENTS", selected_vars
  ))) %>%
  mutate(
    across(any_of(c(categorical_vars, "CITY", "COUNTY")), clean_missing_text),
    across(any_of(numeric_vars), coerce_numeric_text)
  )

sample_result <- build_analysis_samples(analysis_data)
analysis_samples <- sample_result$data
write_check_file(sample_result$audit, "check_analysis_sample_exclusions.csv")

build_numeric_summary <- function(data, vars) {
  if (length(vars) == 0) {
    return(tibble())
  }

  data %>%
    select(sample_definition, DATA_Y, all_of(vars)) %>%
    pivot_longer(
      cols = all_of(vars),
      names_to = "Variable",
      values_to = "Value"
    ) %>%
    group_by(sample_definition, DATA_Y, Variable) %>%
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
    select(sample_definition, DATA_Y, all_of(vars)) %>%
    pivot_longer(
      cols = all_of(vars),
      names_to = "Variable",
      values_to = "Category"
    ) %>%
    group_by(sample_definition, DATA_Y, Variable) %>%
    mutate(
      missing_n = sum(is.na(Category)),
      missing_pct = missing_n / n()
    ) %>%
    ungroup() %>%
    filter(!is.na(Category)) %>%
    group_by(sample_definition, DATA_Y, Variable, Category, missing_n, missing_pct) %>%
    summarise(Count = n(), .groups = "drop") %>%
    group_by(sample_definition, DATA_Y, Variable) %>%
    mutate(Percentage = Count / sum(Count)) %>%
    ungroup()

  counts %>%
    transmute(
      `Survey Year` = DATA_Y,
      sample_definition,
      Variable,
      Category,
      Count,
      Percentage,
      `Missing N` = missing_n,
      `Missing %` = missing_pct
    )
}

build_coverage_summary <- function(data, var_map, eligibility_rules) {
  eligible_base <- data %>%
    count(sample_definition, DATA_Y, name = "Eligible N") %>%
    rename(`Survey Year` = DATA_Y)

  var_year_grid <- tidyr::crossing(
    sample_definition = unique(data$sample_definition),
    Variable = unique(var_map$variable),
    `Survey Year` = sort(unique(data$DATA_Y))
  )

  present_by_var_year <- var_map %>%
    group_by(variable, survey_year) %>%
    summarise(
      Present = case_when(
        any(present == 1L, na.rm = TRUE) ~ 1L,
        any(present == 0L, na.rm = TRUE) ~ 0L,
        TRUE ~ NA_integer_
      ),
      .groups = "drop"
    ) %>%
    rename(
      Variable = variable,
      `Survey Year` = survey_year
    )

  long_values <- data %>%
    select(
      sample_definition, DATA_Y, SURVEY_TAG,
      any_of(c("HOUSE_BELONG", "ELIG_INC_FAM_COMPONENTS", unique(var_map$variable)))
    ) %>%
    mutate(
      rent_eligible = if ("HOUSE_BELONG" %in% names(.)) {
        ifelse(is.na(HOUSE_BELONG), NA, HOUSE_BELONG %in% c("租賃", "配住"))
      } else {
        TRUE
      },
      across(any_of(unique(var_map$variable)), as.character)
    ) %>%
    pivot_longer(
      cols = any_of(unique(var_map$variable)),
      names_to = "Variable",
      values_to = "Value"
    ) %>%
    left_join(
      eligibility_rules,
      by = c("DATA_Y" = "Survey Year", "SURVEY_TAG", "Variable")
    ) %>%
    mutate(
      structurally_ineligible = case_when(
        Variable == "RENT" ~ !is.na(rent_eligible) & !rent_eligible,
        eligibility_rule == "not_in_questionnaire" ~ TRUE,
        eligibility_rule == "conditional_on_variable" &
          eligibility_variable == "i1" ~ ELIG_INC_FAM_COMPONENTS %in% FALSE,
        TRUE ~ FALSE
      )
    )

  response_missing <- long_values %>%
    group_by(sample_definition, DATA_Y, Variable) %>%
    summarise(
      `Structural Missing N` = sum(structurally_ineligible, na.rm = TRUE),
      `Response Missing N` = sum(is.na(Value) & !structurally_ineligible),
      .groups = "drop"
    ) %>%
    rename(`Survey Year` = DATA_Y)

  var_year_grid %>%
    left_join(present_by_var_year, by = c("Variable", "Survey Year")) %>%
    left_join(eligible_base, by = c("sample_definition", "Survey Year")) %>%
    left_join(response_missing, by = c("sample_definition", "Variable", "Survey Year")) %>%
    mutate(
      `Eligible N` = coalesce(`Eligible N`, 0L),
      `Response Missing N` = ifelse(Present == 1L, coalesce(`Response Missing N`, `Eligible N`), NA_integer_),
      `Response Missing %` = ifelse(
        Present == 1L & `Eligible N` > 0,
        `Response Missing N` / `Eligible N`,
        NA_real_
      ),
      `Structural Missing N` = case_when(
        Present == 1L ~ coalesce(`Structural Missing N`, 0L),
        Present == 0L ~ `Eligible N`,
        TRUE ~ NA_integer_
      ),
      `Structural Missing %` = ifelse(
        `Eligible N` > 0,
        `Structural Missing N` / `Eligible N`,
        NA_real_
      ),
      `Structural Missing` = case_when(
        is.na(Present) ~ NA,
        Present == 0L ~ TRUE,
        TRUE ~ `Structural Missing N` > 0L
      ),
      `Valid N` = case_when(
        Present == 1L ~ pmax(
          `Eligible N` -
            coalesce(`Response Missing N`, 0L) -
            coalesce(`Structural Missing N`, 0L),
          0L
        ),
        TRUE ~ NA_integer_
      ),
      presence_status = case_when(
        Present == 1L ~ "present",
        Present == 0L ~ "not_present",
        TRUE ~ "review_required"
      )
    ) %>%
    arrange(Variable, `Survey Year`)
}

# 04. Sample Summary -------------------------------------------------------
# Produce sample counts by survey year and geography.

sample_by_year <- analysis_samples %>%
  count(sample_definition, DATA_Y, name = "Sample N") %>%
  rename(`Survey Year` = DATA_Y)

sample_by_city <- analysis_samples %>%
  mutate(CITY = coalesce(CITY, "未知地區")) %>%
  count(sample_definition, DATA_Y, CITY, name = "Sample N") %>%
  rename(`Survey Year` = DATA_Y, City = CITY)

sample_by_county <- analysis_samples %>%
  mutate(
    CITY = coalesce(CITY, "未知縣市"),
    COUNTY = coalesce(COUNTY, "未知地區")
  ) %>%
  count(sample_definition, DATA_Y, CITY, COUNTY, name = "Sample N") %>%
  rename(`Survey Year` = DATA_Y, City = CITY, County = COUNTY)

# 05. Numeric Summary ------------------------------------------------------
# Summarise selected numeric variables by survey year.

numeric_summary <- build_numeric_summary(analysis_samples, numeric_vars)

# 06. Categorical Summary --------------------------------------------------
# Summarise selected categorical variables by survey year.

categorical_summary <- build_categorical_summary(analysis_samples, categorical_vars)

# 07. Coverage & Missing Summary -------------------------------------------
# Separate structural missing from response missing using present flags.

coverage_summary <- build_coverage_summary(
  analysis_samples,
  selected_var_map,
  structural_eligibility
)

# 08. Export Results -------------------------------------------------------
# Export all summary tables to one dedicated output folder.

write_csv(sample_by_year, file.path(summary_output_dir, "sample_by_year.csv"))
write_csv(sample_by_city, file.path(summary_output_dir, "sample_by_city.csv"))
write_csv(sample_by_county, file.path(summary_output_dir, "sample_by_county.csv"))
write_csv(numeric_summary, file.path(summary_output_dir, "numeric_summary.csv"))
write_csv(categorical_summary, file.path(summary_output_dir, "categorical_summary.csv"))
write_csv(coverage_summary, file.path(summary_output_dir, "coverage_summary.csv"))

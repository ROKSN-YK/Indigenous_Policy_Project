if (!isTRUE(getOption("indigenous.pipeline.ready"))) {
  source("code/01-00-load-packages.R", encoding = "UTF-8")
  source("code/03-00-survey-utils.R", encoding = "UTF-8")
}

ensure_main_output_dirs()
ensure_dir("data/processed_data/04_analysis_ready")
ensure_dir("data/processed_data/05_reference")

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

pick_existing_path <- function(candidates, dataset_label) {
  matched <- candidates[file.exists(candidates)]

  if (length(matched) == 0) {
    stop(
      "Missing required harmonized file for ", dataset_label, ". Checked:\n",
      paste(candidates, collapse = "\n")
    )
  }

  matched[[1]]
}

basic_info_path <- pick_existing_path(
  c(
    "data/processed_data/basic_info_from_02.rds",
    "data/processed_data/basic_info.rds"
  ),
  "basic_info"
)

demographic_path <- pick_existing_path(
  c(
    "data/processed_data/demographic_data_from_02.rds",
    "data/processed_data/city_data.rds"
  ),
  "demographic / region"
)

family_path <- pick_existing_path(
  c(
    "data/processed_data/family_data_from_02.rds",
    "data/processed_data/family_data.rds"
  ),
  "family"
)

income_expenditure_path <- pick_existing_path(
  "data/processed_data/03_income_expense/income_expenditure_data.rds",
  "income_expenditure"
)

normalize_demographic_data <- function(data) {
  out <- as_tibble(data)

  if ("city" %in% names(out) && !"CITY" %in% names(out)) {
    out <- out %>% rename(CITY = city)
  }

  if ("county" %in% names(out) && !"COUNTY" %in% names(out)) {
    out <- out %>% rename(COUNTY = county)
  }

  if ("AGE" %in% names(out) && !"AGE_GROUP" %in% names(out)) {
    age_text <- clean_missing_text(out$AGE)

    out <- out %>%
      mutate(
        AGE_GROUP = age_text,
        AGE_GROUP_HARMONIZED = age_text,
        AGE_MEASURE_TYPE = ifelse(!is.na(age_text), "age_group", NA_character_)
      )
  }

  if ("MALE" %in% names(out) && !"MALE_CODE" %in% names(out)) {
    male_numeric <- suppressWarnings(as.integer(as.character(out$MALE)))
    male_label <- case_when(
      male_numeric == 1L ~ "男性",
      male_numeric == 0L ~ "非男性",
      clean_missing_text(out$MALE) %in% c("男", "男性") ~ "男性",
      clean_missing_text(out$MALE) %in% c("女", "女性", "非男性") ~ "非男性",
      TRUE ~ clean_missing_text(out$MALE)
    )

    male_code <- case_when(
      male_label == "男性" ~ 1L,
      male_label == "非男性" ~ 0L,
      TRUE ~ NA_integer_
    )

    out <- out %>%
      mutate(
        MALE_CODE = male_code,
        MALE = male_label
      )
  }

  out
}

normalize_income_expenditure_data <- function(data) {
  out <- as_tibble(data)

  rename_map <- c(
    INC_FAM_GOV = "INC_FAM_GOV_INCOME",
    INC_FAM_INTEREST = "INC_FAM_INTEREST_INCOME",
    INC_FAM_OTHER = "INC_FAM_OTHER_INCOME",
    INC_FAM_RENT = "INC_FAM_RENT_INCOME",
    INC_FAM_TOTAL = "INC_FAM_TOTAL_INCOME",
    INC_FAM_TRANSFER = "INC_FAM_TRANSFER_INCOME",
    INC_FAM_WORK = "INC_FAM_WORK_INCOME",
    INC_PERS_GOV = "INC_PERS_GOV_INCOME",
    INC_PERS_INTEREST = "INC_PERS_INTEREST_INCOME",
    INC_PERS_OTHER = "INC_PERS_OTHER_INCOME",
    INC_PERS_RENT = "INC_PERS_RENT_INCOME",
    INC_PERS_TRANSFER = "INC_PERS_TRANSFER_INCOME",
    INC_PERS_WORK = "INC_PERS_WORK_INCOME",
    EXP_ALCOHOL = "EXP_ALCOHOL_EXPENDITURE",
    EXP_BOOKS = "EXP_BOOKS_EXPENDITURE",
    EXP_CARE = "EXP_CARE_EXPENDITURE",
    EXP_CLEANING = "EXP_CLEANING_EXPENDITURE",
    EXP_CLOTHING = "EXP_CLOTHING_EXPENDITURE",
    EXP_DINING_LODGING = "EXP_DINING_LODGING_EXPENDITURE",
    EXP_EDU_TUITION = "EXP_EDU_TUITION_EXPENDITURE",
    EXP_EDU_BOOKS_COMBINED = "EXP_EDU_BOOKS_COMBINED_EXPENDITURE",
    EXP_FOOD = "EXP_FOOD_EXPENDITURE",
    EXP_FURNITURE = "EXP_FURNITURE_EXPENDITURE",
    EXP_HOUSING_UTIL = "EXP_HOUSING_UTIL_EXPENDITURE",
    EXP_LOAN_INTEREST = "EXP_LOAN_INTEREST_EXPENDITURE",
    EXP_MEDICAL = "EXP_MEDICAL_EXPENDITURE",
    EXP_OTHER = "EXP_OTHER_EXPENDITURE",
    EXP_TAX_INS_GIFT = "EXP_TAX_INS_GIFT_EXPENDITURE",
    EXP_TRANSPORT_COMM = "EXP_TRANSPORT_COMM_EXPENDITURE",
    EXP_TRAVEL = "EXP_TRAVEL_EXPENDITURE"
  )

  for (old_name in names(rename_map)) {
    new_name <- rename_map[[old_name]]
    if (old_name %in% names(out) && !new_name %in% names(out)) {
      out <- out %>% rename(!!new_name := all_of(old_name))
    }
  }

  out
}

basic_info <- as_tibble(readRDS(basic_info_path))
demographic <- normalize_demographic_data(readRDS(demographic_path))
family <- as_tibble(readRDS(family_path))
income_expenditure <- normalize_income_expenditure_data(readRDS(income_expenditure_path))

combined_data <- basic_info %>%
  left_join(demographic, by = c("ID", "DATA_Y")) %>%
  left_join(family, by = c("ID", "DATA_Y")) %>%
  left_join(income_expenditure, by = c("ID", "DATA_Y"))

respondent_unit_lookup <- tribble(
  ~DATA_Y, ~RESPONDENT_UNIT, ~RESPONDENT_UNIT_SOURCE,
  2002L, "economic_household_head", "91年問卷首頁：訪問對象為經濟戶長",
  2006L, "phone_respondent", "95年電話調查S1/S2：接聽電話受訪者",
  2010L, "household_member", "99年問卷：填表人戶內人口編號",
  2014L, "economic_household_head", "103年問卷封面：經濟戶長本人或代答",
  2017L, "economic_household_head", "106年問卷G部分：經濟戶長基本資料",
  2021L, "economic_household_head", "110年問卷B部分：經濟戶長基本資料"
)

combined_data <- combined_data %>%
  left_join(respondent_unit_lookup, by = "DATA_Y")

if (any(is.na(combined_data$RESPONDENT_UNIT))) {
  stop("RESPONDENT_UNIT is missing for one or more survey years.")
}

validate_output_keys(combined_data, "cross_year_combined_data")

family_join_audit <- family %>%
  group_by(DATA_Y) %>%
  summarise(
    source_n = n(),
    source_n_family_valid = sum(!is.na(N_FAMILY)),
    source_n_indi_valid = sum(!is.na(N_INDI)),
    .groups = "drop"
  ) %>%
  left_join(
    combined_data %>%
      group_by(DATA_Y) %>%
      summarise(
        combined_n = n(),
        combined_n_family_valid = sum(!is.na(N_FAMILY)),
        combined_n_indi_valid = sum(!is.na(N_INDI)),
        .groups = "drop"
      ),
    by = "DATA_Y"
  )

write_check_file(family_join_audit, "check_family_join_integrity.csv")

invalid_family_join <- family_join_audit %>%
  filter(
    source_n != combined_n |
      source_n_family_valid != combined_n_family_valid |
      source_n_indi_valid != combined_n_indi_valid
  )
if (nrow(invalid_family_join) > 0L) {
  stop(
    "Family variables changed during cross-year join for year(s): ",
    paste(invalid_family_join$DATA_Y, collapse = ", ")
  )
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
    mutate(across(all_of(value_vars), as.character)) %>%
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
    N_FAMILY = coerce_numeric_text(N_FAMILY),
    N_INDI = coerce_numeric_text(N_INDI)
  )

combined_with_numeric <- combined_data %>%
  select(-any_of(c("AGE_RAW", "N_FAMILY", "N_INDI"))) %>%
  bind_cols(numeric_candidates %>% select(-DATA_Y))

numeric_vars <- intersect(
  c(
    "N_FAMILY", "N_INDI", "N_INDI_UNDER6", "N_INDI_7_15",
    "N_INDI_16_54", "N_INDI_55_64", "N_INDI_65PLUS", "N_INDI_55PLUS"
    ),
  names(combined_with_numeric)
)

categorical_vars <- names(combined_with_numeric) %>%
  keep(~ !.x %in% c("ID", "SOURCE_ID", "DATA_Y", numeric_vars)) %>%
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

export_intermediate_csv <- tolower(
  Sys.getenv("EXPORT_INTERMEDIATE_CSV", unset = "false")
) %in% c("1", "true", "yes")

if (export_intermediate_csv) {
  message("EXPORT_INTERMEDIATE_CSV=true: writing optional analysis-ready CSV.")
  fwrite(
    as.data.table(combined_with_numeric),
    "data/processed_data/04_analysis_ready/cross_year_combined_data.csv"
  )
} else {
  message("Skipping optional analysis-ready CSV; downstream scripts use the RDS file.")
}

write_reference_csv <- function(data, path){
  dir.create(
    dirname(path),
    recursive = TRUE,
    showWarnings = FALSE
  )

  utils::write.csv(
    as.data.frame(data),
    file = path,
    row.names = FALSE,
    na = "",
    fileEncoding = "UTF-8"
  )
}

write_reference_csv(
  summary_by_year,
  "data/processed_data/05_reference/cross_year_summary_by_year.csv"
  )
write_reference_csv(
  summary_by_year_region,
  "data/processed_data/05_reference/cross_year_summary_by_year_region.csv"
  )
write_reference_csv(
  numeric_by_year,
  "data/processed_data/05_reference/cross_year_numeric_by_year.csv"
  )
write_reference_csv(
  numeric_by_year_region,
  "data/processed_data/05_reference/cross_year_numeric_by_year_region.csv"
  )
write_reference_csv(
  categorical_by_year,
  "data/processed_data/05_reference/cross_year_categorical_by_year.csv"
  )
write_reference_csv(
  categorical_by_year_region,
  "data/processed_data/05_reference/cross_year_categorical_by_year_region.csv"
  )

if (!isTRUE(getOption("indigenous.pipeline.ready"))) {
  source("code/01-00-load-packages.R", encoding = "UTF-8")
  source("code/03-00-survey-utils.R", encoding = "UTF-8")
}

# Mainline version: this script reads only 02-stage imported survey objects.

ensure_main_output_dirs()

context <- read_import_context()
import_index <- context$import_index
survey_datasets <- context$survey_datasets
crosswalk_path <- "data/processed_data/03_crosswalks/unified_answer_crosswalk_basic_info.csv"

family_crosswalk_vars <- read_csv(crosswalk_path, show_col_types = FALSE) %>%
  filter(integrated_var %in% c("HOUSE_BELONG", "RENT")) %>%
  distinct(data_year, integrated_var, raw_var)

resolved_vars <- resolve_dataset_variables(
  crosswalk_path = crosswalk_path,
  import_index = import_index,
  survey_datasets = survey_datasets
) %>%
  filter(integrated_var %in% c("HOUSE_BELONG", "RENT"))

label_lookup <- make_unified_lookup(crosswalk_path)

write_missing_variable_check(
  bind_rows(
    if (file.exists(file.path(CHECKS_DIR, "check_missing_variables_by_year.csv"))) {
      read_csv(file.path(CHECKS_DIR, "check_missing_variables_by_year.csv"), show_col_types = FALSE) %>%
        mutate(
          survey_tag = as.character(survey_tag),
          data_year = as.integer(data_year),
          integrated_var = as.character(integrated_var),
          expected_raw_var = as.character(expected_raw_var),
          resolved_dataset_var = as.character(resolved_dataset_var),
          status = as.character(status)
        ) %>%
        transmute(
          data_year,
          survey_tag,
          integrated_var,
          raw_var = expected_raw_var,
          dataset_var = resolved_dataset_var,
          status
        )
    } else {
      tibble()
    },
    resolved_vars
  ) %>% distinct()
)

family_count_crosswalk_path <- "data/processed_data/03_crosswalks/family_count_crosswalk.csv"
manual_family_map <- read_csv(
  family_count_crosswalk_path,
  col_types = cols(.default = col_character()),
  show_col_types = FALSE
) %>%
  mutate(data_year = as.integer(data_year))

rent_supplement_map <- tribble(
  ~data_year, ~main_var, ~supplement_var,
  2014, "g2", "g2o",
  2017, "h2", "h2o",
  2021, "c2", "c2o"
)

pull_raw_or_label <- function(dataset, dataset_var) {
  if (is.na(dataset_var) || !dataset_var %in% names(dataset)) {
    return(rep(NA_character_, nrow(dataset)))
  }

  get_raw_text(dataset[[dataset_var]])
}

pull_raw_numeric_text <- function(dataset, dataset_var){
  if(is.na(dataset_var) || !dataset_var %in% names(dataset)){
    return(rep(NA_character_, nrow(dataset)))
  }

  values <- dataset[[dataset_var]]

  if(inherits(values, "haven_labelled") || haven::is.labelled(values)){
    values <- haven::zap_labels(values)
  }

  as.character(values)
}

pull_numeric_or_na <- function(dataset, dataset_var) {
  if (
    is.na(dataset_var) ||
      dataset_var == "" ||
      !dataset_var %in% names(dataset)
  ) {
    return(rep(NA_real_, nrow(dataset)))
  }

  values <- dataset[[dataset_var]]
  is_labelled <- inherits(values, "haven_labelled") || haven::is.labelled(values)
  value_labels <- rep(NA_character_, length(values))

  if (is_labelled) {
    value_labels <- as.character(haven::as_factor(values, levels = "labels"))
  }

  special_missing <- !is.na(value_labels) & str_detect(
    str_trim(value_labels),
    "不知道|拒答|未回答|不詳"
  )
  numeric_values <- if (is_labelled) haven::zap_labels(values) else values
  result <- suppressWarnings(as.numeric(numeric_values))
  result[special_missing] <- NA_real_
  result
}

build_rent_source_vector <- function(main_raw, supplement_raw) {
  supplement_open_top <- !is.na(main_raw) &
    str_detect(main_raw, "以上|及以上") &
    !is.na(supplement_raw) & supplement_raw != ""
  case_when(
    supplement_open_top ~ "supplement_open_top",
    !is.na(main_raw) & main_raw != "" ~ "main",
    (is.na(main_raw) | main_raw == "") & !is.na(supplement_raw) & supplement_raw != "" ~ "supplement",
    TRUE ~ "missing"
  )
}

harmonize_rent_with_imputation <- function(dataset, data_year, survey_tag, resolved_rent_row, label_lookup) {
  if (nrow(resolved_rent_row) == 0 || is.na(resolved_rent_row$dataset_var[[1]])) {
    empty <- tibble(
      raw_value = rep(NA_character_, nrow(dataset)),
      label = rep(NA_character_, nrow(dataset)),
      code = rep(NA_integer_, nrow(dataset)),
      mapped = rep(FALSE, nrow(dataset)),
      fallback_used = rep(FALSE, nrow(dataset))
    )
    return(list(result = empty, check = tibble()))
  }

  main_var <- resolved_rent_row$dataset_var[[1]]
  main_raw <- pull_raw_or_label(dataset, main_var)
  supplement_row <- rent_supplement_map %>% filter(data_year == !!data_year)
  supplement_var <- if (nrow(supplement_row) == 0) NA_character_ else supplement_row$supplement_var[[1]]
  supplement_raw <- pull_raw_or_label(dataset, supplement_var)

  open_top <- !is.na(main_raw) &
    str_detect(main_raw, "以上|及以上") &
    !is.na(supplement_raw) & supplement_raw != ""

  imputed_raw <- case_when(
    is.na(main_raw) | main_raw == "" ~ supplement_raw,
    open_top ~ supplement_raw,
    TRUE ~ main_raw
  )

  temp_dataset <- dataset
  temp_dataset[[main_var]] <- imputed_raw

  harmonized <- harmonize_single_variable(
    dataset = temp_dataset,
    dataset_var = main_var,
    data_year = data_year,
    integrated_var = "RENT",
    raw_var = resolved_rent_row$raw_var[[1]],
    label_lookup = label_lookup,
    output = c("label", "code"),
    unmapped = "raw"
  )

  exact_supplement <- (open_top | (is.na(main_raw) | main_raw == "")) &
    !is.na(suppressWarnings(as.numeric(supplement_raw))) &
    suppressWarnings(as.numeric(supplement_raw)) > 0
  if (any(exact_supplement)) {
    harmonized$raw_value[exact_supplement] <- supplement_raw[exact_supplement]
    harmonized$label[exact_supplement] <- supplement_raw[exact_supplement]
    harmonized$code[exact_supplement] <- NA_integer_
    harmonized$mapped[exact_supplement] <- TRUE
  }

  rent_check <- tibble(
    data_year = data_year,
    survey_tag = survey_tag,
    main_var = main_var,
    supplement_var = supplement_var,
    rent_before_main = main_raw,
    rent_before_supplement = supplement_raw,
    rent_after_imputation = imputed_raw,
    rent_source = build_rent_source_vector(main_raw, supplement_raw),
    rent_harmonized = harmonized$label
  ) %>%
    count(
      data_year,
      survey_tag,
      main_var,
      supplement_var,
      rent_before_main,
      rent_before_supplement,
      rent_after_imputation,
      rent_source,
      rent_harmonized,
      name = "frequency"
    )

  list(result = harmonized, check = rent_check)
}

rent_checks_df <- tibble(
  data_year = integer(),
  survey_tag = character(),
  main_var = character(),
  supplement_var = character(),
  rent_before_main = character(),
  rent_before_supplement = character(),
  rent_after_imputation = character(),
  rent_source = character(),
  rent_harmonized = character(),
  frequency = integer()
)

family_count_checks_df <- tibble(
  data_year = integer(),
  survey_tag = character(),
  integrated_var = character(),
  expected_raw_var = character(),
  variable_exists = logical(),
  non_missing_n = integer(),
  similar_dataset_vars = character()
)

family_from_02 <- map_dfr(seq_len(nrow(import_index)), function(i) {
  dataset <- get_dataset_by_row(import_index, survey_datasets, i)
  data_year <- import_index$data_year[[i]]
  survey_tag <- import_index$survey_tag[[i]]
  survey_keys <- build_survey_keys(dataset, data_year, survey_tag)
  family_vars <- manual_family_map %>% filter(data_year == !!data_year)

  for (count_var in c("n_family_var", "n_indi_var")) {
    expected_var <- family_vars[[count_var]][[1]]
    integrated_name <- ifelse(count_var == "n_family_var", "N_FAMILY", "N_INDI")
    exists <- expected_var %in% names(dataset)
    similar <- names(dataset)[str_detect(names(dataset), fixed(str_remove(expected_var, "_[0-9]+$")))]
    family_count_checks_df <<- bind_rows(
      family_count_checks_df,
      tibble(
        data_year,
        survey_tag,
        integrated_var = integrated_name,
        expected_raw_var = expected_var,
        variable_exists = exists,
        non_missing_n = if (exists) sum(!is.na(dataset[[expected_var]])) else 0L,
        similar_dataset_vars = paste(similar, collapse = ";")
      )
    )
  }

  output <- tibble(
    ID = survey_keys$ID,
    DATA_Y = survey_keys$DATA_Y,
    N_FAMILY = pull_raw_numeric_text(dataset, family_vars$n_family_var[[1]]),
    N_INDI = pull_raw_numeric_text(dataset, family_vars$n_indi_var[[1]]),
    N_INDI_UNDER6 = pull_numeric_or_na(dataset, family_vars$n_indi_under6_var[[1]]),
    N_INDI_7_15 = pull_numeric_or_na(dataset, family_vars$n_indi_7_15_var[[1]]),
    N_INDI_16_54 = pull_numeric_or_na(dataset, family_vars$n_indi_16_54_var[[1]]),
    N_INDI_55_64 = pull_numeric_or_na(dataset, family_vars$n_indi_55_64_var[[1]]),
    N_INDI_65PLUS = pull_numeric_or_na(dataset, family_vars$n_indi_65plus_var[[1]]),
    HOUSE_BELONG = NA_character_,
    HOUSE_BELONG_RAW = NA_character_,
    HOUSE_BELONG_CODE = NA_integer_,
    RENT = NA_character_,
    RENT_RAW = NA_character_,
    RENT_CODE = NA_integer_
  ) %>%
    mutate(
      N_INDI_55PLUS = N_INDI_55_64 + N_INDI_65PLUS,
      HAS_INDI_55PLUS = ifelse(is.na(N_INDI_55PLUS), NA, N_INDI_55PLUS > 0),
      HAS_INDI_65PLUS = ifelse(is.na(N_INDI_65PLUS), NA, N_INDI_65PLUS > 0)
    )

  house_row <- resolved_vars %>%
    filter(data_year == !!data_year, integrated_var == "HOUSE_BELONG") %>%
    slice(1)

  if (nrow(house_row) > 0 && !is.na(house_row$dataset_var[[1]]) && house_row$dataset_var[[1]] %in% names(dataset)) {
    house_harmonized <- harmonize_single_variable(
      dataset = dataset,
      dataset_var = house_row$dataset_var[[1]],
      data_year = data_year,
      integrated_var = "HOUSE_BELONG",
      raw_var = house_row$raw_var[[1]],
      label_lookup = label_lookup,
      output = c("label", "code"),
      unmapped = "na"
    )
    output$HOUSE_BELONG <- house_harmonized$label
    output$HOUSE_BELONG_RAW <- house_harmonized$raw_value
    output$HOUSE_BELONG_CODE <- house_harmonized$code
  }

  rent_row <- resolved_vars %>%
    filter(data_year == !!data_year, integrated_var == "RENT") %>%
    slice(1)

  rent_result <- harmonize_rent_with_imputation(
    dataset = dataset,
    data_year = data_year,
    survey_tag = survey_tag,
    resolved_rent_row = rent_row,
    label_lookup = label_lookup
  )

  output$RENT <- rent_result$result$label
  output$RENT_RAW <- rent_result$result$raw_value
  output$RENT_CODE <- rent_result$result$code
  rent_checks_df <<- bind_rows(rent_checks_df, rent_result$check)

  validate_row_count(output, nrow(dataset), "family_data_from_02", data_year, survey_tag)
  output
})

validate_output_keys(family_from_02, "family_data_from_02")

family_age_count_audit <- family_from_02 %>%
  mutate(
    age_cells_sum = N_INDI_UNDER6 + N_INDI_7_15 + N_INDI_16_54 + N_INDI_55_64 + N_INDI_65PLUS,
    n_indi_numeric = suppressWarnings(as.numeric(N_INDI)),
    n_family_numeric = suppressWarnings(as.numeric(N_FAMILY))
  ) %>%
  group_by(DATA_Y) %>%
  summarise(
    sample_n = n(),
    structurally_ineligible_n = sum(is.na(age_cells_sum)),
    age_cells_match_n = sum(age_cells_sum == n_indi_numeric, na.rm = TRUE),
    age_cells_mismatch_n = sum(age_cells_sum != n_indi_numeric, na.rm = TRUE),
    invalid_55plus_relation_n = sum(N_INDI_55PLUS > n_indi_numeric | n_indi_numeric > n_family_numeric, na.rm = TRUE),
    has_indi_55plus_n = sum(HAS_INDI_55PLUS %in% TRUE, na.rm = TRUE),
    has_indi_65plus_n = sum(HAS_INDI_65PLUS %in% TRUE, na.rm = TRUE),
    indi_55plus_total = sum(N_INDI_55PLUS, na.rm = TRUE),
    .groups = "drop"
  )

write_check_file(family_age_count_audit, "check_family_indigenous_age_counts.csv")

invalid_family_age_counts <- family_age_count_audit %>%
  filter(
    (DATA_Y == 2002L & structurally_ineligible_n != sample_n) |
      (DATA_Y >= 2006L & (age_cells_mismatch_n > 0L | invalid_55plus_relation_n > 0L)) |
      (DATA_Y == 2021L & (has_indi_55plus_n != 3103L | has_indi_65plus_n != 1807L | indi_55plus_total != 4362))
  )
if (nrow(invalid_family_age_counts) > 0L) {
  stop("Family indigenous age-count validation failed for year(s): ", paste(invalid_family_age_counts$DATA_Y, collapse = ", "))
}

write_check_file(
  rent_checks_df %>%
    distinct() %>%
    arrange(data_year, survey_tag, main_var, supplement_var),
  "check_rent_imputation.csv"
)

write_check_file(
  family_count_checks_df %>%
    distinct() %>%
    arrange(data_year, survey_tag, integrated_var),
  "check_family_count_variables.csv"
)

write_check_file(
  family_from_02 %>%
    mutate(
      rent_eligible = HOUSE_BELONG %in% c("租賃", "配住"),
      rent_valid = !is.na(RENT)
    ) %>%
    group_by(DATA_Y) %>%
    summarise(
      sample_n = n(),
      rent_eligible_n = sum(rent_eligible, na.rm = TRUE),
      rent_valid_n = sum(rent_valid),
      eligible_but_missing_rent_n = sum(rent_eligible & !rent_valid, na.rm = TRUE),
      .groups = "drop"
    ),
  "check_rent_eligibility_vs_valid.csv"
)

saveRDS(as.data.table(family_from_02), "data/processed_data/family_data_from_02.rds")
write_csv(family_from_02, "output/family_data_from_02.csv")

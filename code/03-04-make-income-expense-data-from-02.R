source("code/01-00-load-packages.R")
source("code/03-00-survey-utils.R")

# Mainline version: this script reads only 02-stage imported survey objects.

ensure_main_output_dirs()
ensure_dir("data/processed_data/03_income_expense")

context <- read_import_context()
import_index <- context$import_index
survey_datasets <- context$survey_datasets

income_crosswalk_path <- "data/processed_data/03_crosswalks/unified_answer_crosswalk_income.csv"
expenditure_crosswalk_path <- "data/processed_data/03_crosswalks/unified_answer_crosswalk_expenditure.csv"
output_dir <- "data/processed_data/03_income_expense"

build_block_spec <- function(crosswalk_path, import_index, survey_datasets) {
  available_years <- sort(unique(import_index$data_year))

  resolved_vars <- resolve_dataset_variables(
    crosswalk_path = crosswalk_path,
    import_index = import_index,
    survey_datasets = survey_datasets
  )

  crosswalk_vars <- read_csv(crosswalk_path, show_col_types = FALSE) %>%
    filter(data_year %in% available_years) %>%
    distinct(data_year, integrated_var, raw_var, mapping_type)

  crosswalk_vars %>%
    left_join(
      resolved_vars %>% select(data_year, survey_tag, integrated_var, raw_var, dataset_var, status),
      by = c("data_year", "integrated_var", "raw_var")
    ) %>%
    mutate(
      survey_tag = as.character(survey_tag),
      status = case_when(
        !is.na(status) ~ status,
        is.na(raw_var) | raw_var == "" ~ "missing_in_metadata",
        TRUE ~ "missing_in_metadata"
      )
    ) %>%
    distinct(data_year, integrated_var, raw_var, .keep_all = TRUE) %>%
    arrange(data_year, integrated_var, raw_var)
}

choose_primary_row <- function(block_spec, data_year, integrated_var) {
  candidates <- block_spec %>%
    filter(data_year == !!data_year, integrated_var == !!integrated_var) %>%
    mutate(
      raw_var_missing = is.na(raw_var) | raw_var == "",
      dataset_missing = is.na(dataset_var) | dataset_var == "",
      composite_raw = str_detect(coalesce(raw_var, ""), ";"),
      amount_var_preferred = str_detect(coalesce(dataset_var, ""), "_2$|_2o$"),
      yes_no_var = str_detect(coalesce(dataset_var, ""), "_1$")
    ) %>%
    arrange(dataset_missing, raw_var_missing, composite_raw, desc(amount_var_preferred), yes_no_var, raw_var)

  if (nrow(candidates) == 0) {
    return(tibble())
  }

  candidates %>% slice(1)
}

sanitize_prefix <- function(x) {
  x %>%
    str_replace_all("[^A-Za-z0-9]+", "_") %>%
    str_replace_all("_+", "_") %>%
    str_replace_all("^_|_$", "") %>%
    toupper()
}

make_unmapped_check <- function(harmonized, data_year, survey_tag, integrated_var) {
  tibble(
    data_year = data_year,
    survey_tag = survey_tag,
    integrated_var = integrated_var,
    raw_value = harmonized$raw_value,
    mapped = harmonized$mapped
  ) %>%
    filter(!is.na(raw_value), raw_value != "", !mapped) %>%
    count(data_year, survey_tag, integrated_var, raw_value, name = "frequency")
}

build_mapping_check <- function(block_spec, file_name) {
  write_check_file(
    block_spec %>%
      transmute(
        data_year,
        survey_tag = as.character(survey_tag),
        integrated_var,
        expected_raw_var = raw_var,
        resolved_dataset_var = dataset_var,
        status
      ) %>%
      distinct() %>%
      arrange(data_year, survey_tag, integrated_var, expected_raw_var),
    file_name
  )
}

build_distribution_check <- function(data, value_prefix, file_name) {
  code_col <- paste0(value_prefix, "_CODE")
  label_col <- value_prefix

  distribution <- names(data) %>%
    keep(~ str_ends(.x, paste0("_", code_col))) %>%
    map_dfr(function(one_col) {
      prefix <- str_remove(one_col, paste0("_", code_col, "$"))
      label_name <- paste0(prefix, "_", label_col)
      integrated_var <- prefix

      tibble(
        data_year = data$DATA_Y,
        harmonized_code = data[[one_col]],
        harmonized_label = data[[label_name]],
        integrated_var = integrated_var
      ) %>%
        count(data_year, integrated_var, harmonized_code, harmonized_label, name = "frequency")
    })

  write_check_file(
    distribution %>% arrange(data_year, integrated_var, harmonized_code, harmonized_label),
    file_name
  )
}

validate_code_columns <- function(data, block_spec, crosswalk_path, value_prefix, dataset_name) {
  crosswalk_codes <- read_csv(crosswalk_path, show_col_types = FALSE) %>%
    filter(!is.na(unified_code), unified_code != "") %>%
    mutate(unified_code = as.integer(unified_code)) %>%
    distinct(integrated_var, unified_code)

  code_cols <- names(data) %>% keep(~ str_ends(.x, paste0("_", value_prefix, "_CODE")))

  for (one_col in code_cols) {
    integrated_var <- str_remove(one_col, paste0("_", value_prefix, "_CODE$"))
    allowed_codes <- crosswalk_codes %>%
      filter(integrated_var == !!integrated_var) %>%
      pull(unified_code) %>%
      unique()

    if (length(allowed_codes) == 0) {
      next
    }

    invalid_rows <- data %>%
      filter(!is.na(.data[[one_col]]) & !.data[[one_col]] %in% allowed_codes)

    if (nrow(invalid_rows) > 0) {
      stop(dataset_name, " contains invalid codes in ", one_col, ".")
    }
  }
}

build_block_dataset <- function(block_spec, label_lookup, value_prefix, check_unmapped_file) {
  unmapped_checks <- tibble(
    data_year = integer(),
    survey_tag = character(),
    integrated_var = character(),
    raw_value = character(),
    frequency = integer()
  )

  integrated_vars <- sort(unique(block_spec$integrated_var))

  block_rows <- vector("list", nrow(import_index))

  for (i in seq_len(nrow(import_index))) {
    dataset <- get_dataset_by_row(import_index, survey_datasets, i)
    data_year <- import_index$data_year[[i]]
    survey_tag <- import_index$survey_tag[[i]]
    id_var <- get_survey_id_var(dataset, data_year = data_year, survey_tag = survey_tag)

    output <- tibble(
      ID = dataset[[id_var]],
      DATA_Y = data_year
    )

    for (one_var in integrated_vars) {
      prefix <- sanitize_prefix(one_var)
      selected_row <- choose_primary_row(block_spec, data_year, one_var)

      raw_col <- paste0(prefix, "_", value_prefix, "_RAW")
      code_col <- paste0(prefix, "_", value_prefix, "_CODE")
      label_col <- paste0(prefix, "_", value_prefix)

      if (nrow(selected_row) == 0 || is.na(selected_row$dataset_var[[1]]) || selected_row$status[[1]] != "ok") {
        output[[raw_col]] <- NA_character_
        output[[code_col]] <- NA_integer_
        output[[label_col]] <- NA_character_
        next
      }

      harmonized <- harmonize_single_variable(
        dataset = dataset,
        dataset_var = selected_row$dataset_var[[1]],
        data_year = data_year,
        integrated_var = one_var,
        raw_var = selected_row$raw_var[[1]],
        label_lookup = label_lookup,
        output = c("label", "code"),
        unmapped = ifelse(selected_row$mapping_type[[1]] == "conceptual_only", "raw", "na")
      )

      output[[raw_col]] <- harmonized$raw_value
      output[[code_col]] <- harmonized$code
      output[[label_col]] <- harmonized$label

      unmapped_checks <- bind_rows(
        unmapped_checks,
        make_unmapped_check(
          harmonized = harmonized,
          data_year = data_year,
          survey_tag = survey_tag,
          integrated_var = one_var
        )
      )
    }

    validate_row_count(output, nrow(dataset), paste0(value_prefix, "_data"), data_year, survey_tag)
    block_rows[[i]] <- output
  }

  block_data <- bind_rows(block_rows)

  validate_output_keys(block_data, paste0(value_prefix, "_data"))

  write_check_file(
    unmapped_checks %>% distinct() %>% arrange(data_year, survey_tag, integrated_var, raw_value),
    check_unmapped_file
  )

  block_data
}

income_spec <- build_block_spec(income_crosswalk_path, import_index, survey_datasets)
expenditure_spec <- build_block_spec(expenditure_crosswalk_path, import_index, survey_datasets)

build_mapping_check(income_spec, "check_income_variable_mapping.csv")
build_mapping_check(expenditure_spec, "check_expenditure_variable_mapping.csv")

write_check_file(
  expenditure_spec %>%
    filter(str_detect(coalesce(raw_var, ""), "^(Q12-|J7-|M7-|H7-)")) %>%
    transmute(
      data_year,
      survey_tag,
      integrated_var,
      raw_var,
      mapping_type,
      resolved_dataset_var = dataset_var,
      selected_field_type = case_when(
        str_detect(coalesce(dataset_var, ""), "_2o$") ~ "open_amount",
        str_detect(coalesce(dataset_var, ""), "_2$") ~ "amount",
        str_detect(coalesce(dataset_var, ""), "_1$") ~ "yes_no",
        TRUE ~ "other_or_missing"
      ),
      status
    ) %>%
    distinct() %>%
    arrange(data_year, integrated_var, raw_var),
  "check_two_stage_expenditure_variables.csv"
)

income_lookup <- make_unified_lookup(income_crosswalk_path)
expenditure_lookup <- make_unified_lookup(expenditure_crosswalk_path)

income_data <- build_block_dataset(
  block_spec = income_spec,
  label_lookup = income_lookup,
  value_prefix = "INCOME",
  check_unmapped_file = "check_unmapped_income_values.csv"
)

expenditure_data <- build_block_dataset(
  block_spec = expenditure_spec,
  label_lookup = expenditure_lookup,
  value_prefix = "EXPENDITURE",
  check_unmapped_file = "check_unmapped_expenditure_values.csv"
)

income_expenditure_data <- income_data %>%
  full_join(expenditure_data, by = c("ID", "DATA_Y"))

validate_output_keys(income_expenditure_data, "income_expenditure_data")

validate_code_columns(
  data = income_data,
  block_spec = income_spec,
  crosswalk_path = income_crosswalk_path,
  value_prefix = "INCOME",
  dataset_name = "income_data"
)

validate_code_columns(
  data = expenditure_data,
  block_spec = expenditure_spec,
  crosswalk_path = expenditure_crosswalk_path,
  value_prefix = "EXPENDITURE",
  dataset_name = "expenditure_data"
)

build_distribution_check(income_data, "INCOME", "check_income_distribution.csv")
build_distribution_check(expenditure_data, "EXPENDITURE", "check_expenditure_distribution.csv")

saveRDS(as.data.table(income_data), file.path(output_dir, "income_data.rds"))
saveRDS(as.data.table(expenditure_data), file.path(output_dir, "expenditure_data.rds"))
saveRDS(as.data.table(income_expenditure_data), file.path(output_dir, "income_expenditure_data.rds"))

write_csv(income_data, file.path(output_dir, "income_data.csv"))
write_csv(expenditure_data, file.path(output_dir, "expenditure_data.csv"))
write_csv(income_expenditure_data, file.path(output_dir, "income_expenditure_data.csv"))

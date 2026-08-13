## Legacy version: kept only for historical comparison.
## Current mainline workflow is based on from-02 scripts.
source("code/01-00-load-packages.R")
source("code/03-00-survey-utils.R")

import_index_path <- "data/processed_data/02_metadata/imported_survey_index.csv"
survey_datasets_path <- "data/processed_data/02_metadata/survey_datasets.rds"
income_crosswalk_path <- "data/processed_data/03_crosswalks/unified_answer_crosswalk_income.csv"
expenditure_crosswalk_path <- "data/processed_data/03_crosswalks/unified_answer_crosswalk_expenditure.csv"

if (!file.exists(import_index_path) || !file.exists(survey_datasets_path)) {
  stop("Please run code/02-00-import-cross-year-survey-data.R before building income/expenditure data.")
}

import_index <- read_csv(import_index_path, show_col_types = FALSE)
survey_datasets <- readRDS(survey_datasets_path)
import_index <- import_index %>%
  mutate(survey_tag = as.character(survey_tag))

income_var_lookup <- resolve_dataset_variables(income_crosswalk_path)
expenditure_var_lookup <- resolve_dataset_variables(expenditure_crosswalk_path)
all_var_lookup <- bind_rows(income_var_lookup, expenditure_var_lookup) %>%
  distinct(data_year, raw_var, dataset_var)

income_label_lookup <- make_unified_label_lookup(income_crosswalk_path)
expenditure_label_lookup <- make_unified_label_lookup(expenditure_crosswalk_path)

income_var_map <- read_csv(income_crosswalk_path, show_col_types = FALSE) %>%
  distinct(data_year, integrated_var, raw_var) %>%
  left_join(all_var_lookup, by = c("data_year", "raw_var")) %>%
  distinct(data_year, integrated_var, raw_var, .keep_all = TRUE) %>%
  arrange(data_year, integrated_var)

expenditure_var_map <- read_csv(expenditure_crosswalk_path, show_col_types = FALSE) %>%
  distinct(data_year, integrated_var, raw_var) %>%
  left_join(all_var_lookup, by = c("data_year", "raw_var")) %>%
  distinct(data_year, integrated_var, raw_var, .keep_all = TRUE) %>%
  arrange(data_year, integrated_var)

build_block_data <- function(dataset, data_year, var_map, label_lookup) {
  id_var <- get_survey_id_var(dataset)

  output <- tibble(
    ID = dataset[[id_var]],
    DATA_Y = data_year
  )

  integrated_vars <- unique(var_map$integrated_var)

  for (one_var in integrated_vars) {
    var_rows <- var_map %>%
      filter(data_year == !!data_year, integrated_var == !!one_var)

    if (nrow(var_rows) == 0) {
      output[[one_var]] <- NA_character_
      next
    }

    if (one_var == "EXP_TOTAL_SYN") {
      total_row <- var_rows %>%
        filter(!is.na(dataset_var)) %>%
        slice(1)

      if (nrow(total_row) == 0) {
        output[[one_var]] <- NA_character_
      } else {
        output[[one_var]] <- harmonize_single_variable(
          dataset = dataset,
          dataset_var = total_row$dataset_var[[1]],
          data_year = data_year,
          integrated_var = one_var,
          raw_var = total_row$raw_var[[1]],
          label_lookup = label_lookup
        )
      }

      next
    }

    usable_row <- var_rows %>%
      filter(!is.na(dataset_var)) %>%
      slice(1)

    if (nrow(usable_row) == 0) {
      output[[one_var]] <- NA_character_
      next
    }

    output[[one_var]] <- harmonize_single_variable(
      dataset = dataset,
      dataset_var = usable_row$dataset_var[[1]],
      data_year = data_year,
      integrated_var = one_var,
      raw_var = usable_row$raw_var[[1]],
      label_lookup = label_lookup
    )
  }

  output
}

available_years <- sort(unique(import_index$data_year))

income_data_list <- map(available_years, function(one_year) {
  survey_tag <- get_survey_tag_from_year(import_index, one_year)

  if (is.na(survey_tag) || !survey_tag %in% names(survey_datasets)) {
    return(NULL)
  }

  build_block_data(
    dataset = survey_datasets[[survey_tag]],
    data_year = one_year,
    var_map = income_var_map,
    label_lookup = income_label_lookup
  )
})

expenditure_data_list <- map(available_years, function(one_year) {
  survey_tag <- get_survey_tag_from_year(import_index, one_year)

  if (is.na(survey_tag) || !survey_tag %in% names(survey_datasets)) {
    return(NULL)
  }

  build_block_data(
    dataset = survey_datasets[[survey_tag]],
    data_year = one_year,
    var_map = expenditure_var_map,
    label_lookup = expenditure_label_lookup
  )
})

income_data <- bind_rows(income_data_list) %>% setDT()
expenditure_data <- bind_rows(expenditure_data_list) %>% setDT()
income_expenditure_data <- income_data %>%
  full_join(expenditure_data, by = c("ID", "DATA_Y")) %>%
  setDT()

saveRDS(income_data, "data/processed_data/income_data.rds")
saveRDS(expenditure_data, "data/processed_data/expenditure_data.rds")
saveRDS(income_expenditure_data, "data/processed_data/income_expenditure_data.rds")

write_csv(as_tibble(income_data), "output/income_data.csv")
write_csv(as_tibble(expenditure_data), "output/expenditure_data.csv")
write_csv(as_tibble(income_expenditure_data), "output/income_expenditure_data.csv")

source("code/01-00-load-packages.R")

find_survey_dta_files <- function(raw_data_dir = Sys.getenv("RAW_DATA_DIR", "data/raw_data")) {
  dta_files <- list.files(
    path = raw_data_dir,
    pattern = "^data\\d+(?:_\\d+)?\\.dta$",
    recursive = TRUE,
    full.names = TRUE
  )

  tibble(file_path = dta_files) %>%
    mutate(
      file_name = basename(file_path),
      survey_tag = str_match(file_name, "^data(\\d+(?:_\\d+)?)\\.dta$")[, 2],
      survey_year_roc = as.integer(str_extract(survey_tag, "^\\d+")),
      data_year = if_else(survey_year_roc < 1911, survey_year_roc + 1911L, survey_year_roc)
    ) %>%
    arrange(data_year, survey_tag)
}

read_survey_datasets <- function(import_index) {
  dataset_list <- vector("list", nrow(import_index))

  for (i in seq_len(nrow(import_index))) {
    dataset_list[[i]] <- read_dta(import_index$file_path[i])
  }

  names(dataset_list) <- import_index$survey_tag
  dataset_list
}

import_index <- find_survey_dta_files()
if (nrow(import_index) == 0) {
  stop("No data*.dta files found under RAW_DATA_DIR=", Sys.getenv("RAW_DATA_DIR", "data/raw_data"))
}
survey_datasets <- read_survey_datasets(import_index)

dir.create("data/processed_data/02_metadata", recursive = TRUE, showWarnings = FALSE)

saveRDS(survey_datasets, "data/processed_data/02_metadata/survey_datasets.rds")
write_csv(import_index, "data/processed_data/02_metadata/imported_survey_index.csv")

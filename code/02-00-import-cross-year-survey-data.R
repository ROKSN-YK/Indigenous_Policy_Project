if (!isTRUE(getOption("indigenous.pipeline.ready"))) {
  source("code/01-00-load-packages.R", encoding = "UTF-8")
}

find_survey_data_files <- function(raw_data_dir = Sys.getenv("RAW_DATA_DIR", "data/raw_data")) {
  supported_tags <- c("91_1", "91_2", "95", "99", "103", "106", "110")
  survey_files <- list.files(
    path = raw_data_dir,
    pattern = "^data\\d+(?:_\\d+)?\\.(?:dta|sav)$",
    recursive = TRUE,
    full.names = TRUE,
    ignore.case = TRUE
  )
  normalized_paths <- str_replace_all(survey_files, "\\\\", "/")
  survey_files <- survey_files[
    !str_detect(normalized_paths, "(^|/)archive(/|$)")
  ]

  index <- tibble(file_path = survey_files) %>%
    mutate(
      file_name = basename(file_path),
      survey_tag = str_match(
        str_to_lower(file_name),
        "^data(\\d+(?:_\\d+)?)\\.(?:dta|sav)$"
      )[, 2],
      survey_year_roc = as.integer(str_extract(survey_tag, "^\\d+")),
      data_year = if_else(survey_year_roc < 1911, survey_year_roc + 1911L, survey_year_roc)
    )

  ignored <- index %>% filter(!survey_tag %in% supported_tags)
  if (nrow(ignored) > 0L) {
    message(
      "Ignoring non-pipeline survey files: ",
      paste(ignored$file_path, collapse = ", ")
    )
  }

  index %>%
    filter(survey_tag %in% supported_tags) %>%
    arrange(data_year, survey_tag)
}

read_survey_datasets <- function(import_index) {
  dataset_list <- vector("list", nrow(import_index))

  for (i in seq_len(nrow(import_index))) {
    extension <- str_to_lower(tools::file_ext(import_index$file_path[i]))
    dataset_list[[i]] <- switch(
      extension,
      dta = read_dta(import_index$file_path[i]),
      sav = read_sav(import_index$file_path[i]),
      stop("Unsupported survey file type: ", import_index$file_path[i])
    )
  }

  names(dataset_list) <- import_index$survey_tag
  dataset_list
}

import_index <- find_survey_data_files()
if (nrow(import_index) == 0) {
  stop(
    "No supported data*.dta or data*.sav files found under RAW_DATA_DIR=",
    Sys.getenv("RAW_DATA_DIR", "data/raw_data")
  )
}
required_tags <- c("91_1", "91_2", "95", "99", "103", "106", "110")
missing_tags <- setdiff(required_tags, import_index$survey_tag)
if (length(missing_tags) > 0L) {
  stop(
    "原始資料不完整，為避免覆蓋既有成果，本次停止執行。缺少：",
    paste(missing_tags, collapse = ", "),
    "（每份可使用 .dta 或 .sav）。",
    call. = FALSE
  )
}
duplicate_tags <- import_index %>% count(survey_tag) %>% filter(n > 1L)
if (nrow(duplicate_tags) > 0L) {
  stop(
    "Each survey tag must have exactly one source file. Duplicates: ",
    paste(duplicate_tags$survey_tag, collapse = ", ")
  )
}
survey_datasets <- read_survey_datasets(import_index)

dir.create("data/processed_data/02_metadata", recursive = TRUE, showWarnings = FALSE)

saveRDS(survey_datasets, "data/processed_data/02_metadata/survey_datasets.rds")
write_csv(import_index, "data/processed_data/02_metadata/imported_survey_index.csv")

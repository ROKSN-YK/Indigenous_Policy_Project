if (!isTRUE(getOption("indigenous.pipeline.ready"))) {
  source("code/01-00-load-packages.R", encoding = "UTF-8")
  source("code/03-00-survey-utils.R", encoding = "UTF-8")
}

# Mainline version: this script reads only 02-stage imported survey objects.

ensure_main_output_dirs()

context <- read_import_context()
import_index <- context$import_index
survey_datasets <- context$survey_datasets

basic_info_from_02 <- map_dfr(seq_len(nrow(import_index)), function(i) {
  dataset <- get_dataset_by_row(import_index, survey_datasets, i)
  data_year <- import_index$data_year[[i]]
  survey_tag <- import_index$survey_tag[[i]]

  out <- build_survey_keys(dataset, data_year, survey_tag)

  validate_row_count(out, nrow(dataset), "basic_info_from_02", data_year, survey_tag)
  out
})

validate_output_keys(basic_info_from_02, "basic_info_from_02")

saveRDS(as.data.table(basic_info_from_02), "data/processed_data/basic_info_from_02.rds")
write_csv(basic_info_from_02, "output/basic_info_from_02.csv")

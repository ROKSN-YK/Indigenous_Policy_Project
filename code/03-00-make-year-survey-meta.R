source("code/01-00-load-packages.R")
source("code/03-00-survey-utils.R")

# Legacy-support metadata builder.
# The current mainline 03 workflow uses the from-02 scripts, and metadata is
# standardized under data/processed_data/02_metadata/survey_meta.

ensure_main_output_dirs()

context <- read_import_context()
import_index <- context$import_index
survey_datasets <- context$survey_datasets

write_single_meta <- function(dataset, survey_tag, data_year, output_dir = SURVEY_META_DIR) {
  ensure_dir(output_dir)

  meta <- tibble(
    variable = names(dataset),
    label = map_chr(dataset, ~ {
      value <- attr(.x, "label")
      if (is.null(value)) NA_character_ else as.character(value)
    }),
    type = map_chr(dataset, ~ class(.x)[1]),
    source = survey_tag
  )

  write_csv(meta, file.path(output_dir, paste0("meta_", survey_tag, ".csv")))
}

walk(seq_len(nrow(import_index)), function(i) {
  dataset <- get_dataset_by_row(import_index, survey_datasets, i)
  write_single_meta(
    dataset = dataset,
    survey_tag = import_index$survey_tag[[i]],
    data_year = import_index$data_year[[i]]
  )
})

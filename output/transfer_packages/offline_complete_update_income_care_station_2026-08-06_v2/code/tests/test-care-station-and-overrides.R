source("code/01-00-load-packages.R", encoding = "UTF-8")
source("code/03-00-survey-utils.R", encoding = "UTF-8")

override_crosswalk <- tempfile(fileext = ".csv")
override_meta_dir <- tempfile("override-meta-")
dir.create(override_meta_dir, recursive = TRUE)
write_csv(
  tibble(
    data_year = 2010L,
    option_year = "99",
    integrated_var = "INC_FAM_OTHER",
    raw_var = "I6"
  ),
  override_crosswalk
)
write_csv(
  tibble(
    variable = "i7",
    label = "I7.包含您本人，全家每月其他收入",
    storage_type = "integer",
    survey_tag = "99"
  ),
  file.path(override_meta_dir, "meta_99.csv")
)
resolved <- resolve_dataset_variables(
  crosswalk_path = override_crosswalk,
  import_index = tibble(data_year = 2010L, survey_tag = "99"),
  survey_datasets = list(`99` = tibble(i7 = 1L)),
  meta_dir = override_meta_dir
)
stopifnot(
  nrow(resolved) == 1L,
  resolved$dataset_var[[1]] == "i7",
  resolved$status[[1]] == "ok_override"
)

source("code/03-05-build-care-station-town-year-panel.R", encoding = "UTF-8")
panel <- readRDS("data/processed_data/05_reference/care_station_town_year_panel_long.rds")
stopifnot(
  n_distinct(paste(panel$station_county, panel$station_township)) == 122L,
  110L %in% panel$survey_roc_year,
  all(panel$care_station_count >= panel$care_station_new_count),
  all(diff(panel$care_station_count[panel$station_county == "南投縣" & panel$station_township == "仁愛鄉"]) >= 0L)
)

message("Care-station panel and dataset-variable override tests passed.")

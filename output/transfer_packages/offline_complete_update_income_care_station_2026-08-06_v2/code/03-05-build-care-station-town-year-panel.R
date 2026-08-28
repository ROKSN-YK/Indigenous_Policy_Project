if (!isTRUE(getOption("indigenous.pipeline.ready"))) {
  source("code/01-00-load-packages.R", encoding = "UTF-8")
  source("code/03-00-survey-utils.R", encoding = "UTF-8")
}

station_roster_path <- Sys.getenv(
  "CARE_STATION_ROSTER",
  unset = "data/raw_data/114年文健站營運單位清冊.csv"
)
if (!file.exists(station_roster_path)) {
  stop("找不到文健站清冊：", station_roster_path)
}

normalize_admin_key <- function(x) {
  x %>%
    as.character() %>%
    str_replace_all("台", "臺") %>%
    str_replace_all("[[:space:]　]", "") %>%
    str_trim() %>%
    na_if("")
}

station_roster <- read_csv(
  station_roster_path,
  skip = 2,
  show_col_types = FALSE,
  name_repair = "unique"
) %>%
  transmute(
    station_id = suppressWarnings(as.integer(.data[["編號"]])),
    station_county = normalize_admin_key(.data[["縣市"]]),
    station_township = normalize_admin_key(.data[["行政區"]]),
    station_name = as.character(.data[["名稱"]]),
    established_roc_year = suppressWarnings(as.integer(.data[["成立年度"]]))
  ) %>%
  filter(!is.na(station_id), !is.na(station_county), !is.na(station_township))

invalid_established <- station_roster %>%
  filter(is.na(established_roc_year) | established_roc_year < 80L | established_roc_year > 114L)
write_check_file(invalid_established, "check_care_station_invalid_established_year.csv")
if (nrow(invalid_established) > 0L) {
  stop("文健站清冊有無效成立年度；請查看 check_care_station_invalid_established_year.csv")
}

duplicate_station_ids <- station_roster %>% count(station_id) %>% filter(n > 1L)
if (nrow(duplicate_station_ids) > 0L) {
  stop("文健站清冊的編號不唯一：", paste(duplicate_station_ids$station_id, collapse = ", "))
}

panel_years <- 90L:114L
towns <- station_roster %>% distinct(station_county, station_township)
station_panel_long <- tidyr::crossing(towns, survey_roc_year = panel_years) %>%
  left_join(
    station_roster %>%
      count(station_county, station_township, established_roc_year, name = "care_station_new_count"),
    by = c(
      "station_county", "station_township",
      "survey_roc_year" = "established_roc_year"
    )
  ) %>%
  mutate(care_station_new_count = coalesce(care_station_new_count, 0L)) %>%
  group_by(station_county, station_township) %>%
  arrange(survey_roc_year, .by_group = TRUE) %>%
  mutate(
    care_station_count = cumsum(care_station_new_count),
    care_station_any = care_station_count > 0L,
    care_station_first_year = ifelse(
      any(care_station_new_count > 0L),
      min(survey_roc_year[care_station_new_count > 0L]),
      NA_integer_
    ),
    care_station_years_since_first = ifelse(
      care_station_any,
      survey_roc_year - care_station_first_year,
      NA_integer_
    ),
    care_station_event_time = survey_roc_year - care_station_first_year,
    care_station_exposed_1y = care_station_years_since_first >= 1L,
    care_station_exposed_3y = care_station_years_since_first >= 3L,
    care_station_exposed_5y = care_station_years_since_first >= 5L,
    care_station_source = "114年現存營運清冊依成立年度回推",
    care_station_source_limitation = "可能不含114年前已停辦或撤站之歷史站點"
  ) %>%
  ungroup()

ensure_dir("data/processed_data/05_reference")
write_csv(
  station_panel_long,
  "data/processed_data/05_reference/care_station_town_year_panel_long.csv"
)
saveRDS(
  station_panel_long,
  "data/processed_data/05_reference/care_station_town_year_panel_long.rds"
)

station_roster_audit <- station_roster %>%
  summarise(
    station_n = n(),
    town_n = n_distinct(paste(station_county, station_township)),
    min_established_roc_year = min(established_roc_year),
    max_established_roc_year = max(established_roc_year),
    has_110_panel = 110L %in% station_panel_long$survey_roc_year
  )
write_check_file(station_roster_audit, "check_care_station_panel_build.csv")


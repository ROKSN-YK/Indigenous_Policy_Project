if (!isTRUE(getOption("indigenous.pipeline.ready"))) {
  source("code/01-00-load-packages.R", encoding = "UTF-8")
  source("code/03-00-survey-utils.R", encoding = "UTF-8")
}

combined_path <- "data/processed_data/04_analysis_ready/cross_year_combined_data.rds"
station_panel_path <- "data/processed_data/05_reference/care_station_town_year_panel_long.rds"
if (!file.exists(combined_path) || !file.exists(station_panel_path)) {
  stop("文健站合併需要先完成04-01及03-05。")
}

normalize_admin_key <- function(x) {
  x %>%
    as.character() %>%
    str_replace_all("台", "臺") %>%
    str_replace_all("[[:space:]　]", "") %>%
    str_trim() %>%
    na_if("")
}

combined <- readRDS(combined_path) %>% as_tibble()
station_panel <- readRDS(station_panel_path) %>% as_tibble()
source_n <- nrow(combined)

analysis_with_station <- combined %>%
  mutate(
    care_join_county = normalize_admin_key(CITY),
    care_join_township = normalize_admin_key(COUNTY),
    survey_roc_year = as.integer(DATA_Y) - 1911L,
    care_precise_township = !is.na(care_join_county) & !is.na(care_join_township) &
      !care_join_township %in% c("未知地區", "北部地區", "中部地區", "南部地區", "東部及離島地區")
  ) %>%
  left_join(
    station_panel,
    by = c(
      "care_join_county" = "station_county",
      "care_join_township" = "station_township",
      "survey_roc_year"
    )
  ) %>%
  mutate(
    care_station_match_status = case_when(
      !care_precise_township ~ "geography_not_township",
      !is.na(care_station_count) ~ "matched_current_roster_town",
      TRUE ~ "no_station_in_current_roster"
    ),
    care_station_count = ifelse(
      care_precise_township & is.na(care_station_count), 0L, care_station_count
    ),
    care_station_new_count = ifelse(
      care_precise_township & is.na(care_station_new_count), 0L, care_station_new_count
    ),
    care_station_any = ifelse(
      care_precise_township & is.na(care_station_any), FALSE, care_station_any
    ),
    care_station_source = coalesce(
      care_station_source,
      "114年現存營運清冊依成立年度回推"
    ),
    care_station_source_limitation = coalesce(
      care_station_source_limitation,
      "可能不含114年前已停辦或撤站之歷史站點"
    )
  ) %>%
  select(-care_join_county, -care_join_township, -care_precise_township)

if (nrow(analysis_with_station) != source_n || anyDuplicated(analysis_with_station[c("ID", "DATA_Y")])) {
  stop("文健站暴露合併造成個體列數或ID×年度唯一性改變。")
}

saveRDS(
  analysis_with_station,
  "data/processed_data/04_analysis_ready/cross_year_combined_with_care_station.rds"
)

if (tolower(Sys.getenv("EXPORT_STATION_MERGED_INDIVIDUAL_CSV", unset = "false")) %in% c("1", "true", "yes")) {
  warning("正在輸出個體層CSV；此檔不得攜出受限環境。")
  write_csv(
    analysis_with_station,
    "data/processed_data/04_analysis_ready/cross_year_combined_with_care_station.csv"
  )
}

station_merge_audit <- analysis_with_station %>%
  count(DATA_Y, care_station_match_status, name = "respondent_n") %>%
  group_by(DATA_Y) %>%
  mutate(respondent_share = respondent_n / sum(respondent_n)) %>%
  ungroup()
write_check_file(station_merge_audit, "check_care_station_merge_coverage.csv")

station_exposure_audit <- analysis_with_station %>%
  group_by(DATA_Y) %>%
  summarise(
    respondent_n = n(),
    township_geography_n = sum(care_station_match_status != "geography_not_township"),
    exposed_n = sum(care_station_any %in% TRUE, na.rm = TRUE),
    mean_station_count = ifelse(
      township_geography_n > 0L,
      mean(care_station_count[care_station_match_status != "geography_not_township"], na.rm = TRUE),
      NA_real_
    ),
    .groups = "drop"
  )
write_check_file(station_exposure_audit, "check_care_station_exposure_by_survey_year.csv")


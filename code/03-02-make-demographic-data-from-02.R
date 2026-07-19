source("code/01-00-load-packages.R")
source("code/03-00-survey-utils.R")

# Mainline version: this script reads only 02-stage imported survey objects.

ensure_main_output_dirs()

context <- read_import_context()
import_index <- context$import_index
survey_datasets <- context$survey_datasets
crosswalk_path <- "data/processed_data/03_crosswalks/unified_answer_crosswalk_basic_info.csv"

demographic_vars <- c("MALE", "AGE", "EDU", "RACE")
demographic_lookup <- make_unified_lookup(crosswalk_path)

resolved_vars <- resolve_dataset_variables(
  crosswalk_path = crosswalk_path,
  import_index = import_index,
  survey_datasets = survey_datasets
) %>%
  filter(integrated_var %in% demographic_vars)

write_missing_variable_check(resolved_vars)

crosswalk_vars <- read_csv(crosswalk_path, show_col_types = FALSE) %>%
  filter(integrated_var %in% demographic_vars) %>%
  distinct(data_year, integrated_var, raw_var)

determine_age_measure_type <- function(data_year, dataset_var, crosswalk_rows, dataset) {
  if (nrow(crosswalk_rows) > 0) {
    return("age_group")
  }

  if (!is.na(dataset_var) && dataset_var %in% names(dataset) && is.numeric(dataset[[dataset_var]])) {
    return("exact_age")
  }

  NA_character_
}

coerce_numeric_or_na <- function(x) {
  suppressWarnings(as.numeric(as.character(x)))
}

get_location_columns <- function(dataset, data_year) {
  if (data_year %in% c(2002, 2006) && "county" %in% names(dataset)) {
    county_chr <- get_raw_text(dataset$county)
    return(tibble(CITY = substr(county_chr, 1, 3), COUNTY = substr(county_chr, 4, nchar(county_chr))))
  }

  if (data_year == 2010 && "countya" %in% names(dataset)) {
    county_chr <- get_raw_text(dataset$countya)
    return(tibble(CITY = substr(county_chr, 1, 3), COUNTY = substr(county_chr, 4, nchar(county_chr))))
  }

  if (data_year %in% c(2014, 2017) && "county2" %in% names(dataset)) {
    county_chr <- get_raw_text(dataset$county2)
    return(tibble(CITY = substr(county_chr, 2, 4), COUNTY = substr(county_chr, 5, nchar(county_chr))))
  }

  if (data_year == 2021 && "county1" %in% names(dataset)) {
    county_chr <- get_raw_text(dataset$county1)
    return(tibble(CITY = county_chr, COUNTY = county_chr))
  }

  tibble(CITY = NA_character_, COUNTY = NA_character_)
}

normalize_tai_character <- function(x) {
  str_replace_all(as.character(x), "台", "臺")
}

harmonize_admin_name <- function(x) {
  normalized <- normalize_tai_character(x)
  recode(
    normalized,
    "臺北縣" = "新北市",
    "臺中縣" = "臺中市",
    "臺南縣" = "臺南市",
    "高雄縣" = "高雄市",
    "桃園縣" = "桃園市",
    .default = normalized
  )
}

combined_township_labels <- c(
  "八里鄉三芝鄉", "竹南鎮後龍鎮造橋鄉", "頭城礁溪員山鄉", "五結冬山鄉",
  "六龜鄉美濃鎮", "后里鄉外埔鄉", "大樹鄉仁武鄉", "新埔鎮芎林鄉橫山鄉",
  "林園鄉鳥松鄉", "水里鄉草屯鎮", "清水鎮沙鹿鎮", "烏日鄉霧峰鄉",
  "竹北市新豐鄉"
)

add_harmonized_location_columns <- function(location_df) {
  location_df %>%
    mutate(
      ADMIN_NAME_ORIGINAL = CITY,
      ADMIN_NAME_YEAR_SPECIFIC = normalize_tai_character(CITY),
      ADMIN_NAME_HARMONIZED = harmonize_admin_name(CITY),
      COUNTY_ORIGINAL = COUNTY,
      COUNTY = normalize_tai_character(COUNTY),
      CITY = ADMIN_NAME_YEAR_SPECIFIC,
      COUNTY_MAPPING_STATUS = case_when(
        COUNTY %in% combined_township_labels ~ "ambiguous_combined_townships",
        is.na(COUNTY) | COUNTY == "" ~ "missing",
        TRUE ~ "single_township"
      )
    )
}

male_checks_df <- tibble(
  data_year = integer(),
  survey_tag = character(),
  raw_value = character(),
  mapped_value = character(),
  frequency = integer()
)

unmapped_checks_df <- tibble(
  data_year = integer(),
  survey_tag = character(),
  integrated_var = character(),
  raw_value = character(),
  frequency = integer()
)

demo_from_02 <- map_dfr(seq_len(nrow(import_index)), function(i) {
  dataset <- get_dataset_by_row(import_index, survey_datasets, i)
  data_year <- import_index$data_year[[i]]
  survey_tag <- import_index$survey_tag[[i]]
  id_var <- get_survey_id_var(dataset, data_year = data_year, survey_tag = survey_tag)

  output <- tibble(
    ID = dataset[[id_var]],
    DATA_Y = data_year,
    MALE_CODE = NA_integer_,
    MALE = NA_character_,
    AGE_RAW = NA_real_,
    AGE_GROUP_CODE = NA_integer_,
    AGE_GROUP = NA_character_,
    AGE_MEASURE_TYPE = NA_character_,
    EDU_CODE = NA_integer_,
    EDU = NA_character_,
    RACE_CODE = NA_integer_,
    RACE = NA_character_
  )

  for (one_var in demographic_vars) {
    one_row <- resolved_vars %>%
      filter(data_year == !!data_year, integrated_var == !!one_var) %>%
      slice(1)

    crosswalk_rows <- demographic_lookup %>%
      filter(data_year == !!data_year, integrated_var == !!one_var, raw_var == one_row$raw_var[[1]])

    if (nrow(one_row) == 0 || is.na(one_row$dataset_var[[1]]) || !one_row$dataset_var[[1]] %in% names(dataset)) {
      next
    }

    harmonized <- harmonize_single_variable(
      dataset = dataset,
      dataset_var = one_row$dataset_var[[1]],
      data_year = data_year,
      integrated_var = one_var,
      raw_var = one_row$raw_var[[1]],
      label_lookup = demographic_lookup,
      output = c("label", "code"),
      unmapped = "na"
    )

    if (one_var == "MALE") {
      output$MALE_CODE <- harmonized$code
      output$MALE <- harmonized$label

      male_checks_df <<- bind_rows(
        male_checks_df,
        tibble(
        data_year = data_year,
        survey_tag = survey_tag,
        raw_value = harmonized$raw_value,
        mapped_value = harmonized$label
      ) %>%
          count(data_year, survey_tag, raw_value, mapped_value, name = "frequency")
      )
    }

    if (one_var == "AGE") {
      measure_type <- determine_age_measure_type(
        data_year = data_year,
        dataset_var = one_row$dataset_var[[1]],
        crosswalk_rows = crosswalk_rows,
        dataset = dataset
      )

      output$AGE_MEASURE_TYPE <- measure_type

      if (identical(measure_type, "exact_age")) {
        output$AGE_RAW <- coerce_numeric_or_na(dataset[[one_row$dataset_var[[1]]]])
      }

      if (identical(measure_type, "age_group")) {
        output$AGE_GROUP_CODE <- harmonized$code
        output$AGE_GROUP <- harmonized$label
      }
    }

    if (one_var == "EDU") {
      output$EDU_CODE <- harmonized$code
      output$EDU <- harmonized$label
    }

    if (one_var == "RACE") {
      output$RACE_CODE <- harmonized$code
      output$RACE <- harmonized$label
    }

    unmapped_checks_df <<- bind_rows(
      unmapped_checks_df,
      tibble(
      data_year = data_year,
      survey_tag = survey_tag,
      integrated_var = one_var,
      raw_value = harmonized$raw_value,
      mapped = harmonized$mapped
    ) %>%
        filter(!is.na(raw_value), raw_value != "", !mapped) %>%
        count(data_year, survey_tag, integrated_var, raw_value, name = "frequency")
    )
  }

  output <- bind_cols(
    output,
    get_location_columns(dataset, data_year) %>% add_harmonized_location_columns()
  )

  validate_row_count(output, nrow(dataset), "demographic_data_from_02", data_year, survey_tag)
  output
})

validate_output_keys(demo_from_02, "demographic_data_from_02")

valid_male_values <- c("男性", "非男性", NA_character_)
invalid_male <- demo_from_02 %>%
  filter(!(MALE %in% valid_male_values | is.na(MALE)))

if (nrow(invalid_male) > 0) {
  stop("MALE contains values outside of 男性 / 非男性 / NA.")
}

age_raw_non_numeric <- demo_from_02 %>%
  filter(!is.na(AGE_RAW) & is.na(suppressWarnings(as.numeric(AGE_RAW))))

if (nrow(age_raw_non_numeric) > 0) {
  stop("AGE_RAW contains non-numeric values.")
}

write_check_file(
  male_checks_df %>%
    distinct() %>%
    arrange(data_year, survey_tag, raw_value, mapped_value),
  "check_male_mapping.csv"
)

write_check_file(
  demo_from_02 %>%
    filter(COUNTY_MAPPING_STATUS != "single_township") %>%
    count(DATA_Y, ADMIN_NAME_YEAR_SPECIFIC, COUNTY_ORIGINAL, COUNTY, COUNTY_MAPPING_STATUS, name = "frequency") %>%
    arrange(DATA_Y, ADMIN_NAME_YEAR_SPECIFIC, COUNTY),
  "check_geography_ambiguous_or_missing.csv"
)

write_check_file(
  unmapped_checks_df %>%
    distinct() %>%
    arrange(data_year, survey_tag, integrated_var, raw_value),
  "check_unmapped_demographic_values.csv"
)

saveRDS(as.data.table(demo_from_02), "data/processed_data/demographic_data_from_02.rds")
write_csv(demo_from_02, "output/demographic_data_from_02.csv")

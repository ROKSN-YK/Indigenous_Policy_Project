source("code/01-00-load-packages.R")

SURVEY_META_DIR <- "data/processed_data/02_metadata/survey_meta"
CHECKS_DIR <- "output/checks"

ensure_dir <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
}

ensure_main_output_dirs <- function() {
  ensure_dir("data/processed_data")
  ensure_dir("output")
  ensure_dir(CHECKS_DIR)
  ensure_dir(SURVEY_META_DIR)
}

read_import_context <- function(
    import_index_path = "data/processed_data/02_metadata/imported_survey_index.csv",
    survey_datasets_path = "data/processed_data/02_metadata/survey_datasets.rds") {
  if (!file.exists(import_index_path) || !file.exists(survey_datasets_path)) {
    stop("Please run code/02-00-import-cross-year-survey-data.R before this script.")
  }

  import_index <- read_csv(import_index_path, show_col_types = FALSE) %>%
    mutate(
      survey_tag = as.character(survey_tag),
      data_year = as.integer(data_year)
    )

  survey_datasets <- readRDS(survey_datasets_path)

  list(import_index = import_index, survey_datasets = survey_datasets)
}

get_survey_id_var <- function(dataset, data_year = NA_integer_, survey_tag = NA_character_) {
  id_candidates <- c("id", "no")
  matched <- intersect(id_candidates, names(dataset))

  if (length(matched) == 0) {
    stop(
      "Cannot find ID variable for data_year=", data_year,
      ", survey_tag=", survey_tag,
      ". Expected one of: ", paste(id_candidates, collapse = ", ")
    )
  }

  matched[[1]]
}

get_survey_tag_from_year <- function(import_index, data_year) {
  matched <- import_index %>%
    filter(data_year == !!data_year) %>%
    arrange(survey_tag)

  if (nrow(matched) == 0) {
    return(NA_character_)
  }

  matched$survey_tag[[1]]
}

get_dataset_by_row <- function(import_index, survey_datasets, row_index) {
  survey_tag <- import_index$survey_tag[[row_index]]

  if (!survey_tag %in% names(survey_datasets)) {
    stop("Cannot find dataset in survey_datasets.rds for survey_tag=", survey_tag)
  }

  survey_datasets[[survey_tag]]
}

extract_question_id_from_label <- function(label) {
  normalized_label <- label %>%
    iconv(from = "", to = "UTF-8", sub = "") %>%
    enc2utf8() %>%
    str_replace_all("[^[:print:][:space:]]", "") %>%
    str_trim()

  question_id <- str_match(
    normalized_label,
    "^([A-Za-z]?\\d+(?:[-_]\\d+)*)\\."
  )[, 2]

  ifelse(is.na(question_id), NA_character_, toupper(question_id))
}

build_question_var_lookup <- function(meta_path) {
  meta <- read_csv(meta_path, show_col_types = FALSE)

  meta %>%
    mutate(
      question_id = extract_question_id_from_label(label),
      question_id = str_replace_all(question_id, "_", "-"),
      label_utf8 = iconv(label, from = "", to = "UTF-8", sub = ""),
      amount_priority = case_when(
        str_detect(coalesce(label_utf8, ""), "平均每個月支出金額") ~ 3L,
        str_detect(variable, "_2o$") ~ 2L,
        str_detect(variable, "_2$") ~ 2L,
        str_detect(variable, "_1$") ~ 1L,
        TRUE ~ 0L
      )
    ) %>%
    filter(!is.na(question_id)) %>%
    arrange(question_id, desc(amount_priority), variable) %>%
    distinct(question_id, .keep_all = TRUE)
}

resolve_var_from_name_pattern <- function(raw_var, meta_variables) {
  if (is.na(raw_var) || raw_var == "") {
    return(NA_character_)
  }

  if (str_detect(raw_var, ";")) {
    return(NA_character_)
  }

  base_candidate <- raw_var %>%
    str_to_lower() %>%
    str_replace_all("-", "_")

  candidate_order <- c(base_candidate)

  if (str_detect(raw_var, "^[A-Z]\\d+-\\d+$")) {
    candidate_order <- c(
      paste0(base_candidate, "_2"),
      paste0(base_candidate, "_2o"),
      paste0(base_candidate, "_1"),
      candidate_order
    )
  }

  matched <- intersect(candidate_order, meta_variables)

  if (length(matched) == 0) {
    return(NA_character_)
  }

  matched[[1]]
}

build_crosswalk_var_lookup <- function(crosswalk_path) {
  read_csv(crosswalk_path, show_col_types = FALSE) %>%
    distinct(data_year, integrated_var, raw_var) %>%
    filter(!is.na(raw_var), raw_var != "")
}

resolve_dataset_variables <- function(
    crosswalk_path,
    import_index = NULL,
    survey_datasets = NULL,
    meta_dir = SURVEY_META_DIR) {
  ensure_dir(meta_dir)
  crosswalk_lookup <- build_crosswalk_var_lookup(crosswalk_path)

  if (!is.null(import_index)) {
    available_years <- sort(unique(import_index$data_year))
    crosswalk_lookup <- crosswalk_lookup %>%
      filter(data_year %in% available_years)
  }

  map_dfr(sort(unique(crosswalk_lookup$data_year)), function(one_year) {
    survey_tag <- if (is.null(import_index)) {
      get_survey_tag_from_year(
        tibble(data_year = one_year, survey_tag = as.character(one_year - 1911)),
        one_year
      )
    } else {
      get_survey_tag_from_year(import_index, one_year)
    }

    meta_path <- file.path(meta_dir, paste0("meta_", one_year - 1911, ".csv"))

    if (!file.exists(meta_path) && one_year == 2002) {
      meta_path <- file.path(meta_dir, "meta_91_1.csv")
    }

    if (!file.exists(meta_path)) {
      return(
        crosswalk_lookup %>%
          filter(data_year == one_year) %>%
          transmute(
            data_year,
            survey_tag = survey_tag,
            integrated_var,
            raw_var,
            dataset_var = NA_character_,
            status = "missing_in_metadata"
          )
      )
    }

    question_lookup <- build_question_var_lookup(meta_path)
    meta_variables <- read_csv(meta_path, show_col_types = FALSE)$variable

    dataset_names <- NULL
    if (!is.null(import_index) && !is.null(survey_datasets) && !is.na(survey_tag) && survey_tag %in% names(survey_datasets)) {
      dataset_names <- names(survey_datasets[[survey_tag]])
    }

    crosswalk_lookup %>%
      filter(data_year == one_year) %>%
      mutate(question_id = str_to_upper(raw_var)) %>%
      left_join(question_lookup, by = "question_id") %>%
      mutate(
        dataset_var = if_else(
          is.na(variable),
          map_chr(raw_var, resolve_var_from_name_pattern, meta_variables = meta_variables),
          variable
        ),
        status = case_when(
          is.na(dataset_var) ~ "missing_in_metadata",
          !is.null(dataset_names) & !dataset_var %in% dataset_names ~ "missing_in_dataset",
          TRUE ~ "ok"
        )
      ) %>%
      transmute(
        data_year,
        survey_tag = survey_tag,
        integrated_var,
        raw_var,
        dataset_var,
        status
      ) %>%
      distinct(data_year, integrated_var, raw_var, .keep_all = TRUE)
  })
}

standardize_label_text <- function(x) {
  x %>%
    as.character() %>%
    str_replace_all("\\s+", "") %>%
    str_replace_all("　", "") %>%
    str_trim()
}

make_unified_lookup <- function(crosswalk_path) {
  lookup <- read_csv(crosswalk_path, show_col_types = FALSE) %>%
    filter(!is.na(raw_option_text), raw_option_text != "") %>%
    mutate(
      raw_option_text_std = standardize_label_text(raw_option_text),
      raw_option_code_std = standardize_label_text(
        ifelse(
          integrated_var == "RENT" & !is.na(raw_option_order) & raw_option_order != "",
          raw_option_order,
          raw_option_code
        )
      ),
      unified_label = na_if(unified_label, ""),
      unified_code = suppressWarnings(as.integer(unified_code))
    ) %>%
    select(data_year, integrated_var, raw_var, raw_option_text_std, raw_option_code_std, unified_code, unified_label) %>%
    distinct()

  ambiguous <- lookup %>%
    group_by(data_year, integrated_var, raw_var, raw_option_text_std, raw_option_code_std) %>%
    summarise(
      mapping_n = n_distinct(paste(unified_code, unified_label, sep = "::")),
      .groups = "drop"
    ) %>%
    filter(mapping_n > 1L)

  if (nrow(ambiguous) > 0) {
    stop(
      "Ambiguous raw option mappings found in ", crosswalk_path,
      ". Rebuild or manually correct the crosswalk before harmonization."
    )
  }

  lookup
}

get_raw_text <- function(x) {
  if (inherits(x, "haven_labelled") || haven::is.labelled(x)) {
    return(as.character(as_factor(x)))
  }

  as.character(x)
}

get_raw_numeric <- function(x) {
  out <- suppressWarnings(as.numeric(as.character(x)))
  out
}

parse_unified_range <- function(label) {
  label_std <- standardize_label_text(label)
  label_std <- str_replace_all(label_std, ",", "")
  label_std <- str_replace_all(label_std, "元", "")

  if (is.na(label_std) || label_std == "") {
    return(list(lower = NA_real_, upper = NA_real_))
  }

  if (str_detect(label_std, "^未滿\\d+")) {
    upper <- suppressWarnings(as.numeric(str_extract(label_std, "\\d+")))
    return(list(lower = 0, upper = upper - 1))
  }

  if (str_detect(label_std, "^\\d+-\\d+$")) {
    parts <- str_split(label_std, "-", simplify = TRUE)
    return(list(
      lower = suppressWarnings(as.numeric(parts[, 1])),
      upper = suppressWarnings(as.numeric(parts[, 2]))
    ))
  }

  if (str_detect(label_std, "^\\d+及以上") || str_detect(label_std, "^\\d+以上")) {
    lower <- suppressWarnings(as.numeric(str_extract(label_std, "^\\d+")))
    return(list(lower = lower, upper = Inf))
  }

  list(lower = NA_real_, upper = NA_real_)
}

match_numeric_to_lookup <- function(raw_numeric, lookup) {
  if (is.na(raw_numeric) || nrow(lookup) == 0) {
    return(list(code = NA_integer_, label = NA_character_))
  }

  ranges <- map(lookup$unified_label, parse_unified_range)
  matched_idx <- which(map_lgl(ranges, function(one_range) {
    !is.na(one_range$lower) && !is.na(one_range$upper) &&
      raw_numeric >= one_range$lower && raw_numeric <= one_range$upper
  }))

  if (length(matched_idx) == 0) {
    return(list(code = NA_integer_, label = NA_character_))
  }

  matched_idx <- matched_idx[[1]]
  list(
    code = lookup$unified_code[[matched_idx]],
    label = lookup$unified_label[[matched_idx]]
  )
}

normalize_male_value <- function(code_value, label_value, raw_value) {
  raw_std <- standardize_label_text(raw_value)

  if (!is.na(code_value)) {
    if (code_value == 1L) {
      return(list(code = 1L, label = "男性", source = "crosswalk"))
    }

    if (code_value %in% c(0L, 2L)) {
      return(list(code = 0L, label = "非男性", source = "crosswalk"))
    }
  }

  if (!is.na(label_value)) {
    label_std <- standardize_label_text(label_value)

    if (label_std %in% c("男", "男性")) {
      return(list(code = 1L, label = "男性", source = "crosswalk"))
    }

    if (label_std %in% c("女", "女性", "非男性")) {
      return(list(code = 0L, label = "非男性", source = "crosswalk"))
    }
  }

  if (raw_std %in% c("男", "男性", "1")) {
    return(list(code = 1L, label = "男性", source = "fallback"))
  }

  if (raw_std %in% c("女", "女性", "0", "2")) {
    return(list(code = 0L, label = "非男性", source = "fallback"))
  }

  list(code = NA_integer_, label = NA_character_, source = "unmapped")
}

harmonize_single_variable <- function(
    dataset,
    dataset_var,
    data_year,
    integrated_var,
    raw_var,
    label_lookup,
    output = c("label", "code"),
    unmapped = c("raw", "na")) {
  output <- match.arg(output, several.ok = TRUE)
  unmapped <- match.arg(unmapped)

  n_rows <- nrow(dataset)

  if (is.na(dataset_var) || !dataset_var %in% names(dataset)) {
    empty_result <- tibble(
      raw_value = rep(NA_character_, n_rows),
      label = rep(NA_character_, n_rows),
      code = rep(NA_integer_, n_rows),
      mapped = rep(FALSE, n_rows),
      fallback_used = rep(FALSE, n_rows)
    )
    return(empty_result)
  }

  raw_values <- dataset[[dataset_var]]
  raw_text <- get_raw_text(raw_values)
  raw_numeric <- get_raw_numeric(raw_values)
  raw_code_std <- ifelse(is.na(raw_numeric), NA_character_, sub("\\.0+$", "", as.character(raw_numeric)))
  raw_text_std <- standardize_label_text(raw_text)

  lookup <- label_lookup %>%
    filter(
      data_year == !!data_year,
      integrated_var == !!integrated_var,
      raw_var == !!raw_var
    ) %>%
    distinct(raw_option_text_std, unified_code, unified_label, .keep_all = TRUE)

  if (nrow(lookup) > 0) {
    code_map <- setNames(lookup$unified_code, lookup$raw_option_text_std)
    label_map <- setNames(lookup$unified_label, lookup$raw_option_text_std)
    mapped_code <- unname(code_map[raw_text_std])
    mapped_label <- unname(label_map[raw_text_std])
  } else {
    mapped_code <- rep(NA_integer_, n_rows)
    mapped_label <- rep(NA_character_, n_rows)
  }

  # Label text differs across Stata/SPSS exports.  Use the underlying option
  # code as a deterministic fallback for categorical variables and ranges.
  if (nrow(lookup) > 0 && "raw_option_code_std" %in% names(lookup)) {
    lookup_code <- sub("\\.0+$", "", lookup$raw_option_code_std)
    for (i in seq_len(n_rows)) {
      if (!is.na(mapped_label[[i]]) || is.na(raw_code_std[[i]])) {
        next
      }
      code_idx <- which(!is.na(lookup_code) & lookup_code == raw_code_std[[i]])
      if (length(code_idx) == 1) {
        mapped_code[[i]] <- lookup$unified_code[[code_idx]]
        mapped_label[[i]] <- lookup$unified_label[[code_idx]]
      }
    }
  }

  if (nrow(lookup) > 0) {
    for (i in seq_len(n_rows)) {
      if (!is.na(mapped_label[[i]]) || is.na(raw_text_std[[i]]) || raw_text_std[[i]] == "") {
        next
      }

      partial_idx <- which(
        str_detect(lookup$raw_option_text_std, fixed(raw_text_std[[i]])) |
          str_detect(raw_text_std[[i]], fixed(lookup$raw_option_text_std))
      )

      if (length(partial_idx) == 1) {
        mapped_code[[i]] <- lookup$unified_code[[partial_idx]]
        mapped_label[[i]] <- lookup$unified_label[[partial_idx]]
      }
    }

    numeric_matches <- map(seq_len(n_rows), function(i) {
      if (!is.na(mapped_label[[i]]) || is.na(raw_numeric[[i]])) {
        return(list(code = mapped_code[[i]], label = mapped_label[[i]]))
      }
      match_numeric_to_lookup(raw_numeric[[i]], lookup)
    })

    mapped_code <- map_int(numeric_matches, ~ ifelse(is.null(.x$code) || is.na(.x$code), NA_integer_, as.integer(.x$code)))
    mapped_label <- map_chr(numeric_matches, ~ ifelse(is.null(.x$label) || is.na(.x$label), NA_character_, as.character(.x$label)))
  }

  fallback_used <- rep(FALSE, n_rows)

  if (integrated_var == "MALE") {
    male_results <- map(seq_len(n_rows), function(i) {
      normalize_male_value(mapped_code[[i]], mapped_label[[i]], raw_text[[i]])
    })
    mapped_code <- map_int(male_results, "code")
    mapped_label <- map_chr(male_results, "label")
    fallback_used <- map_chr(male_results, "source") == "fallback"
  }

  mapped_flag <- !(is.na(mapped_label) & is.na(mapped_code))

  if (unmapped == "raw") {
    mapped_label <- ifelse(is.na(mapped_label), raw_text, mapped_label)
  }

  if (unmapped == "na") {
    mapped_label[!mapped_flag] <- NA_character_
    mapped_code[!mapped_flag] <- NA_integer_
  }

  tibble(
    raw_value = raw_text,
    label = mapped_label,
    code = as.integer(mapped_code),
    mapped = mapped_flag,
    fallback_used = fallback_used
  )
}

append_check_file <- function(check_df, file_name) {
  ensure_main_output_dirs()
  file_path <- file.path(CHECKS_DIR, file_name)

  if (file.exists(file_path)) {
    existing <- read_csv(file_path, show_col_types = FALSE)
    combined <- bind_rows(existing, check_df) %>% distinct()
  } else {
    combined <- check_df %>% distinct()
  }

  write_csv(combined, file_path)
}

write_check_file <- function(check_df, file_name) {
  ensure_main_output_dirs()
  write_csv(check_df %>% distinct(), file.path(CHECKS_DIR, file_name))
}

validate_output_keys <- function(data, dataset_name) {
  required_cols <- c("ID", "DATA_Y")
  missing_cols <- setdiff(required_cols, names(data))

  if (length(missing_cols) > 0) {
    stop(dataset_name, " is missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  duplicated_rows <- data %>%
    count(ID, DATA_Y) %>%
    filter(n > 1)

  if (nrow(duplicated_rows) > 0) {
    stop(dataset_name, " has duplicated ID + DATA_Y keys.")
  }
}

validate_row_count <- function(data, expected_n, dataset_name, data_year, survey_tag) {
  if (nrow(data) != expected_n) {
    stop(
      dataset_name, " row count mismatch for data_year=", data_year,
      ", survey_tag=", survey_tag,
      ". Expected ", expected_n, " rows but got ", nrow(data), "."
    )
  }
}

build_analysis_samples <- function(data, race_var = "RACE", indigenous_exclusion_year = 2017L) {
  if (!race_var %in% names(data)) {
    stop("Cannot build indigenous analysis sample: missing ", race_var, ".")
  }

  race_value <- data[[race_var]]
  include_indigenous <- data$DATA_Y != indigenous_exclusion_year |
    (!is.na(race_value) & race_value != "非原住民族")

  samples <- bind_rows(
    data %>% mutate(sample_definition = "full_sample"),
    data[include_indigenous, , drop = FALSE] %>%
      mutate(sample_definition = "indigenous_analysis_sample")
  )

  audit <- data %>%
    mutate(
      excluded_non_indigenous = DATA_Y == indigenous_exclusion_year & !is.na(.data[[race_var]]) & .data[[race_var]] == "非原住民族",
      excluded_missing_race = DATA_Y == indigenous_exclusion_year & is.na(.data[[race_var]])
    ) %>%
    group_by(DATA_Y) %>%
    summarise(
      full_sample_n = n(),
      excluded_non_indigenous_n = sum(excluded_non_indigenous),
      excluded_missing_race_n = sum(excluded_missing_race),
      indigenous_analysis_sample_n = full_sample_n - excluded_non_indigenous_n - excluded_missing_race_n,
      .groups = "drop"
    )

  list(data = samples, audit = audit)
}

write_missing_variable_check <- function(check_df) {
  write_check_file(
    check_df %>%
      mutate(
        survey_tag = as.character(survey_tag),
        data_year = as.integer(data_year),
        integrated_var = as.character(integrated_var),
        raw_var = as.character(raw_var),
        dataset_var = as.character(dataset_var),
        status = as.character(status)
      ) %>%
      transmute(
        data_year,
        survey_tag,
        integrated_var,
        expected_raw_var = raw_var,
        resolved_dataset_var = dataset_var,
        status
      ),
    "check_missing_variables_by_year.csv"
  )
}

if (!isTRUE(getOption("indigenous.pipeline.ready"))) {
  source("code/01-00-load-packages.R", encoding = "UTF-8")
  source("code/03-00-survey-utils.R", encoding = "UTF-8")
}

# Mainline version: this script reads only 02-stage imported survey objects.

ensure_main_output_dirs()
ensure_dir("data/processed_data/03_income_expense")

context <- read_import_context()
import_index <- context$import_index
survey_datasets <- context$survey_datasets

income_crosswalk_path <- "data/processed_data/03_crosswalks/unified_answer_crosswalk_income.csv"
expenditure_crosswalk_path <- "data/processed_data/03_crosswalks/unified_answer_crosswalk_expenditure.csv"
output_dir <- "data/processed_data/03_income_expense"

build_block_spec <- function(crosswalk_path, import_index, survey_datasets) {
  available_years <- sort(unique(import_index$data_year))

  resolved_vars <- resolve_dataset_variables(
    crosswalk_path = crosswalk_path,
    import_index = import_index,
    survey_datasets = survey_datasets
  )

  crosswalk_vars <- read_csv(crosswalk_path, show_col_types = FALSE) %>%
    mutate(survey_tag = as.character(option_year)) %>%
    filter(data_year %in% available_years) %>%
    distinct(data_year, survey_tag, integrated_var, raw_var, mapping_type)

  crosswalk_vars %>%
    left_join(
      resolved_vars %>% select(data_year, survey_tag, integrated_var, raw_var, dataset_var, status),
      by = c("data_year", "survey_tag", "integrated_var", "raw_var")
    ) %>%
    mutate(
      survey_tag = as.character(survey_tag),
      status = case_when(
        !is.na(status) ~ status,
        is.na(raw_var) | raw_var == "" ~ "missing_in_metadata",
        TRUE ~ "missing_in_metadata"
      )
    ) %>%
    distinct(data_year, survey_tag, integrated_var, raw_var, .keep_all = TRUE) %>%
    arrange(data_year, survey_tag, integrated_var, raw_var)
}

choose_primary_row <- function(block_spec, data_year, survey_tag, integrated_var) {
  candidates <- block_spec %>%
    filter(
      data_year == !!data_year,
      survey_tag == !!survey_tag,
      integrated_var == !!integrated_var
    ) %>%
    mutate(
      raw_var_missing = is.na(raw_var) | raw_var == "",
      dataset_missing = is.na(dataset_var) | dataset_var == "",
      composite_raw = str_detect(coalesce(raw_var, ""), ";"),
      amount_var_preferred = str_detect(coalesce(dataset_var, ""), "_2$"),
      yes_no_var = str_detect(coalesce(dataset_var, ""), "_1$")
    ) %>%
    arrange(dataset_missing, raw_var_missing, composite_raw, desc(amount_var_preferred), yes_no_var, raw_var)

  if (nrow(candidates) == 0) {
    return(tibble())
  }

  candidates %>% slice(1)
}

sanitize_prefix <- function(x) {
  x %>%
    str_replace_all("[^A-Za-z0-9]+", "_") %>%
    str_replace_all("_+", "_") %>%
    str_replace_all("^_|_$", "") %>%
    toupper()
}

make_unmapped_check <- function(harmonized, data_year, survey_tag, integrated_var) {
  tibble(
    data_year = data_year,
    survey_tag = survey_tag,
    integrated_var = integrated_var,
    raw_value = harmonized$raw_value,
    mapped = harmonized$mapped
  ) %>%
    filter(!is.na(raw_value), raw_value != "", !mapped) %>%
    count(data_year, survey_tag, integrated_var, raw_value, name = "frequency")
}

build_mapping_check <- function(block_spec, file_name) {
  write_check_file(
    block_spec %>%
      transmute(
        data_year,
        survey_tag = as.character(survey_tag),
        integrated_var,
        expected_raw_var = raw_var,
        resolved_dataset_var = dataset_var,
        status
      ) %>%
      distinct() %>%
      arrange(data_year, survey_tag, integrated_var, expected_raw_var),
    file_name
  )
}

build_source_field_schema <- function(block_spec, domain) {
  map_dfr(seq_len(nrow(import_index)), function(i) {
    dataset <- get_dataset_by_row(import_index, survey_datasets, i)
    data_year <- import_index$data_year[[i]]
    survey_tag <- import_index$survey_tag[[i]]

    block_spec %>%
      filter(data_year == !!data_year, status %in% c("ok", "ok_override"), !is.na(dataset_var)) %>%
      distinct(data_year, integrated_var, raw_var, dataset_var) %>%
      mutate(
        domain = domain,
        survey_tag = as.character(survey_tag),
        storage_type = map_chr(dataset_var, ~ paste(class(dataset[[.x]]), collapse = ";")),
        value_label_n = map_int(dataset_var, ~ length(attr(dataset[[.x]], "labels"))),
        non_missing_n = map_int(dataset_var, ~ sum(!is.na(dataset[[.x]]))),
        distinct_n = map_int(dataset_var, ~ n_distinct(dataset[[.x]], na.rm = TRUE)),
        indicator_var = ifelse(
          str_detect(dataset_var, "_2$"),
          str_replace(dataset_var, "_2$", "_1"),
          NA_character_
        ),
        indicator_exists = !is.na(indicator_var) & indicator_var %in% names(dataset),
        open_amount_var = ifelse(
          str_detect(dataset_var, "_2$"),
          str_replace(dataset_var, "_2$", "_2o"),
          NA_character_
        ),
        open_amount_exists = !is.na(open_amount_var) & open_amount_var %in% names(dataset)
      ) %>%
      select(
        domain, data_year, survey_tag, integrated_var, raw_var, dataset_var,
        storage_type, value_label_n, non_missing_n, distinct_n,
        indicator_var, indicator_exists, open_amount_var, open_amount_exists
      )
  })
}

build_distribution_check <- function(data, value_prefix, file_name) {
  code_col <- paste0(value_prefix, "_CODE")
  label_col <- value_prefix

  distribution <- names(data) %>%
    keep(~ str_ends(.x, paste0("_", code_col))) %>%
    map_dfr(function(one_col) {
      prefix <- str_remove(one_col, paste0("_", code_col, "$"))
      label_name <- paste0(prefix, "_", label_col)
      integrated_var <- prefix

      tibble(
        data_year = data$DATA_Y,
        harmonized_code = data[[one_col]],
        harmonized_label = data[[label_name]],
        integrated_var = integrated_var
      ) %>%
        count(data_year, integrated_var, harmonized_code, harmonized_label, name = "frequency")
    })

  write_check_file(
    distribution %>% arrange(data_year, integrated_var, harmonized_code, harmonized_label),
    file_name
  )
}

validate_code_columns <- function(data, block_spec, crosswalk_path, value_prefix, dataset_name) {
  crosswalk_codes <- read_csv(crosswalk_path, show_col_types = FALSE) %>%
    filter(!is.na(unified_code), unified_code != "") %>%
    mutate(unified_code = as.integer(unified_code)) %>%
    distinct(integrated_var, unified_code)

  code_cols <- names(data) %>% keep(~ str_ends(.x, paste0("_", value_prefix, "_CODE")))

  for (one_col in code_cols) {
    integrated_var <- str_remove(one_col, paste0("_", value_prefix, "_CODE$"))
    allowed_codes <- crosswalk_codes %>%
      filter(integrated_var == !!integrated_var) %>%
      pull(unified_code) %>%
      unique()
    if (value_prefix == "EXPENDITURE") {
      allowed_codes <- union(allowed_codes, 0L)
    }

    if (length(allowed_codes) == 0) {
      next
    }

    invalid_rows <- data %>%
      filter(!is.na(.data[[one_col]]) & !.data[[one_col]] %in% allowed_codes)

    if (nrow(invalid_rows) > 0) {
      stop(dataset_name, " contains invalid codes in ", one_col, ".")
    }
  }
}

classify_two_stage_values <- function(indicator_raw, amount_raw) {
  indicator_text <- str_trim(coalesce(as.character(indicator_raw), ""))
  amount_text <- coalesce(as.character(amount_raw), "")
  explicit_no <- indicator_text %in% c("沒有", "無")
  indicator_missing <- indicator_text == "" |
    str_detect(indicator_text, "未回答|不知道|拒答|跳答|不適用")
  zero_label <- str_detect(
    amount_text,
    "沒有這項支出|沒有這項收入|無此消費|無此收入"
  )
  nonresponse <- str_detect(amount_text, "未回答|不知道|拒答|跳答|不適用")
  usable_amount <- amount_text != "" & !zero_label & !nonresponse
  amount_missing <- amount_text == "" | nonresponse

  tibble(
    explicit_no,
    indicator_missing,
    usable_amount,
    amount_missing,
    conflict = explicit_no & usable_amount,
    zero_from_indicator = explicit_no & !usable_amount
  )
}

apply_two_stage_indicator_override <- function(two_stage_state, indicator_code, override_row) {
  if (nrow(override_row) == 0L) {
    return(two_stage_state)
  }
  if (nrow(override_row) > 1L) {
    stop("Two-stage indicator override must contain at most one row.")
  }

  override_no <- !is.na(indicator_code) & indicator_code == override_row$no_code[[1]]
  two_stage_state$explicit_no <- two_stage_state$explicit_no | override_no
  if (override_row$amount_conflict_action[[1]] == "indicator_no_wins") {
    two_stage_state$zero_from_indicator <- two_stage_state$explicit_no
    two_stage_state$conflict <- two_stage_state$explicit_no & two_stage_state$usable_amount
  }
  two_stage_state
}

classify_unlabelled_numeric <- function(underlying_numeric, labelled_codes, known_option_codes, mapped) {
  unlabelled_numeric <- if (length(labelled_codes) > 0L) {
    !is.na(underlying_numeric) & !underlying_numeric %in% labelled_codes
  } else {
    rep(FALSE, length(underlying_numeric))
  }
  known_unlabelled_code <- !is.na(underlying_numeric) &
    underlying_numeric %in% known_option_codes & mapped
  unlabelled_numeric & !known_unlabelled_code
}

build_block_dataset <- function(block_spec, label_lookup, value_prefix, check_unmapped_file) {
  indicator_override_path <- "data/processed_data/03_crosswalks/two_stage_indicator_overrides.csv"
  indicator_overrides <- if (file.exists(indicator_override_path)) {
    read_csv(indicator_override_path, show_col_types = FALSE) %>%
      mutate(data_year = as.integer(data_year), survey_tag = as.character(survey_tag))
  } else {
    tibble()
  }
  unmapped_checks <- tibble(
    data_year = integer(),
    survey_tag = character(),
    integrated_var = character(),
    raw_value = character(),
    frequency = integer()
  )
  field_value_checks <- tibble(
    data_year = integer(),
    survey_tag = character(),
    integrated_var = character(),
    dataset_var = character(),
    value_source = character(),
    frequency = integer(),
    example_values = character()
  )
  indicator_conflict_checks <- tibble(
    data_year = integer(), survey_tag = character(), integrated_var = character(),
    dataset_var = character(), indicator_var = character(), indicator_label_set = character(),
    explicit_no_n = integer(), indicator_missing_n = integer(), usable_amount_n = integer(),
    indicator_missing_amount_missing_n = integer(), conflict_n = integer(),
    eligible_n = integer(), conflict_pct = double(),
    example_amount_values = character()
  )

  integrated_vars <- sort(unique(block_spec$integrated_var))

  block_rows <- vector("list", nrow(import_index))

  for (i in seq_len(nrow(import_index))) {
    dataset <- get_dataset_by_row(import_index, survey_datasets, i)
    data_year <- import_index$data_year[[i]]
    survey_tag <- import_index$survey_tag[[i]]
    survey_keys <- build_survey_keys(dataset, data_year, survey_tag)

    output <- tibble(
      ID = survey_keys$ID,
      DATA_Y = survey_keys$DATA_Y
    )

    if (value_prefix == "INCOME") {
      i1_text <- if (data_year == 2014L && "i1" %in% names(dataset)) {
        str_trim(coalesce(get_raw_text(dataset[["i1"]]), ""))
      } else {
        rep("", nrow(dataset))
      }
      output$ELIG_INC_FAM_COMPONENTS <- case_when(
        data_year != 2014L ~ NA,
        str_detect(i1_text, "^有") ~ TRUE,
        str_detect(i1_text, "^沒有") ~ FALSE,
        TRUE ~ NA
      )
      output$ELIG_INC_FAM_COMPONENTS_SOURCE <- if (data_year == 2014L) {
        na_if(i1_text, "")
      } else {
        rep(NA_character_, nrow(dataset))
      }
    }

    for (one_var in integrated_vars) {
      prefix <- sanitize_prefix(one_var)
      selected_row <- choose_primary_row(
        block_spec,
        data_year,
        survey_tag,
        one_var
      )

      raw_col <- paste0(prefix, "_", value_prefix, "_RAW")
      code_col <- paste0(prefix, "_", value_prefix, "_CODE")
      label_col <- paste0(prefix, "_", value_prefix)
      source_col <- paste0(prefix, "_", value_prefix, "_VALUE_SOURCE")

      if (nrow(selected_row) == 0 || is.na(selected_row$dataset_var[[1]]) ||
          !selected_row$status[[1]] %in% c("ok", "ok_override")) {
        output[[raw_col]] <- NA_character_
        output[[code_col]] <- NA_integer_
        output[[label_col]] <- NA_character_
        output[[source_col]] <- NA_character_
        next
      }

      harmonized <- harmonize_single_variable(
        dataset = dataset,
        dataset_var = selected_row$dataset_var[[1]],
        data_year = data_year,
        integrated_var = one_var,
        raw_var = selected_row$raw_var[[1]],
        label_lookup = label_lookup,
        output = c("label", "code"),
        unmapped = ifelse(selected_row$mapping_type[[1]] == "conceptual_only", "raw", "na")
      )
      value_source <- ifelse(
        is.na(harmonized$raw_value),
        "missing",
        "source_question"
      )

      # Labelled bracket codes and unlabelled open-entry
      # amounts can coexist in one Stata column.  Membership in the Stata
      # value-label code set, rather than numeric appearance alone, determines
      # whether a value is a code or an exact amount.
      selected_values <- dataset[[selected_row$dataset_var[[1]]]]
      if (inherits(selected_values, "haven_labelled") || haven::is.labelled(selected_values)) {
        labelled_codes <- suppressWarnings(as.numeric(unname(attr(selected_values, "labels"))))
        underlying_numeric <- suppressWarnings(as.numeric(selected_values))
        known_option_codes <- label_lookup %>%
          filter(
            .data$data_year == .env$data_year,
            .data$integrated_var == .env$one_var,
            .data$raw_var == selected_row$raw_var[[1]]
          ) %>%
          pull(raw_option_code_std) %>%
          suppressWarnings(as.numeric()) %>%
          unique()
        unlabelled_numeric <- classify_unlabelled_numeric(
          underlying_numeric,
          labelled_codes,
          known_option_codes,
          harmonized$mapped
        )
        if (any(unlabelled_numeric)) {
          exact_text <- format(
            underlying_numeric[unlabelled_numeric],
            scientific = FALSE,
            trim = TRUE
          )
          harmonized$raw_value[unlabelled_numeric] <- exact_text
          harmonized$code[unlabelled_numeric] <- NA_integer_
          harmonized$label[unlabelled_numeric] <- exact_text
          harmonized$mapped[unlabelled_numeric] <- TRUE
          value_source[unlabelled_numeric] <- "unlabelled_numeric_exact_amount"
        }
      }

      # Later surveys store two-stage expenditure questions in separate
      # columns: *_1 is "有/沒有", while *_2 is the amount bracket.  A missing
      # amount is a true zero when the companion indicator explicitly says
      # "沒有"; it is not response missing.
      if (value_prefix == "EXPENDITURE" && str_detect(selected_row$dataset_var[[1]], "_2$")) {
        indicator_var <- str_replace(selected_row$dataset_var[[1]], "_2$", "_1")
        zero_from_indicator <- rep(FALSE, nrow(dataset))
        if (indicator_var %in% names(dataset)) {
          indicator_raw <- get_raw_text(dataset[[indicator_var]])
          indicator_code <- suppressWarnings(as.integer(as.character(dataset[[indicator_var]])))
          amount_text <- coalesce(harmonized$raw_value, "")
          two_stage_state <- classify_two_stage_values(indicator_raw, amount_text)
          one_override <- indicator_overrides %>%
            filter(
              .data$data_year == .env$data_year,
              .data$survey_tag == as.character(.env$survey_tag),
              .data$integrated_var == .env$one_var,
              .data$indicator_var == .env$indicator_var
            )
          if (nrow(one_override) > 1L) {
            stop("Duplicate two-stage indicator override: ", data_year, "/", one_var)
          }
          two_stage_state <- apply_two_stage_indicator_override(
            two_stage_state, indicator_code, one_override
          )
          explicit_no <- two_stage_state$explicit_no
          indicator_missing <- two_stage_state$indicator_missing
          usable_amount <- two_stage_state$usable_amount
          amount_missing <- two_stage_state$amount_missing
          conflict <- two_stage_state$conflict
          zero_from_indicator <- two_stage_state$zero_from_indicator

          indicator_label_set <- tibble(code = indicator_code, label = indicator_raw) %>%
            filter(!is.na(code) | (!is.na(label) & label != "")) %>%
            distinct() %>%
            arrange(code, label) %>%
            transmute(pair = paste0(coalesce(as.character(code), "NA"), "=", coalesce(label, "NA"))) %>%
            pull(pair) %>%
            paste(collapse = ";")
          indicator_conflict_checks <- bind_rows(
            indicator_conflict_checks,
            tibble(
              data_year = data_year, survey_tag = as.character(survey_tag), integrated_var = one_var,
              dataset_var = selected_row$dataset_var[[1]], indicator_var = indicator_var,
              indicator_label_set = indicator_label_set,
              explicit_no_n = sum(explicit_no, na.rm = TRUE),
              indicator_missing_n = sum(indicator_missing, na.rm = TRUE),
              usable_amount_n = sum(usable_amount, na.rm = TRUE),
              indicator_missing_amount_missing_n = sum(indicator_missing & amount_missing, na.rm = TRUE),
              conflict_n = sum(conflict, na.rm = TRUE), eligible_n = nrow(dataset),
              conflict_pct = sum(conflict, na.rm = TRUE) / nrow(dataset),
              example_amount_values = paste(head(sort(unique(amount_text[conflict])), 5L), collapse = ";")
            )
          )

          harmonized$raw_value[zero_from_indicator] <- "沒有這項支出"
          harmonized$code[zero_from_indicator] <- 0L
          harmonized$label[zero_from_indicator] <- "沒有這項支出"
          harmonized$mapped[zero_from_indicator] <- TRUE
          value_source[zero_from_indicator] <- "indicator_no_zero"
        }

        open_amount_var <- str_replace(selected_row$dataset_var[[1]], "_2$", "_2o")
        if (open_amount_var %in% names(dataset)) {
          open_amount <- suppressWarnings(as.numeric(as.character(dataset[[open_amount_var]])))
          use_open_amount <- !zero_from_indicator & !is.na(open_amount) & open_amount > 0
          if (any(use_open_amount)) {
            exact_text <- format(
              open_amount[use_open_amount],
              scientific = FALSE,
              trim = TRUE
            )
            harmonized$raw_value[use_open_amount] <- exact_text
            harmonized$code[use_open_amount] <- NA_integer_
            harmonized$label[use_open_amount] <- exact_text
            harmonized$mapped[use_open_amount] <- TRUE
            value_source[use_open_amount] <- "open_amount"
          }
        }
      }

      output[[raw_col]] <- harmonized$raw_value
      output[[code_col]] <- harmonized$code
      output[[label_col]] <- harmonized$label
      output[[source_col]] <- value_source

      field_value_checks <- bind_rows(
        field_value_checks,
        tibble(
          data_year = data_year,
          survey_tag = as.character(survey_tag),
          integrated_var = one_var,
          dataset_var = selected_row$dataset_var[[1]],
          value_source,
          raw_value = harmonized$raw_value
        ) %>%
          group_by(data_year, survey_tag, integrated_var, dataset_var, value_source) %>%
          summarise(
            frequency = n(),
            example_values = paste(head(sort(unique(na.omit(raw_value))), 5L), collapse = ";"),
            .groups = "drop"
          )
      )

      unmapped_checks <- bind_rows(
        unmapped_checks,
        make_unmapped_check(
          harmonized = harmonized,
          data_year = data_year,
          survey_tag = survey_tag,
          integrated_var = one_var
        )
      )
    }

    validate_row_count(output, nrow(dataset), paste0(value_prefix, "_data"), data_year, survey_tag)
    block_rows[[i]] <- output
  }

  block_data <- bind_rows(block_rows)

  validate_output_keys(block_data, paste0(value_prefix, "_data"))

  write_check_file(
    unmapped_checks %>% distinct() %>% arrange(data_year, survey_tag, integrated_var, raw_value),
    check_unmapped_file
  )

  write_check_file(
    field_value_checks %>%
      distinct() %>%
      arrange(data_year, integrated_var, dataset_var, value_source),
    paste0("check_", str_to_lower(value_prefix), "_value_sources.csv")
  )

  if (value_prefix == "EXPENDITURE") {
    write_check_file(
      indicator_conflict_checks %>% distinct() %>% arrange(data_year, survey_tag, integrated_var),
      "check_two_stage_indicator_conflict.csv"
    )
  }

  block_data
}

income_spec <- build_block_spec(income_crosswalk_path, import_index, survey_datasets)
expenditure_spec <- build_block_spec(expenditure_crosswalk_path, import_index, survey_datasets)

unexpected_resolution_failures <- bind_rows(income_spec, expenditure_spec) %>%
  filter(
    !is.na(raw_var), raw_var != "",
    !status %in% c("ok", "ok_override")
  )
if (nrow(unexpected_resolution_failures) > 0L) {
  stop(
    "Crosswalk specifies source questions that cannot be resolved: ",
    paste(
      paste0(
        unexpected_resolution_failures$data_year, "/",
        unexpected_resolution_failures$integrated_var, "=",
        unexpected_resolution_failures$raw_var, " (",
        unexpected_resolution_failures$status, ")"
      ),
      collapse = "; "
    )
  )
}

build_mapping_check(income_spec, "check_income_variable_mapping.csv")
build_mapping_check(expenditure_spec, "check_expenditure_variable_mapping.csv")
write_check_file(
  bind_rows(
    build_source_field_schema(income_spec, "income"),
    build_source_field_schema(expenditure_spec, "expenditure")
  ) %>%
    arrange(data_year, domain, integrated_var, dataset_var),
  "check_source_field_schema.csv"
)

write_check_file(
  expenditure_spec %>%
    filter(str_detect(coalesce(raw_var, ""), "^(Q12-|J7-|M7-|H7-)")) %>%
    transmute(
      data_year,
      survey_tag,
      integrated_var,
      raw_var,
      mapping_type,
      resolved_dataset_var = dataset_var,
      selected_field_type = case_when(
        str_detect(coalesce(dataset_var, ""), "_2o$") ~ "open_amount",
        str_detect(coalesce(dataset_var, ""), "_2$") ~ "amount",
        str_detect(coalesce(dataset_var, ""), "_1$") ~ "yes_no",
        TRUE ~ "other_or_missing"
      ),
      status
    ) %>%
    distinct() %>%
    arrange(data_year, integrated_var, raw_var),
  "check_two_stage_expenditure_variables.csv"
)

income_lookup <- make_unified_lookup(income_crosswalk_path)
expenditure_lookup <- make_unified_lookup(expenditure_crosswalk_path)

income_data <- build_block_dataset(
  block_spec = income_spec,
  label_lookup = income_lookup,
  value_prefix = "INCOME",
  check_unmapped_file = "check_unmapped_income_values.csv"
)

expenditure_data <- build_block_dataset(
  block_spec = expenditure_spec,
  label_lookup = expenditure_lookup,
  value_prefix = "EXPENDITURE",
  check_unmapped_file = "check_unmapped_expenditure_values.csv"
)

income_expenditure_data <- income_data %>%
  full_join(expenditure_data, by = c("ID", "DATA_Y"))

write_check_file(
  income_data %>%
    filter(DATA_Y == 2014L) %>%
    count(
      DATA_Y,
      ELIG_INC_FAM_COMPONENTS,
      ELIG_INC_FAM_COMPONENTS_SOURCE,
      name = "frequency"
    ) %>%
    arrange(ELIG_INC_FAM_COMPONENTS, ELIG_INC_FAM_COMPONENTS_SOURCE),
  "check_structural_eligibility_i1.csv"
)

validate_output_keys(income_expenditure_data, "income_expenditure_data")

validate_code_columns(
  data = income_data,
  block_spec = income_spec,
  crosswalk_path = income_crosswalk_path,
  value_prefix = "INCOME",
  dataset_name = "income_data"
)

validate_code_columns(
  data = expenditure_data,
  block_spec = expenditure_spec,
  crosswalk_path = expenditure_crosswalk_path,
  value_prefix = "EXPENDITURE",
  dataset_name = "expenditure_data"
)

build_distribution_check(income_data, "INCOME", "check_income_distribution.csv")
build_distribution_check(expenditure_data, "EXPENDITURE", "check_expenditure_distribution.csv")

saveRDS(as.data.table(income_data), file.path(output_dir, "income_data.rds"))
saveRDS(as.data.table(expenditure_data), file.path(output_dir, "expenditure_data.rds"))
saveRDS(as.data.table(income_expenditure_data), file.path(output_dir, "income_expenditure_data.rds"))

export_intermediate_csv <- tolower(
  Sys.getenv("EXPORT_INTERMEDIATE_CSV", unset = "false")
) %in% c("1", "true", "yes")

if (export_intermediate_csv) {
  message("EXPORT_INTERMEDIATE_CSV=true: writing optional wide CSV copies.")
  fwrite(as.data.table(income_data), file.path(output_dir, "income_data.csv"))
  fwrite(as.data.table(expenditure_data), file.path(output_dir, "expenditure_data.csv"))
  fwrite(
    as.data.table(income_expenditure_data),
    file.path(output_dir, "income_expenditure_data.csv")
  )
} else {
  message(
    "Skipping optional intermediate CSV copies. ",
    "RDS outputs are complete and are used by downstream scripts."
  )
}

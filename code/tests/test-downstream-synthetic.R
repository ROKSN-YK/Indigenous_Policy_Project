source_project <- normalizePath(".", winslash = "/", mustWork = TRUE)
test_root <- tempfile("indigenous-downstream-")
dir.create(test_root, recursive = TRUE)

file.copy(file.path(source_project, "code"), test_root, recursive = TRUE)
dir.create(file.path(test_root, "data", "processed_data"), recursive = TRUE)
file.copy(
  file.path(source_project, "data", "processed_data", "03_crosswalks"),
  file.path(test_root, "data", "processed_data"),
  recursive = TRUE
)

years <- c(2002L, 2002L, 2006L, 2010L, 2014L, 2017L, 2021L)
tags <- c("91_1", "91_2", "95", "99", "103", "106", "110")
base <- data.frame(
  ID = paste0(tags, "::1"),
  SOURCE_ID = "1",
  SURVEY_TAG = tags,
  DATA_Y = years,
  stringsAsFactors = FALSE
)

basic <- base
demographic <- transform(
  base[c("ID", "DATA_Y")],
  CITY = "測試市",
  COUNTY = "測試區",
  AGE_GROUP = "30-39歲",
  AGE_GROUP_HARMONIZED = "30-39歲",
  AGE_MEASURE_TYPE = "age_group",
  MALE = "男性",
  MALE_CODE = 1L,
  RACE = "阿美族"
)
family <- transform(
  base[c("ID", "DATA_Y")],
  N_FAMILY = "2",
  N_INDI = "2",
  N_INDI_UNDER6 = ifelse(DATA_Y == 2002L, NA, 1),
  N_INDI_7_15 = ifelse(DATA_Y == 2002L, NA, 0),
  N_INDI_16_54 = ifelse(DATA_Y == 2002L, NA, 1),
  N_INDI_55_64 = ifelse(DATA_Y == 2002L, NA, 0),
  N_INDI_65PLUS = ifelse(DATA_Y == 2002L, NA, 0),
  N_INDI_55PLUS = ifelse(DATA_Y == 2002L, NA, 0),
  HAS_INDI_55PLUS = ifelse(DATA_Y == 2002L, NA, FALSE),
  HAS_INDI_65PLUS = ifelse(DATA_Y == 2002L, NA, FALSE),
  HOUSE_BELONG = "租賃",
  RENT = "1,000-2,999元"
)
money <- transform(
  base[c("ID", "DATA_Y")],
  INC_FAM_WORK = ifelse(DATA_Y == 2014L, "10,000-19,999 元", NA),
  INC_FAM_WORK_RAW = ifelse(DATA_Y == 2014L, "10,000-19,999 元", NA),
  INC_FAM_WORK_CODE = ifelse(DATA_Y == 2014L, 1L, NA_integer_),
  ELIG_INC_FAM_COMPONENTS = ifelse(DATA_Y == 2014L, FALSE, NA),
  EXP_TRAVEL = ifelse(DATA_Y == 2002L & tags == "91_2", "1,000-1,999 元", NA),
  EXP_TRAVEL_RAW = ifelse(DATA_Y == 2002L & tags == "91_2", "1,000-1,999 元", NA),
  EXP_TRAVEL_CODE = ifelse(DATA_Y == 2002L & tags == "91_2", 1L, NA_integer_),
  EXP_EDU_BOOKS_COMBINED = ifelse(
    (DATA_Y == 2002L & tags == "91_2") | DATA_Y %in% c(2006L, 2010L),
    "1,000-1,999 元", NA
  ),
  EXP_EDU_BOOKS_COMBINED_RAW = ifelse(
    (DATA_Y == 2002L & tags == "91_2") | DATA_Y %in% c(2006L, 2010L),
    "1,000-1,999 元", NA
  ),
  EXP_EDU_BOOKS_COMBINED_CODE = ifelse(
    (DATA_Y == 2002L & tags == "91_2") | DATA_Y %in% c(2006L, 2010L),
    1L, NA_integer_
  )
)

dir.create(file.path(test_root, "data", "processed_data", "03_income_expense"), recursive = TRUE)
saveRDS(basic, file.path(test_root, "data", "processed_data", "basic_info_from_02.rds"))
saveRDS(demographic, file.path(test_root, "data", "processed_data", "demographic_data_from_02.rds"))
saveRDS(family, file.path(test_root, "data", "processed_data", "family_data_from_02.rds"))
saveRDS(money, file.path(test_root, "data", "processed_data", "03_income_expense", "income_expenditure_data.rds"))

old_wd <- getwd()
on.exit(setwd(old_wd), add = TRUE)
setwd(test_root)
source("code/04-01-aggregate-cross-year-data.R", encoding = "UTF-8")
source("code/05-01-summary-statistics.R", encoding = "UTF-8")
source("code/05-02-income-expenditure-recode-summary.R", encoding = "UTF-8")

numeric_reference <- read.csv(
  "data/processed_data/05_reference/cross_year_numeric_by_year.csv",
  check.names = FALSE
)
stopifnot("N_INDI_UNDER6" %in% numeric_reference$variable)

categorical_reference <- read.csv(
  "data/processed_data/05_reference/cross_year_categorical_by_year.csv",
  check.names = FALSE
)
stopifnot(!"SOURCE_ID" %in% categorical_reference$variable)

coverage <- read.csv("output/summary_statistics/coverage_summary.csv", check.names = FALSE)
names(coverage) <- make.names(names(coverage))
stopifnot(any(
  coverage$Survey.Year == 2002L &
    coverage$Variable == "EXP_TRAVEL_EXPENDITURE" &
    coverage$Structural.Missing.N > 0L
))
stopifnot(any(
  coverage$Survey.Year == 2014L &
    coverage$Variable == "INC_FAM_WORK_INCOME" &
    coverage$Structural.Missing.N > 0L
))

recoded_coverage <- read.csv(
  "output/summary_statistics/income_expenditure_recoded/income_expenditure_coverage_summary.csv",
  check.names = FALSE
)
stopifnot(all(
  recoded_coverage$structural_missing_status ==
    "evaluated_from_structural_eligibility"
))
stopifnot(all(
  recoded_coverage$Valid.N +
    recoded_coverage$Response.Missing.N +
    recoded_coverage$Structural.Missing.N ==
    recoded_coverage$Eligible.N
))

message("Synthetic downstream pipeline tests passed.")

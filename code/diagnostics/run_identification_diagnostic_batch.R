#!/usr/bin/env Rscript

# Repository-local identification diagnostics for the Cultural Health Station study.
# This script reads canonical/archived repository outputs only and writes exclusively
# to diagnostics/ and docs/evidence/. It never modifies raw or canonical datasets.

options(stringsAsFactors = FALSE)
set.seed(20260814)

root <- normalizePath(".", mustWork = TRUE)
out_dir <- file.path(root, "diagnostics")
report_dir <- file.path(root, "docs", "evidence")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)
for (d in c("gate2_selection_figures", "gate2_pretrend_figures", "gate3_ddd_figures")) {
  dir.create(file.path(out_dir, d), recursive = TRUE, showWarnings = FALSE)
}

paths <- list(
  canonical = "data/processed_data/04_analysis_ready/cross_year_combined_with_care_station.rds",
  canonical_upstream = "data/processed_data/04_analysis_ready/cross_year_combined_data.rds",
  imported_index = "data/processed_data/02_metadata/imported_survey_index.csv",
  imported_rds = "data/processed_data/02_metadata/survey_datasets.rds",
  station_panel = "data/processed_data/05_reference/care_station_town_year_panel_long.csv",
  categorical_town = "data/processed_data/05_reference/cross_year_categorical_by_year_region.csv",
  numeric_town = "data/processed_data/05_reference/cross_year_numeric_by_year_region.csv",
  archived_coverage = "archive/2026-08-11/20260810-offline-run/output/summary_statistics/coverage_summary.csv",
  archived_age_check = "archive/2026-08-11/20260810-offline-run/output/checks/check_family_indigenous_age_counts.csv",
  archived_merge_check = "archive/2026-08-11/20260810-offline-run/output/checks/check_care_station_merge_coverage.csv",
  archived_sample = "archive/2026-08-11/20260810-offline-run/output/summary_statistics/sample_by_year.csv",
  recode_table = "archive/2026-08-11/20260810-offline-run/output/summary_statistics/income_expenditure_recoded/income_expenditure_recoding_table.csv",
  family_crosswalk = "data/processed_data/03_crosswalks/family_count_crosswalk.csv",
  questionnaire_crosswalk = "data/processed_data/03_crosswalks/unified_answer_crosswalk_expenditure.csv",
  weight_crosswalk = "data/processed_data/03_crosswalks/manual_question_crosswalk.tsv",
  midpoint_doc = "data/processed_data/01_documentation/2026-07-20_summary_rebuild_codebook.md",
  station_doc = "docs/OFFLINE_CORRECTION_AND_CARE_STATION_GUIDE_2026-08-06.md"
)

missing_paths <- names(paths)[!file.exists(file.path(root, unlist(paths)))]
if (length(missing_paths)) stop("Missing required repository inputs: ", paste(missing_paths, collapse = ", "))

write_csv <- function(x, path) write.csv(x, path, row.names = FALSE, na = "")
write_md <- function(lines, path) writeLines(enc2utf8(lines), path, useBytes = TRUE)
fmt <- function(x, digits = 1) ifelse(is.na(x), "NA", format(round(x, digits), big.mark = ",", trim = TRUE))
assert_cols <- function(x, required, object_name) {
  absent <- setdiff(required, names(x))
  if (length(absent)) stop(object_name, " is missing required variables: ", paste(absent, collapse = ", "))
}

# ---- Step 0: repository state -------------------------------------------------
canonical <- readRDS(paths$canonical)
import_idx <- read.csv(paths$imported_index, check.names = FALSE)
assert_cols(canonical, c("ID", "DATA_Y", "CITY", "COUNTY", "EXP_MEDICAL_EXPENDITURE", "care_station_first_year"), "canonical household dataset")
assert_cols(import_idx, c("survey_tag", "data_year", "file_path"), "imported survey index")
canonical_years <- sort(unique(canonical$DATA_Y))
canonical_town_ok <- sum(!is.na(canonical$COUNTY) & !canonical$COUNTY %in%
  c("未知地區", "北部地區", "中部地區", "南部地區", "東部及離島地區"))

inspection <- c(
  "# Repository inspection（Step 0）",
  "",
  "## Canonical 與資料狀態",
  "",
  paste0("- **OBSERVED** canonical household-level 候選：`", paths$canonical, "`（", nrow(canonical), " 列、年度：", paste(canonical_years, collapse = ", "), "）。"),
  paste0("- **OBSERVED** 具可用鄉鎮地理的 canonical 列數：", canonical_town_ok, "。2021 僅四大區域，不能與鄉鎮文健站 panel 配對。"),
  paste0("- **OBSERVED** imported survey index 僅列：", paste(import_idx$data_year, collapse = ", "), "；`survey_datasets.rds` 同樣僅含 2021。"),
  paste0("- **DOCUMENTED** 2002–2021 六波曾於受限離線環境運行；其聚合檢查表位於 `", paths$archived_sample, "`，但 repository 不含 2002–2017 household microdata。"),
  "- **INFERRED** 現存 household canonical 不是本研究 2006–2017 主視窗可直接使用的跨波 canonical；archive 的鄉鎮邊際彙總只能支持部分診斷。",
  "",
  "## Discovered definitions and files",
  "",
  paste0("- station town-year panel：`", paths$station_panel, "`。"),
  "- treatment first year：`care_station_first_year`（民國年）；來源為 114 年現存營運清冊回推。",
  "- survey year：`DATA_Y`（西元年）；station panel 對應欄為 `survey_roc_year`（民國年）。",
  "- township key：`CITY + COUNTY`；不得只用鄉鎮名稱。",
  "- Indigenous household/member counts：`N_INDI` 及 F14 年齡格。",
  "- 55+ rule：`N_INDI_55_64 + N_INDI_65PLUS > 0`；程式證據 `code/03-03-make-family-data-from-02.R`。",
  "- medical outcome：`EXP_MEDICAL_EXPENDITURE`；級距以中點、開放金額優先，非精確連續金額。",
  paste0("- survey weights：候選欄位見 `", paths$weight_crosswalk, "`；跨波定義未齊，故本批不計 weighted count。"),
  "- care outcome：`EXP_CARE_EXPENDITURE`；food outcome：`EXP_FOOD_EXPENDITURE`。",
  "- questionnaire PDFs：`docs/codebooks/ques95.pdf`、`ques99.pdf`、`ques103.pdf`、`ques106.pdf`。",
  paste0("- expenditure crosswalk：`", paths$questionnaire_crosswalk, "`。"),
  "- existing policy scripts：`code/03-05-build-care-station-town-year-panel.R`、`code/04-02-merge-care-station-exposure.R`。",
  "- existing summary scripts：`code/05-01-summary-statistics.R`、`code/05-02-income-expenditure-recode-summary.R`。",
  "- existing DID note：`data/processed_data/01_documentation/DID_ANALYSIS_GUIDE.md`；未發現已完成的 Callaway–Sant’Anna 或 eligibility DDD 程式。",
  "",
  "## Material limitations",
  "",
  "- **BLOCKED — MISSING JOINT MICRODATA**：archive 只保留各變數的鄉鎮邊際分布，無法把 eligibility 與 medical outcome 交叉。",
  "- **BLOCKED — WEIGHT DEFINITION AMBIGUITY**：權數名稱與定義跨波不同，尚無逐波可比性認定。",
  "- **WARNING — HISTORICAL ROSTER**：registry-external 代表不在 114 年現存清冊，不等於經證實 never-treated。",
  "- **WARNING — COHORT BINNING**：本診斷把 canonical first year 映射至『下一個調查波首次可觀察為已處置』；若研究者意指精確成立年度 cohort，需另行決定。"
)
write_md(inspection, file.path(out_dir, "repository_inspection.md"))

# ---- Shared aggregate inputs --------------------------------------------------
cat_town <- read.csv(paths$categorical_town, check.names = FALSE)
num_town <- read.csv(paths$numeric_town, check.names = FALSE)
station <- read.csv(paths$station_panel, check.names = FALSE)
assert_cols(cat_town, c("DATA_Y", "CITY", "COUNTY", "variable", "category", "n"), "town categorical marginals")
assert_cols(num_town, c("DATA_Y", "CITY", "COUNTY", "variable", "non_missing_n", "mean"), "town numeric marginals")
assert_cols(station, c("station_county", "station_township", "survey_roc_year", "care_station_first_year"), "station panel")
expected_main_years <- c(2006, 2010, 2014, 2017)
if (!all(expected_main_years %in% unique(cat_town$DATA_Y))) stop("Town marginals do not contain all required policy-window years: ", paste(setdiff(expected_main_years, unique(cat_town$DATA_Y)), collapse=", "))
observed_first <- unique(na.omit(station$care_station_first_year))
if (!length(observed_first) || any(observed_first < 80 | observed_first > 114)) stop("Unexpected care_station_first_year values; expected ROC years 80–114.")
town_treat <- unique(station[c("station_county", "station_township", "care_station_first_year")])
names(town_treat)[1:2] <- c("CITY", "COUNTY")
town_treat$first_year_gregorian <- town_treat$care_station_first_year + 1911L

cohort_from_first <- function(y) {
  ifelse(is.na(y), "registry-external / potential never-treated",
    ifelse(y <= 2005, "always-treated / pre-window",
      ifelse(y <= 2006, "2006 cohort",
        ifelse(y <= 2010, "2010 cohort",
          ifelse(y <= 2014, "2014 cohort",
            ifelse(y <= 2017, "2017 cohort", "2018+ not-yet-treated"))))))
}
town_treat$cohort <- cohort_from_first(town_treat$first_year_gregorian)

all_towns <- unique(cat_town[c("CITY", "COUNTY")])
town_map <- merge(all_towns, town_treat, by = c("CITY", "COUNTY"), all.x = TRUE)
town_map$cohort[is.na(town_map$cohort)] <- "registry-external / potential never-treated"
combined_township_labels <- c(
  "八里鄉三芝鄉", "竹南鎮後龍鎮造橋鄉", "頭城礁溪員山鄉", "五結冬山鄉",
  "六龜鄉美濃鎮", "后里鄉外埔鄉", "大樹鄉仁武鄉", "新埔鎮芎林鄉橫山鄉",
  "林園鄉鳥松鄉", "水里鄉草屯鎮", "清水鎮沙鹿鎮", "烏日鄉霧峰鄉", "竹北市新豐鄉"
)
non_town_labels <- c(combined_township_labels, "未知地區", "北部地區", "中部地區", "南部地區", "東部及離島地區")
town_map$geography_precise <- !is.na(town_map$CITY) & !is.na(town_map$COUNTY) & !town_map$COUNTY %in% non_town_labels
cohort_levels <- c("always-treated / pre-window", "2006 cohort", "2010 cohort", "2014 cohort", "2017 cohort", "2018+ not-yet-treated", "registry-external / potential never-treated")

# ---- Gate 1: eligibility support from marginal tables -------------------------
elig <- subset(cat_town, DATA_Y %in% c(2006, 2010, 2014, 2017) & variable == "HAS_INDI_55PLUS")
elig <- merge(elig, town_map[c("CITY", "COUNTY", "cohort", "geography_precise")], by = c("CITY", "COUNTY"), all.x = TRUE)
elig <- subset(elig, geography_precise %in% TRUE)
elig$eligibility_group <- ifelse(toupper(elig$category) == "TRUE",
  "household contains Indigenous person aged 55+",
  "household does not contain Indigenous person aged 55+")

concentration <- do.call(rbind, lapply(split(elig, interaction(elig$cohort, elig$DATA_Y, elig$eligibility_group, drop = TRUE)), function(d) {
  total <- sum(d$n)
  d$household_share <- if (total > 0) d$n / total else NA_real_
  d[c("cohort", "DATA_Y", "eligibility_group", "CITY", "COUNTY", "n", "household_share")]
}))
names(concentration)[names(concentration) == "DATA_Y"] <- "survey_year"
write_csv(concentration[order(concentration$cohort, concentration$survey_year, concentration$eligibility_group, -concentration$household_share), ], file.path(out_dir, "gate1_town_concentration.csv"))

support <- do.call(rbind, lapply(split(concentration, interaction(concentration$cohort, concentration$survey_year, concentration$eligibility_group, drop = TRUE)), function(d) {
  shares <- sort(d$household_share, decreasing = TRUE)
  data.frame(
    treatment_cohort = d$cohort[1], survey_year = d$survey_year[1], eligibility_group = d$eligibility_group[1],
    household_n = sum(d$n), unique_towns = sum(d$n > 0), valid_medical_n = NA_integer_,
    weighted_household_count = NA_real_, mean_medical = NA_real_, median_medical = NA_real_, sd_medical = NA_real_,
    p80_medical = NA_real_, p90_medical = NA_real_, zero_medical_share = NA_real_, missing_outcome_share = NA_real_,
    max_single_town_share = ifelse(length(shares), shares[1], NA_real_),
    top_three_town_share = ifelse(length(shares), sum(head(shares, 3)), NA_real_),
    flag_towns_lt_10 = sum(d$n > 0) < 10,
    flag_largest_town_gt_25pct = ifelse(length(shares), shares[1] > .25, NA),
    flag_top3_gt_50pct = ifelse(length(shares), sum(head(shares, 3)) > .50, NA),
    flag_valid_n_materially_smaller = NA,
    status = "PARTIAL — eligibility counts observable; eligibility-specific outcome distribution BLOCKED",
    notes = "Marginal town summaries do not contain the joint distribution of HAS_INDI_55PLUS and EXP_MEDICAL_EXPENDITURE."
  )
}))
support$treatment_cohort <- factor(support$treatment_cohort, levels = cohort_levels)
support <- support[order(support$treatment_cohort, support$survey_year, support$eligibility_group), ]
support$treatment_cohort <- as.character(support$treatment_cohort)
write_csv(support, file.path(out_dir, "gate1_cohort_wave_eligibility.csv"))

md_table <- c("# Gate 1 cohort × wave × eligibility support", "", "Outcome statistics are `NA` because only separate town-level marginals survive in the repository; they cannot be cross-tabulated without microdata.", "", "| Cohort | Year | Eligibility | HH N | Towns | Max town share | Top 3 share | Flags |", "|---|---:|---|---:|---:|---:|---:|---|")
for (i in seq_len(nrow(support))) {
  flags <- paste(c(if (isTRUE(support$flag_towns_lt_10[i])) "towns<10", if (isTRUE(support$flag_largest_town_gt_25pct[i])) "max>25%", if (isTRUE(support$flag_top3_gt_50pct[i])) "top3>50%"), collapse = "; ")
  md_table <- c(md_table, sprintf("| %s | %s | %s | %s | %s | %.1f%% | %.1f%% | %s |", support$treatment_cohort[i], support$survey_year[i], support$eligibility_group[i], support$household_n[i], support$unique_towns[i], 100 * support$max_single_town_share[i], 100 * support$top_three_town_share[i], flags))
}
write_md(md_table, file.path(out_dir, "gate1_cohort_wave_eligibility.md"))

cohort_town_counts <- aggregate(COUNTY ~ cohort, town_map, function(x) length(x))
names(cohort_town_counts)[2] <- "towns_in_observed_geography"
gate1_summary <- c(
  "# Gate 1 summary", "",
  "**Evidence label: Insufficient information.**", "",
  "- **OBSERVED** 55+ and non-55+ household counts, unique towns, and concentration are recoverable from archived town marginals and are reported in the CSV/MD tables.",
  "- **UNRESOLVED** Eligibility-specific valid medical N, mean, median, SD, percentiles, zeros, and missingness cannot be recovered because joint microdata/cross-tabs are absent.",
  "- **UNRESOLVED** Weighted counts are not reported because cross-wave weight definitions remain unvalidated.",
  "- **2006 cohort**: only one primary-window pre-period (2002 is extended robustness and has no F14 eligibility); it cannot carry an eligibility-specific pre-trend diagnostic in this repository.",
  "- **2010 cohort**: 55+ support counts are observable, but the required outcome-within-eligibility cells are not. Primary-window pre-trend has only 2006 as a pre-period.",
  "- **2014 cohort**: 55+ support counts are observable and 2006/2010 form two primary pre-waves, but outcome-within-eligibility support remains unavailable.",
  "- **2017 cohort**: can provide pre-treatment descriptive history but no meaningful post-treatment dynamics within the 2017 endpoint.",
  "",
  "What would support Gate 1: restoration of 2006–2017 household microdata (or privacy-preserving cohort × wave × eligibility × town joint extracts) showing adequate valid outcome N and dispersion.",
  "What would undermine Gate 1: key 2010/2014 cells with few towns, severe town dominance, or medical validity materially below eligibility household N."
)
write_md(gate1_summary, file.path(out_dir, "gate1_summary.md"))

# ---- Reconstruct overall town medical means (not eligibility-specific) --------
medical_midpoint <- function(year, label) {
  s <- gsub("[ ,，_]", "", as.character(label))
  if (grepl("沒有這項支出|無此消費", s)) return(0)
  if (grepl("不知道|拒答|未回答|^NA$", s)) return(NA_real_)
  if (year == 2002) {
    if (grepl("未滿1000|999元及以下", s)) return(500)
    if (grepl("1000元至未滿3000|1千~未滿3千", s)) return(2000)
    if (grepl("3000元至未滿5000|3千~未滿5千", s)) return(4000)
    if (grepl("5000-6999|5千~未滿7千", s)) return(6000)
    if (grepl("7000-9999|7千~未滿1萬元", s)) return(8500)
    if (grepl("1萬元以上", s)) return(11500)
  }
  if (year %in% c(2006, 2010)) {
    if (grepl("999元及以下|未滿1000", s)) return(499.5)
    vals <- c("1000-1999"=1499.5,"2000-2999"=2499.5,"3000-3999"=3499.5,"4000-4999"=4499.5,"5000-6999"=5999.5,"7000-9999"=8499.5,"10000-14999"=12499.5,"15000-19999"=17499.5,"20000-29999"=24999.5)
    for (k in names(vals)) if (grepl(k, s, fixed = TRUE)) return(vals[[k]])
    if (grepl("30000元及以上", s)) return(34999.5)
  }
  if (year %in% c(2014, 2017)) {
    if (grepl("499元及以下|未滿500", s)) return(249.5)
    if (grepl("500-999|500元~未滿1000", s)) return(749.5)
    vals <- c("1000-1999"=1499.5,"2000-2999"=2499.5,"3000-3999"=3499.5,"4000-4999"=4499.5,"5000-6999"=5999.5,"7000-9999"=8499.5,"10000-14999"=12499.5,"15000-19999"=17499.5,"20000-29999"=24999.5)
    for (k in names(vals)) if (grepl(k, s, fixed = TRUE)) return(vals[[k]])
    if (grepl("30000元及以上", s)) return(34999.5)
  }
  NA_real_
}

med_cat <- subset(cat_town, DATA_Y %in% c(2002, 2006, 2010, 2014, 2017) & variable == "EXP_MEDICAL_EXPENDITURE")
med_cat$midpoint <- mapply(medical_midpoint, med_cat$DATA_Y, med_cat$category)
med_cat$mapped <- !is.na(med_cat$midpoint)
med_split <- split(med_cat, interaction(med_cat$DATA_Y, med_cat$CITY, med_cat$COUNTY, drop = TRUE))
town_med <- do.call(rbind, lapply(med_split, function(d) {
  valid <- d$mapped
  data.frame(DATA_Y = d$DATA_Y[1], CITY = d$CITY[1], COUNTY = d$COUNTY[1],
    valid_n = sum(d$n[valid]), medical_mean_midpoint = if (sum(d$n[valid]) > 0) weighted.mean(d$midpoint[valid], d$n[valid]) else NA_real_,
    zero_share = if (sum(d$n[valid]) > 0) sum(d$n[valid & d$midpoint == 0]) / sum(d$n[valid]) else NA_real_,
    unmapped_category_n = sum(d$n[!valid]))
}))
town_med <- merge(town_med, town_map, by = c("CITY", "COUNTY"), all.x = TRUE)

# ---- Gate 2A: baseline balance ------------------------------------------------
numeric_vars <- c("N_FAMILY", "N_INDI_55PLUS", "N_INDI_65PLUS")
num_base <- subset(num_town, DATA_Y %in% c(2006, 2010, 2014) & variable %in% numeric_vars)
num_wide <- reshape(num_base[c("DATA_Y", "CITY", "COUNTY", "variable", "mean")], idvar = c("DATA_Y", "CITY", "COUNTY"), timevar = "variable", direction = "wide")
names(num_wide) <- sub("mean\\.", "", names(num_wide))
baseline_panel <- merge(town_med, num_wide, by = c("DATA_Y", "CITY", "COUNTY"), all.x = TRUE)

balance_specs <- data.frame(target_cohort = c("2006 cohort", "2010 cohort", "2014 cohort", "2017 cohort"), baseline_year = c(2002, 2006, 2010, 2014))
balance_rows <- list()
for (j in seq_len(nrow(balance_specs))) {
  tc <- balance_specs$target_cohort[j]; byear <- balance_specs$baseline_year[j]
  d <- subset(baseline_panel, DATA_Y == byear & geography_precise %in% TRUE)
  d$treated_group <- d$cohort == tc
  target_order <- match(tc, cohort_levels)
  d$control_group <- match(d$cohort, cohort_levels) > target_order | d$cohort == "registry-external / potential never-treated"
  for (v in c("medical_mean_midpoint", numeric_vars)) {
    if (!v %in% names(d)) next
    a <- d[d$treated_group & !is.na(d[[v]]), v]
    b <- d[d$control_group & !is.na(d[[v]]), v]
    pooled <- sqrt(((length(a)-1)*var(a) + (length(b)-1)*var(b)) / max(length(a)+length(b)-2, 1))
    balance_rows[[length(balance_rows)+1]] <- data.frame(target_cohort=tc, baseline_year=byear, variable=v,
      earlier_town_n=length(a), later_or_external_town_n=length(b), earlier_mean=mean(a), later_or_external_mean=mean(b),
      mean_difference=mean(a)-mean(b), standardized_difference=ifelse(is.finite(pooled) && pooled>0,(mean(a)-mean(b))/pooled,NA_real_),
      status=ifelse(length(a)<2 || length(b)<2,"INSUFFICIENT","DESCRIPTIVE"))
  }
}
balance <- do.call(rbind, balance_rows)
write_csv(balance, file.path(out_dir, "gate2_baseline_balance.csv"))

# Descriptive adoption model among towns not treated by 2006, using 2006 covariates.
adopt <- subset(baseline_panel, DATA_Y == 2006 & geography_precise %in% TRUE & !is.na(first_year_gregorian) & first_year_gregorian > 2006)
predictors <- intersect(c("medical_mean_midpoint", "N_FAMILY", "N_INDI_55PLUS", "N_INDI_65PLUS"), names(adopt))
complete <- complete.cases(adopt[c("first_year_gregorian", predictors)])
adopt_model <- adopt[complete, ]
adoption_out <- data.frame()
if (nrow(adopt_model) >= length(predictors) + 5) {
  for (v in predictors) adopt_model[[paste0("z_", v)]] <- as.numeric(scale(adopt_model[[v]]))
  form <- as.formula(paste("first_year_gregorian ~", paste(paste0("z_", predictors), collapse = " + ")))
  fit <- lm(form, data = adopt_model)
  co <- summary(fit)$coefficients
  adoption_out <- data.frame(term = rownames(co), estimate_years = co[,1], std_error = co[,2], t_value = co[,3], p_value = co[,4], model_n = nrow(adopt_model), r_squared = summary(fit)$r.squared, interpretation = "Descriptive association with later calendar adoption; not causal and not evidence that adjustment removes endogeneity.")
} else {
  adoption_out <- data.frame(term="BLOCKED", estimate_years=NA, std_error=NA, t_value=NA, p_value=NA, model_n=nrow(adopt_model), r_squared=NA, interpretation="Insufficient complete town-level baseline observations.")
}
write_csv(adoption_out, file.path(out_dir, "gate2_adoption_predictors.csv"))

png(file.path(out_dir, "gate2_selection_figures", "baseline_medical_by_cohort.png"), width = 1200, height = 750, res = 140)
plot_selection <- subset(town_med, DATA_Y==2006 & geography_precise %in% TRUE)
short_labels <- c(
  "always-treated / pre-window"="pre-window", "2006 cohort"="2006", "2010 cohort"="2010",
  "2014 cohort"="2014", "2017 cohort"="2017", "2018+ not-yet-treated"="2018+",
  "registry-external / potential never-treated"="registry-external"
)
plot_selection$cohort_short <- factor(unname(short_labels[plot_selection$cohort]), levels=unname(short_labels))
par(mar=c(5,11,3,1)); boxplot(medical_mean_midpoint ~ cohort_short, data=plot_selection, horizontal=TRUE, las=1, xlab="2006 medical expenditure midpoint mean", ylab="", main="Descriptive baseline town distributions")
dev.off()

write_md(c(
  "# Gate 2 treatment-selection summary", "", "**Evidence label: Mixed, with important unresolved selection risk.**", "",
  "- **OBSERVED** `gate2_baseline_balance.csv` compares each focal cohort with later/current-roster-external towns at the last available pre-wave using town-level means and standardized differences.",
  "- **OBSERVED** `gate2_adoption_predictors.csv` is a descriptive linear model of calendar adoption year among towns untreated by 2006. Coefficients are associations, not a selection correction.",
  "- **INFERRED** Differences in baseline medical expenditure or older Indigenous composition are plausible threats because they can align both with adoption timing and future expenditure trajectories.",
  "- **UNRESOLVED** Repository lacks medical resources, clinic/hospital access, remoteness, and historical station closures; absence of large observed standardized differences would not establish exogeneity.",
  "- **WARNING** Registry-external towns may include historically treated/closed stations and are not validated never-treated controls."
), file.path(out_dir, "gate2_summary.md"))

write_md(c(
  "# External data requirements", "",
  "No external data were fetched or merged.", "",
  "| Variable | Suggested source | Years | Unit | Purpose | Priority |",
  "|---|---|---|---|---|---|",
  "| Complete historical Cultural Health Station openings/closures | Indigenous Peoples Council administrative rosters | Through 2017, ideally annual from inception | station and township | Correct first-treatment and never-treated classification | High |",
  "| Indigenous population and Indigenous 55+ population | Official township population statistics | 2002–2017 annual or survey years | township-year | Adoption selection and composition | High |",
  "| Medical resources (clinics, hospitals, beds, providers) | Ministry of Health and Welfare open statistics | 2002–2017 | township/county-year | Health-access selection and concurrent shocks | High |",
  "| Remoteness/access classification and travel time | Government geographic/remoteness datasets | stable definition plus change dates | township | Baseline selection and heterogeneity | High |",
  "| Long-term-care resources and age-targeted programs | MOHW/local government administrative data | 2002–2017 | township-year | Concurrent older-adult policies relevant to DDD | High |",
  "| Mountain/plain Indigenous township classification | Official Indigenous area classification | definition valid for each wave | township | Stratification and selection description | Medium |"
), file.path(out_dir, "external_data_requirements.md"))

# ---- Gate 2: overall (not eligibility-specific) pre-trends --------------------
pool_mean <- function(d) {
  if (!nrow(d) || sum(d$valid_n, na.rm=TRUE)==0) return(c(mean=NA,se=NA,towns=0,n=0))
  m <- weighted.mean(d$medical_mean_midpoint, d$valid_n, na.rm=TRUE)
  se <- if (sum(!is.na(d$medical_mean_midpoint)) > 1) sd(d$medical_mean_midpoint, na.rm=TRUE)/sqrt(sum(!is.na(d$medical_mean_midpoint))) else NA
  c(mean=m,se=se,towns=sum(!is.na(d$medical_mean_midpoint)),n=sum(d$valid_n,na.rm=TRUE))
}
pre_rows <- list()
for (tc in c("2006 cohort","2010 cohort","2014 cohort")) {
  cy <- as.integer(sub(" cohort", "", tc))
  for (yr in c(2002,2006,2010,2014,2017)) {
    td <- subset(town_med, DATA_Y==yr & geography_precise %in% TRUE & cohort==tc)
    cd <- subset(town_med, DATA_Y==yr & geography_precise %in% TRUE & (is.na(first_year_gregorian) | first_year_gregorian > yr))
    a <- pool_mean(td); b <- pool_mean(cd)
    diff <- a["mean"]-b["mean"]; sed <- sqrt(a["se"]^2+b["se"]^2)
    pre_rows[[length(pre_rows)+1]] <- data.frame(cohort=tc,survey_year=yr,event_time_years=yr-cy,
      treated_mean=a["mean"],treated_se=a["se"],treated_towns=a["towns"],treated_valid_n=a["n"],
      not_yet_mean=b["mean"],not_yet_se=b["se"],not_yet_towns=b["towns"],not_yet_valid_n=b["n"],
      difference=diff,difference_ci_low=diff-1.96*sed,difference_ci_high=diff+1.96*sed,
      period=ifelse(yr<cy,"pre","post_or_treatment"),source_limitation="Town-level marginal midpoint reconstruction; current-roster treatment history; CIs are descriptive across-town approximations.")
  }
}
pretrend <- do.call(rbind, pre_rows)
write_csv(subset(pretrend, survey_year>=2006), file.path(out_dir, "gate2_pretrend_eventtime.csv"))
write_csv(subset(pretrend, survey_year<=2017), file.path(out_dir, "gate2_pretrend_2002_robustness.csv"))

png(file.path(out_dir,"gate2_pretrend_figures","overall_medical_pretrends.png"),width=1200,height=900,res=140)
par(mfrow=c(3,1),mar=c(4,5,3,1))
for (tc in c("2006 cohort","2010 cohort","2014 cohort")) {
  d<-subset(pretrend,cohort==tc); ylim<-range(c(d$treated_mean,d$not_yet_mean),na.rm=TRUE)
  plot(d$survey_year,d$treated_mean,type="b",pch=19,col="#9C2F2F",ylim=ylim,xlab="Survey year",ylab="Monthly medical midpoint",main=tc)
  lines(d$survey_year,d$not_yet_mean,type="b",pch=17,col="#285F8F"); abline(v=as.integer(sub(" cohort","",tc)),lty=2); legend("topleft",c("cohort","not-yet-treated"),col=c("#9C2F2F","#285F8F"),pch=c(19,17),lty=1,bty="n")
}
dev.off()

write_md(c(
  "# Gate 2 medical pre-trend summary", "", "**Evidence label: Mixed / insufficient for several cohorts.**", "",
  "- **OBSERVED** The CSVs contain raw pooled midpoint means for each focal cohort and contemporaneous not-yet-treated towns. They are reconstructed from town × outcome-category marginal counts.",
  "- **2006 cohort**: no primary-window pre-period; 2002 supplies only one extended pre observation, so a trajectory cannot be assessed.",
  "- **2010 cohort**: only 2006 is pre-treatment in the primary window; adding 2002 gives two points but 2002 has weaker geography and questionnaire comparability.",
  "- **2014 cohort**: 2006 and 2010 permit one primary-window pre-change comparison; 2002 is extended robustness only.",
  "- **2002 geography**: archived merge audit reports 12,146/13,113 households (92.63%) with township geography. For the aggregate medical reconstruction, documented combined-township and unknown labels are conservatively excluded; 11,278 valid-medical records across 118 precise town labels remain.",
  "- **2002 comparability**: the wave has no F14 eligibility fields, uses coarser medical expenditure bins, and has weaker geographic resolution; it is robustness evidence only.",
  "- **UNRESOLVED** Regression-adjusted event studies and HonestDiD-compatible individual-level covariance inputs cannot be safely produced from marginal tables.",
  "- Non-significant or imprecise differences must not be read as proof of parallel trends; the reported intervals are descriptive across-town approximations and may not rule out economically meaningful divergence."
), file.path(out_dir, "gate2_pretrend_summary.md"))

# ---- Gate 3: eligibility DDD --------------------------------------------------
gate3_support <- support[c("treatment_cohort","survey_year","eligibility_group","household_n","unique_towns","max_single_town_share","top_three_town_share")]
gate3_support$medical_outcome_within_cell_available <- FALSE
gate3_support$status <- "PARTIAL SUPPORT COUNTS ONLY — DDD joint outcome cells BLOCKED"
write_csv(gate3_support, file.path(out_dir, "gate3_ddd_cell_support.csv"))
gate3_pre <- data.frame(
  diagnostic="55+ minus non-55+ medical expenditure gap by cohort and pre-wave",
  status="BLOCKED — MISSING JOINT MICRODATA",
  exact_reason="Repository retains separate township marginals for HAS_INDI_55PLUS and EXP_MEDICAL_EXPENDITURE, not their joint distribution.",
  consequence="Cannot calculate eligibility-specific outcomes, relative pre-trends, event-time DDD coefficients, or composition-adjusted DDD.",
  smallest_next_action="Restore restricted 2006–2017 household microdata or export privacy-preserving cohort × wave × eligibility × town cells containing outcome moments and covariance/inference inputs."
)
write_csv(gate3_pre, file.path(out_dir, "gate3_ddd_pretrend.csv"))
write_md(c("# BLOCKED", "", "No DDD figure can be produced without the joint eligibility × outcome distribution. See `diagnostics/gate3_ddd_pretrend.csv`."), file.path(out_dir,"gate3_ddd_figures","README.md"))
write_md(c(
  "# Gate 3 summary", "", "**Evidence label: Insufficient information.**", "",
  "- **OBSERVED** Eligibility-group household counts and town concentration are available as marginals.",
  "- **BLOCKED** Relative medical-expenditure gaps and DDD event-time coefficients cannot be computed without joint microdata.",
  "- **UNRESOLVED** Age-composition change can be described only in aggregate, not linked to the outcome or non-55+ selection.",
  "- DDD, if later estimable, would be supporting evidence for a differential effect for target-eligible households. It would not remove town-time shocks that differentially affect older households, concurrent age-targeted policies, or community spillovers."
), file.path(out_dir,"gate3_summary.md"))

# ---- Outcome comparability audit ---------------------------------------------
common_amount_2006_2010 <- "999及以下; 1,000–1,999; 2,000–2,999; 3,000–3,999; 4,000–4,999; 5,000–6,999; 7,000–9,999; 10,000–14,999; 15,000–19,999; 20,000–29,999; 30,000以上開放金額; 無支出"
common_amount_2014_2017 <- "未滿1,000; 1,000–1,999; 2,000–2,999; 3,000–3,999; 4,000–4,999; 5,000–6,999; 7,000–9,999; 10,000–14,999; 15,000–19,999; 20,000–29,999; 30,000以上開放金額"
care_wave <- data.frame(
  row_type="wave_definition", wave_a=c(2006,2010,2014,2017), wave_b=NA,
  variable=c("Q12-13 / EXP_CARE_EXPENDITURE","J7-7 / EXP_CARE_EXPENDITURE","J7-9 / EXP_CARE_EXPENDITURE","M7-9 / EXP_CARE_EXPENDITURE"),
  wording=c("兒童照顧、老人照顧、身心障礙者照顧等","兒童照顧/老人照顧/身心障礙者照顧","兒童/老人/身心障礙者照顧","保姆費/安養院/身障者照顧"),
  response_categories=c(common_amount_2006_2010,common_amount_2006_2010,common_amount_2014_2017,common_amount_2014_2017),
  included_items=c("兒童、老人、身心障礙照顧","兒童、老人、身心障礙照顧","兒童、老人、身心障礙照顧","保姆、安養院、身障者照顧"),
  excluded_items="問卷未明載", coding_conversion="兩階段有無支出＋級距中點；無支出為0；開放金額優先（依 repository recode）",
  classification=NA, evidence_path=c("docs/codebooks/ques95.pdf p.10–11","docs/codebooks/ques99.pdf p.7","docs/codebooks/ques103.pdf p.8","docs/codebooks/ques106.pdf p.12"),
  rationale="Wave definition"
)
pair_matrix <- combn(c(2006,2010,2014,2017),2)
care_pairs <- do.call(rbind,lapply(seq_len(ncol(pair_matrix)),function(i){a<-pair_matrix[1,i];b<-pair_matrix[2,i]; changed<-b==2017; data.frame(row_type="pair_comparison",wave_a=a,wave_b=b,variable="EXP_CARE_EXPENDITURE",wording=NA,response_categories=NA,included_items=NA,excluded_items=NA,coding_conversion=NA,classification=if(changed)"Material definition change" else "Highly comparable",evidence_path=paste(care_wave$evidence_path[care_wave$wave_a %in% c(a,b)],collapse="; "),rationale=if(changed)"2017 changes broad child/older/disabled care to nanny/nursing-home/disabled care; service boundary is materially different." else "Broad target groups and amount structure are substantively aligned." )}))
care_audit <- rbind(care_wave,care_pairs)
write_csv(care_audit,file.path(out_dir,"outcome_care_crosswave_audit.csv"))

food_wave <- data.frame(
  row_type="wave_definition",wave_a=c(2006,2010,2014,2017),wave_b=NA,
  variable=c("Q12-1 / EXP_FOOD_EXPENDITURE","J1 / EXP_FOOD_EXPENDITURE","J1 / EXP_FOOD_EXPENDITURE","M1 / EXP_FOOD_EXPENDITURE"),
  wording=c("吃飯、蔬菜魚肉、水果、飲料費等","吃飯、蔬菜魚肉、水果、飲料費等","買菜、水果、非酒精飲料費、零食等","買米/肉/菜、水果、非酒精飲料費、糖果零食等"),
  response_categories=c("2,999以下至70,000以上開放金額","2,999以下至70,000以上開放金額","2,999以下；3,000–4,999；5,000–6,999；7,000–9,999；10,000–11,999；12,000–14,999；其後至70,000以上","同2014邊界"),
  included_items=c("吃飯（可能包含外食）、蔬菜魚肉、水果、飲料","吃飯（可能包含外食）、蔬菜魚肉、水果、飲料","家庭購買食材、水果、非酒精飲料、零食；外食另列J7-6","家庭購買米肉菜、水果、非酒精飲料、糖果零食；外食另列M7-6"),
  excluded_items=c("酒菸檳榔另題；外食未明確拆分","酒菸檳榔另題；外食未明確拆分","外食費、學生住宿、自助旅行住宿另題","外食費、學生住宿、自助旅行住宿另題"),
  coding_conversion="級距中點；開放金額依 repository 規則",classification=NA,
  evidence_path=c("docs/codebooks/ques95.pdf p.8","docs/codebooks/ques99.pdf p.6","docs/codebooks/ques103.pdf p.6,8","docs/codebooks/ques106.pdf p.10,12"),rationale="Wave definition"
)
food_pairs <- do.call(rbind,lapply(seq_len(ncol(pair_matrix)),function(i){a<-pair_matrix[1,i];b<-pair_matrix[2,i]; split_boundary<-(a<=2010 && b>=2014); data.frame(row_type="pair_comparison",wave_a=a,wave_b=b,variable="EXP_FOOD_EXPENDITURE",wording=NA,response_categories=NA,included_items=NA,excluded_items=NA,coding_conversion=NA,classification=if(split_boundary)"Material definition change" else "Highly comparable",evidence_path=paste(food_wave$evidence_path[food_wave$wave_a %in% c(a,b)],collapse="; "),rationale=if(split_boundary)"2006/2010 wording uses 吃飯 and does not separately identify eating out; 2014/2017 define food as grocery-type purchases and move 外食/住宿 to a separate item." else "Food basket wording and response-bin structure are substantially aligned within this period." )}))
food_audit <- rbind(food_wave,food_pairs)
write_csv(food_audit,file.path(out_dir,"outcome_food_crosswave_audit.csv"))

write_md(c(
  "# Outcome cross-wave comparability summary", "",
  "## Medical expenditure", "",
  "**DOCUMENTED — suitable for the primary four-wave diagnostic outcome, with measurement warnings.** 2006/2010 ask about 看病就醫、保險費、醫療設備; 2014/2017 refine this to 醫療保險費 and 醫療用品/設備. Bin boundaries change in 2014, and all interval-derived values are midpoint approximations rather than exact expenditures.", "",
  "## Care expenditure", "",
  "**DOCUMENTED — suitable only for restricted-period comparison (2006–2014); 2017 only supplementary/mechanism-consistent evidence.** The 2017 wording replaces broad child/older/disabled care with nanny/nursing-home/disabled care, a material service-boundary change.", "",
  "## Food expenditure", "",
  "**DOCUMENTED — suitable only for restricted-period comparison within 2006–2010 or within 2014–2017; unsuitable for a single causal four-wave comparison without a defensible harmonization decision.** In 2014/2017, eating out and accommodation are a separate item, whereas 2006/2010 food wording includes 吃飯 and does not document the same boundary.", "",
  "No audit conclusion changes the primary medical-expenditure research question."
),file.path(out_dir,"outcome_comparability_summary.md"))

coverage_log_source <- read.csv(paths$archived_coverage, check.names=FALSE)
medical_coverage <- subset(coverage_log_source, sample_definition=="full_sample" & Variable=="EXP_MEDICAL_EXPENDITURE" & `Survey Year` %in% expected_main_years)
medical_missing_by_year <- setNames(medical_coverage$`Response Missing N`, medical_coverage$`Survey Year`)
medical_total_by_year <- setNames(medical_coverage$`Eligible N`, medical_coverage$`Survey Year`)
excluded_2002_medical_n <- sum(med_cat$n[med_cat$DATA_Y==2002 & med_cat$COUNTY %in% non_town_labels])
retained_2002_medical_n <- sum(med_cat$n[med_cat$DATA_Y==2002 & !med_cat$COUNTY %in% non_town_labels])
retained_2002_town_n <- nrow(unique(med_cat[med_cat$DATA_Y==2002 & !med_cat$COUNTY %in% non_town_labels,c("CITY","COUNTY")]))
run_log <- data.frame(
  log_type=c("canonical_year_coverage","geography_exclusion","medical_missingness","medical_missingness","medical_missingness","medical_missingness","weight_status","joint_distribution_status"),
  survey_year=c(NA,2002,2006,2010,2014,2017,NA,NA),
  observed_n=c(nrow(canonical),excluded_2002_medical_n,unname(medical_missing_by_year["2006"]),unname(medical_missing_by_year["2010"]),unname(medical_missing_by_year["2014"]),unname(medical_missing_by_year["2017"]),NA,NA),
  denominator_n=c(nrow(canonical),sum(med_cat$n[med_cat$DATA_Y==2002]),unname(medical_total_by_year["2006"]),unname(medical_total_by_year["2010"]),unname(medical_total_by_year["2014"]),unname(medical_total_by_year["2017"]),NA,NA),
  detail=c(
    paste0("Active canonical contains years: ",paste(canonical_years,collapse=","),"; required 2006/2010/2014/2017 microdata absent."),
    paste0("Valid-medical records under documented combined-township or unknown labels excluded from aggregate 2002 robustness; ",retained_2002_medical_n," valid-medical records across ",retained_2002_town_n," precise labels retained."),
    "Archived full-sample medical response missing N.","Archived full-sample medical response missing N.","Archived full-sample medical response missing N.","Archived full-sample medical response missing N.",
    "Weighted outputs suppressed because cross-wave household-weight definitions are unvalidated.",
    "Eligibility-specific outcome moments and DDD suppressed because only separate marginals are available."
  )
)
write_csv(run_log,file.path(out_dir,"diagnostic_run_log.csv"))

# ---- Manifest and final report ------------------------------------------------
manifest <- data.frame(
  diagnostic_id=c("STEP0","G1","G2A","G2B","G3","D5_CARE","D5_FOOD"),
  gate=c("Repository","Gate 1","Gate 2","Gate 2","Gate 3","Outcome audit","Outcome audit"),
  script_path="code/diagnostics/run_identification_diagnostic_batch.R",
  input_files=c(paste(paths$canonical,paths$imported_index,sep=";"),paste(paths$categorical_town,paths$station_panel,sep=";"),paste(paths$numeric_town,paths$categorical_town,paths$station_panel,sep=";"),paste(paths$categorical_town,paths$station_panel,sep=";"),paths$categorical_town,"docs/codebooks/ques95.pdf;docs/codebooks/ques99.pdf;docs/codebooks/ques103.pdf;docs/codebooks/ques106.pdf", "docs/codebooks/ques95.pdf;docs/codebooks/ques99.pdf;docs/codebooks/ques103.pdf;docs/codebooks/ques106.pdf"),
  output_files=c("diagnostics/repository_inspection.md;diagnostics/diagnostic_run_log.csv","diagnostics/gate1_cohort_wave_eligibility.csv;diagnostics/gate1_town_concentration.csv","diagnostics/gate2_baseline_balance.csv;diagnostics/gate2_adoption_predictors.csv","diagnostics/gate2_pretrend_eventtime.csv;diagnostics/gate2_pretrend_2002_robustness.csv","diagnostics/gate3_ddd_cell_support.csv;diagnostics/gate3_ddd_pretrend.csv","diagnostics/outcome_care_crosswave_audit.csv","diagnostics/outcome_food_crosswave_audit.csv"),
  sample_definition=c("repository inventory","household marginals by town, 2006–2017","town-level pre-treatment aggregates","town-level overall medical marginals; not eligibility-specific","household eligibility marginals only","questionnaire waves 2006/2010/2014/2017","questionnaire waves 2006/2010/2014/2017"),
  treatment_definition="care_station_first_year from 114-year current roster; mapped to first observable survey cohort: <=2005 pre-window, 2006, 2007–2010, 2011–2014, 2015–2017, 2018+; external means absent from current roster",
  outcome_definition=c("N/A","EXP_MEDICAL unavailable jointly with eligibility","town medical midpoint mean and demographic marginals","EXP_MEDICAL category midpoint reconstruction","EXP_MEDICAL unavailable jointly with eligibility","EXP_CARE questionnaire construct","EXP_FOOD questionnaire construct"),
  status=c("COMPLETED","PARTIAL","COMPLETED_DESCRIPTIVE","PARTIAL","BLOCKED","COMPLETED","COMPLETED"),
  warning_count=c(3,3,3,4,4,2,2),
  notes=c("Canonical microdata only 2021","Outcome moments within eligibility cells unavailable","Selection model is descriptive and limited to available town aggregates","No adjusted event study/HonestDiD covariance inputs","Missing joint eligibility × outcome distribution","2017 material definition change","2014 introduces separate eating-out/accommodation item")
)
write_csv(manifest,file.path(out_dir,"diagnostic_manifest.csv"))

report <- c(
  "# 文化健康站研究：識別診斷證據報告", "", "## 12.1 執行摘要", "",
  "本批次檢查統計支持、處置選擇、醫療支出前趨勢、55+ eligibility DDD 前趨勢，以及照顧與食物支出的跨波可比性。**OBSERVED**：repository 的 active canonical 個體檔只有 2021，且無鄉鎮地理；六波資料只留下鄉鎮層的單變數邊際彙總。這些彙總足以重建 eligibility 戶數／集中度、整體（非 eligibility-specific）醫療支出描述趨勢，以及有限的處置選擇比較。**UNRESOLVED**：eligibility × medical outcome 的聯合分布、有效樣本、DDD gap、個體層調整與正式推論均無法重建。最大風險是歷史站點清冊誤分類、關鍵 cohort 的有限前期、缺 joint microdata、處置選擇與 survey weight 定義未驗證。此報告不作最終因果研究決定。", "",
  "## 12.2 Gate 1 — 統計支持", "",
  "整體證據：**insufficient information**。2006 cohort 僅 7 個可觀察鄉鎮且高度集中；2010 cohort 的 55+ cell 在 2006/2010/2014 分別有 711/333/384 戶、12/13/16 鄉鎮，top-three share 約 37%–41%；2014 cohort 同期為 534/270/356 戶、9/10/13 鄉鎮，但 top-three share 約 44%–56%，非55+ cell 的單一鄉鎮占比最高約 39%。2017 cohort 不提供有意義的 post-treatment dynamics。eligibility-specific outcome moments 皆為 BLOCKED，因此不能只憑邊際支持戶數認定關鍵 cohort 足以承載主分析。", "",
  "## 12.3 Gate 2 — 處置選擇與前趨勢", "",
  "### Observable baseline selection", "",
  "**OBSERVED** 較早採用鄉鎮在 older-Indigenous composition 上有大幅標準化差異：2010 cohort 對較晚／清冊外控制的 2006 基線 `N_INDI_55PLUS` 約 +1.19 SD、`N_INDI_65PLUS` 約 +0.90 SD；2014 cohort 的 2010 基線約 +1.86 SD、+2.09 SD，家庭規模約 -0.93 SD，醫療支出約 -0.34 SD。這些是 treatment selection 的 concerning evidence。**INFERRED** 差異可能同時關聯採用時點與醫療支出趨勢。**UNRESOLVED** 醫療資源、偏遠性、人口母數及已撤站歷史；觀察到的 covariate adjustment 不會消除 endogeneity。", "",
  "### Outcome pre-trends", "",
  "**OBSERVED** 整體醫療支出 midpoint 趨勢可由鄉鎮 × 類別邊際表重建。2006 cohort 無可估 trajectory 的 primary pre-period；2010 cohort 需依賴 2002 才有兩點；2014 cohort 有 2006/2010 一段 primary pre-change。**INFERRED** 非顯著或寬區間不能證明平行趨勢，也未必排除具經濟意義的分歧。", "",
  "## 12.4 Gate 3 — Eligibility DDD", "",
  "證據：**insufficient information**。**OBSERVED** 支持戶數與集中度可見；**BLOCKED** 55+ 與非55+ 的醫療支出差距、相對前趨勢及 DDD coefficients。DDD 即使日後可估，也只應解釋為 target-eligible households 的 differential effect；無法排除差異影響 older households 的 town-time shocks、同時期年齡政策或社區 spillovers。", "",
  "## 12.5 Outcome comparability", "",
  "- **Medical — DOCUMENTED**：四波概念大致可比，但 2014 改變級距邊界；midpoint 為測量近似。",
  "- **Care — DOCUMENTED**：2006–2014 可作 restricted-period；2017 定義改為保姆／安養院／身障照顧，屬 material change。",
  "- **Food — DOCUMENTED**：2006–2010 與 2014–2017 各自較可比；2014 起外食／住宿另列，四波單一 causal comparison 不宜在未決定 harmonization 前執行。", "",
  "## 12.6 Threat register", "",
  "| Threat | Evidence | Severity | Can current data address it? | Recommended response |",
  "|---|---|---|---|---|",
  "| Endogenous station placement | Baseline aggregate differences can be measured; key resources/remoteness absent | High | Partly | Restore covariates and treat estimates as sensitivity evidence |",
  "| Limited treated clusters | Gate 1 concentration/town counts observable but outcome joint cells absent | High | Partly | Restore joint cells; report cluster counts and leave-one-town-out |",
  "| Repeated-cross-section composition change | Age marginals vary by wave; cannot link composition to outcome | High | Partly | Joint household extract and composition diagnostics |",
  "| Historical station-list misclassification | Panel explicitly uses 114-year current roster and may omit closed stations | Critical | No | Obtain complete opening/closure history before defining never-treated |",
  "| Care definition drift | 2017 wording materially changes service boundary | High | Yes | Restrict to 2006–2014 or supplementary use |",
  "| Food definition drift | 2014 separates eating out/accommodation | High | Yes | Period-restricted analysis or explicit harmonization decision |",
  "| Midpoint expenditure measurement | Repository documents midpoint/open-bin approximations | Medium | Partly | Retain interval coding; sensitivity/interval methods later |",
  "| Survey-weight comparability | Candidate weights differ and definitions are unverified | High | No | Validate each wave's sampling/weight documentation |",
  "| Spillovers | Community stations may affect non-eligible households | Medium | No direct measure | Interpret DDD as differential effect; add spillover sensitivity |",
  "| Concurrent age-targeted policies | No township-year policy inventory in repository | High | No | Build concurrent-policy timeline/data before final DDD |", "",
  "## 12.7 What would falsify the current research strategy?", "",
  "- Strong cohort-vs-not-yet differential medical pre-trends, especially for 2014 where two primary pre-waves exist.",
  "- Baseline selection aligned with medical outcomes/resources and not credibly addressed by design or sensitivity analysis.",
  "- Restored joint data showing inadequate 55+ support, very few towns, or dominance by one town in 2010/2014.",
  "- Restored DDD data showing the 55+ minus non-55+ gap diverged before treatment.",
  "- Historical roster showing many registry-external controls were previously treated or station closures were selective.", "",
  "## Unresolved items and smallest next actions", "",
  "1. **BLOCKED — MISSING JOINT MICRODATA**：restore restricted household data or export joint sufficient statistics with outcome moments and inference inputs.",
  "2. **BLOCKED — HISTORICAL TREATMENT HISTORY**：obtain complete station openings and closures; rebuild first-treatment and never-treated status.",
  "3. **BLOCKED — WEIGHT DEFINITIONS**：supply per-wave sampling manuals and validated household weights.",
  "4. **BLOCKED — DDD**：joint eligibility × medical outcome distribution is required; separate marginals cannot substitute.",
  "5. **UNRESOLVED — COHORT MAPPING DECISION**：confirm whether cohorts are exact establishment years or first-observed survey-wave intervals before final causal estimation."
)
write_md(report,file.path(report_dir,"IDENTIFICATION-DIAGNOSTIC-REPORT.md"))

writeLines(capture.output(sessionInfo()), file.path(out_dir,"session_info.txt"))
write_md(c("# BLOCKED", "", "Selection figures are limited to the available aggregate baseline plot; no additional model figures were created from unavailable microdata."), file.path(out_dir,"gate2_selection_figures","README.md"))
write_md(c("# Notes", "", "Figure shows descriptive overall medical midpoint trends reconstructed from town-level marginal category counts. It is not eligibility-specific and does not establish parallel trends."), file.path(out_dir,"gate2_pretrend_figures","README.md"))

message("Identification diagnostic batch completed with explicit partial/BLOCKED statuses. Outputs: ", out_dir)

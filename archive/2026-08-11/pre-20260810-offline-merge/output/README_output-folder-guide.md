# Output Folder Guide

This folder stores exported analysis outputs that are intended for quick inspection.

## Current layout

- `basic_info_from_02.csv`
- `demographic_data_from_02.csv`
- `family_data_from_02.csv`
- `checks/`: validation tables written by the `03-xx` cleaning scripts
- `summary_statistics/`: descriptive outputs written by `05-01-summary-statistics.R` and `05-02-income-expenditure-recode-summary.R`
- `figures/`, `tables/`, `models/`, `hetero/`, `reports/`, `summary/`: reserved folders for later analysis-stage exports
- Historical exports that are no longer written by the current pipeline are stored under the project-level dated `archive/` folders, not mixed into the active `output/` tree.

## Notes

- The remaining top-level CSV files are kept in place because current scripts write directly to these paths.
- Current income and expenditure data are stored under `data/processed_data/03_income_expense/`.
- `summary_statistics/income_expenditure_recoded/` intentionally excludes the respondent-level file with `ID`; only the aggregate summary and recoding lookup are kept here.
- If we later want a numbered output structure, the safer next step is to update script output paths first and then migrate files together.

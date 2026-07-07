# Output Folder Guide

This folder stores exported analysis outputs that are intended for quick inspection.

## Current layout

- `basic_info_from_02.csv`
- `demographic_data_from_02.csv`
- `family_data_from_02.csv`
- `income_data.csv`
- `income_data_from_02.csv`
- `expenditure_data.csv`
- `expenditure_data_from_02.csv`
- `income_expenditure_data.csv`
- `income_expenditure_data_from_02.csv`
- `checks/`: validation tables written by the `03-xx` cleaning scripts
- `summary_statistics/`: descriptive outputs written by `05-01-summary-statistics.R` and `05-02-income-expenditure-recode-summary.R`
- `figures/`, `tables/`, `models/`, `hetero/`, `reports/`, `summary/`: reserved folders for later analysis-stage exports

## Notes

- The top-level CSV files are kept in place because current scripts write directly to these paths.
- `summary_statistics/income_expenditure_recoded/` intentionally excludes the respondent-level file with `ID`; only the aggregate summary and recoding lookup are kept here.
- If we later want a numbered output structure, the safer next step is to update script output paths first and then migrate files together.

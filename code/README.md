# Code Numbering

This folder is being aligned to the main project structure:

- `00-xx`: main workflow control
- `01-xx`: package loading
- `02-xx`: data import
- `03-xx`: data cleaning
- `04-xx`: analysis sample construction
- `05-xx`: descriptive statistics
- `06-xx`: figures
- `07-xx`: DID models
- `08-xx`: robustness checks
- `09-xx`: result export
- `99-xx`: temporary exploration or one-off tests

Current `03` sequence:

- `03-00-make-year-survey-meta.R`: inspect yearly survey structure and export variable metadata
- `03-01-make-basic-info.R`: build common respondent ID and survey year table
- `03-02-make-demographic-data.R`: harmonize demographic and location variables
- `03-03-make-family-data.R`: harmonize family structure and housing variables
- `03-04-make-income-expense-data.R`: harmonize income and expenditure variables

Current `01` sequence:

- `01-00-load-packages.R`: load shared R packages used by the cleaning scripts

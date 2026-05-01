library(haven)
library(dplyr)

dt <- read_dta('data/raw_data/AJ030005 110年原住民族經濟狀況調查/data110.dta')
dt <- dt %>%
  mutate(across(where(is.labelled), as_factor))

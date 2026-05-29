library(haven)
library(dplyr)


# 110年資料 -------------------------------------------------------------------

dt <- read_dta('data/raw_data/AJ030005 110年原住民族經濟狀況調查/data110.dta') %>%
  mutate(across(where(is.labelled), as_factor)) %>% 
  select(id, level, county1)  # 在這裡放入你需要的欄位，我先隨意放入三個欄位
# this is a test

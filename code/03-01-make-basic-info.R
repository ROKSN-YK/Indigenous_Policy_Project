## Legacy version: kept only for historical comparison.
## Current mainline workflow uses 03-01-make-basic-info-from-02.R.
source("code/01-00-load-packages.R")

# data_91_1 <- read_dta("data/raw_data/economic_survey/91年/data91_1.dta") %>%
#   select(id) %>% 
#   mutate(ID = id,
#          DATA_Y = 2002) %>% 
#   select(ID, DATA_Y) %>% 
#   setDT()
# 
# data_91_2 <- read_dta("data/raw_data/economic_survey/91年/data91_2.dta") %>%
#   select(id) %>% 
#   mutate(ID = id + 36320,
#          DATA_Y = 2002) %>% 
#   select(ID, DATA_Y) %>% 
#   setDT()  

processed_yr_data <- list()

idx <- 0
for (yr in c(91, 95, 99)) {
  idx <- idx + 1
  tmp_data <- read_dta(paste0("data/raw_data/economic_survey/", yr, "年/data", yr, ".dta")) %>%
    select(id) %>% 
    mutate(ID = id,
           DATA_Y = yr+1911) %>% 
    select(ID, DATA_Y) %>% 
    setDT()
  processed_yr_data[[idx]] <- tmp_data
}

for (yr in c(103, 106)) {
  idx <- idx + 1
  tmp_data <- read_dta(paste0("data/raw_data/economic_survey/", yr, "年/data", yr, ".dta")) %>%
    select(no) %>% 
    mutate(ID = no,
           DATA_Y = yr+1911) %>% 
    select(ID, DATA_Y) %>% 
    setDT()
  processed_yr_data[[idx]] <- tmp_data
}

basic_info <- rbindlist(processed_yr_data)

saveRDS(basic_info, "data/processed_data/basic_info.rds")
fwrite(basic_info, "output/basic_info.csv")

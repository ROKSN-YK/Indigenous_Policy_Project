source("code/utils/setup.R")

basic_info <- readRDS("data/processed_data/basic_info.rds")

demo_list <- list()

demo_list[[1]] <- read_dta("data/raw_data/economic_survey/91年/data91.dta") %>%
  select(id, county, q1, q2, q3, q4) %>% 
  mutate(ID = id,
         DATA_Y = 2002,
         MALE = q1,
         AGE = q2,
         EDU = q3,
         RACE = q4) %>% 
  select(ID, DATA_Y, county, MALE, AGE, EDU, RACE) %>%
  mutate(across(where(is.labelled), as_factor)) %>% 
  mutate(
    city = substr(county, 1, 3),
    county = substr(county, 4, nchar(as.character(county))),
    MALE = case_when(
      MALE == "男" ~ 1,
      MALE == "女" ~ 0,
      TRUE ~ NA_real_
    )
  ) %>% 
  setDT()


demo_list[[2]] <- read_dta("data/raw_data/economic_survey/95年/data95.dta") %>%
  select(id, county, c10, c2, c3, c1) %>% 
  mutate(ID = id,
         DATA_Y = 95+1911,
         MALE = c10,
         AGE = c2,
         EDU = c3,
         RACE = c1) %>% 
  select(ID, DATA_Y, county, MALE, AGE, EDU, RACE) %>%
  mutate(across(where(is.labelled), as_factor)) %>% 
  mutate(
    city = substr(county, 1, 3),
    county = substr(county, 4, nchar(as.character(county))),
    MALE = case_when(
      MALE == "男" ~ 1,
      MALE == "女" ~ 0,
      TRUE ~ NA_real_
    )
  ) %>% 
  setDT()

demo_list[[3]] <- read_dta("data/raw_data/economic_survey/99年/data99.dta") %>%
  select(id, countya, sex, m3, m4, m2) %>% 
  mutate(ID = id,
         DATA_Y = 99+1911,
         MALE = sex,
         AGE = m3,
         EDU = m4,
         RACE = m2) %>% 
  select(ID, DATA_Y, countya, MALE, AGE, EDU, RACE) %>%
  mutate(across(where(is.labelled), as_factor)) %>% 
  mutate(
    city = substr(countya, 1, 3),
    county = substr(countya, 4, nchar(as.character(countya))),
    MALE = case_when(
      MALE == "男性" ~ 1,
      MALE == "女性" ~ 0,
      TRUE ~ NA_real_
    )
  ) %>% 
  select(ID, DATA_Y, MALE, AGE, EDU, RACE, city, county) %>% 
  setDT()

demo_list[[4]] <- read_dta("data/raw_data/economic_survey/103年/data103.dta") %>%
  select(no, county2, gender, n3, n4, n2) %>%
  mutate(ID = no,
         DATA_Y = 103+1911,
         MALE = gender,
         AGE = n3,
         EDU = n4,
         RACE = n2) %>% 
  select(ID, DATA_Y, county2, MALE, AGE, EDU, RACE) %>%
  mutate(across(where(is.labelled), as_factor)) %>% 
  mutate(
    city = substr(county2, 2, 4),
    county = substr(county2, 5, nchar(as.character(county2))),
    MALE = case_when(
      MALE == "男性" ~ 1,
      MALE == "女性" ~ 0,
      TRUE ~ NA_real_
    )
  ) %>% 
  select(ID, DATA_Y, MALE, AGE, EDU, RACE, city, county) %>% 
  setDT()

demo_list[[5]] <- read_dta("data/raw_data/economic_survey/106年/data106.dta") %>%
  select(no, county2, g1, g2, g3, g5) %>% 
  mutate(ID = no,
         DATA_Y = 106+1911,
         MALE = g1,
         AGE = g2,
         EDU = g3,
         RACE = g5) %>%  
  select(ID, DATA_Y, county2, MALE, AGE, EDU, RACE) %>%
  mutate(across(where(is.labelled), as_factor)) %>% 
  mutate(
    city = substr(county2, 2, 4),
    county = substr(county2, 5, nchar(as.character(county2))),
    MALE = case_when(
      MALE == "男性" ~ 1,
      MALE == "女性" ~ 0,
      TRUE ~ NA_real_
    )
  ) %>% 
  select(ID, DATA_Y, MALE, AGE, EDU, RACE, city, county) %>% 
  setDT()

demo_data <- rbindlist(demo_list, use.names = T)
setnames(demo_data, colnames(demo_data), toupper(colnames(demo_data)))

saveRDS(demo_data, "data/processed_data/city_data.rds")

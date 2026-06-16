source("code/01-00-load-packages.R")

basic_info <- readRDS("data/processed_data/basic_info.rds")

family_list <- list()

family_list[[1]] <- read_dta("data/raw_data/economic_survey/91年/data91.dta") %>%
  select(id, q7a, q7b, q18, q19) %>% 
  mutate(ID = id,
         DATA_Y = 2002,
         N_FAMILY = q7a,
         N_INDI = q7b,
         HOUSE_BELONG = q18,
         RENT = q19) %>% 
  select(ID, DATA_Y, N_FAMILY, N_INDI, HOUSE_BELONG, RENT) %>%
  mutate(across(where(is.labelled), as_factor)) %>% 
  setDT()

family_list[[2]] <- read_dta("data/raw_data/economic_survey/95年/data95.dta") %>%
  select(id, c5, c51, q3, q4) %>% 
  mutate(ID = id,
         DATA_Y = 95+1911,
         N_FAMILY = c5,
         N_INDI = c51,
         HOUSE_BELONG = q3,
         RENT = q4) %>% 
  select(ID, DATA_Y, N_FAMILY, N_INDI, HOUSE_BELONG, RENT) %>%
  mutate(across(where(is.labelled), as_factor)) %>% 
  setDT()

family_list[[3]] <- read_dta("data/raw_data/economic_survey/99年/data99.dta") %>%
  select(id, f2, f2_1, g1, g2) %>% 
  mutate(ID = id,
         DATA_Y = 99+1911,
         N_FAMILY = f2,
         N_INDI = f2_1,
         HOUSE_BELONG = g1,
         RENT = g2) %>% 
  select(ID, DATA_Y, N_FAMILY, N_INDI, HOUSE_BELONG, RENT) %>%
  mutate(across(where(is.labelled), as_factor)) %>% 
  select(ID, DATA_Y, N_FAMILY, N_INDI, HOUSE_BELONG, RENT) %>% 
  setDT()

family_list[[4]] <- read_dta("data/raw_data/economic_survey/103年/data103.dta") %>%
  select(no, f1, f1_1, g1, g2, g2o) %>%
  mutate(ID = no,
         DATA_Y = 103+1911,
         N_FAMILY = f1,
         N_INDI = f1_1,
         HOUSE_BELONG = g1,
         RENT = g2,
         RENT_TMP = g2o) %>% 
  select(ID, DATA_Y, N_FAMILY, N_INDI, HOUSE_BELONG, RENT, RENT_TMP) %>%
  mutate(
    RENT = coalesce(RENT_TMP, RENT)
  ) %>% 
  mutate(across(where(is.labelled), as_factor)) %>% 
  select(ID, DATA_Y, N_FAMILY, N_INDI, HOUSE_BELONG, RENT) %>% 
  setDT()

family_list[[5]] <- read_dta("data/raw_data/economic_survey/106年/data106.dta") %>%
  select(no, f1, f1_1_6, h1, h2, h2o) %>% 
  mutate(ID = no,
         DATA_Y = 106+1911,
         N_FAMILY = f1,
         N_INDI = f1_1_6,
         HOUSE_BELONG = h1,
         RENT = h2,
         RENT_TMP = h2o) %>%  
  select(ID, DATA_Y, N_FAMILY, N_INDI, HOUSE_BELONG, RENT, RENT_TMP) %>%
  mutate(
    RENT_label = list(attr(RENT, "labels")),
    RENT = labelled(
      coalesce(
        as.numeric(zap_labels(RENT_TMP)),
        as.numeric(zap_labels(RENT))
      ),
      labels = RENT_label[[1]]
    )
  ) %>% 
  select(-RENT_label) %>% 
  mutate(across(where(is.labelled), as_factor)) %>% 
  select(ID, DATA_Y, N_FAMILY, N_INDI, HOUSE_BELONG, RENT) %>% 
  setDT()

family_data <- rbindlist(family_list, use.names = T)
setnames(family_data, colnames(family_data), toupper(colnames(family_data)))

saveRDS(family_data, "data/processed_data/family_data.rds")

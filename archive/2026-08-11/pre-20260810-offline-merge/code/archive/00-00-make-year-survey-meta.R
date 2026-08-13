source("code/utils/setup.R")

write_survey_meta_by_year <- function(year, path){
  dt <- read_dta(paste0("data/raw_data/economic_survey/",
                        year, "年/data", year, ".dta"))
  meta <- data.frame(
    variable = names(dt),
    label = sapply(dt, function(x) attr(x, "label")),
    type = sapply(dt, function(x) class(x)[1]),
    source = year
    )
  
  if (!dir.exists(path)) {
    dir.create(path, recursive = T)
    message("The specified path doesn't exist. A new directory has been created at:", path, "\n")
  }
  fwrite(meta, paste0(path, "meta_", year, ".csv"))
}

target_year <- c(95,99, 103, 106)
walk(target_year, write_survey_meta_by_year, path = "output/meta/")


# For 91 data cleaning ----------------------------------------------------

dt <- read_dta(paste0("data/raw_data/economic_survey/",
                      "91", "年/data", "91_1", ".dta"))
meta <- data.frame(
  variable = names(dt),
  label = sapply(dt, function(x) attr(x, "label")),
  type = sapply(dt, function(x) class(x)[1]),
  source = "91_1"
)
fwrite(meta, paste0("output/meta/", "meta_", "91_1", ".csv"))

dt <- read_dta(paste0("data/raw_data/economic_survey/",
                      "91", "年/data", "91_2", ".dta"))
meta <- data.frame(
  variable = names(dt),
  label = sapply(dt, function(x) attr(x, "label")),
  type = sapply(dt, function(x) class(x)[1]),
  source = "91_2"
)
fwrite(meta, paste0("output/meta/", "meta_", "91_2", ".csv"))

# dt <- read_dta("data/raw_data/economic_survey/106年/data106.dta")
# meta <- data.frame(
#   variable = names(dt),
#   label = sapply(dt, function(x) attr(x, "label")),
#   type = sapply(dt, function(x) class(x)[1])
# )

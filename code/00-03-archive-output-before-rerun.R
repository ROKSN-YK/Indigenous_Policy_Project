find_project_root <- function() {
  candidates <- unique(c(getwd(), dirname(getwd())))
  matched <- candidates[file.exists(file.path(candidates, "code", "00-00-run-remote-pipeline.R"))]
  if (length(matched) == 0L) stop("找不到專案根目錄。請由 Indigenous_Policy_Project 執行。", call. = FALSE)
  normalizePath(matched[[1]], winslash = "/", mustWork = TRUE)
}

project_root <- find_project_root()
setwd(project_root)

date_tag <- format(Sys.Date(), "%Y-%m-%d")
archive_root <- file.path("archive", date_tag)
archive_dir <- file.path(archive_root, "pre-v2-v3-full-rerun")
if (dir.exists(archive_dir)) {
  stop("備份目錄已存在，為避免覆寫已停止：", archive_dir, call. = FALSE)
}
if (!dir.exists("output")) stop("找不到 output；未執行任何變更。", call. = FALSE)

dir.create(archive_root, recursive = TRUE, showWarnings = FALSE)
dir.create(archive_dir, recursive = FALSE, showWarnings = FALSE)
copied <- file.copy("output", archive_dir, recursive = TRUE, copy.date = TRUE)
if (!isTRUE(copied) || !dir.exists(file.path(archive_dir, "output"))) {
  stop("output 備份失敗；請勿開始重跑。", call. = FALSE)
}

paths <- list.files(file.path(archive_dir, "output"), recursive = TRUE, full.names = TRUE)
paths <- paths[file.info(paths)$isdir %in% FALSE]
manifest <- data.frame(
  path = substring(paths, nchar(archive_dir) + 2L),
  bytes = file.info(paths)$size,
  md5 = unname(tools::md5sum(paths)),
  stringsAsFactors = FALSE
)
write.csv(manifest, file.path(archive_dir, "BEFORE_OUTPUT_MANIFEST.csv"), row.names = FALSE, fileEncoding = "UTF-8")
writeLines(
  c(
    paste("created_at:", format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")),
    paste("source:", normalizePath("output", winslash = "/", mustWork = TRUE)),
    paste("files:", nrow(manifest)),
    "purpose: v2+v3 full-wave rerun before baseline; do not modify"
  ),
  file.path(archive_dir, "README.txt"),
  useBytes = TRUE
)

message("重跑前 output 已封存：", normalizePath(archive_dir, winslash = "/"))
message("檔案數：", nrow(manifest), "；請確認 BEFORE_OUTPUT_MANIFEST.csv 後再重跑。")

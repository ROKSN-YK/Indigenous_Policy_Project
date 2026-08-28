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
  archive_dir <- paste0(archive_dir, "-retry-", format(Sys.time(), "%H%M%S"))
  message("偵測到前次備份目錄；本次改用：", archive_dir)
}
if (!dir.exists("output")) stop("找不到 output；未執行任何變更。", call. = FALSE)

dir.create(archive_root, recursive = TRUE, showWarnings = FALSE)
dir.create(archive_dir, recursive = FALSE, showWarnings = FALSE)

# Only preserve the before/after evidence required by the offline checklist.
# Large row-level exports, figures, models, reports, old archives, and transfer
# ZIPs are deliberately excluded when disk space is limited.
backup_sources <- c(
  "output/checks",
  "output/summary_statistics",
  "output/pipeline_manifest.csv",
  "output/README_output-folder-guide.md"
)
backup_sources <- backup_sources[file.exists(backup_sources)]
if (!any(backup_sources %in% c("output/checks", "output/summary_statistics"))) {
  stop("找不到 output/checks 或 output/summary_statistics；未建立有效基準。", call. = FALSE)
}

copy_tree <- function(source, destination_root) {
  source <- sub("/+$", "", source)
  target <- file.path(destination_root, source)
  if (!dir.exists(source)) {
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    ok <- file.copy(source, target, overwrite = FALSE, copy.date = TRUE)
    return(data.frame(source = source, target = target, copied = ok))
  }

  dir.create(target, recursive = TRUE, showWarnings = FALSE)
  entries <- list.files(
    source,
    recursive = TRUE,
    full.names = TRUE,
    all.files = TRUE,
    no.. = TRUE,
    include.dirs = TRUE
  )
  relative <- substring(entries, nchar(source) + 2L)
  targets <- file.path(target, relative)
  is_dir <- file.info(entries)$isdir %in% TRUE
  invisible(mapply(
    function(path, dir_flag) {
      if (dir_flag) dir.create(path, recursive = TRUE, showWarnings = FALSE)
    },
    targets,
    is_dir
  ))
  file_entries <- entries[!is_dir]
  file_targets <- targets[!is_dir]
  invisible(lapply(unique(dirname(file_targets)), dir.create, recursive = TRUE, showWarnings = FALSE))
  copied <- mapply(
    file.copy,
    from = file_entries,
    to = file_targets,
    MoreArgs = list(overwrite = FALSE, copy.date = TRUE),
    USE.NAMES = FALSE
  )
  data.frame(source = file_entries, target = file_targets, copied = copied)
}

copy_results <- do.call(rbind, lapply(backup_sources, copy_tree, destination_root = archive_dir))
failed_copy <- copy_results[!copy_results$copied, , drop = FALSE]
if (nrow(failed_copy) > 0L) {
  write.csv(failed_copy, file.path(archive_dir, "FAILED_COPY.csv"), row.names = FALSE, fileEncoding = "UTF-8")
  stop(
    "output 備份有 ", nrow(failed_copy),
    " 個檔案失敗；請查看 ", file.path(archive_dir, "FAILED_COPY.csv"),
    "，暫勿開始重跑。",
    call. = FALSE
  )
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
    "scope: minimal output/checks + output/summary_statistics + manifests",
    "purpose: v2+v3 full-wave rerun before baseline; do not modify"
  ),
  file.path(archive_dir, "README.txt"),
  useBytes = TRUE
)

message("重跑前 output 已封存：", normalizePath(archive_dir, winslash = "/"))
message("檔案數：", nrow(manifest), "；請確認 BEFORE_OUTPUT_MANIFEST.csv 後再重跑。")

required_packages <- c(
  "haven", "dplyr", "data.table", "purrr", "readr", "stringr",
  "tidyr", "tibble"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0L) {
  stop(
    "缺少必要的 R 套件：", paste(missing_packages, collapse = ", "), "\n",
    "本程式不會在離線電腦自動安裝套件；請先請管理者完成安裝。",
    call. = FALSE
  )
}

suppressPackageStartupMessages(
  invisible(lapply(required_packages, library, character.only = TRUE))
)

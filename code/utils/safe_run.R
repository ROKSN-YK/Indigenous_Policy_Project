# safe_run.R -- run pipeline scripts so the console never shows data values.
#
# Usage (inside remote RStudio, working dir = project root):
#   source("code/utils/safe_run.R")
#   safe_run_pipeline()                            # whole pipeline, step by step
#   safe_run("code/05-01-summary-statistics.R")    # a single script
#
# Console shows ONLY: progress lines, OK/FAIL, masked error text,
# failing file:line, and object shapes (rows, cols, column names/types).
# Everything the scripts print goes to a PRIVATE log (never export):
#   data/processed_data/_logs/
# A masked summary that is meant to be exported is written to:
#   output/_run_log/
#
# Masking rule: quoted text that is not a plain name/path -> <VAL>,
# any run of 3+ digits -> <N>. Unquoted words are kept, so a script that
# pastes raw values into its own stop() text could still leak them.
#
# ASCII only on purpose: safe to type by hand in the remote session.
# Compatible with R 4.0.x (no |>, no \(x)). Does not modify pipeline code.

.sr_private_dir <- "data/processed_data/_logs"
.sr_export_dir  <- "output/_run_log"

# Mask anything that may be a data value. Fail closed.
safe_mask <- function(x, max_chars = 400L) {
  tryCatch({
    x <- enc2utf8(paste(as.character(x), collapse = " "))
    x <- gsub("([\"'`])([^\"'`]*[^A-Za-z0-9_./ -][^\"'`]*)\\1",
              "\\1<VAL>\\1", x, perl = TRUE)
    x <- gsub("[0-9]{3,}", "<N>", x, perl = TRUE)
    if (nchar(x) > max_chars) x <- paste0(substr(x, 1L, max_chars), " ...")
    x
  }, error = function(e) "<message hidden: could not be masked safely>")
}

# file:line of each frame that has source info (code, not data).
.sr_where <- function(calls) {
  locs <- character()
  for (cl in calls) {
    sr <- attr(cl, "srcref")
    if (is.null(sr)) next
    f <- tryCatch(basename(utils::getSrcFilename(sr)), error = function(e) "")
    if (length(f) != 1L || !nzchar(f)) next
    fn <- tryCatch(deparse(cl[[1]])[1L], error = function(e) "?")
    if (nchar(fn) > 40L) fn <- substr(fn, 1L, 40L)
    locs <- c(locs, sprintf("%s:%d  %s()", f, sr[[1L]], fn))
  }
  unique(locs)
}

# Shapes of data frames in an environment (no values).
.sr_shapes <- function(env) {
  res <- character()
  for (n in ls(env)) {
    obj <- get(n, envir = env)
    if (!is.data.frame(obj)) next
    cols <- names(obj)
    types <- vapply(obj, function(v) class(v)[1L], character(1))
    show <- head(paste0(cols, "<", types, ">"), 40L)
    more <- if (length(cols) > 40L) sprintf(" ... +%d more", length(cols) - 40L) else ""
    res <- c(res, sprintf("%s: %d rows x %d cols | %s%s", n, nrow(obj), ncol(obj),
                          paste(show, collapse = ", "), more))
  }
  res
}

.sr_say <- function(...) cat(..., "\n", sep = "", file = stderr())

# Open private log, hide printed output, block View(). Returns state env.
.sr_open <- function(tag) {
  dir.create(.sr_private_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(.sr_export_dir,  recursive = TRUE, showWarnings = FALSE)
  st <- new.env()
  st$stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  st$log <- file.path(.sr_private_dir, sprintf("%s_%s_full.log", st$stamp, tag))
  st$summary <- file.path(.sr_export_dir, sprintf("%s_%s_summary.txt", st$stamp, tag))
  st$con <- file(st$log, open = "wt", encoding = "UTF-8")
  sink(st$con, type = "output")
  st$old_opt <- options(keep.source = TRUE, warn = 1)
  st$had_view <- exists("View", envir = globalenv(), inherits = FALSE)
  if (st$had_view) st$old_view <- get("View", envir = globalenv())
  assign("View", function(...) invisible(NULL), envir = globalenv())
  st$steps <- list()
  st
}

.sr_close <- function(st) {
  sink(type = "output")
  close(st$con)
  options(st$old_opt)
  if (st$had_view) {
    assign("View", st$old_view, envir = globalenv())
  } else if (exists("View", envir = globalenv(), inherits = FALSE)) {
    rm("View", envir = globalenv())
  }
}

# Run fn() under handlers; record one step result in st$steps.
.sr_exec <- function(st, label, fn, env = NULL) {
  rec <- list(label = label, ok = FALSE, secs = 0, warns = character(),
              err = NULL, where = character(), shapes = character())
  con <- st$con
  t0 <- proc.time()[["elapsed"]]
  writeLines(paste0("===== ", label), con)
  ok <- tryCatch({
    withCallingHandlers(
      fn(),
      message = function(m) {
        writeLines(paste0("[message] ", conditionMessage(m)), con)
        invokeRestart("muffleMessage")
      },
      warning = function(w) {
        writeLines(paste0("[warning] ", conditionMessage(w)), con)
        rec$warns <<- c(rec$warns, safe_mask(conditionMessage(w), 200L))
        invokeRestart("muffleWarning")
      },
      error = function(e) {
        writeLines(paste0("[error] ", conditionMessage(e)), con)
        w <- .sr_where(sys.calls())
        if (length(w) >= length(rec$where)) rec$where <<- w
      }
    )
    TRUE
  }, error = function(e) {
    rec$err <<- safe_mask(conditionMessage(e))
    FALSE
  })
  rec$ok <- ok
  rec$secs <- proc.time()[["elapsed"]] - t0
  if (ok && !is.null(env)) rec$shapes <- .sr_shapes(env)
  st$steps[[length(st$steps) + 1L]] <- rec
  ok
}

.sr_report <- function(st, title) {
  pkgs <- c("haven", "dplyr", "data.table", "purrr", "readr", "stringr", "tidyr", "tibble")
  pkg_ver <- vapply(pkgs, function(p) {
    v <- tryCatch(as.character(utils::packageVersion(p)), error = function(e) "MISSING")
    paste0(p, " ", v)
  }, character(1))
  lines <- c(
    "=== safe_run summary (masked; intended for export review) ===",
    paste0("run:      ", title),
    paste0("time:     ", st$stamp),
    paste0("R:        ", R.version.string),
    paste0("packages: ", paste(pkg_ver, collapse = "; ")),
    ""
  )
  for (i in seq_along(st$steps)) {
    r <- st$steps[[i]]
    status <- if (is.na(r$ok)) "SKIPPED" else if (r$ok) "OK" else "FAIL"
    lines <- c(lines, sprintf("[%02d] %-7s %6.1fs  warnings=%d  %s",
                              i, status, r$secs, length(r$warns), r$label))
    if (isFALSE(r$ok)) {
      lines <- c(lines, paste0("     error: ", r$err))
      if (length(r$where)) lines <- c(lines, paste0("     at ", r$where))
    }
    if (length(r$warns)) lines <- c(lines, paste0("     ~ ", head(unique(r$warns), 5L)))
    if (length(r$shapes)) lines <- c(lines, paste0("     obj ", r$shapes))
  }
  writeLines(lines, st$summary)
  n_fail <- sum(vapply(st$steps, function(r) isFALSE(r$ok), logical(1)))
  .sr_say(sprintf("[safe_run] %s  (%d steps, %d failed)",
                  if (n_fail == 0L) "OK" else "FAIL", length(st$steps), n_fail))
  for (r in st$steps) if (isFALSE(r$ok)) {
    .sr_say("  FAILED: ", r$label)
    .sr_say("  error:  ", r$err)
    if (length(r$where)) .sr_say("  at:     ", paste(r$where, collapse = "\n          "))
  }
  .sr_say("  summary (exportable): ", st$summary)
  .sr_say("  full log (DO NOT export): ", st$log)
  invisible(n_fail == 0L)
}

# Run one script.
safe_run <- function(path) {
  stopifnot(file.exists(path))
  st <- .sr_open(sub("\\.R$", "", basename(path)))
  on.exit(.sr_close(st), add = TRUE)
  .sr_say("[safe_run] ", path)
  env <- new.env(parent = globalenv())
  .sr_exec(st, path, function()
    source(path, local = env, encoding = "UTF-8", keep.source = TRUE), env)
  .sr_report(st, path)
}

# Run the pipeline defined in 00-00 step by step, without editing it:
# setup part -> each pipeline_steps entry (stop at first failure) -> final checks.
safe_run_pipeline <- function(pipeline = "code/00-00-run-remote-pipeline.R") {
  stopifnot(file.exists(pipeline))
  exprs <- parse(pipeline, keep.source = TRUE, encoding = "UTF-8")
  is_loop <- vapply(exprs, function(e)
    is.call(e) && identical(e[[1]], as.name("for")) && "pipeline_steps" %in% all.names(e),
    logical(1))
  if (sum(is_loop) != 1L) stop("cannot find the pipeline_steps loop in ", pipeline)
  k <- which(is_loop)
  pre <- exprs[seq_len(k - 1L)]
  post <- if (k < length(exprs)) exprs[(k + 1L):length(exprs)] else expression()

  st <- .sr_open("pipeline")
  on.exit(.sr_close(st), add = TRUE)
  .sr_say("[safe_run] pipeline: ", pipeline)

  ok <- .sr_exec(st, "setup (00-00 before loop)", function()
    for (e in pre) eval(e, envir = globalenv()))
  steps <- if (ok) get("pipeline_steps", envir = globalenv()) else character()
  for (i in seq_along(steps)) {
    label <- sprintf("%s (%s)", names(steps)[[i]], unname(steps[[i]]))
    if (!ok) {
      st$steps[[length(st$steps) + 1L]] <- list(label = label, ok = NA, secs = 0,
        warns = character(), err = NULL, where = character(), shapes = character())
      next
    }
    .sr_say(sprintf("  [%02d/%02d] %s", i, length(steps), names(steps)[[i]]))
    path <- unname(steps[[i]])
    env <- new.env(parent = globalenv())
    ok <- .sr_exec(st, label, function()
      source(path, local = env, encoding = "UTF-8", keep.source = TRUE))
    invisible(gc(verbose = FALSE))
  }
  if (ok && length(post)) {
    .sr_exec(st, "final checks (00-00 after loop)", function()
      for (e in post) eval(e, envir = globalenv()))
  }
  .sr_report(st, pipeline)
}

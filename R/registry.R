`%||%` <- function(x, y) if (is.null(x)) y else x

.has_root_marker <- function(path) {
  length(list.files(path, pattern = "\\.Rproj$")) > 0 ||
    file.exists(file.path(path, "DESCRIPTION"))       ||
    file.exists(file.path(path, ".here"))             ||
    file.exists(file.path(path, ".git"))
}

# Directory of the currently executing script (not necessarily getwd())
.script_dir <- function() {
  # source() call stack
  idx <- which(vapply(sys.calls(), \(x) deparse(x[[1]]) == "source", logical(1)))
  if (length(idx) > 0) {
    frame <- sys.frame(idx[length(idx)])
    path  <- if (is.character(frame$ofile)) frame$ofile
              else if (is.character(frame$file)) frame$file
              else NULL
    if (!is.null(path) && nzchar(path))
      return(dirname(normalizePath(path, mustWork = FALSE)))
  }
  # knitr / Quarto rendering
  if (requireNamespace("knitr", quietly = TRUE)) {
    input <- tryCatch(knitr::current_input(dir = TRUE), error = function(e) NULL)
    if (is.character(input) && nzchar(input))
      return(dirname(normalizePath(input, mustWork = FALSE)))
  }
  # Rscript path/to/script.R
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) > 0) {
    path <- sub("^--file=", "", file_arg[[1L]])
    return(dirname(normalizePath(path, mustWork = FALSE)))
  }
  NULL
}

# Walk up from getwd() — and also from the script's own directory — to find
# the project root (.Rproj, DESCRIPTION, .here, .git).
.find_root <- function() {
  starts <- unique(c(getwd(), .script_dir()))
  for (start in starts) {
    path <- start
    for (i in seq_len(20L)) {
      if (.has_root_marker(path)) return(path)
      parent <- dirname(path)
      if (parent == path) break
      path <- parent
    }
  }
  .script_dir() %||% getwd()
}

# Resolve the registry file path. Uses the path stored by tinylog_script(), or
# falls back to the tinylog.file option (default: "_tinylog_proj.yaml").
.registry_path <- function() {
  getOption(".tinylog_registry_path") %||%
    file.path(.find_root(), getOption("tinylog.file", "_tinylog_proj.yaml"))
}

.in_knitr <- function() {
  requireNamespace("knitr", quietly = TRUE) &&
    !is.null(tryCatch(knitr::current_input(), error = function(e) NULL))
}

.order_registry_entry <- function(entry) {
  key_order <- c("data_source", "description", "first_run", "latest_run", "script_runtime", "n_files", "outputs")
  entry[c(intersect(key_order, names(entry)), setdiff(names(entry), key_order))]
}

# Format a single scalar value for inline YAML
.yaml_scalar <- function(v) {
  if (is.null(v) || (length(v) == 1L && is.na(v))) return("null")
  if (is.logical(v)) return(if (isTRUE(v)) "true" else "false")
  if (is.numeric(v)) return(as.character(v))
  paste0("'", gsub("'", "''", as.character(v)), "'")
}

# Serialize the data_dictionary section with inline (flow) sequences for column samples
.format_dd_yaml <- function(dd) {
  lines <- "data_dictionary:"
  for (script in names(dd)) {
    lines <- c(lines, paste0("  ", script, ":"))
    for (input_name in names(dd[[script]])) {
      lines <- c(lines, paste0("    ", input_name, ":"))
      cols <- dd[[script]][[input_name]]$columns
      if (!is.null(names(cols))) {
        # sample_values = TRUE: named list — one inline sequence per column
        lines <- c(lines, "      columns:")
        for (col_name in names(cols)) {
          vals <- vapply(cols[[col_name]], .yaml_scalar, character(1L))
          lines <- c(lines, paste0("        ", .yaml_scalar(col_name), ": [", paste(vals, collapse = ", "), "]"))
        }
      } else {
        # sample_values = FALSE: flat list of column names, also inline
        col_scalars <- vapply(unlist(cols), .yaml_scalar, character(1L))
        lines <- c(lines, paste0("      columns: [", paste(col_scalars, collapse = ", "), "]"))
      }
    }
  }
  paste(lines, collapse = "\n")
}

# Write the full registry, using custom inline formatting for data_dictionary
.write_registry <- function(registry, path) {
  dd   <- registry$data_dictionary
  main <- registry[names(registry) != "data_dictionary"]
  main_yaml <- yaml::as.yaml(main)
  if (is.null(dd) || length(dd) == 0L) {
    cat(main_yaml, file = path)
  } else {
    cat(main_yaml, .format_dd_yaml(dd), "\n", sep = "", file = path)
  }
  invisible(NULL)
}

.get_current_script_name <- function() {
  # 1. source() call stack — standard usage
  idx <- which(vapply(sys.calls(), \(x) deparse(x[[1]]) == "source", logical(1)))
  if (length(idx) > 0) {
    frame <- sys.frame(idx[length(idx)])
    path  <- if (is.character(frame$ofile)) frame$ofile
              else if (is.character(frame$file)) frame$file
              else NULL
    if (!is.null(path) && nzchar(path)) return(basename(path))
  }
  # 2. knitr / Quarto rendering
  if (requireNamespace("knitr", quietly = TRUE)) {
    input <- tryCatch(knitr::current_input(), error = function(e) NULL)
    if (is.character(input) && nzchar(input)) return(basename(input))
  }
  # 3. Rscript path/to/script.R
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) > 0) return(basename(sub("^--file=", "", file_arg[[1L]])))
  # 4. RStudio interactive fallback
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    path <- tryCatch(rstudioapi::getSourceEditorContext()$path, error = function(e) NULL)
    if (is.character(path) && nzchar(path)) return(basename(path))
  }
  NULL
}

#' Register a script in the project registry
#'
#' Call once near the top of every script, after sourcing this package.
#' Creates or updates an entry in `_registry.yaml` and sets the script name
#' so that [tinylog_output()] can associate outputs with it.
#'
#' `tl_script()` is a short alias for `tinylog_script()`.
#'
#' @param data_source Character. The input data this script reads (path or description).
#' @param description Character. One-line description of what the script does.
#' @param name Character. Script name. Detected automatically when run via `source()`.
#' @param pin_to_top Logical. Pin this script to the top of the registry. Default `FALSE`.
#' @param record_runtime Logical. Record elapsed time on exit. Default `TRUE`.
#' @param yaml_file Character. Registry file name. Defaults to the `tinylog.file` option,
#'   or `"_tinylog_proj.yaml"` if unset. Set `options(tinylog.file = "my_log.yaml")` to
#'   change it project-wide.
#'
#' @export
tinylog_script <- function(data_source,
                             description,
                             name = .get_current_script_name(),
                             pin_to_top = FALSE,
                             record_runtime = TRUE,
                             yaml_file = getOption("tinylog.file", "_tinylog_proj.yaml")) {
  if (is.null(name)) {
    message("tinylog_script: could not detect script name; run via source() or pass name= explicitly")
    return(invisible(NULL))
  }

  registry_path <- file.path(.find_root(), yaml_file)
  options(.tinylog_registry_path = registry_path)

  if (file.exists(registry_path)) {
    registry <- yaml::read_yaml(registry_path)
  } else {
    registry <- list(
      `$version`    = "0.1.0",
      `$learn_more` = "https://github.com/tomasrei/tinylog",
      scripts       = list()
    )
  }

  now <- format(Sys.time(), "%Y-%m-%d %H:%M")
  entry <- list(
    data_source = data_source,
    description = description,
    first_run   = registry$scripts[[name]]$first_run %||% now,
    latest_run  = now,
    outputs     = "none"
  )
  if (pin_to_top) entry$pin_to_top <- TRUE
  registry$scripts[[name]] <- entry
  registry$data_dictionary[[name]] <- NULL

  if (sample(20L, 1L) == 1L) {
    message(
      "tinylog tip: place tinylog_script() at the very top of '", name, "' ",
      "(before library() calls) so the runtime covers the full script, not just the code after it."
    )
  }

  all_names <- names(registry$scripts)
  pinned    <- all_names[vapply(registry$scripts[all_names], \(s) isTRUE(s$pin_to_top), logical(1))]
  rest      <- sort(all_names[!all_names %in% pinned])
  registry$scripts <- lapply(registry$scripts[c(pinned, rest)], .order_registry_entry)
  .write_registry(registry, registry_path)

  options(.tinylog_current_script = name)

  if (record_runtime) {
    .start_sec <- as.numeric(Sys.time())
    .name      <- name
    .reg_path  <- registry_path
    .order_fn  <- .order_registry_entry
    idx <- which(vapply(sys.calls(), \(x) deparse(x[[1]]) == "source", logical(1)))
    if (length(idx) == 0L) {
      if (.in_knitr()) {
        # Track runtime via knitr document hook — fires after all chunks complete
        .old_hook <- knitr::knit_hooks$get("document")
        knitr::knit_hooks$set(document = local({
          start    <- .start_sec
          nm       <- .name
          rp       <- .reg_path
          of       <- .order_fn
          old_hook <- .old_hook
          function(x) {
            .elapsed <- round((as.numeric(Sys.time()) - start) / 60, 1)
            if (file.exists(rp)) {
              .reg <- yaml::read_yaml(rp)
              if (!is.null(.reg$scripts[[nm]])) {
                .reg$scripts[[nm]]$script_runtime <- sprintf("%.1f min", .elapsed)
                .reg$scripts <- lapply(.reg$scripts, of)
                .write_registry(.reg, rp)
                message(nm, ": ", sprintf("%.1f min", .elapsed), " elapsed")
              }
            }
            if (is.function(old_hook)) old_hook(x) else x
          }
        }))
      } else {
        message("runtime tracking requires source() — run via source(here(\"scripts/", name, "\")) to record elapsed time")

      }
    } else {
      .write_runtime <- local({
        start <- .start_sec
        nm    <- name
        rp    <- registry_path
        of    <- .order_registry_entry
        function() {
          .elapsed <- round((as.numeric(Sys.time()) - start) / 60, 1)
          if (file.exists(rp)) {
            .reg <- yaml::read_yaml(rp)
            if (!is.null(.reg$scripts[[nm]])) {
              .reg$scripts[[nm]]$script_runtime <- sprintf("%.1f min", .elapsed)
              .reg$scripts <- lapply(.reg$scripts, of)
              .write_registry(.reg, rp)
              message(nm, ": ", sprintf("%.1f min", .elapsed), " elapsed")
            }
          }
        }
      })
      .idx_val <- idx[length(idx)]
      do.call(
        on.exit,
        list(bquote(.(.write_runtime)()), add = TRUE, after = TRUE),
        envir = sys.frame(.idx_val)
      )
    }
  }

  invisible(name)
}

#' @rdname tinylog_script
#' @export
tl_script <- tinylog_script

#' Record an output file path in the registry
#'
#' Wraps the file path argument of any save call. Registers the path under the
#' current script's registry entry and returns the path unchanged, so it can be
#' dropped inline into any save function.
#'
#' `tl_output()` is a short alias for `tinylog_output()`.
#'
#' Requires [tinylog_script()] to have been called first in the same session.
#'
#' @param file Character. Absolute path to the output file.
#'
#' @return `file`, invisibly.
#' @export
#'
#' @examples
#' \dontrun{
#' ggsave(filename = tinylog_output(here::here("typst/plots/my_plot.png")))
#' write.csv(tab, file = tinylog_output(here::here("data/misc/summary.csv")))
#' }
tinylog_output <- function(file) {
  registry_path <- .registry_path()
  script_name   <- getOption(".tinylog_current_script")

  if (is.null(script_name)) stop(
    "tinylog_output() requires tinylog_script() to have been called first."
  )
  if (!file.exists(registry_path)) return(invisible(file))

  root     <- .find_root()
  rel_file <- if (startsWith(file, root)) substring(file, nchar(root) + 2L) else file

  registry     <- yaml::read_yaml(registry_path)
  existing_raw <- registry$scripts[[script_name]]$outputs %||% list()
  existing <- if (identical(existing_raw, "none") || length(existing_raw) == 0) {
    character(0)
  } else {
    as.character(unlist(existing_raw))
  }

  all_out <- unique(c(existing, rel_file))
  outputs <- all_out[order(dirname(all_out),
                           startsWith(basename(all_out), "sensitivity_"),
                           basename(all_out))]

  registry$scripts[[script_name]]$outputs <- outputs
  registry$scripts[[script_name]]$n_files <- length(outputs)
  registry$scripts <- lapply(registry$scripts, .order_registry_entry)
  .write_registry(registry, registry_path)

  invisible(file)
}

#' @rdname tinylog_output
#' @export
tl_output <- tinylog_output

#' Add a data frame to the project data dictionary
#'
#' Place at the end of a read/clean pipeline to capture column names and
#' optionally sample values. Returns the data frame unchanged.
#'
#' `tl_dict()` is a short alias for `tinylog_dict()`.
#'
#' Requires [tinylog_script()] to have been called first in the same session.
#'
#' @param df A data frame.
#' @param .name Character. Label for this entry. Defaults to the variable name of `df`
#'   as written in the calling code (e.g. `mtcars |> tinylog_dict()` records as `"mtcars"`).
#'   Override when the expression is not a simple name or when you need a custom label.
#' @param sample_values Logical. Record 5 sample values per column. Default `TRUE`.
#' @param sample_string_length Integer or `Inf`. Maximum characters per sample value before truncating with `"..."`. Default `18L`.
#'
#' @return `df`, invisibly.
#' @export
#'
#' @examples
#' \dontrun{
#' dat <- read.csv(here::here("data/raw/file.csv")) |> tinylog_dict()
#' dat <- readRDS(here::here("data/clean/file.rds")) |> tinylog_dict(.name = "occupation")
#' }
tinylog_dict <- function(df, .name = NULL, sample_values = TRUE, sample_string_length = 18L) {
  script_name <- getOption(".tinylog_current_script")
  if (is.null(script_name)) stop(
    "tinylog_dict() requires tinylog_script() to have been called first."
  )
  if (!is.data.frame(df)) stop(
    "tinylog_dict() requires a data frame."
  )

  registry_path <- .registry_path()
  if (!file.exists(registry_path)) return(invisible(df))

  registry <- yaml::read_yaml(registry_path)

  if (is.null(registry$data_dictionary))                      registry$data_dictionary <- list()
  if (is.null(registry$data_dictionary[[script_name]]))       registry$data_dictionary[[script_name]] <- list()

  auto_name <- deparse(substitute(df))
  name <- if (!is.null(.name)) {
    .name
  } else if (grepl("^[A-Za-z._][A-Za-z0-9._]*$", auto_name)) {
    auto_name
  } else {
    n <- length(registry$data_dictionary[[script_name]])
    paste0("input_", n + 1L)
  }

  if (!is.null(registry$data_dictionary[[script_name]][[name]])) {
    base <- name
    i <- 2L
    while (!is.null(registry$data_dictionary[[script_name]][[paste0(base, "_", i)]])) i <- i + 1L
    name <- paste0(base, "_", i)
  }

  clip <- function(v) {
    if (!(is.character(v) || is.factor(v))) return(v)
    s <- as.character(v)
    if (is.finite(sample_string_length) && nchar(s) > sample_string_length)
      paste0(substr(s, 1L, sample_string_length), "...")
    else s
  }

  entry <- list(
    columns = if (sample_values)
      lapply(df, \(col) lapply(as.list(head(col, 5L)), clip))
    else
      as.list(names(df))
  )

  registry$data_dictionary[[script_name]][[name]] <- entry
  .write_registry(registry, registry_path)

  invisible(df)
}

#' @rdname tinylog_dict
#' @export
tl_dict <- tinylog_dict

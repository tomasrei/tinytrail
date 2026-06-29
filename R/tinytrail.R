# Public API: tinytrail(), tinytrail_write(), tinytrail_dict()
#
# Sub-functions used exclusively by the public API are defined first.

.build_script_entry <- function(description, data_source, pin_to_top, first_run, now) {
  entry <- list(
    description = description,
    first_run   = first_run %||% now,
    latest_run  = now,
    outputs     = "none"
  )
  if (!is.null(data_source)) entry$data_source <- data_source
  if (pin_to_top) entry$pin_to_top <- TRUE
  entry
}

.sort_scripts <- function(scripts) {
  all_names <- names(scripts)
  pinned    <- all_names[vapply(scripts[all_names], \(s) isTRUE(s$pin_to_top), logical(1))]
  rest      <- sort(all_names[!all_names %in% pinned])
  lapply(scripts[c(pinned, rest)], .order_registry_entry)
}

.setup_runtime_hook <- function(script_name, registry_path, start_sec, source_idx) {
  record_elapsed <- local({
    script_name   <- script_name
    registry_path <- registry_path
    start_sec     <- start_sec
    function() {
      elapsed_min <- round((as.numeric(Sys.time()) - start_sec) / 60, 1)
      if (!file.exists(registry_path)) return()
      registry <- yaml::read_yaml(registry_path)
      if (is.null(registry$scripts[[script_name]])) return()
      registry$scripts[[script_name]]$script_runtime <- sprintf("%.1f min", elapsed_min)
      registry$scripts <- lapply(registry$scripts, .order_registry_entry)
      .write_registry(registry, registry_path)
      message(script_name, ": ", sprintf("%.1f min", elapsed_min), " elapsed")
    }
  })

  if (length(source_idx) == 0L) {
    if (.in_knitr()) {
      old_hook <- knitr::knit_hooks$get("document")
      knitr::knit_hooks$set(document = local({
        record_elapsed <- record_elapsed
        old_hook       <- old_hook
        function(x) {
          record_elapsed()
          if (is.function(old_hook)) old_hook(x) else x
        }
      }))
    } else {
      message(
        "runtime tracking requires source() -- run via source(here(\"scripts/", script_name, "\")) ",
        "to record elapsed time"
      )
    }
  } else {
    idx_val <- source_idx[length(source_idx)]
    do.call(
      on.exit,
      list(bquote(.(record_elapsed)()), add = TRUE, after = TRUE),
      envir = sys.frame(idx_val)
    )
  }
}

#' Register a script in the project trail
#'
#' Call once near the top of every script. Creates or updates an entry in
#' `_tinytrail.yaml` and sets the script name so that outputs can be recorded.
#'
#' By default (`auto = TRUE`) common write functions (`write.csv`, `saveRDS`,
#' `readr::write_csv`, `ggplot2::ggsave`, etc.) are hooked automatically so
#' their output file paths are captured without any `tinytrail_write()` wrapper.
#' Set `auto = FALSE` to use explicit `tinytrail_write()` calls instead.
#'
#' @param description Character. Description of what the script does.
#' @param data_source Character. Optional. Enter the sources of data used in
#'   this script — name the dataset or survey, not a file path
#'   (e.g. `"Current Population Survey (BLS)"`).
#' @param pin_to_top Logical. Pin this script to the top of the trail. Useful
#'   for a `main.R` that sources other scripts — keeps it visible at the top of
#'   `_tinytrail.yaml` regardless of alphabetical order. Default `FALSE`.
#' @param record_runtime Logical. Record elapsed time on exit. Default `TRUE`.
#' @param name Character. Override the auto-detected script name. Useful in
#'   testing or when auto-detection is not available.
#' @param auto Logical. Automatically intercept common write functions and
#'   record their output paths. Default `TRUE`. Set to `FALSE` to use explicit
#'   `tinytrail_write()` calls instead.
#' @param extra_hooks A `data.frame` with columns `fn` and `arg` specifying
#'   additional write functions to intercept when `auto = TRUE`. `fn` is the
#'   function name (`"my_save"` for a script-level function, or `"pkg::fn"`
#'   for a package function). `arg` is the name of the file-path argument in
#'   that function. Functions from packages that are not installed are silently
#'   skipped.
#'
#' @returns `name` (the script name), invisibly. Called for its side effect of
#'   creating or updating the YAML trail file in the project root.
#' @export
#'
#' @examples
#' \donttest{
#' withr::with_tempdir({
#'   writeLines("Version: 1.0", "DESCRIPTION")
#'   withr::with_options(
#'     list(.tinytrail_registry_path = NULL, .tinytrail_current_script = NULL,
#'          .tinytrail_traced_fns = NULL, .tinytrail_hooks_table = NULL), {
#'
#'     # auto = TRUE (default): write.csv captured without tinytrail_write()
#'     tinytrail(
#'       description    = "Clean and reshape survey data",
#'       data_source    = "Current Population Survey (BLS)",
#'       record_runtime = FALSE,
#'       name           = "clean.R"
#'     )
#'     write.csv(mtcars, "cars.csv")
#'
#'     # extra_hooks: add a function not in the built-in list
#'     tinytrail(
#'       description    = "Export final tables",
#'       record_runtime = FALSE,
#'       name           = "export.R",
#'       extra_hooks    = data.frame(fn = "tinytable::save_tt", arg = "output")
#'     )
#'
#'     # auto = FALSE: use explicit tinytrail_write() wrappers
#'     tinytrail(
#'       description    = "Sources and runs all project scripts in order",
#'       pin_to_top     = TRUE,
#'       record_runtime = FALSE,
#'       auto           = FALSE,
#'       name           = "main.R"
#'     )
#'   })
#' })
#' }
tinytrail <- function(description,
                      data_source  = NULL,
                      pin_to_top   = FALSE,
                      record_runtime = TRUE,
                      name         = NULL,
                      auto         = TRUE,
                      extra_hooks  = NULL) {
  name <- name %||% .get_current_script_name()
  if (is.null(name)) {
    message("tinytrail: could not detect script name; run via source()")
    return(invisible(NULL))
  }

  registry_path <- .registry_path()
  options(.tinytrail_registry_path = registry_path)

  registry <- .read_or_init_registry(registry_path)
  now      <- format(Sys.time(), "%Y-%m-%d %H:%M")
  entry    <- .build_script_entry(
    description = description,
    data_source = data_source,
    pin_to_top  = pin_to_top,
    first_run   = registry$scripts[[name]]$first_run,
    now         = now
  )
  registry$scripts[[name]]         <- entry
  registry$data_dictionary[[name]] <- NULL

  if (sample(.TIP_FREQUENCY, 1L) == 1L) {
    message(
      "tinytrail tip: place tinytrail() at the very top of '", name, "' ",
      "(before library() calls) so the runtime covers the full script, not just the code after it."
    )
  }

  registry$scripts <- .sort_scripts(registry$scripts)
  .write_registry(registry, registry_path)

  options(.tinytrail_current_script = name)

  if (record_runtime) {
    start_sec  <- as.numeric(Sys.time())
    source_idx <- which(vapply(sys.calls(), \(x) deparse(x[[1]]) == "source", logical(1)))
    .setup_runtime_hook(
      script_name   = name,
      registry_path = registry_path,
      start_sec     = start_sec,
      source_idx    = source_idx
    )
  }

  if (auto) {
    .setup_write_hooks(extra = extra_hooks)
    source_idx <- which(vapply(sys.calls(), \(x) deparse(x[[1]]) == "source", logical(1)))
    if (length(source_idx) > 0L) {
      teardown_ <- .teardown_write_hooks
      do.call(
        on.exit,
        list(bquote((.(teardown_))()), add = TRUE, after = TRUE),
        envir = sys.frame(source_idx[length(source_idx)])
      )
    }
    # Rscript / interactive: hooks stay active until R exits — no teardown needed
  }

  invisible(name)
}

#' Record an output file path in the trail
#'
#' Wraps the file path argument of any save call. Registers the path under the
#' current script's trail entry and returns the path unchanged, so it can be
#' dropped inline into any save function.
#'
#' Requires `tinytrail()` to have been called first in the same session.
#'
#' @param file Character. Path to the output file.
#'
#' @return `file`, invisibly.
#' @export
#'
#' @examples
#' \donttest{
#' withr::with_tempdir({
#'   writeLines("Version: 1.0", "DESCRIPTION")
#'   withr::with_options(
#'     list(.tinytrail_registry_path = NULL, .tinytrail_current_script = NULL), {
#'
#'     tinytrail("Process raw data", name = "analysis.R", record_runtime = FALSE)
#'     out <- tinytrail_write("output/results.csv")
#'   })
#' })
#' }
tinytrail_write <- function(file) {
  script_name <- getOption(".tinytrail_current_script")

  if (is.null(script_name)) {
    .warn_no_tinytrail(
      script_name   = .get_current_script_name() %||% "<unknown script>",
      registry_path = .registry_path()
    )
    return(invisible(file))
  }

  tryCatch({
    registry_path <- .registry_path()
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
                             startsWith(basename(all_out), .SENSITIVITY_PREFIX),
                             basename(all_out))]

    registry$scripts[[script_name]]$outputs <- outputs
    registry$scripts[[script_name]]$n_outputs <- length(outputs)
    registry$scripts <- lapply(registry$scripts, .order_registry_entry)
    .write_registry(registry, registry_path)
  }, error = function(e) {
    message("tinytrail: could not record '", basename(file), "': ", conditionMessage(e))
  })

  invisible(file)
}

#' Add a data frame to the project data dictionary
#'
#' Place at the end of a read/clean pipeline to capture column names and
#' optionally sample values. Returns the data frame unchanged.
#'
#' Requires `tinytrail()` to have been called first in the same session.
#'
#' @param df A data frame.
#' @param .name Character. Label for this entry. Defaults to the variable name of `df`
#'   as written in the calling code (e.g. `mtcars |> tinytrail_dict()` records as `"mtcars"`).
#'   Override when the expression is not a simple name or when you need a custom label.
#' @param sample_values Logical. Record 5 sample values per column. Default `TRUE`.
#' @param sample_string_length Integer or `Inf`. Maximum characters per sample value
#'   before truncating with `"..."`. Default `18L`.
#'
#' @return `df`, invisibly.
#' @importFrom utils head
#' @export
#'
#' @examples
#' \donttest{
#' withr::with_tempdir({
#'   writeLines("Version: 1.0", "DESCRIPTION")
#'   withr::with_options(
#'     list(.tinytrail_registry_path = NULL, .tinytrail_current_script = NULL), {
#'
#'     tinytrail("Analyse mtcars", name = "analysis.R", record_runtime = FALSE)
#'     dat <- mtcars |> tinytrail_dict(.name = "cars")
#'   })
#' })
#' }
tinytrail_dict <- function(df, .name = NULL, sample_values = TRUE, sample_string_length = 18L) {
  script_name <- getOption(".tinytrail_current_script")

  if (is.null(script_name)) {
    .warn_no_tinytrail(
      script_name   = .get_current_script_name() %||% "<unknown script>",
      registry_path = .registry_path()
    )
    return(invisible(df))
  }

  if (!is.data.frame(df)) stop("tinytrail_dict() requires a data frame.")

  registry_path <- .registry_path()
  if (!file.exists(registry_path)) return(invisible(df))

  registry <- yaml::read_yaml(registry_path)
  if (is.null(registry$data_dictionary))
    registry$data_dictionary <- list()
  if (is.null(registry$data_dictionary[[script_name]]))
    registry$data_dictionary[[script_name]] <- list()

  auto_name <- deparse(substitute(df))
  dict_name <- if (!is.null(.name)) {
    .name
  } else if (grepl("^[A-Za-z._][A-Za-z0-9._]*$", auto_name)) {
    auto_name
  } else {
    n <- length(registry$data_dictionary[[script_name]])
    paste0("input_", n + 1L)
  }

  if (!is.null(registry$data_dictionary[[script_name]][[dict_name]])) {
    warning(
      "tinytrail_dict(): '", dict_name, "' already recorded for '", script_name,
      "' -- overwriting. Rename the data frame or use .name to distinguish stages.",
      call. = FALSE
    )
  }

  entry <- list(
    columns = if (sample_values)
      lapply(df, \(col) lapply(as.list(head(col, .DICT_SAMPLE_N)),
                               \(v) .truncate_sample_value(v, sample_string_length)))
    else
      as.list(names(df))
  )

  registry$data_dictionary[[script_name]][[dict_name]] <- entry
  .write_registry(registry, registry_path)

  invisible(df)
}

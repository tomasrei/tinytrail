# Private helpers for automatic write-call interception (used by tinytrail()).

# Built-in write functions to intercept: key -> list(fn, pkg, arg)
# "arg" is the parameter name holding the output file path in each function.
.WRITE_HOOKS <- list(
  write.table   = list(fn = "write.table",   pkg = "utils",      arg = "file"),
  write.csv     = list(fn = "write.csv",     pkg = "utils",      arg = "file"),
  write.csv2    = list(fn = "write.csv2",    pkg = "utils",      arg = "file"),
  saveRDS       = list(fn = "saveRDS",       pkg = "base",       arg = "file"),
  save          = list(fn = "save",          pkg = "base",       arg = "file"),
  write_csv     = list(fn = "write_csv",     pkg = "readr",      arg = "file"),
  write_tsv     = list(fn = "write_tsv",     pkg = "readr",      arg = "file"),
  write_delim   = list(fn = "write_delim",   pkg = "readr",      arg = "file"),
  write_rds     = list(fn = "write_rds",     pkg = "readr",      arg = "file"),
  ggsave        = list(fn = "ggsave",        pkg = "ggplot2",    arg = "filename"),
  write_xlsx    = list(fn = "write_xlsx",    pkg = "writexl",    arg = "path"),
  saveWorkbook  = list(fn = "saveWorkbook",  pkg = "openxlsx",   arg = "file"),
  write_parquet = list(fn = "write_parquet", pkg = "arrow",      arg = "sink"),
  write_feather = list(fn = "write_feather", pkg = "arrow",      arg = "sink"),
  write_sav     = list(fn = "write_sav",     pkg = "haven",      arg = "path"),
  write_dta     = list(fn = "write_dta",     pkg = "haven",      arg = "path"),
  write_sas     = list(fn = "write_sas",     pkg = "haven",      arg = "path"),
  write_json    = list(fn = "write_json",    pkg = "jsonlite",   arg = "path"),
  fwrite        = list(fn = "fwrite",        pkg = "data.table", arg = "file")
)

# Parses "pkg::fn" or "fn" from an extra_hooks entry into a spec list.
.parse_hook_spec <- function(entry_name, arg) {
  if (grepl("::", entry_name, fixed = TRUE)) {
    parts <- strsplit(entry_name, "::", fixed = TRUE)[[1L]]
    list(fn = parts[2L], pkg = parts[1L], arg = arg)
  } else {
    list(fn = entry_name, pkg = NULL, arg = arg)
  }
}

# Returns the environment to trace in for a given package.
# Prefers the attached package env (intercepts fn() search-path calls).
# Falls back to namespace when the package is not attached (intercepts pkg::fn() calls).
.trace_env <- function(pkg) {
  if (is.null(pkg)) return(globalenv())
  if (!requireNamespace(pkg, quietly = TRUE)) return(NULL)
  pkg_env_name <- paste0("package:", pkg)
  if (pkg_env_name %in% search()) as.environment(pkg_env_name) else asNamespace(pkg)
}

# Traces a single function. Returns TRUE on success, FALSE if unavailable.
.hook_one <- function(fn_name, pkg, arg) {
  where <- .trace_env(pkg)
  if (is.null(where)) return(FALSE)

  tracer <- bquote(
    tryCatch({
      if (!is.null(getOption(".tinytrail_current_script"))) {
        val <- .(as.name(arg))
        if (is.character(val) && length(val) == 1L && nzchar(val))
          tinytrail_write(val)
      }
    }, error = function(e) NULL)
  )

  tryCatch(
    { suppressMessages(trace(fn_name, tracer = tracer, print = FALSE, where = where)); TRUE },
    error = function(e) FALSE
  )
}

# Activates hooks for all built-in write functions plus any user-supplied extras.
# Stores the active key list and full hook table in options for teardown.
.setup_write_hooks <- function(extra = NULL) {
  hooks <- .WRITE_HOOKS
  if (!is.null(extra)) {
    for (i in seq_len(nrow(extra))) {
      spec <- .parse_hook_spec(extra$fn[i], extra$arg[i])
      hooks[[paste0(spec$pkg %||% "global", "::", spec$fn)]] <- spec
    }
  }

  traced <- character(0)
  for (key in names(hooks)) {
    spec <- hooks[[key]]
    if (.hook_one(spec$fn, spec$pkg, spec$arg)) traced <- c(traced, key)
  }

  options(.tinytrail_traced_fns  = traced,
          .tinytrail_hooks_table = hooks)
  invisible(traced)
}

# Removes all active hooks and clears the tracking options.
.teardown_write_hooks <- function() {
  traced <- getOption(".tinytrail_traced_fns",  character(0))
  hooks  <- getOption(".tinytrail_hooks_table", list())
  for (key in traced) {
    spec <- hooks[[key]]
    if (is.null(spec)) next
    where <- tryCatch(.trace_env(spec$pkg), error = function(e) NULL)
    if (!is.null(where))
      tryCatch(suppressMessages(untrace(spec$fn, where = where)), error = function(e) NULL)
  }
  options(.tinytrail_traced_fns  = NULL,
          .tinytrail_hooks_table = NULL)
  invisible(NULL)
}


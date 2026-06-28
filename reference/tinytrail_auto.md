# Register a script and automatically track all write/save calls

Drop-in alternative to
[`tinytrail()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail.md).
Call once near the top of every script. In addition to registering the
script in `_tinytrail.yaml`, it hooks common write functions
(`write.csv`, `saveRDS`, `readr::write_csv`, `ggplot2::ggsave`, etc.) so
their output file paths are recorded automatically — no
[`tinytrail_write()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail_write.md)
wrapper needed on each save call. Hooks are silently removed when the
script exits.

## Usage

``` r
tinytrail_auto(
  description,
  data_source = NULL,
  pin_to_top = FALSE,
  record_runtime = TRUE,
  name = NULL,
  extra_hooks = NULL
)
```

## Arguments

- description:

  Character. Description of what the script does.

- data_source:

  Character. Optional. Enter the sources of data used in this script —
  name the dataset or survey, not a file path (e.g.
  `"Current Population Survey (BLS)"`).

- pin_to_top:

  Logical. Pin this script to the top of the trail. Useful for a
  `main.R` that sources other scripts — keeps it visible at the top of
  `_tinytrail.yaml` regardless of alphabetical order. Default `FALSE`.

- record_runtime:

  Logical. Record elapsed time on exit. Default `TRUE`.

- name:

  Character. Override the auto-detected script name. Useful in testing
  or when auto-detection is not available.

- extra_hooks:

  Named character vector of additional write functions to intercept.
  Names are function identifiers (`"fn"` for a function defined in the
  script, or `"pkg::fn"` for a package function), values are the name of
  the file-path argument in that function. Example:
  `c(my_save = "path", "sf::st_write" = "dsn")`. Functions from packages
  that are not installed are silently skipped.

## Value

`name` (the script name), invisibly. Called for its side effect of
creating or updating the YAML trail file in the project root.

## Examples

``` r
# \donttest{
withr::with_tempdir({
  writeLines("Version: 1.0", "DESCRIPTION")
  withr::with_options(
    list(.tinytrail_registry_path = NULL, .tinytrail_current_script = NULL,
         .tinytrail_traced_fns = NULL, .tinytrail_hooks_table = NULL), {

    tinytrail_auto(
      description    = "Clean and reshape survey data",
      data_source    = "Current Population Survey (BLS)",
      record_runtime = FALSE,
      name           = "clean.R"
    )

    write.csv(mtcars, "cars.csv")   # recorded automatically
    saveRDS(mtcars,   "cars.rds")   # recorded automatically
  })
})
#> Error in .teardown_write_hooks(): could not find function ".teardown_write_hooks"
# }
```

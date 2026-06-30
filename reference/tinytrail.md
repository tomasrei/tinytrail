# Register a script in the project trail

Call once near the top of every script. Creates or updates an entry in
`_tinytrail.yaml` and sets the script name so that outputs can be
recorded.

## Usage

``` r
tinytrail(
  description,
  data_source = NULL,
  pin_to_top = FALSE,
  record_runtime = TRUE,
  name = NULL,
  auto = TRUE,
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

  Character. Override the auto-detected script name. Intended for use in
  tests and non-standard execution environments where auto-detection is
  unavailable.

- auto:

  Logical. Automatically intercept common write functions and record
  their output paths. Default `TRUE`. Set to `FALSE` to use explicit
  [`tinytrail_write()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail_write.md)
  calls instead.

- extra_hooks:

  A `list` with elements `fn` and `arg` specifying additional write
  functions to intercept when `auto = TRUE`. `fn` is a character vector
  of function names (`"my_save"` for a script-level function, or
  `"pkg::fn"` for a package function). `arg` is a character vector of
  the corresponding file-path argument names. Functions from packages
  that are not installed are silently skipped.

## Value

`name` (the script name), invisibly. Called for its side effect of
creating or updating the YAML trail file in the project root.

## Details

By default (`auto = TRUE`) common write functions (`write.csv`,
`saveRDS`,
[`readr::write_csv`](https://readr.tidyverse.org/reference/write_delim.html),
[`ggplot2::ggsave`](https://ggplot2.tidyverse.org/reference/ggsave.html),
etc.) are hooked automatically so their output file paths are captured
without any
[`tinytrail_write()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail_write.md)
wrapper. Set `auto = FALSE` to use explicit
[`tinytrail_write()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail_write.md)
calls instead.

## See also

[`tinytrail_write()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail_write.md)
to record output paths explicitly,
[`tinytrail_dict()`](https://tinytrail-r.github.io/tinytrail/reference/tinytrail_dict.md)
to capture a data dictionary.

## Examples

``` r
# \donttest{
withr::with_tempdir({
  writeLines("Package: testproject\nVersion: 0.1.0", "DESCRIPTION")

  tinytrail(
    description    = "Clean and summarise survey data",
    data_source    = "Current Population Survey (BLS)",
    record_runtime = FALSE,
    name           = "clean.R"
  )
  write.csv(mtcars, "clean.csv")
  png("age_dist.png"); hist(mtcars$mpg, main = "MPG"); dev.off()
})
#> agg_record_19922828779d 
#>                       2 
# }
```

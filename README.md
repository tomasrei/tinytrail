# tinylog

**tinylog** is a lightweight script registry for R projects. It tracks which scripts produced which output files by maintaining a human-readable YAML file (`_tinylog_proj.yaml`) at the project root.

## Installation

```r
# From CRAN:
install.packages("tinylog")

# Development version from GitHub:
# install.packages("pak")
pak::pak("tomasrei/tinylog")
```

## Usage

Place `tinylog_script()` once near the top of each script, and wrap save calls with `tinylog_output()`:

```r
library(tinylog)

tinylog_script(
  data_source = "data/raw/survey.csv",
  description = "Clean and reshape survey data"
)

dat <- read.csv(here::here("data/raw/survey.csv")) |>
  tinylog_dict()

# ... processing ...

write.csv(dat, file = tinylog_output(here::here("data/clean/survey_clean.csv")))
```

This creates or updates `_tinylog_proj.yaml`:

```yaml
scripts:
  01_clean.R:
    data_source: data/raw/survey.csv
    description: Clean and reshape survey data
    first_run: '2026-06-27 09:00'
    latest_run: '2026-06-27 09:01'
    script_runtime: 0.1 min
    n_files: 1
    outputs:
    - data/clean/survey_clean.csv
```

## Short aliases

`tl_script()`, `tl_output()`, and `tl_dict()` are short aliases for interactive use.

## Options

Set `options(tinylog.file = "my_log.yaml")` to change the registry filename project-wide.

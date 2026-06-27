# tinytrail

**tinytrail** is a lightweight R package that — once initialised — leaves a 'tiny trail' of human- and AI-readable text, making it effortless to keep track of small to medium-sized projects. It maintains a YAML trail file (`_tinytrail.yaml`) at the project root recording which scripts produced which output files.

## Installation

```r
# Development version from GitHub:
# install.packages("pak")
pak::pak("tomasrei/tinytrail")
```

## Usage

Place `tinytrail()` once near the top of each script, wrap save calls with `tinytrail_write()`, and optionally pipe data frames through `tinytrail_dict()`:

```r
library(tinytrail)

tinytrail(
  data_source = "data/raw/survey.csv",
  description = "Clean and reshape survey data"
)

dat <- read.csv(here::here("data/raw/survey.csv")) |>
  tinytrail_dict()

# ... processing ...

write.csv(dat, file = tinytrail_write(here::here("data/clean/survey_clean.csv")))
```

This creates or updates `_tinytrail.yaml`:

```yaml
$version: 0.1.0
$learn_more: https://github.com/tomasrei/tinytrail
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

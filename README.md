# tinytrail

**tinytrail** is a lightweight R package that — once initialized — leaves a 'tiny trail' of human- and AI-readable text, making it effortless to keep track of small to medium-sized projects. It maintains a YAML trail file (`_tinytrail.yaml`) at the project root recording which scripts produced which output files.

## Installation

```r
# Development version from GitHub:
# install.packages("pak")
pak::pak("tomasrei/tinytrail")
```

## Usage

Place `tinytrail()` once near the top of each script and wrap save calls with `tinytrail_write()`:

```r
library(tinytrail)

tinytrail(
  description = "Clean and reshape survey data",
  data_source = "Current Population Survey (BLS)"
)

# ... processing ...

write.csv(dat, file = tinytrail_write("data/clean/survey_clean.csv"))
```

This creates or updates `_tinytrail.yaml`:

```yaml
$version: 0.1.0
$learn_more: https://github.com/tomasrei/tinytrail
scripts:
  01_clean.R:
    description: Clean and reshape survey data
    data_source: Current Population Survey (BLS)
    first_run: '2026-06-27 09:00'
    latest_run: '2026-06-27 09:01'
    script_runtime: 0.1 min
    n_files: 1
    outputs:
    - data/clean/survey_clean.csv
```

Optionally, pipe data frames through `tinytrail_dict()` to capture column names and sample values:

```r
dat <- read.csv("data/raw/survey.csv") |>
  tinytrail_dict()
```

This adds a data dictionary entry to `_tinytrail.yaml`:

```yaml
data_dictionary:
  01_clean.R:
    dat:
      columns:
        id: [1, 2, 3, 4, 5]
        age: [34, 52, 28, 41, 37]
        response: ['yes', 'no', 'yes', 'yes', 'no']
```

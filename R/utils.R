# Utilities and package-level constants

`%||%` <- function(x, y) if (is.null(x)) y else x

.TINYTRAIL_VERSION  <- "0.1.0"
.TINYTRAIL_URL      <- "https://github.com/tomasrei/tinytrail"
.ROOT_SEARCH_DEPTH  <- 20L  # max directory levels to walk up in .find_root()
.DICT_SAMPLE_N      <- 5L   # number of sample values captured per column
.TIP_FREQUENCY      <- 20L  # show startup tip on 1-in-N runs
.SENSITIVITY_PREFIX <- "sensitivity_"  # output filename prefix that sorts last
.REGISTRY_FILENAME  <- "_tinytrail.yaml"
.KEY_ORDER          <- c("description", "data_source", "first_run",
                         "latest_run", "script_runtime", "n_outputs", "outputs")

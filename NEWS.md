# tinylog 0.1.0

* Initial CRAN release.
* `tinylog_script()` registers a script in the project YAML registry and optionally records elapsed runtime.
* `tinylog_output()` wraps any save call to log the output file path under the calling script's registry entry.
* `tinylog_dict()` captures column names and sample values for input data frames.
* Short aliases `tl_script()`, `tl_output()`, and `tl_dict()` are provided for interactive use.

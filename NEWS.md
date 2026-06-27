# tinytrail 0.1.0

* Initial release (renamed from `tinylog`).
* `tinytrail()` registers a script in the project YAML trail and optionally records elapsed runtime.
* `tinytrail_write()` wraps any save call to log the output file path under the calling script's trail entry.
* `tinytrail_dict()` captures column names and sample values for input data frames.

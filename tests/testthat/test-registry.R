test_that("tinylog_output() errors without tinylog_script()", {
  withr::local_options(.tinylog_current_script = NULL, .tinylog_registry_path = NULL)
  expect_error(tinylog_output("some/file.png"), "tinylog_script")
})

test_that("tinylog_script() sets the script name option", {
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  withr::local_options(.tinylog_current_script = NULL, .tinylog_registry_path = NULL)

  tinylog_script(
    name        = "test.R",
    data_source = "none",
    description = "test",
    record_runtime = FALSE
  )

  expect_equal(getOption(".tinylog_current_script"), "test.R")
  expect_true(file.exists("_tinylog_proj.yaml"))
})

test_that("tinylog_output() registers path and returns it", {
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  withr::local_options(.tinylog_current_script = NULL, .tinylog_registry_path = NULL)

  tinylog_script(
    name        = "test.R",
    data_source = "none",
    description = "test",
    record_runtime = FALSE
  )

  path <- file.path(tmp, "output.png")
  result <- tinylog_output(path)

  expect_equal(result, path)

  reg <- yaml::read_yaml("_tinylog_proj.yaml")
  expect_true(any(grepl("output.png", unlist(reg$scripts[["test.R"]]$outputs))))
})

test_that("tinylog_dict() errors without tinylog_script()", {
  withr::local_options(.tinylog_current_script = NULL, .tinylog_registry_path = NULL)
  expect_error(tinylog_dict(data.frame(x = 1)), "tinylog_script")
})

test_that("tinylog_dict() errors on non-data-frame", {
  withr::local_options(.tinylog_current_script = "test.R", .tinylog_registry_path = NULL)
  expect_error(tinylog_dict(list(x = 1)), "data frame")
})

test_that("tinylog_dict() records columns and sample values in data_dictionary", {
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  withr::local_options(.tinylog_current_script = NULL, .tinylog_registry_path = NULL)

  tinylog_script(
    name        = "test.R",
    data_source = "none",
    description = "test",
    record_runtime = FALSE
  )

  df <- data.frame(mpg = c(21, 22, 18, 24, 19), cyl = c(6L, 4L, 8L, 4L, 6L))
  result <- df |> tinylog_dict(.name = "my_data")

  expect_identical(result, df)

  reg <- yaml::read_yaml("_tinylog_proj.yaml")
  entry <- reg$data_dictionary[["test.R"]][["my_data"]]
  expect_length(entry$columns$mpg, 5L)
  expect_length(entry$columns$cyl, 5L)
})

test_that("tinylog_dict() auto-names entry from df variable name", {
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  withr::local_options(.tinylog_current_script = NULL, .tinylog_registry_path = NULL)

  tinylog_script(
    name        = "test.R",
    data_source = "none",
    description = "test",
    record_runtime = FALSE
  )

  df1 <- data.frame(x = 1:3)
  df2 <- data.frame(y = 1:3)
  df1 |> tinylog_dict()
  df2 |> tinylog_dict()

  reg <- yaml::read_yaml("_tinylog_proj.yaml")
  expect_true(!is.null(reg$data_dictionary[["test.R"]][["df1"]]))
  expect_true(!is.null(reg$data_dictionary[["test.R"]][["df2"]]))
})

test_that("tinylog_dict() warns and overwrites on duplicate df name", {
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  withr::local_options(.tinylog_current_script = NULL, .tinylog_registry_path = NULL)

  tinylog_script(
    name        = "test.R",
    data_source = "none",
    description = "test",
    record_runtime = FALSE
  )

  dat <- data.frame(x = 1:3)
  dat |> tinylog_dict()
  expect_warning(dat |> tinylog_dict(), "Rename the data frame")

  reg <- yaml::read_yaml("_tinylog_proj.yaml")
  entries <- names(reg$data_dictionary[["test.R"]])
  expect_equal(entries, "dat")
})

test_that("tinylog_dict() omits sample values when sample_values = FALSE", {
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  withr::local_options(.tinylog_current_script = NULL, .tinylog_registry_path = NULL)

  tinylog_script(
    name        = "test.R",
    data_source = "none",
    description = "test",
    record_runtime = FALSE
  )

  df <- data.frame(x = 1:3, y = letters[1:3])
  df |> tinylog_dict(sample_values = FALSE)

  reg <- yaml::read_yaml("_tinylog_proj.yaml")
  entry <- reg$data_dictionary[["test.R"]][["df"]]
  expect_equal(unlist(entry$columns), c("x", "y"))
})

test_that("tinylog_dict() truncates long strings at sample_string_length", {
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  withr::local_options(.tinylog_current_script = NULL, .tinylog_registry_path = NULL)

  tinylog_script(
    name        = "test.R",
    data_source = "none",
    description = "test",
    record_runtime = FALSE
  )

  df <- data.frame(label = c("short", "this is a very long string indeed"), x = 1:2)
  df |> tinylog_dict(sample_string_length = 18L)

  reg <- yaml::read_yaml("_tinylog_proj.yaml")
  labels <- unlist(reg$data_dictionary[["test.R"]][["df"]]$columns$label)
  expect_equal(labels[[1]], "short")
  expect_equal(labels[[2]], "this is a very lon...")
  expect_true(nchar(labels[[2]]) == 18L + 3L)
})

test_that("tinylog_dict() respects sample_string_length = Inf", {
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  withr::local_options(.tinylog_current_script = NULL, .tinylog_registry_path = NULL)

  tinylog_script(
    name        = "test.R",
    data_source = "none",
    description = "test",
    record_runtime = FALSE
  )

  long <- paste(rep("a", 100), collapse = "")
  df <- data.frame(label = long)
  df |> tinylog_dict(sample_string_length = Inf)

  reg <- yaml::read_yaml("_tinylog_proj.yaml")
  val <- reg$data_dictionary[["test.R"]][["df"]]$columns$label[[1]]
  expect_equal(nchar(val), 100L)
})

test_that("n_files is correct after lapply over multiple outputs", {
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  withr::local_options(.tinylog_current_script = NULL, .tinylog_registry_path = NULL)

  tinylog_script(
    name        = "test.R",
    data_source = "none",
    description = "test",
    record_runtime = FALSE
  )

  paths <- file.path(tmp, paste0("plot_", 1:3, ".png"))
  lapply(paths, tinylog_output)

  reg <- yaml::read_yaml("_tinylog_proj.yaml")
  expect_equal(reg$scripts[["test.R"]]$n_files, 3L)
  expect_length(reg$scripts[["test.R"]]$outputs, 3L)
})

test_that("n_files is correct after purrr::map over multiple outputs", {
  skip_if_not_installed("purrr")
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  withr::local_options(.tinylog_current_script = NULL, .tinylog_registry_path = NULL)

  tinylog_script(
    name        = "test.R",
    data_source = "none",
    description = "test",
    record_runtime = FALSE
  )

  paths <- file.path(tmp, paste0("plot_", 1:3, ".png"))
  purrr::map(paths, tinylog_output)

  reg <- yaml::read_yaml("_tinylog_proj.yaml")
  expect_equal(reg$scripts[["test.R"]]$n_files, 3L)
  expect_length(reg$scripts[["test.R"]]$outputs, 3L)
})

test_that("all three functions work together without source() (simple_main scenario)", {
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)
  withr::local_options(.tinylog_current_script = NULL, .tinylog_registry_path = NULL)

  tinylog_script(
    name           = "simple_main.R",
    data_source    = "mtcars (built-in)",
    description    = "smoke test without source()",
    record_runtime = FALSE
  )

  mtcars |> tinylog_dict()

  dat <- within(mtcars, efficiency_class <- ifelse(mpg > 20, "High", "Low"))
  dat |> tinylog_dict()

  out <- file.path(tmp, "mtcars_simple.rds")
  tinylog_output(out)

  reg <- yaml::read_yaml("_tinylog_proj.yaml")

  expect_equal(reg$scripts[["simple_main.R"]]$n_files, 1L)
  expect_length(reg$data_dictionary[["simple_main.R"]][["mtcars"]]$columns$mpg, 5L)
  expect_length(reg$data_dictionary[["simple_main.R"]][["dat"]]$columns$mpg, 5L)
  expect_true(!is.null(reg$data_dictionary[["simple_main.R"]][["dat"]]$columns$efficiency_class))
})

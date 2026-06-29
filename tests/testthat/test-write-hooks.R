# Tests for auto-hook interception.
# Each test verifies that calling a hooked write function records the output
# path in the registry. We test the hook fires — not that the write function
# itself works correctly (that is the upstream package's responsibility).

# ---------------------------------------------------------------------------
# File-local helpers
# ---------------------------------------------------------------------------

local_session <- function(tmp, envir = parent.frame()) {
  withr::local_dir(tmp, .local_envir = envir)
  withr::local_options(
    .tinytrail_current_script = NULL,
    .tinytrail_registry_path  = NULL,
    .tinytrail_traced_fns     = NULL,
    .tinytrail_hooks_table    = NULL,
    .local_envir = envir
  )
  tinytrail(name = "test.R", data_source = "none",
            description = "test", record_runtime = FALSE)
  # Tear down traces before options are restored (LIFO: this runs first).
  withr::defer(.teardown_write_hooks(), envir = envir)
}

has_output <- function(filename) {
  reg <- yaml::read_yaml("_tinytrail.yaml")
  any(grepl(filename, unlist(reg$scripts[["test.R"]]$outputs), fixed = TRUE))
}

# ---------------------------------------------------------------------------
# base R / utils
# ---------------------------------------------------------------------------

test_that("write.csv hook captures path", {
  tmp <- withr::local_tempdir()
  local_session(tmp)
  write.csv(mtcars, "out.csv")
  expect_true(has_output("out.csv"))
})

test_that("write.csv2 hook captures path", {
  tmp <- withr::local_tempdir()
  local_session(tmp)
  write.csv2(mtcars, "out.csv")
  expect_true(has_output("out.csv"))
})

test_that("write.table hook captures path", {
  tmp <- withr::local_tempdir()
  local_session(tmp)
  write.table(mtcars, "out.txt")
  expect_true(has_output("out.txt"))
})

test_that("saveRDS hook captures path", {
  tmp <- withr::local_tempdir()
  local_session(tmp)
  saveRDS(mtcars, "out.rds")
  expect_true(has_output("out.rds"))
})

test_that("save hook captures path", {
  tmp <- withr::local_tempdir()
  local_session(tmp)
  save(mtcars, file = "out.rda")
  expect_true(has_output("out.rda"))
})

# ---------------------------------------------------------------------------
# grDevices — path captured at device open, not dev.off()
# ---------------------------------------------------------------------------

test_that("png hook captures path", {
  tmp <- withr::local_tempdir()
  local_session(tmp)
  png("out.png")
  withr::defer(dev.off())
  expect_true(has_output("out.png"))
})

test_that("jpeg hook captures path", {
  tmp <- withr::local_tempdir()
  local_session(tmp)
  jpeg("out.jpg")
  withr::defer(dev.off())
  expect_true(has_output("out.jpg"))
})

test_that("tiff hook captures path", {
  tmp <- withr::local_tempdir()
  local_session(tmp)
  tiff("out.tif")
  withr::defer(dev.off())
  expect_true(has_output("out.tif"))
})

test_that("bmp hook captures path", {
  tmp <- withr::local_tempdir()
  local_session(tmp)
  bmp("out.bmp")
  withr::defer(dev.off())
  expect_true(has_output("out.bmp"))
})

test_that("pdf hook captures path", {
  tmp <- withr::local_tempdir()
  local_session(tmp)
  pdf("out.pdf")
  withr::defer(dev.off())
  expect_true(has_output("out.pdf"))
})

test_that("postscript hook captures path", {
  tmp <- withr::local_tempdir()
  local_session(tmp)
  postscript("out.ps")
  withr::defer(dev.off())
  expect_true(has_output("out.ps"))
})

test_that("cairo_pdf hook captures path", {
  skip_if_not(capabilities("cairo"), "Cairo not available on this platform")
  skip_if_not(
    tryCatch({ f <- tempfile(fileext = ".pdf"); cairo_pdf(f); dev.off(); TRUE },
             error = function(e) FALSE, warning = function(w) FALSE),
    "Cairo DLL failed to load at runtime"
  )
  tmp <- withr::local_tempdir()
  local_session(tmp)
  cairo_pdf("out.pdf")
  withr::defer(dev.off())
  expect_true(has_output("out.pdf"))
})

test_that("svg hook captures path", {
  skip_if_not(capabilities("cairo"), "Cairo not available on this platform")
  skip_if_not(
    tryCatch({ f <- tempfile(fileext = ".svg"); svg(f); dev.off(); TRUE },
             error = function(e) FALSE, warning = function(w) FALSE),
    "Cairo DLL failed to load at runtime"
  )
  tmp <- withr::local_tempdir()
  local_session(tmp)
  svg("out.svg")
  withr::defer(dev.off())
  expect_true(has_output("out.svg"))
})

# ---------------------------------------------------------------------------
# readr
# ---------------------------------------------------------------------------

test_that("write_csv hook captures path", {
  skip_if_not_installed("readr")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  readr::write_csv(mtcars, "out.csv")
  expect_true(has_output("out.csv"))
})

test_that("write_tsv hook captures path", {
  skip_if_not_installed("readr")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  readr::write_tsv(mtcars, "out.tsv")
  expect_true(has_output("out.tsv"))
})

test_that("write_delim hook captures path", {
  skip_if_not_installed("readr")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  readr::write_delim(mtcars, "out.txt", delim = "|")
  expect_true(has_output("out.txt"))
})

test_that("write_rds hook captures path", {
  skip_if_not_installed("readr")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  readr::write_rds(mtcars, "out.rds")
  expect_true(has_output("out.rds"))
})

# ---------------------------------------------------------------------------
# ggplot2
# ---------------------------------------------------------------------------

test_that("ggsave hook captures path", {
  skip_if_not_installed("ggplot2")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(mpg, wt)) + ggplot2::geom_point()
  ggplot2::ggsave("out.png", p, width = 2, height = 2)
  expect_true(has_output("out.png"))
})

# ---------------------------------------------------------------------------
# writexl / openxlsx / openxlsx2
# ---------------------------------------------------------------------------

test_that("write_xlsx hook captures path", {
  skip_if_not_installed("writexl")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  writexl::write_xlsx(mtcars, "out.xlsx")
  expect_true(has_output("out.xlsx"))
})

test_that("saveWorkbook hook captures path", {
  skip_if_not_installed("openxlsx")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(wb, "Sheet1")
  openxlsx::saveWorkbook(wb, "out.xlsx", overwrite = TRUE)
  expect_true(has_output("out.xlsx"))
})

test_that("wb_save hook captures path", {
  skip_if_not_installed("openxlsx2")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  wb <- openxlsx2::wb_workbook()$add_worksheet("Sheet1")
  openxlsx2::wb_save(wb, "out.xlsx")
  expect_true(has_output("out.xlsx"))
})

# ---------------------------------------------------------------------------
# arrow
# ---------------------------------------------------------------------------

test_that("write_parquet hook captures path", {
  skip_if_not_installed("arrow")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  arrow::write_parquet(mtcars, "out.parquet")
  expect_true(has_output("out.parquet"))
})

test_that("write_feather hook captures path", {
  skip_if_not_installed("arrow")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  arrow::write_feather(mtcars, "out.feather")
  expect_true(has_output("out.feather"))
})

# ---------------------------------------------------------------------------
# haven
# ---------------------------------------------------------------------------

test_that("write_sav hook captures path", {
  skip_if_not_installed("haven")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  haven::write_sav(mtcars, "out.sav")
  expect_true(has_output("out.sav"))
})

test_that("write_dta hook captures path", {
  skip_if_not_installed("haven")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  haven::write_dta(mtcars, "out.dta")
  expect_true(has_output("out.dta"))
})

test_that("write_sas hook captures path", {
  skip_if_not_installed("haven")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  haven::write_sas(mtcars, "out.sas7bdat")
  expect_true(has_output("out.sas7bdat"))
})

# ---------------------------------------------------------------------------
# jsonlite
# ---------------------------------------------------------------------------

test_that("write_json hook captures path", {
  skip_if_not_installed("jsonlite")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  jsonlite::write_json(mtcars, "out.json")
  expect_true(has_output("out.json"))
})

# ---------------------------------------------------------------------------
# data.table
# ---------------------------------------------------------------------------

test_that("fwrite hook captures path", {
  skip_if_not_installed("data.table")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  data.table::fwrite(data.table::as.data.table(mtcars), "out.csv")
  expect_true(has_output("out.csv"))
})

# ---------------------------------------------------------------------------
# tinytable
# ---------------------------------------------------------------------------

test_that("save_tt hook captures path", {
  skip_if_not_installed("tinytable")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  tinytable::save_tt(tinytable::tt(mtcars[1:3, 1:3]), "out.html", overwrite = TRUE)
  expect_true(has_output("out.html"))
})

# ---------------------------------------------------------------------------
# yaml
# ---------------------------------------------------------------------------

test_that("write_yaml hook captures path", {
  tmp <- withr::local_tempdir()
  local_session(tmp)
  yaml::write_yaml(list(a = 1, b = 2), "out.yaml")
  expect_true(has_output("out.yaml"))
})

# ---------------------------------------------------------------------------
# kableExtra
# ---------------------------------------------------------------------------

test_that("save_kable hook captures path", {
  skip_if_not_installed("kableExtra")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  kableExtra::save_kable(kableExtra::kbl(mtcars[1:3, 1:3]), "out.html")
  expect_true(has_output("out.html"))
})

# ---------------------------------------------------------------------------
# sf
# ---------------------------------------------------------------------------

test_that("st_write hook captures path", {
  skip_if_not_installed("sf")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  pt <- sf::st_as_sf(data.frame(x = 0, y = 0), coords = c("x", "y"))
  sf::st_write(pt, "out.gpkg", quiet = TRUE)
  expect_true(has_output("out.gpkg"))
})

# ---------------------------------------------------------------------------
# xml2
# ---------------------------------------------------------------------------

test_that("write_xml hook captures path", {
  skip_if_not_installed("xml2")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  xml2::write_xml(xml2::read_xml("<root><a/></root>"), "out.xml")
  expect_true(has_output("out.xml"))
})

# ---------------------------------------------------------------------------
# rgl (requires NULL device to avoid display dependency)
# ---------------------------------------------------------------------------

test_that("snapshot3d hook captures path", {
  skip_if_not_installed("rgl")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  withr::local_options(rgl.useNULL = TRUE)
  rgl::open3d()
  withr::defer(rgl::close3d())
  rgl::snapshot3d("out.png")
  expect_true(has_output("out.png"))
})

# ---------------------------------------------------------------------------
# officer
# ---------------------------------------------------------------------------

test_that("print.rdocx hook captures path", {
  skip_if_not_installed("officer")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  print(officer::read_docx(), target = "out.docx")
  expect_true(has_output("out.docx"))
})

test_that("print.rpptx hook captures path", {
  skip_if_not_installed("officer")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  print(officer::read_pptx(), target = "out.pptx")
  expect_true(has_output("out.pptx"))
})

test_that("print.rtf hook captures path", {
  skip_if_not_installed("officer")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  print(officer::rtf_doc(), target = "out.rtf")
  expect_true(has_output("out.rtf"))
})

# ---------------------------------------------------------------------------
# magick
# ---------------------------------------------------------------------------

test_that("image_write hook captures path", {
  skip_if_not_installed("magick")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  magick::image_write(magick::image_blank(10, 10, color = "white"), "out.png")
  expect_true(has_output("out.png"))
})

# ---------------------------------------------------------------------------
# imager
# ---------------------------------------------------------------------------

test_that("save.image hook captures path", {
  skip_if_not_installed("imager")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  img <- imager::as.cimg(array(1, c(10L, 10L, 1L, 1L)))
  imager::save.image(img, "out.png")
  expect_true(has_output("out.png"))
})

# ---------------------------------------------------------------------------
# svglite
# ---------------------------------------------------------------------------

test_that("svglite hook captures path", {
  skip_if_not_installed("svglite")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  svglite::svglite("out.svg")
  withr::defer(dev.off())
  expect_true(has_output("out.svg"))
})

# ---------------------------------------------------------------------------
# rvg
# ---------------------------------------------------------------------------

test_that("dml hook captures path", {
  skip_if_not_installed("rvg")
  skip_if_not(
    tryCatch({ f <- tempfile(fileext = ".emf"); rvg::dml(f); dev.off(); TRUE },
             error = function(e) FALSE, warning = function(w) FALSE),
    "rvg::dml device failed to open at runtime"
  )
  tmp <- withr::local_tempdir()
  local_session(tmp)
  rvg::dml("out.emf")
  withr::defer(dev.off())
  expect_true(has_output("out.emf"))
})

# ---------------------------------------------------------------------------
# terra
# ---------------------------------------------------------------------------

test_that("writeRaster hook captures path", {
  skip_if_not_installed("terra")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  r <- terra::rast(nrows = 2, ncols = 2, vals = 1:4)
  terra::writeRaster(r, "out.tif", overwrite = TRUE)
  expect_true(has_output("out.tif"))
})

test_that("writeVector hook captures path", {
  skip_if_not_installed("terra")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  v <- terra::vect(data.frame(x = 0, y = 0), geom = c("x", "y"))
  terra::writeVector(v, "out.gpkg", overwrite = TRUE)
  expect_true(has_output("out.gpkg"))
})

# ---------------------------------------------------------------------------
# stars
# ---------------------------------------------------------------------------

test_that("write_stars hook captures path", {
  skip_if_not_installed("stars")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  s <- stars::st_as_stars(matrix(1:4, 2, 2))
  stars::write_stars(s, "out.tif")
  expect_true(has_output("out.tif"))
})

# ---------------------------------------------------------------------------
# fst
# ---------------------------------------------------------------------------

test_that("write_fst hook captures path", {
  skip_if_not_installed("fst")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  fst::write_fst(mtcars, "out.fst")
  expect_true(has_output("out.fst"))
})

# ---------------------------------------------------------------------------
# htmlwidgets (requires a package that produces a widget)
# ---------------------------------------------------------------------------

test_that("saveWidget hook captures path", {
  skip_if_not_installed("htmlwidgets")
  skip_if_not_installed("leaflet")
  tmp <- withr::local_tempdir()
  local_session(tmp)
  htmlwidgets::saveWidget(leaflet::leaflet(), "out.html", selfcontained = FALSE)
  expect_true(has_output("out.html"))
})

# ---------------------------------------------------------------------------
# Resilience — hook / write failures must not interrupt the user's script
# ---------------------------------------------------------------------------

test_that("tinytrail_write() emits a message but does not error on registry failure", {
  tmp <- withr::local_tempdir()
  local_session(tmp)
  writeLines(": invalid ][", "_tinytrail.yaml")   # corrupt the registry
  expect_no_error(tinytrail_write("some/file.csv"))
  expect_message(tinytrail_write("some/file.csv"), "tinytrail")
})

test_that("auto hook does not interrupt the user's write call on registry failure", {
  tmp <- withr::local_tempdir()
  local_session(tmp)
  writeLines(": invalid ][", "_tinytrail.yaml")   # corrupt the registry
  expect_no_error(write.csv(mtcars, "out.csv"))
  expect_true(file.exists("out.csv"))             # the write still completed
})

test_that("consecutive", {
    years <- c(1900:1903, 1905:1906)

    expect_identical(consecutive(years), c(1L, 1L, 1L, 1L, 2L, 2L))
    expect_identical(suppressWarnings(consecutive(c(1, NA, 2, 2))),
                     c(1L, rep(NA_integer_, 3L)))
    expect_warning(consecutive(c(1, NA, 2, 2)))
    expect_error(suppressWarnings(consecutive(letters[1:3])))
})

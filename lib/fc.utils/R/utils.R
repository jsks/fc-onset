#' @export
extract_digits <- function(x) {
    m <- gregexpr("\\d", x)
    regmatches(x, m)
}


#' Find consecutive elements
#'
#' Given a NumericVector, return the grouping indices for consecutive
#' elements.
#'
#' @param x NumericVector
#'
#' @examples
#' consecutive(c(1900:1905, 1908:1910))
#'
#' @export
consecutive <- function(x) UseMethod("consecutive", x)

#' @export
consecutive.numeric <- function(x) {
    if (anyNA(x))
        warning("NA's in given vector")

    cumsum(c(T, diff(x) != 1))
}

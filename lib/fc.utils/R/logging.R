#' Formatted logging
#'
#' Output a formatted log message. Ellipsis arguments are first passed
#' to \code{\link{sprintf}} before being printed to console with
#' \code{\link{print}}.
#'
#' @param ... \code{\link{sprintf}} style format string and arguments
#' @param type Type of message, either INFO or WARN
#'
#' @examples
#' log(type = "INFO", "Hello %s", "world")
#'
#' @export
log <- function(type = c("INFO", "WARN", "ERROR"), ...) {
    level <- match.arg(type)
    prefix <- sprintf("[%s] [%s]", level, Sys.time())

    msg <- paste(prefix, sprintf(...))
    print(msg)
}

#' @examples
#' info("Information message")
#'
#' @rdname log
#' @export
info <- function(...) log(type = "INFO", ...)

#' @examples
#' warn("Warning message")
#'
#' @rdname log
#' @export
warn <- function(...) log(type = "WARN", ...)

.onLoad <- function(libname, pkgname) {
    # This is only for building the project image in order to avoid
    # including CmdStan by precompiling our model. Don't every do
    # something like this in a real package, please.
    utils::assignInNamespace("cmdstan_version", function(...) "2.34.1", ns = "cmdstanr")
}

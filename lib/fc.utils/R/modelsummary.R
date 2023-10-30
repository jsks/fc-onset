#' @export
model_info <- function(s) UseMethod("model_info", s)

#' @export
model_info.character <- function(s) {
    v <- strsplit(s, "-")[[1]]
    if (length(v) != 3 || any(nchar(v) == 0))
        stop(sprintf("Misformed model string? %s", s))

    list(outcome = v[1], treatment_aggregation = v[2], episodes = v[3])
}

#' @importFrom parameters model_parameters
#' @export
model_parameters.CmdStanMCMC <- function(model, pars = c(), ...) {
    # Note, modelsummary is calling `parameters` with do.call with
    # args as `list(model = model, ...)`. If the first function
    # argument for our method is called anything besides `model`, it
    # will silently fail because modelsummary decided to silence all
    # error messages...
    draws <- model$draws(pars, format = "df")

    # This is a hack, but we need to recover the original variable names
    # in the right order
    labels <- dirname(model$data_file()) |> file.path("labels.rds") |> readRDS()

    args <- append(list(.x = draws), labels)
    draws <- do.call(posterior::rename_variables, args)

    parameters::parameters(draws, ...)
}

#' @export
post_summarise <- function(x, ...) UseMethod("post_summarise", x)

#' @export
post_summarise.CmdStanFit <- function(x, pars, model_info = F, rename = F, probs = c(0.05, 0.5, 0.95)) {
    draws <- x$draws(pars)

    if (isTRUE(rename)) {
        f <- dirname(x$data_file()) |> file.path("labels.rds")
        if (!file.exists(f))
            stop("No labels found for model")

        labels <- readRDS(f)
        args <- append(list(.x = draws), labels[labels %in% posterior::variables(draws)])
        draws <- do.call(posterior::rename_variables, args)
    }

    df <- posterior::summarise_draws(draws, ~stats::quantile(.x, probs))

    if (isTRUE(model_info)) {
        # This is also a horrible hack
        model <- dirname(x$data_file()) |> basename()
        li <- model_info(model)
        df <- cbind(df, li)
    }

    return(df)
}

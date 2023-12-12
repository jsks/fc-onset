#!/usr/bin/env Rscript

library(dplyr)
library(fc.utils)

dir.create("data/models", showWarnings = F)
df <- readRDS("./data/merged_data.rds") |> ungroup()

###
# Create a design matrix with all possible analysis combinations
treatments <- c("bin", "bin_5y", "prop")
outcomes <- c("frozen", "strict_frozen")
units <- c("all", "high_intensity")
censored <- c("no_censored", "with_censored")

design <- expand.grid("outcome" = outcomes, "treatment" = treatments,
                      "episodes" = units, "censored" = censored) |>
    mutate(name = sprintf("%s-%s-%s-%s", outcome, treatment, episodes, censored))

for (row in 1:nrow(design)) {
    info("Model %s", design[row, "name"])

    # Start off by setting the unit of analysis
    sub.df <- if (design[row, "episodes"] == "high_intensity")
        filter(df, cumulative_intensity == 1)
    else
        df

    # Filter out censored observations if necessary, ie conflicts
    # beginning before 1975
    if (design[row, "censored"] == "no_censored")
        sub.df <- filter(sub.df, censored == 0)

    # Select control variables - this is mostly static across models
    X <- select(sub.df, censored, episode_duration, recur, high_intensity, incompatibility,
                cold_war, ongoing_intrastate, ongoing_interstate)

    # If we've dropped censored episodes, no need for binary control
    # var
    if (design[row, "censored"] == "no_censored")
        X <- select(X, -censored)

    X <- mutate(X, episode_duration = log(episode_duration) |> scale()) |>
        data.matrix()

    cases <- rowSums(is.na(X)) == 0

    # Select the treatment option
    state_sup <- paste0("ext_sup_s_state_", design[row, "treatment"])
    rebel_sup <- paste0("ext_sup_s_rebel_", design[row, "treatment"])

    treatments <- select(sub.df, {{ state_sup }}, {{ rebel_sup }}) |>
        mutate(interaction = .data[[{{ state_sup }}]] * .data[[{{ rebel_sup }}]]) |>
        data.matrix()

    # Set the outcome variable
    y <- sub.df[[design[row, "outcome"]]]

    f <- sprintf("./data/models/%s.RData", design[row, "name"])
    save(sub.df, cases, treatments, X, y, file = f)
}

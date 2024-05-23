#!/usr/bin/env Rscript

library(dplyr)
library(fc.utils)

dir.create("data/model_inputs", showWarnings = F)
df <- readRDS("./data/merged_data.rds") |> ungroup()

###
# Create a design matrix with all possible analysis combinations
treatments <- c("bin", "prop")
outcomes <- c("frozen", "strict_frozen")
units <- c("all", "cumulative_intensity")

design <- expand.grid("outcome" = outcomes, "treatment" = treatments, "episodes" = units) |>
    mutate(id = sprintf("%04d", row_number()))

# Save the design matrix
saveRDS(design, "./data/model_inputs/design.rds")

for (row in 1:nrow(design)) {
    info("Model %s", design[row, "id"])

    # Start off by setting the unit of analysis
    sub.df <- if (design[row, "episodes"] == "cumulative_intensity")
        filter(df, cumulative_intensity == 1)
    else
        df

    # Select control variables - this is mostly static across models
    X <- select(sub.df, episode_censored, episode_duration, recur, pko,
                cumulative_intensity,
                incompatibility, cold_war, ongoing_intrastate, ongoing_interstate)

    if (design[row, "episodes"] == "cumulative_intensity")
        X <- select(X, -cumulative_intensity)

    X <- mutate(X, episode_duration = scale(episode_duration),
                episode_duration2 = scale(episode_duration^2),
                episode_duration3 = scale(episode_duration^3)) |>
        select(everything(), episode_duration, episode_duration2, episode_duration3) |>
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

    f <- sprintf("./data/model_inputs/%s.RData", design[row, "id"])
    save(sub.df, cases, treatments, X, y, file = f)
}

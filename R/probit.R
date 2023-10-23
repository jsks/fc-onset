#!/usr/bin/env Rscript

library(cmdstanr)
library(dplyr)
library(fc)
library(yaml)

options(mc.cores = parallel::detectCores() - 1)

input <- commandArgs(trailingOnly = T)
schema_file <- if (length(input) == 0) "models/frozen-bin-all.yml" else input

stopifnot(file.exists(schema_file))

schema <- read_yaml(schema_file)
info("Running model: %s", schema$name)
sprintf("posteriors/%s", schema$name) |> dir.create(showWarnings = F, recursive = T)

df <- readRDS("./data/model_data.rds") |> ungroup()

###
# Set the Unit of analysis
if (schema$episodes == "high_intensity")
    df <- filter(df, cumulative_intensity == 1)

###
# Select control variables - currently this is static across all models
X <- select(df, censored, episode_duration, recur, max_intensity, incompatibility) |>
    mutate(episode_duration = log(episode_duration)) |>
    data.matrix()

cases <- rowSums(is.na(X)) == 0

###
# Select the treatment option
state_sup <- paste0("ext_sup_s_state_", schema$treatment)
rebel_sup <- paste0("ext_sup_s_rebel_", schema$treatment)

treatments <- select(df, {{ state_sup }}, {{ rebel_sup }}) |>
    mutate(interaction = .data[[{{ state_sup }}]] * .data[[{{ rebel_sup }}]]) |>
    data.matrix()

###
# Assemble model input
data <- list(n = sum(cases),
             k = ncol(treatments),
             T = treatments[cases, ],
             interaction_id = which(colnames(treatments) == "interaction"),
             m = ncol(X),
             X = X[cases, ],
             n_countries = n_distinct(df$gwno_a),
             country_id = as.factor(df$gwno_a[cases]) |> as.integer(),
             y = df$strict_frozen[cases])
str(data)

sprintf("posteriors/%s/model_input.RData", schema$name) |> save.image()

mod <- cmdstan_model("./stan/probit.stan")
fit <- mod$sample(data = data)

fit$summary("delta")

# Save, save, save!
sprintf("posteriors/%s/model_output.rds", schema$name) |>
    fit$save_object()

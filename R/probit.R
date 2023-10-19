#!/usr/bin/env Rscript

library(bayesplot)
library(cmdstanr)
library(dplyr)

options(mc.cores = parallel::detectCores() - 1)

df <- readRDS("./data/model_data.rds") |> ungroup()

X <- select(df, incompatibility, cold_war, duration, max_intensity) |>
    data.matrix()

cases <- rowSums(is.na(X)) == 0

treatments <- select(df, ext_sup_s_state_max_5y, ext_sup_s_rebel_max_5y) |>
    mutate(interaction = ext_sup_s_state_max_5y * ext_sup_s_rebel_max_5y) |>
    data.matrix()

data <- list(n = sum(cases),
             k = ncol(treatments),
             T = treatments[cases, ],
             m = ncol(X),
             X = X[cases, ],
             n_countries = n_distinct(df$gwno_a),
             country_id = as.factor(df$gwno_a[cases]) |> as.integer(),
             y = df$frozen[cases])
str(data)

mod <- cmdstan_model("./stan/probit.stan")
fit <- mod$sample(data = data)

fit$save_object("posteriors/probit.rds")

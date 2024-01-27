#!/usr/bin/env Rscript

library(cmdstanr)
library(dplyr)
library(fc.utils)
library(tools)

options(mc.cores = parallel::detectCores() - 1)

input <- commandArgs(trailingOnly = T)
default <- "data/models/data_001.RData"
model_data <- if (!exists("input") || length(input) == 0) default else input

stopifnot(file.exists(model_data))

load(model_data)
model_name <- basename(model_data) |> file_path_sans_ext()

info("Running model: %s", model_name)
sprintf("posteriors/%s", model_name) |> dir.create(showWarnings = F, recursive = T)

stan_data <- list(N = sum(cases),
                  K = ncol(treatments),
                  T = treatments[cases, ],
                  interaction_id = which(colnames(treatments) == "interaction"),
                  M = ncol(X),
                  X = X[cases, ],
                  n_countries = n_distinct(sub.df$gwno_a),
                  country_id = as.factor(sub.df$gwno_a[cases]) |> as.integer(),
                  n_contest_types = 2,
                  contest_id = sub.df$incompatibility[cases] + 1,
                  y = y[cases])
str(stan_data)

mod <- cmdstan_model("./stan/hierarchical_probit.stan")
fit <- mod$sample(data = stan_data, sig_figs = 3, adapt_delta = 0.99)

# Treatment coefficients
fit$summary("delta")

# Save, save, save!
sprintf("posteriors/%s/fit.rds", model_name) |>
    fit$save_object()

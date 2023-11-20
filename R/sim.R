#!/usr/bin/env Rscript
#
# Quick simulation script to check the implementation of the probit
# model. For a more robust (and computationally intensitive) check see
# sbc.R.
###

library(bayesplot)
library(cmdstanr)
library(dplyr)

options(mc.cores = parallel::detectCores() - 1)

n <- 300
k <- 3
m <- 2

n_countries <- 2
n_contest_types <- 2

stan_data <- list(n = n,
                  k = k,
                  m = m,
                  n_countries = n_countries,
                  n_contest_types = n_contest_types,
                  X = rnorm(n * m, 0, 3) |> matrix(nrow = n, ncol = m),
                  T = sample(0:1, n * k, replace = TRUE) |> matrix(nrow = n, ncol = k),
                  country_id = sample(1:n_countries, n, replace = TRUE),
                  contest_id = sample(1:n_contest_types, n, replace = TRUE))
str(stan_data)

###
# Simulate a fake dataset
sim <- cmdstan_model("./stan/sim.stan")
sim_data <- sim$sample(data = stan_data, fixed_param = TRUE, chains = 1, iter_sampling = 1)

stan_data$y <- as.vector(sim_data$draws("y_sim", format = "matrix"))
stan_data$interaction_id <- 1

###
# Fit our fake dataset and see if we can recover the true parameter
# values
mod <- cmdstan_model("./stan/probit.stan")
fit <- mod$sample(data = stan_data, adapt_delta = 0.99)

# Parameter plots
parameters <- c("alpha", "beta", "sigma", "gamma", "mu", "tau", "delta")
true_values <- as.vector(sim_data$draws(parameters, format = "matrix"))

fit$draws(parameters) |> mcmc_recover_intervals(true_values)

# Predicted probabilities
theta <- sim_data$draws("theta", format = "matrix")
theta_hat <- fit$draws("theta", format = "draws_matrix")
ppc_dens_overlay(as.vector(theta), theta_hat[1:100, ])

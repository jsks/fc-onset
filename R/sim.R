#!/usr/bin/env Rscript

library(bayesplot)
library(cmdstanr)
library(dplyr)
library(extraDistr)
library(MASS, include.only = "mvrnorm")

set.seed(43)

n <- 200
m <- 2
k <- 1

alpha <- rnorm(1, 0, 5)
beta <- rnorm(m, 0, 2.5)
delta <- rnorm(k, 0, 2.5)

X <- mvrnorm(n, rep(0, m), diag(rep(2, m), nrow = m, ncol = m))
treatment <- sapply(k, \(i) rbinom(n, 1, runif(1, max = 0.75)))

n_countries <- 4L
sigma <- rhcauchy(1, 1)
countries <- rep(rnorm(n_countries, 0, sigma), n / n_countries)

theta <- pnorm(alpha + X %*% beta + treatment %*% delta + countries) |> as.vector()
summary(theta)

y <- rbinom(n, 1, theta)
table(y)

data <- list(n = n,
             m = m,
             k = k,
             X = X,
             T = treatment,
             n_countries = n_countries,
             country_id = as.factor(countries) |> as.integer(),
             sample_prior = 1,
             y = y)
str(data)

mod <- cmdstan_model("./stan/probit.stan")

# Sample from prior
data <- list(n = n, m = m, k = k, X = X, T = treatment, n_countries = n_countries,
             country_id = rep(1, n), sample_prior = 1, y = rep(1, n))

fit <- mod$sample(data = data, chains = 1)



fit <- mod$sample(data = data, parallel_chains = 4, max_treedepth = 12, adapt_delta = 0.95)

# Parameter plots
fit$draws(c("alpha", "beta", "delta", "sigma")) |>
    mcmc_recover_intervals(c(alpha, beta, delta, sigma))

# Predicted probabilities
theta_hat <- fit$draws("theta", format = "draws_matrix")
ppc_dens_overlay(as.vector(theta), theta_hat[1:100, ])

#!/usr/bin/env Rscript
#
# Simulation Based Calibration for the probit model
###

library(cmdstanr)
library(dplyr)
library(MASS, include.only = "mvrnorm")
library(parallel)

options(mc.cores = parallel::detectCores() / 2)

rank_statistic <- function(draws, true_value) {
    sum(draws < true_value)
}

n <- 300
m <- 2
k <- 3

parameters <- c("alpha", "beta", "gamma", "sigma", "delta", "mu", "tau")

X <- mvrnorm(n, rep(0, m), diag(rep(2, m), nrow = m, ncol = m))

n_countries <- 3
country_id <- sample(1:n_countries, n, replace = T)

n_conflict_types <- 2
conflict_id <- sample(1:n_conflict_types, n, replace = T)

treatments <- sample(0:1, n*3, replace = T) |> matrix(nrow = n, ncol = 3)

data <- list(n = n,
             k = k,
             T = treatments,
             m = m,
             X = X,
             n_countries = n_countries,
             country_id = country_id,
             n_contest_types = n_conflict_types,
             contest_id = conflict_id)

sim <- cmdstan_model("./stan/sim.stan")
sim_data <- sim$sample(data = data, fixed_param = TRUE, chains = 1)

# Simulated parameter values
pv <- sim_data$draws(parameters, format = "data.frame")

# Simulated outcomes
y_sim <- sim_data$draws("y_sim", format = "matrix")

###
# For each simulated outcome, run the model and compute the rank
# statistic for each parameter between the posterior draws and the
# true (ie simulated) value
mod <- cmdstan_model("./stan/probit.stan")
ranks <- mclapply(1:nrow(y_sim), function(i) {
    stan_data <- data
    stan_data$y <- as.vector(y_sim[i, ])
    stan_data$interaction_id <- 1

    fit <- mod$sample(data = stan_data, iter_sampling = 500, chains = 2, parallel_chains = 2,
                      adapt_delta = 0.95, thin = 2, refresh = 0)
    mapply(rank_statistic, fit$draws(parameters, format = "data.frame"), pv[i, ])
})

df <- bind_rows(ranks)
saveRDS(df, "posteriors/sbc.rds")

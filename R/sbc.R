#!/usr/bin/env Rscript
#
# Simulation Based Calibration for the probit model
###

library(cmdstanr)
library(dplyr)
library(fc.utils)
library(MASS, include.only = "mvrnorm")
library(parallel)

options(mc.cores = parallel::detectCores() / 2)

iter <- 5000
n <- 248
m <- 8
k <- 3

info("Running simulation based calibration for %d iterations and %d threads",
     iter, parallel::detectCores())

parameters <- c("alpha", "beta", "gamma", "sigma", "delta", "mu", "tau")

X <- sample(0:1, n * m, replace = T) |> matrix(nrow = n, ncol = m)

n_countries <- 3
country_id <- sample(1:n_countries, n, replace = T)

n_conflict_types <- 2
conflict_id <- sample(1:n_conflict_types, n, replace = T)

treatments <- sample(0:1, n*2, replace = T) |> matrix(nrow = n, ncol = 2)
treatments <- cbind(treatments, treatments[, 1] * treatments[, 2])

data <- list(N = n,
             K = k,
             T = treatments,
             M = m,
             X = X,
             n_countries = n_countries,
             country_id = country_id,
             n_contest_types = n_conflict_types,
             contest_id = conflict_id)

sim <- cmdstan_model(exe_file = "stan/sim")
sim_data <- sim$sample(data = data, fixed_param = TRUE, chains = 1, iter_sampling = iter)

# Simulated parameter values
pv <- sim_data$draws(parameters, format = "data.frame")

# Simulated outcomes
y_sim <- sim_data$draws("y_sim", format = "matrix")

###
# For each simulated outcome, run the model and compute the rank
# statistic for each parameter between the posterior draws and the
# true (ie simulated) value
mod <- cmdstan_model(exe_file = "stan/hierarchical_probit")
ranks <- mclapply(1:nrow(y_sim), function(i) {
    stan_data <- data
    stan_data$y <- as.vector(y_sim[i, ])
    stan_data$interaction_id <- 1

    fit <- mod$sample(data = stan_data, chains = 2, iter_warmup = 1000,
                      iter_sampling = 1000, adapt_delta = 0.95, refresh = 0)

    diagnostics <- fit$diagnostic_summary()
    if (sum(diagnostics$num_divergent) > 0 | sum(diagnostics$num_max_treedepth) > 0) {
        warning("Divergent transitions or max treedepth exceeded")
        return(NULL)
    }

    mapply(rank_statistic, fit$draws(parameters, format = "data.frame"), pv[i, ])
})

df <- bind_rows(ranks)

dir.create("posteriors", showWarnings = F)
saveRDS(df, "posteriors/sbc.rds")

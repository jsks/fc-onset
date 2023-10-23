#!/usr/bin/env Rscript

library(dplyr)
library(fc)
library(yaml)

dir.create("models", showWarnings = F)

treatments <- c("bin", "bin_5y", "prop")
outcomes <- c("frozen", "strict_frozen")
units <- c("all", "high_intensity")

df <- expand.grid("outcome" = outcomes, "treatment" = treatments, "episodes" = units) |>
    mutate(name = paste0(outcome, "-", treatment, "-", episodes))

for (row in 1:nrow(df)) {
    info("Writing model profile %s", df[row, "name"])
    write_yaml(df[row, ], sprintf("./models/%s.yml", df[row, "name"]))
}

#!/usr/bin/env Rscript
#
# Create final version of the frozen conflict dataset
###

library(dplyr)
library(fc)

adj <- read.csv("./data/dataset/adjusted_conflict_candidates.csv") |>
    filter(Correction == 0) |>
    select(conflict_id, year, frozen)

episodes <- read.csv("./data/conflict_episodes.csv") |>
    select(conflict_id, conflictep_id, year, gwno_a, side_a, side_b, intensity_level,
           incompatibility, recur)

cy <- left_join(episodes, adj, by = c("conflict_id", "year")) |>
    mutate(frozen = ifelse(!is.na(frozen), 1, 0)) |>
    group_by(conflict_id) |>
    filter(year <= if (any(frozen == 1)) min(year[frozen == 1]) else max(year))

info("Final dataset has %d conflict episodes of which %d are frozen",
     n_distinct(cy$conflictep_id), sum(cy$frozen))

saveRDS(cy, "./data/dataset/frozen_conflicts.rds")

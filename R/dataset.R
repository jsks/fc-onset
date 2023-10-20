#!/usr/bin/env Rscript
#
# Create final version of the frozen conflict dataset
###

library(dplyr)
library(fc)
library(readxl)

adj <- read.csv("./data/dataset/adjusted_conflict_candidates.csv") |>
    filter(Correction == 0) |>
    select(conflict_id, year, frozen)

###
# Add cumulative intensity - threshold 1000 BRD
ucdp <- readRDS("./data/raw/UcdpPrioConflict_v23_1.rds") |>
    select(conflict_id, year, cumulative_intensity)

df <- left_join(adj, ucdp, by = c("conflict_id", "year"))

###
# Calculate duration until next active conflict episode
episodes <- read_excel("./data/raw/ucdp-term-acd-3-2021.xlsx") |>
    filter(type_of_conflict %in% 3:4) |>
    select(conflict_id, conflictep_id, year, side_a, side_b, recur)

full.df <- left_join(episodes, df, by = c("conflict_id", "year")) |>
    mutate(frozen = ifelse(!is.na(frozen), 1, 0)) |>
    group_by(conflict_id) |>
    arrange(year) |>
    mutate(duration = ifelse(frozen == 1, lead(year) - year, 0)) |>
    filter(frozen == 1)

info("Final dataset: %d frozen conflicts", nrow(full.df))

select(full.df, conflict_id, year, duration, cumulative_intensity,
       side_a, side_b, frozen, recur) |>
    saveRDS("./data/dataset/frozen_conflicts.rds")

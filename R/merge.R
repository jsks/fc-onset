#!/usr/bin/env Rscript

library(dplyr)
library(haven)
library(readxl)

# Termination dataset (1946 - 2020)
term <- read_xlsx("./data/ucdp-term-dyad-3-2021.xlsx") |>
    select(conflict_id, dyadep_id, dyadepisode, dyadcount, dyadterm, dyad_id, year,
           outcome, side_a, side_b, type_of_conflict, intensity_level) |>
    filter(year <= 2011)

# External Support Dataset - Dyad-year level (1975 - 2017)
# - Non-active dyad not included in dyadic - 11387 (Myanmar vs ULA)
esd <- read_dta("./data/ucdp-esd-dy-181.dta") |>
    filter(active == 1) |>
    select(year, active, conflict_id, dyad_id, gwno_a, gwno_b, matches("ext"))

df <- full_join(term, esd, by = c("conflict_id", "dyad_id", "year")) |>
    filter(year <= 2011, !is.na(dyadep_id))

# Frozen conflict dataset - 27 obs after filling in UCDP dyad_id
load("./data/FCD/fcd.RData")
fcd <- mutate(fcd,
              fc_onset = 1,
              conflictstart_y = ifelse(conflict_id == 18, 1992, conflictstart_y),
              dyad_id = case_when(conflict_id == 1 ~ 422,
                                  conflict_id %in% 2:5 ~ 454,
                                  conflict_id == 6 ~ 737,
                                  conflict_id == 7 ~ 560,
                                  conflict_id == 10 ~ 482,
                                  conflict_id == 13 ~ 569,
                                  conflict_id == 14 ~ 799,
                                  conflict_id == 16 ~ 706,
                                  conflict_id == 18 ~ 571,
                                  conflict_id == 22 ~ 462,
                                  conflict_id == 24 ~ 707,
                                  conflict_id == 26 ~ 835,
                                  conflict_id == 28 ~ 841,
                                  conflict_id == 29 ~ 852,
                                  conflict_id == 30 ~ 839,
                                  conflict_id == 31 ~ 840,
                                  conflict_id == 32 ~ 833,
                                  conflict_id == 33 ~ 721,
                                  conflict_id == 34 ~ 580,
                                  conflict_id == 36 ~ 477,
                                  conflict_id == 37 ~ 427,
                                  conflict_id == 38 ~ 461,
                                  conflict_id == 39 ~ 776,
                                  conflict_id == 40 ~ 656,
                                  conflict_id == 41 ~ 794,
                                  conflict_id == 42 ~ 720)) |>
    select(dyad_id, year = conflictstart_y, fc_onset, onset_war_above_1000) |>
    filter(!is.na(dyad_id)) |>
    group_by(dyad_id) |>
    summarise(onset_war_above_1000 = max(onset_war_above_1000),
              year = first(year),
              fc_onset = first(fc_onset))

# India - Pakistan 422 (UCDP starts 1948, fcd 1949)
full.df <- full_join(df, fcd, by = c("dyad_id", "year")) |>
    arrange(dyad_id, year) |>
    group_by(dyad_id) |>
    mutate(lagged_fc_onset = lead(fc_onset)) |>
    filter(!is.na(dyadep_id)) |>
    ungroup()

# Aggregation formulas for summarise, year -> dyad-level
weighted_average <- function(x, intensity, side_b) {
    v <- as.integer(intensity)[!is.na(x)]
    weighted.mean(x, v / sum(v), na.rm = T)
}

final.df <- group_by(full.df, dyadep_id, conflict_id, side_a, side_b) |>
    filter(all(!is.na(ext_sup))) |>
    summarise(lagged_fc_onset = max(lagged_fc_onset, na.rm = T),
              censored = min(year) < 1975,
              start_year = min(year),
              end_year = max(year),
              duration = n(),
              type_of_conflict = first(type_of_conflict),
              onset_war_above_1000 = max(onset_war_above_1000, na.rm = T),
              max_intensity = max(intensity_level, na.rm = T),
              intensity_avg = mean(intensity_level, na.rm = T),
              outcome = last(outcome),
              across(c(ext_sup, ext_x, ext_w, ext_m, ext_t, ext_f, ext_l),
                     ~weighted_average(.x, intensity_level),
                     .names = "{.col}_wavg"),
              across(c(ext_sup, ext_x, ext_w, ext_m, ext_t, ext_f, ext_l),
                     ~weighted_average(.x, cut(1:n(), seq(0, 100, by = 5))),
                     .names = "{.col}_davg"),
              across(c(ext_sup, ext_x, ext_w, ext_m, ext_t, ext_f, ext_l),
                     ~sum(.x, na.rm = T),
                     .names = "{.col}_count"),
              across(c(ext_sup, ext_x, ext_w, ext_m, ext_t, ext_f, ext_l),
                     ~max(.x, na.rm = T),
                     .names = "{.col}_bin")) |>
    filter(end_year >= 1975) |>
    mutate(lagged_fc_onset = ifelse(is.infinite(lagged_fc_onset), 0, lagged_fc_onset)) |>
    ungroup()

saveRDS(final.df, "data/merged_data.rds")

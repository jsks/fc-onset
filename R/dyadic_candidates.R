#!/usr/bin/env Rscript
#
# R script that identifies dyadic level conflict outcomes, which may
# be frozen conflicts.
###

library(dplyr)
library(fc.utils)
library(readxl)
library(tidyr)

###
# Raw data
#
# Peace Agreements at the dyadic level 1975 - 2021
pce <- read_xlsx("./data/raw/ucdp-peace-agreements-221.xlsx") |>
    select(paid, year, dyad_id, ended, pa_date, duration, cease, inclusive, pa_type, out_iss) |>
    separate_longer_delim(dyad_id, delim = ",") |>
    mutate(dyad_id = as.numeric(dyad_id),
           year = as.numeric(year),
           end_date = as.Date(duration),
           pa_date = as.Date(pa_date),
           duration = end_date - pa_date) |>
    filter(pa_type == 1, is.na(duration) | end_date > as.Date(paste0(year + 1, "-12-31")))

pce_collapsed <- group_by(pce, dyad_id, year) |>
    arrange(pa_date) |>
    slice(n())

# Conflict Terminations at the dyadic level 1948 - 2019
term <- read_xlsx("./data/raw/ucdp-term-dyad-3-2021.xlsx") |>
    filter(type_of_conflict %in% 3:4) |>
    select(conflict_id, dyad_id, dyadepisode, year, side_a, side_b, outcome, intensity_level)

full.df <- filter(pce_collapsed, dyad_id %in% term$dyad_id) |>
    full_join(term, by = c("dyad_id", "year")) |>
    filter(between(year, 1975, 2019))

info("Finished with %d dyadic terminations", sum(!is.na(full.df$outcome)))

write.csv(full.df, "./data/dyadic_episodes.csv", row.names = F)

###
# Filter out candidates for being frozen conflicts
outcomes <- group_by(full.df, dyad_id) |>
    arrange(year) |>
    mutate(idx = consecutive(year)) |>
    group_by(idx, .add = T) |>
    mutate(pax = !is.na(paid),
           next_pax = lead(pax, default = F)) |>
    filter(!is.na(outcome) & !outcome %in% c(3, 4, 6), !pax, !next_pax)

final <- group_by(outcomes, dyad_id) |>
    filter(year == min(year)) |>
    mutate(frozen = 1)

info("Found %d candidate outcomes, ~%.2f%% of all terminations", nrow(final),
     100 * nrow(final) / sum(!is.na(full.df$outcome)))

select(final, conflict_id, dyad_id, year, side_a, side_b, outcome, frozen) |>
    write.csv("./data/dyadic_candidates.csv", row.names = F)

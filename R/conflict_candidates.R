#!/usr/bin/env Rscript

library(dplyr)
library(fc)
library(haven)
library(readxl)
library(tidyr)

###
# Raw Data
#
# Peace Agreements 1975 - 2021
#  pa_type == 1 Full peace agreement
#  inclusive == 1 Comprehensive peace agreement
pce <- read_xlsx("./data/raw/ucdp-peace-agreements-221.xlsx") |>
    select(paid, year, conflict_id, ended, pa_date, duration, cease, inclusive, pa_type, out_iss) |>
    separate_longer_delim(conflict_id, delim = ",") |>
    mutate(conflict_id = as.numeric(conflict_id),
           year = as.numeric(year),
           end_date = as.Date(duration),
           pa_date = as.Date(pa_date),
           duration = end_date - pa_date) |>
    filter(inclusive == 1, pa_type == 1,
           is.na(duration) | end_date > as.Date(paste0(year + 1, "-12-31")))

pce_collapsed <- group_by(pce, conflict_id, year) |>
    arrange(pa_date) |>
    slice(n())

# Conflict Termination Dataset 1948 - 2019
term <- read_excel("./data/raw/ucdp-term-acd-3-2021.xlsx") |>
    filter(type_of_conflict %in% 3:4) |>
    select(conflict_id, conflictep_id, year, gwno_a = gwno_loc, side_a, side_b,
           outcome, intensity_level, incompatibility, recur)

###
# Join all datasets and select civil conflicts between 1975 & 2017
full.df <- filter(pce_collapsed, conflict_id %in% term$conflict_id) |>
    full_join(term, by = c("conflict_id", "year")) |>
    filter(between(year, 1975, 2019))

info("Finished with %d conflict terminations", sum(!is.na(full.df$outcome)))

###
# Filter out candidates for being frozen conflicts
outcomes <- group_by(full.df, conflict_id) |>
    arrange(year) |>
    mutate(idx = consecutive(year)) |>
    group_by(idx, .add = T) |>
    mutate(pax = !is.na(paid),
           next_pax = lead(pax, default = F)) |>
    filter(!is.na(outcome) & !outcome %in% c(3, 4, 6), !pax, !next_pax)

final <- group_by(outcomes, conflict_id) |>
    filter(year == min(year)) |>
    mutate(frozen = 1)

info("Found %d candidate outcomes, ~%.2f%% of all terminations", nrow(final),
     100 * nrow(final) / sum(!is.na(full.df$outcome)))

select(final, conflict_id, year, side_a, side_b, outcome, frozen) |>
    write.csv("./data/conflict_candidates.csv", row.names = F)

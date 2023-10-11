#!/usr/bin/env Rscript

library(dplyr)
library(haven)
library(readxl)
library(tidyr)

printf <- function(...) sprintf(...) |> print()

consecutive <- function(x) {
    if (anyNA(x))
        warning("NA's in given vector")

    cumsum(c(T, diff(x) != 1))
}

###
# Raw Data
#
# Peace Agreements 1975 - 2021
pce <- read_xlsx("./data/raw/ucdp-peace-agreements-221.xlsx") |>
    select(conflict_id, paid, year, ended, duration, cease, inclusive, pa_type) |>
    separate_longer_delim(conflict_id, delim = ",") |>
    mutate(conflict_id = as.numeric(conflict_id),
           year = as.numeric(year)) |>
    group_by(conflict_id, year) |>
    summarise(paid = paste0(paid, collapse = ","),
              cease = max(cease),
              inclusive = min(inclusive),
              pa_type = min(pa_type))

# Conflict Termination Dataset 1948 - 2019
term <- read_excel("./data/raw/ucdp-term-acd-3-2021.xlsx") |>
    select(conflict_id, conflictep_id, year, side_a, side_b,
           confterm, outcome, intensity_level, incompatibility, type_of_conflict) |>
    filter(type_of_conflict %in% 3:4)

# External Support 1975 - 2017
esd <- read_dta("./data/raw/ucdp-esd-dy-181.dta") |>
    filter(active == 1) |>
    group_by(conflict_id, year) |>
    summarise(ext_sup = max(ext_sup),
              ext_f = max(ext_f),
              ext_m = max(ext_m))

###
# Join all datasets and select civil conflicts between 1975 & 2017
full.df <- filter(pce, conflict_id %in% term$conflict_id) |>
    full_join(term, by = c("conflict_id", "year")) |>
    left_join(esd, by = c("conflict_id", "year")) |>
    filter(year >= 1975, year <= 2019)

# Find comprehensive peace agreements signed by *all* conflict actors
df <- group_by(full.df, conflict_id) |>
    arrange(year) |>
    mutate(idx = consecutive(year)) |>
    group_by(idx, .add = T) |>
    mutate(pax = !is.na(paid) & pa_type == 1 & inclusive == 1,
           next_pax = lead(pax, default = F)) |>
    ungroup()

# Frozen Conflict Terminations
outcomes <- filter(df, confterm == 1, side_b != "IS", !outcome %in% c(3, 4, 6),
                   !pax, !next_pax) |>
    group_by(conflict_id, conflictep_id) |>
    filter(year == min(year)) |>
    ungroup() |>
    select(conflict_id, year) |>
    mutate(frozen = 1)

# Full dataset
final <- left_join(df, outcomes, by = c("conflict_id", "year")) |>
    mutate(frozen = ifelse(is.na(frozen), 0, frozen)) |>
    group_by(conflict_id) |>
    filter(!is.na(conflictep_id),
           year <= if (any(frozen == 1)) min(year[frozen == 1]) else max(year))

printf("Found %d frozen conflicts out of %d terminations",
       sum(final$frozen), sum(!is.na(final$outcome)))

filter(final, frozen == 1, year <= 2017, !is.na(ext_sup)) |>
    write.csv("./data/conflict_level_candidates.csv", row.names = F)

###
# Collapse conflict-year panel data
#collapsed.df <- filter(final, conflict_id != 14129) |>
#    group_by(conflict_id) |>
#    summarise(frozen = last(frozen),
#              side_a = last(side_a),
#              side_b = last(side_b),
#              duration = n(),
#              ext_sup = max(ext_sup, na.rm = T),
#              ext_f = max(ext_f, na.rm = T),
#              ext_m = max(ext_m, na.rm = T))

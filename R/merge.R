#!/usr/bin/env Rscript

library(dplyr)
library(fc)
library(haven)
library(readxl)
library(tidyr)

###
# Construct first our full frozen + non-frozen episodes dataset
frozen <- readRDS("./data/raw/frozen_conflicts.rds") |>
    select(conflict_id, year, duration, frozen)

term <- read_excel("./data/raw/ucdp-term-acd-3-2021.xlsx") |>
    filter(type_of_conflict %in% 3:4) |>
    select(conflict_id, conflictep_id, year, gwno_a = gwno_loc, side_a, side_b,
           intensity_level, incompatibility, recur) |>
    group_by(conflictep_id) |>
    mutate(censored = ifelse(min(year) < 1975, 1, 0),
           gwno_a = as.numeric(gwno_a)) |>
    ungroup()

ucdp <- readRDS("./data/raw/UcdpPrioConflict_v23_1.rds") |>
    select(conflict_id, year, cumulative_intensity)

ep <- filter(term, between(year, 1975, 2019)) |>
    full_join(frozen, by = c("conflict_id", "year")) |>
    left_join(ucdp, by = c("conflict_id", "year")) |>
    mutate(frozen = ifelse(is.na(frozen), 0, 1))

# Exclude subsequent episodes after onset of a frozen conflict
reduced <- group_by(ep, conflict_id) |>
    filter(year <= if (any(frozen == 1)) min(year[frozen == 1]) else max(year))

###
# UCDP External support dataset - actor-year level
esd <- read_dta("./data/raw/ucdp-esd-ay-181.dta") |>
    filter(active == 1) |>
    select(conflict_id, year, actor_nonstate, matches("^ext_(sup|.{1})_s")) |>
    group_by(conflict_id, actor_nonstate, year) |>
    summarise(across(starts_with("ext_"), max)) |>
    ungroup()

rebel_sup <- filter(esd, actor_nonstate == 1) |>
    select(-actor_nonstate)

state_sup <- filter(esd, actor_nonstate == 0) |>
    select(-actor_nonstate)

full_ep.df <- full_join(rebel_sup, state_sup, by = c("conflict_id", "year"),
                    suffix = c("_rebel", "_state")) |>
    right_join(reduced, by = c("conflict_id", "year"))

###
# NMC - CINC data
nmc <- read.csv("./data/raw/NMC-60-abridged.csv")

###
# V-Dem - dem., gdppc, population
vdem <- readRDS("./data/raw/V-Dem-CY-Full+Others-v13.rds") |>
    select(country_name, COWcode, year, v2x_polyarchy, e_gdppc, e_pop) |>
    filter(!country_name %in% c("Hong Kong", "Palestine/British Mandate",
                                "Palestine/Gaza", "Palestine/West Bank",
                                "Sao Tome and Principe", "Seychelles",
                                "Somaliland", "Vanuatu", "Zanzibar")) |>
    mutate(gwid = case_when(country_name == "Germany" ~ 260,
                            country_name == "German Democratic Republic" ~ 265,
                            country_name == "Yemen" ~ 678,
                            country_name == "Serbia" & year >= 2006 ~ 340,
                            country_name == "South Korea" ~ 732,
                            T ~ COWcode)) |>
    group_by(country_name) |>
    fill(gwid, .direction = "up") |>
    ungroup()

ctable <- read.csv2("refs/ucdp_countries.csv") |>
    select(country_name, gwid = code, start_year = start, end_year = end) |>
    mutate(end_year = ifelse(is.na(end_year), 2020, end_year))

vdem <- select(ctable, -country_name) |>
    right_join(vdem, by = "gwid")

full.df <- left_join(full_ep.df, vdem, by = c("gwno_a" = "gwid", "year")) |>
    left_join(nmc, by = c("year", "COWcode" = "ccode"))

info("Missing V-Dem observation(s): %d", is.na(full.df$v2x_polyarchy) |> sum())
info("Missing CINC observation(s): %d", is.na(full.df$cinc) |> sum())

###
# Collapse into an episode level dataset
final.df <- filter(full.df, !is.na(ext_sup_s_state)) |>
    group_by(gwno_a, conflict_id, conflictep_id) |>
    arrange(year) |>
    summarise(.groups = "drop",
              frozen = max(frozen),
              year = last(year),
              side_a = first(side_a),
              side_b = first(side_b),
              censored = max(censored),
              episode_duration = n(),
              frozen_duration = last(duration),
              recur = max(recur),
              incompatibility = max(incompatibility == 1),
              cold_war = ifelse(max(year) > 1991, 0, 1),
              cumulative_intensity = max(cumulative_intensity),
              max_intensity = max(intensity_level, na.rm = T),
              avg_intensity = mean(intensity_level, na.rm = T),
              wavg_intensity = weighted.mean(intensity_level, 1:n(), na.rm = T),

              across(c(v2x_polyarchy, e_gdppc, e_pop, cinc), ~mean(.x, na.rm = T), .names = "{.col}_avg"),

              # At anytime during the episode was external support given?
              across(starts_with("ext_"), ~max(.x, na.rm = T), .names = "{.col}_bin"),

              # Proportion of conflict years within an episode with external support
              across(starts_with("ext_"), ~mean(.x, na.rm = T), .names = "{.col}_prop"),

              # Whether external support was given in the last five years before termination
              across(starts_with("ext_"), ~max(tail(.x, 5), na.rm = T), .names = "{.col}_bin_5y")) |>
    mutate(strict_frozen = ifelse(is.na(frozen_duration) | frozen_duration > 2, frozen, 0))

info("Finished with %d conflict episodes and %d frozen conflicts",
     nrow(final.df), sum(final.df$frozen))
info("%d frozen conflicts lasted more than 2 years", sum(final.df$strict_frozen))

high_intensity <- filter(final.df, cumulative_intensity == 1)
info("%d high intensity episodes, with %d frozen onsets and %d >2 onsets",
     nrow(high_intensity),
     sum(high_intensity$frozen),
     sum(high_intensity$strict_frozen))

saveRDS(final.df, "./data/model_data.rds")

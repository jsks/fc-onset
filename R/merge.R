#!/usr/bin/env Rscript

library(dplyr)
library(fc)
library(haven)
library(tidyr)

# Full frozen conflict dataset
ep <- readRDS("./data/dataset/frozen_conflicts.rds")

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
    right_join(ep, by = c("conflict_id", "year"))

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
    summarise(frozen = max(frozen),
              year = last(year),
              side_a = first(side_a),
              side_b = first(side_b),
              duration = n(),
              incompatibility = max(incompatibility == 1),
              cold_war = ifelse(max(year) > 1991, 0, 1),
              max_intensity = max(intensity_level, na.rm = T),
              avg_intensity = mean(intensity_level, na.rm = T),
              wavg_intensity = weighted.mean(intensity_level, 1:n(), na.rm = T),

              across(c(v2x_polyarchy, e_gdppc, e_pop, cinc), ~mean(.x, na.rm = T), .names = "{.col}_avg"),

              # At anytime during the episode was external support given?
              across(starts_with("ext_"), ~max(.x, na.rm = T), .names = "{.col}_max"),

              # Proportion of conflict years within an episode with external support
              across(starts_with("ext_"), ~mean(.x, na.rm = T), .names = "{.col}_prop"),

              # Whether external support was given in the last five years before termination
              across(starts_with("ext_"), ~max(tail(.x, 5), na.rm = T), .names = "{.col}_max_5y")) |>
    ungroup()

saveRDS(final.df, "./data/model_data.rds")

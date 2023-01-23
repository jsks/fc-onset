#!/usr/bin/env Rscript

library(dplyr)
library(haven)
library(readxl)
library(tidyr)

printf <- function(...) sprintf(...) |> print()

# Aggregation formulas for summarise, year -> dyad-level
weighted_average <- function(x, intensity, side_b) {
    v <- as.integer(intensity)[!is.na(x)]
    weighted.mean(x, v / sum(v), na.rm = T)
}

# Termination dataset (1946 - 2020)
term <- read_excel("./data/ucdp-term-dyad-3-2021.xlsx") |>
    select(conflict_id, dyadep_id, dyadepisode, dyadcount, dyadterm, dyad_id, year,
           outcome, side_a, side_a_id, side_b, side_b_id, type_of_conflict, intensity_level) |>
    group_by(dyad_id, dyadepisode) |>
    filter(max(year) >= 1975, min(year) <= 2011)

# External Support Dataset - Dyad-year level (1975 - 2017)
# - Non-active dyad not included in dyadic - 11387 (Myanmar vs ULA)
esd <- read_dta("./data/ucdp-esd-dy-181.dta") |>
    filter(active == 1) |>
    select(year, active, conflict_id, dyad_id, gwno_a, gwno_b, matches("ext"))

df <- full_join(term, esd, by = c("conflict_id", "dyad_id", "year")) |>
    filter(year <= 2011, !is.na(dyadep_id)) |>
    group_by(dyad_id, dyadepisode) |>
    fill(gwno_a, .direction = "updown") |>
    ungroup() |>
    filter(!is.na(gwno_a))

printf("%d dyadic episode years from %d unique dyads", nrow(df), n_distinct(df$dyad_id))

# Frozen conflict dataset - 27 obs after filling in UCDP dyad_id
load("./data/FCD/fcd.RData", envir = e <- new.env())
refs <- read.csv("./refs/ucdp_fcd.csv")

fcd <- left_join(e$fcd, refs, by = "conflict_id") |>
    mutate(fc_onset = 1,
           conflictstart_y = ifelse(conflict_id == 18, 1992, conflictstart_y)) |>
    select(dyad_id, year = conflictstart_y, fc_onset) |>
    filter(!is.na(dyad_id)) |>
    group_by(dyad_id) |>
    summarise(year = first(year),
              fc_onset = first(fc_onset))

episodes.df <- full_join(df, fcd, by = c("dyad_id", "year")) |>
    arrange(dyad_id, year) |>
    group_by(dyad_id) |>
    mutate(lagged_fc_onset = lead(fc_onset)) |>
    filter(!is.na(dyadep_id)) |>
    ungroup()

printf("%d frozen conflicts after merging", sum(episodes.df$lagged_fc_onset, na.rm = T))

###
# NMC - CINC data
nmc <- read.csv("./data/NMC-60-abridged.csv")

###
# V-Dem - dem., gdppc, population
vdem <- readRDS("./data/Country_Year_V-Dem_Full+others_R_v12/V-Dem-CY-Full+Others-v12.rds") |>
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

full_dy.df <- left_join(episodes.df, vdem, by = c("gwno_a" = "gwid", "year")) |>
    left_join(nmc, by = c("year", "COWcode" = "ccode"))

printf("Missing V-Dem observation(s): %d", is.na(full_dy.df$v2x_polyarchy) |> sum())
printf("Missing CINC observation(s): %d", is.na(full_dy.df$cinc) |> sum())

###
# Combined inter/intrastate aggregated dataset
final.df <- group_by(full_dy.df, conflict_id, dyad_id, dyadep_id) |>
    filter(all(!is.na(ext_sup))) |>
    summarise(lagged_fc_onset = max(lagged_fc_onset, na.rm = T),
              censored = min(year) < 1975,
              start_year = min(year),
              end_year = max(year),
              duration = n(),
              type_of_conflict = first(type_of_conflict),
              max_intensity = max(intensity_level, na.rm = T),
              intensity_avg = mean(intensity_level, na.rm = T),
              outcome = last(outcome),
              v2x_polyarchy_range = last(v2x_polyarchy) - first(v2x_polyarchy),
              across(c(v2x_polyarchy, e_gdppc, e_pop, cinc), ~mean(.x, na.rm = T), .names = "{.col}_avg"),
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

filter(final.df, type_of_conflict %in% 3:4) |>
    saveRDS("data/intrastate_merged.rds")

saveRDS(final.df, "data/merged_data.rds")

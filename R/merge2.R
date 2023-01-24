#!/usr/bin/env Rscript

library(dplyr)
library(haven)
library(readxl)
library(tidyr)

# Aggregation formulas for summarise, year -> dyad-level
weighted_average <- function(x, intensity) {
    v <- as.integer(intensity)[!is.na(x)]
    weighted.mean(x[!is.na(x)], v / sum(v))
}


# Termination dataset (1946 - 2020)
term <- read_excel("./data/ucdp-term-dyad-3-2021.xlsx") |>
    select(conflict_id, dyadep_id, dyadepisode, dyadcount, dyadterm, dyad_id,
           year, outcome, side_a, side_a_id, side_b, side_b_id, type_of_conflict,
           intensity_level, incompatibility) |>
    group_by(dyad_id, dyadepisode) |>
    filter(max(year) >= 1975, min(year) <= 2016)

# External Support Dataset - Dyad-year level (1975 - 2017)
esd <- read_dta("./data/ucdp-esd-dy-181.dta") |>
    filter(active == 1) |>
    select(year, conflict_id, civil, dyad_id, gwno_a, gwno_b, matches("ext"))

# Term + ESD - includes conflict episodes starting before 1975, but
# ending within our merge window
df <- full_join(term, esd, by = c("conflict_id", "dyad_id", "year")) |>
    filter(!is.na(dyadep_id), type_of_conflict %in% 3:4, incompatibility %in% c(1, 3)) |>
    mutate(dyadep_id =
               case_when(conflict_id %in% c(13604, 13042, 372, 13246, 13247) ~ "1",
                         T ~ dyadep_id))


sprintf("%d dyadic conflict years from %d unique dyads",
        nrow(df), n_distinct(df$dyad_id))

###
# NMC - CINC data
nmc <- read.csv("./data/NMC-60-abridged.csv")

###
# V-Dem - dem., gdppc, population
vdem <- readRDS("./data/V-Dem-CY-Full+Others-v13.rds") |>
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
                            T ~ COWcode),
           le_gdppc = log(e_gdppc)) |>
    group_by(country_name) |>
    fill(gwid, .direction = "up") |>
    ungroup()

ctable <- read.csv2("refs/ucdp_countries.csv") |>
    select(country_name, gwid = code, start_year = start, end_year = end) |>
    mutate(end_year = ifelse(is.na(end_year), 2020, end_year))

vdem <- select(ctable, -country_name) |>
    right_join(vdem, by = "gwid", multiple = "all")

dy <- left_join(df, vdem, by = c("gwno_a" = "gwid", "year")) |>
    left_join(nmc, by = c("year", "COWcode" = "ccode"))

episodes.df <- group_by(dy, conflict_id, dyad_id, dyadep_id) |>
    arrange(year) |>
    filter(max(year) < 2017, any(!is.na(ext_sup))) |>
    summarise(side_a = first(side_a),
              side_b = first(side_b),
              censored = min(year) < 1975,
              start_year = min(year),
              stop_year = max(year),
              duration = max(year) - min(year),
              max_intensity = max(intensity_level, na.rm = T),
              intensity_avg = mean(intensity_level, na.rm = T),
              outcome = last(outcome),
              across(c(v2x_polyarchy, le_gdppc, e_pop, cinc),
                     ~mean(.x, na.rm = T), .names = "{.col}_avg"),
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
    ungroup()

sprintf("Finished with %d dyadic conflict episodes", nrow(episodes.df))

###
# Florea De Facto States (1949 - 2016)
#dfs <- read_xlsx("./data/EJIR 2020 Florea_dfs_dataset_April_2020.xlsx", sheet = 3)

dfs <- read.csv("./data/de_facto.csv") |>
    mutate(dyadep_id = as.character(dyadep_id))

full.df <- left_join(episodes.df, dfs, by = c("conflict_id", "dyad_id", "dyadep_id")) |>
    mutate(birth = !is.na(dfsonset) & (is.na(death) | death > stop_year))

sprintf("Successful de facto states: %d", sum(full.df$birth))

saveRDS(full.df, "./data/merged_de_facto.rds")

#!/usr/bin/env Rscript

library(dplyr)
library(readxl)

ucdp <- read_xlsx("./data/Dyadic_v23_1.xlsx")
term <- read_xlsx("./data/ucdp-term-acd-3-2021.xlsx")

filter(ucdp, gwno_a == 850) |>
    select(conflict_id, dyad_id, year, side_a, side_b, gwno_a, gwno_b) |>
    View()

x <- filter(term, type_of_conflict %in% 3:4)

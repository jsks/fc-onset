#!/usr/bin/env Rscript

library(dplyr)
library(ggplot2)
library(ggthemes)
library(readxl)

theme_set(theme_tufte())

df <- read_xlsx("./data/EJIR 2020 Florea_dfs_dataset_April_2020.xlsx", sheet = 3) |>
    mutate(typeonset = case_when(typeonset == 1 ~ "Post-war outcome",
                                 typeonset == 2 ~ "Internal Contention",
                                 typeonset == 3 ~ "State collapse",
                                 typeonset == 4 ~ "Decolonisation") |> as.factor(),
           eventtype = case_when(eventtype == 0 ~ "Alive",
                                 eventtype == 1 ~ "Forced reintegration",
                                 eventtype == 2 ~ "Peaceful reintegration",
                                 eventtype == 3 ~ "Statehood") |> as.factor())


counts.df <- group_by(df, dfsname) |>
    summarise(year = first(year),
              typeonset = first(typeonset)) |>
    count(year, typeonset)

# Onset types
pdf("onsettypes.pdf")
ggplot(counts.df, aes(year, n, fill = typeonset)) +
    geom_bar(position = "stack", stat = "identity") +
    ylab("Count") +
    ylab("Year")
dev.off()

# Number of surviving de facto states
pdf("alive_counts.pdf")
counts.df <- count(df, year, typeonset)
 ggplot(counts.df, aes(year, n, fill = typeonset)) +
    geom_bar(position = "stack", stat = "identity") +
    ylab("Count") +
    ylab("Year")
dev.off()

# Deaths over time
pdf("deaths_ts.pdf")
counts.df <- filter(df, eventtype != "Alive") |>
    count(year, eventtype)
 ggplot(counts.df, aes(year, n, fill = eventtype)) +
    geom_bar(position = "stack", stat = "identity") +
    ylab("Count") +
    ylab("Year")
dev.off()


# De facto states per country
counts.df <- count(df, parent)

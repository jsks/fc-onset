#!/usr/bin/env Rscript

library(caTools)
library(dplyr)
library(haven)
library(readxl)
library(sjPlot)

df <- readRDS("./data/merged_data.rds")

###
# Descriptive stats
table(df$lagged_fc_onset)

# How many observations post-Cold War
filter(df, end_year >= 1991) |> nrow()
filter(df, lagged_fc_onset == 1, end_year >= 1991) |> nrow()
filter(df, lagged_fc_onset == 1, censored) |> nrow()

# How many interstate vs intrastate
filter(df, !type_of_conflict %in% 3:4) |> nrow()




###
# Analysis - Basic logistic models
ml <- glm(lagged_fc_onset ~ ext_f_wavg + factor(type_of_conflict) +
              max_intensity, data = df, family = binomial)
summary(ml)

p <- predict(ml, type = "response")
summary(p[df$lagged_fc_onset == 1])
table(df$lagged_fc_onset, p >= 0.25)

colAUC(p, df$lagged_fc_onset, plotROC = T)

###
# Intra-state conflicts
sub.df <- filter(df, type_of_conflict %in% 3:4)

ml <- glm(lagged_fc_onset ~ ext_x_bin  + max_intensity,
          data = sub.df, family= binomial)
summary(ml)

p <- predict(ml, type = "response")
summary(p)
table(sub.df$lagged_fc_onset, predict(ml, type = "response") >= 0.25)

colAUC(p, sub.df$lagged_fc_onset, plotROC = T)

#!/usr/bin/env Rscript

library(caTools)
library(dplyr)
library(ggplot2)

df <- readRDS("./data/intrastate_merged.rds")

ml <- glm(lagged_fc_onset ~ ext_f_wavg + max_intensity + v2x_polyarchy_avg + v2x_polyarchy_range +
              e_gdppc_avg + e_pop_avg + cinc_avg, data = df, family = binomial)



vars <- c("ext_sup_bin", "ext_x_bin", "ext_w_bin", "ext_m_bin",
          "ext_t_bin", "ext_f_bin", "ext_l_bin")

fits <- lapply(vars, function(v) {
    fml <- sprintf("lagged_fc_onset ~ %s + max_intensity + v2x_polyarchy_avg + e_gdppc_avg + e_pop_avg + cinc_avg", v) |>
        formula()

    ml <- glm(fml, data = df, family = "binomial")
    ci <- confint(ml)[2,]

    data.frame(var = v, point = coef(ml)[2], lower = ci[1], upper= ci[2])
}) |> bind_rows()

plot.df <- mutate(fits, var = case_when(var == "ext_sup_bin" ~ "Aggregate Support",
                            var == "ext_x_bin" ~ "Military Support",
                                        var == "ext_w_bin" ~ "Weapons",
                                        var == "ext_m_bin" ~ "Material/Logistics",
                                        var == "ext_t_bin" ~ "Training/Expertise",
                                        var == "ext_f_bin" ~ "Funding",
                                        var == "ext_l_bin" ~ "Access to Territory"))

ggplot(plot.df, aes(point, var)) +
    geom_point() +
    geom_errorbarh(aes(xmin = lower, xmax = upper), height = 0) +
    geom_vline(xintercept = 0, linetype = "dotted") +
    xlab("Estimate + 95% CI") +
    theme(axis.title.y = element_blank())

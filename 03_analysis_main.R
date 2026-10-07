# ============================================================================
# 03_analysis_main.R — event study, city trends, IV, placebo, mortality split
# Source config.R first. Depends: data.table, fixest. Input: city_panel.rds
# ============================================================================
library(data.table); library(fixest)
source("config.R")
panel <- as.data.table(readRDS(file.path(BASE_DIR, "city_panel.rds")))
panel[, year := as.integer(year)]

# Gate the main analysis to the core design years. Recovery editions (2022-2024)
# fall under the Novo Ensino Medio reform, which breaks score comparability, so
# they must not leak into the headline estimates.
panel <- panel[year %in% BALANCE_YEARS]

## 1. Event study (continuous treatment, 2019 reference) --------------------
es <- feols(score_math ~ i(year, internet_2017, ref = 2019) | muni_code + year,
es <- feols(score_math ~ i(year, internet_2017, ref = 2019) | muni_code + year,
            data = panel, weights = ~n_students, cluster = ~muni_code)
cat("\n== Event study (incl. 2022-2024 recovery years if present) ==\n"); print(summary(es))

## 2. City-specific linear trends: recover the 2021 effect by projection -----
# (a direct muni_code[year] term is collinear with 4 periods; instead fit each
#  municipality's 2017-2019 trend and read off the 2021 residual)
pre <- panel[year <= 2019]
tr  <- pre[, {m <- lm(score_math ~ year); .(a = coef(m)[1], b = coef(m)[2])}, by = muni_code]
p21 <- merge(panel[year == 2021, .(muni_code, score_math, internet_2017, n_students)],
             tr, by = "muni_code")
p21[, resid_2021 := score_math - (a + b * 2021)]
ct <- feols(resid_2021 ~ internet_2017, data = p21, weights = ~n_students, cluster = ~muni_code)
cat("\n== City-trend-adjusted 2021 effect ==\n"); print(summary(ct))

## 3. IV: instrument the post x access interaction with post x excess mortality
panel[, post      := as.integer(year == 2021)]
panel[, excess_z  := as.numeric(scale(excess_rate))]
panel[, post_int  := post * internet_2017]
panel[, post_mort := post * excess_z]
iv <- feols(score_math ~ 1 | muni_code + year | post_int ~ post_mort,
            data = panel[!is.na(excess_z)], weights = ~n_students, cluster = ~muni_code)
cat("\n== IV (excess-mortality instrument) ==\n"); print(summary(iv))
cat("First-stage F:\n"); print(fitstat(iv, "ivwald"))

## 4. Placebo: false 2018 treatment on the 2017-2019 sample ------------------
pl <- feols(score_math ~ i(year, internet_2017, ref = 2017) | muni_code + year,
            data = panel[year <= 2019], weights = ~n_students, cluster = ~muni_code)
cat("\n== Placebo (look at year::2018) ==\n"); print(summary(pl))

## 5. Mortality split: event study by above/below median excess mortality ----
panel[, mort_high := as.integer(excess_rate >= median(excess_rate, na.rm = TRUE))]
es_hi <- feols(score_math ~ i(year, internet_2017, ref = 2019) | muni_code + year,
               data = panel[mort_high == 1], weights = ~n_students, cluster = ~muni_code)
es_lo <- feols(score_math ~ i(year, internet_2017, ref = 2019) | muni_code + year,
               data = panel[mort_high == 0], weights = ~n_students, cluster = ~muni_code)
cat("\n== Mortality split (compare year::2021) ==\n")
print(etable(es_hi, es_lo, headers = c("High mortality", "Low mortality"),
             keep = "2021"))

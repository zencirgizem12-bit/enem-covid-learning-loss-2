# ============================================================================
# 02_build_panel.R
# Combines processed/muni_<yr>.rds into a balanced municipality pseudo-panel
# (>= MIN_STUDENTS test-takers in EVERY year), merges SIM excess mortality,
# and builds the treatment variables. Writes city_panel.rds.
#
# Source config.R first.  Depends: data.table
# ============================================================================
library(data.table)
source("config.R")

files <- file.path(PROC_DIR, sprintf("muni_%d.rds", YEARS))
files <- files[file.exists(files)]
panel <- rbindlist(lapply(files, readRDS), fill = TRUE)

# ---- balanced panel: keep municipalities meeting the threshold in every CORE
#      (BALANCE_YEARS) edition. Post-pandemic recovery years (2022-2024) are kept
#      wherever available but are not required, so they never shrink the sample.
ok <- panel[n_students >= MIN_STUDENTS & year %in% BALANCE_YEARS,
            .(nyr = uniqueN(year)), by = muni_code][nyr == length(BALANCE_YEARS), muni_code]
panel <- panel[muni_code %in% ok]
setorder(panel, muni_code, year)

# ---- treatment: pre-determined 2017 full-remote share ----
t0 <- panel[year == min(BALANCE_YEARS), .(muni_code, base_full_remote = pct_full_remote)]
t0[, internet_2017 := as.numeric(scale(base_full_remote))]                 # continuous, z-scored
t0[, high_internet := as.integer(base_full_remote >=
        quantile(base_full_remote, 0.75, na.rm = TRUE))]                   # binary, top quartile
panel <- merge(panel, t0[, .(muni_code, internet_2017, high_internet)], by = "muni_code")

# ---- merge SIM excess mortality (from the BigQuery/Bases dos Dados build) ----
sim_path <- file.path(BASE_DIR, "excess_mortality_sim.rds")
if (file.exists(sim_path)) {
  sim <- as.data.table(readRDS(sim_path))
  sim[, cod6 := as.integer(substr(as.character(cod6), 1, 6))]
  panel[, cod6 := as.integer(substr(as.character(muni_code), 1, 6))]
  panel <- merge(panel, sim[, .(cod6, excess_rate)], by = "cod6", all.x = TRUE)
} else message("note: excess_mortality_sim.rds not found; skipping mortality merge")

saveRDS(panel, file.path(BASE_DIR, "city_panel.rds"))
message("panel written: ", uniqueN(panel$muni_code), " municipalities x ",
        uniqueN(panel$year), " years = ", nrow(panel), " rows")

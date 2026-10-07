# ENEM COVID-19 Learning-Loss — data pipeline

Reproducible pipeline that turns raw INEP ENEM microdata into the
municipality-level pseudo-panel used in the paper *"Digital Infrastructure and
Learning Loss during Brazil's COVID-19 School Closures."* It documents every
variable transformation (Portuguese → English), the corrected digital-access
coding, and the panel-construction rules.

## Repository layout
```
config.R                     paths + global settings (edit this first)
R/
  00_audit_years.R           check columns + Q024/Q025 codes before adding a year
  01_process_microdata.R     raw CSV per year -> municipality x year table
  02_build_panel.R           combine years -> balanced panel + treatment + mortality
  03_analysis_main.R         event study / city-trends / IV / placebo / mortality split
  04_analysis_extensions.R   triple-differences / IPW / Lee bounds
docs/
  data_dictionary.md         full variable mapping and coding rules
```
(`enem_extended_analyses.R` supplied separately is the source for `04`.)

## Data sources
- **ENEM microdata** (INEP, gov.br/inep) — one `;`-separated, Latin-1 CSV per
  year under `microdados_enem_<year>/DADOS/`. Years 2017–2024 as downloaded.
- **SIM excess mortality** — Brazil's universal death registry, pulled via
  Bases dos Dados BigQuery and merged as `excess_mortality_sim.rds`.

## How to run
```r
setwd("path/to/enem_repo")
source("config.R")             # 1. set paths, years, thresholds
source("R/00_audit_years.R")         # 2. (optional) verify columns/codes per year
source("R/01_process_microdata.R")   # 3. writes processed/muni_<year>.rds
source("R/02_build_panel.R")         # 4. writes city_panel.rds
source("R/03_analysis_main.R")       # 5. main models
source("R/04_analysis_extensions.R") # 6. triple-diff, IPW, Lee bounds
```
Requirements: R (≥ 4.2), `data.table`, `fixest`.

## Years and coverage
- **Core design years:** 2017, 2018, 2019, 2021 (ENEM 2020 is excluded; that
  edition ran in early 2021 and the design treats 2021 as the pandemic year).
- **Recovery years:** 2022-2024 are processed and appended wherever available.
  The panel is balanced only on the core years (`BALANCE_YEARS` in config.R), so
  adding recovery editions never shrinks the core sample; the event study in `03`
  then traces the post-2021 trajectory (did the access gap widen, hold, or close?).
- **Before adding a year,** run `R/00_audit_years.R`: it reports missing columns
  and prints the Q024/Q025 answer codes so a silent change in the socioeconomic
  questionnaire cannot corrupt the digital-access coding. If `CO_MUNICIPIO_ESC`
  is absent in some edition, `01` automatically falls back to `CO_MUNICIPIO_PROVA`.

## Key modelling choices (documented in code)
- **Outcome:** municipality mean mathematics score (the most cumulative area,
  hardest to sustain through remote learning).
- **Treatment:** pre-determined **2017** full-remote share, standardized
  (`internet_2017`), so it cannot be mechanically correlated with pandemic-era
  scores. A binary top-quartile version (`high_internet`) is used only where a
  binary contrast is required.
- **Identification:** event study (2019 reference) + municipality-specific
  trends + an excess-mortality instrument, with a 2018 placebo and a
  mortality-split falsification; plus subject triple-differences, IPW to the
  pre-pandemic composition, and Lee (2009) bounds for selection.
- **Digital access** is coded from Q024/Q025 against the INEP dictionaries
  (category A = "Não"); see docs/data_dictionary.md.

## Status
- [x] Pipeline: microdata → municipality panel (01–02)
- [x] Main analysis + selection extensions (03–04)
- [x] Extended to 2022–2024 ENEM cycles (recovery years; balanced on core years)
- [x] Automated variable-availability checks (00_audit_years.R)
- [ ] Recovery-specific write-up (gap trajectory 2022–2024) for the paper across years

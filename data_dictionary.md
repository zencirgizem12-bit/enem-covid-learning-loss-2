# Data dictionary — ENEM learning-loss pipeline

Mapping from raw INEP ENEM microdata variables (Portuguese) to the analysis
names used in this repository. Source: INEP microdata (gov.br/inep), one CSV
per year, `;`-separated, Latin-1 encoded.

## Identifiers & school
| Raw (INEP)               | Analysis name  | Description |
|--------------------------|----------------|-------------|
| CO_MUNICIPIO_ESC         | muni_code      | 7-digit IBGE municipality code (school). Change `MUN_COL` in config.R to CO_MUNICIPIO_PROVA if you built the panel on test location. |
| SG_UF_ESC                | state          | State (UF) abbreviation |
| TP_DEPENDENCIA_ADM_ESC   | school_admin   | 1 Federal, 2 State, 3 Municipal, 4 Private → `is_private = (==4)` |

## Scores (0–1000, IRT-equated)
| Raw            | Analysis name   | Area |
|----------------|-----------------|------|
| NU_NOTA_MT     | score_math      | Mathematics |
| NU_NOTA_CN     | score_science   | Natural sciences |
| NU_NOTA_CH     | score_human     | Human sciences |
| NU_NOTA_LC     | score_language  | Languages & codes |
| NU_NOTA_REDACAO| score_essay     | Essay |
| TP_PRESENCA_MT | presence_math   | 0 absent, 1 present, 2 eliminated → `present = (==1)` |

## Digital access (household questionnaire)
| Raw   | Analysis name | Coding |
|-------|---------------|--------|
| Q024  | q_computer    | Category **A = "Não"** (no computer); B+ = has computer |
| Q025  | q_internet    | Category **A = "Não"** (no internet); B = has internet |

Derived `digital_access` (verified against the INEP dictionaries for every year):
- **no_internet** — `q_internet == "A"` or missing
- **mobile_only** — `q_internet == "B"` and (`q_computer == "A"` or missing)
- **full_remote** — `q_internet == "B"` and `q_computer != "A"` (internet **and** computer)

Municipality shares: `pct_no_internet`, `pct_mobile_only`, `pct_full_remote`.
Missing internet responses are assigned to `no_internet` (the most defensible
imputation: item non-response concentrates among lower-SES respondents).

## Socioeconomic covariates
| Raw   | Analysis name   | Description |
|-------|-----------------|-------------|
| Q006  | income_bracket  | Household income band A..Q; mapped to `income_brl` via `INCOME_MIDPOINT` (2019 scheme — **re-map per year**, bands are indexed to the minimum wage) |
| Q001  | father_educ     | Father's education level |
| Q002  | mother_educ     | Mother's education level |
| TP_COR_RACA | race       | Self-declared colour/race |
| TP_SEXO     | sex        | Sex |

## Municipality-level outputs (per muni × year)
`n_students`, the five `score_*` means, the three `pct_*` access shares,
`income_mean_brl`, `private_math_mean` / `public_math_mean` with `n_private` /
`n_public` (student-weighted, computed separately by school type), `state`.

## Treatment & mortality (built in 02_build_panel.R)
| Name           | Description |
|----------------|-------------|
| internet_2017  | Standardized (z-scored) 2017 full-remote share — the continuous treatment used throughout |
| high_internet  | Binary top-quartile 2017 access — used only where a binary contrast is required (Lee bounds) |
| excess_rate    | SIM 2020 all-cause excess mortality per 100k vs the municipality's 2015–2019 linear trend (merged on the 6-digit code) |

## Notes on reproducibility
- Municipality means are computed among students who **sat** the exam (`present == 1`).
- Balanced panel: municipalities with ≥ `MIN_STUDENTS` test-takers in **every** year.
- SIM excess mortality is built separately via Bases dos Dados BigQuery
  (`basedosdados` → `br_ms_sim.microdados`, population from `br_ibge_populacao.municipio`),
  because the DATASUS FTP is network-blocked; the result is merged here as `excess_mortality_sim.rds`.

## Cross-year notes (2017–2024)
- **File format is stable** across editions: one `;`-separated, Latin-1 CSV named
  `MICRODADOS_ENEM_<year>.csv`; the score, presence, and Q0xx questionnaire
  columns keep the same names 2017–2024.
- **Digital-access coding** relies on `Q024` (computer, A = none) and `Q025`
  (internet, A = none). The socioeconomic questionnaire is renumbered occasionally,
  so `R/00_audit_years.R` prints each year's answer codes; confirm `Q025 ∈ {A,B}`
  and `Q024 ∈ {A,B,C,D,E}` before trusting a newly added edition.
- **School variables** (`CO_MUNICIPIO_ESC`, `SG_UF_ESC`, `TP_DEPENDENCIA_ADM_ESC`)
  are populated only for candidates still linked to a school; for others they are
  blank. Where an edition lacks `CO_MUNICIPIO_ESC` entirely, `01` falls back to
  `CO_MUNICIPIO_PROVA` (test municipality) — a different unit, so keep the choice
  consistent across years and note it if you rely on the fallback.
- **2020 is excluded** by design; **2022–2024 are recovery years**, balanced-optional
  (see `BALANCE_YEARS`).

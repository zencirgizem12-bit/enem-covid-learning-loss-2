# ============================================================================
# 01_process_microdata.R
# Reads one INEP ENEM microdata CSV per year, renames variables PT -> EN,
# codes digital access from Q024/Q025 (verified against INEP dictionaries),
# and aggregates to a municipality x year table. Writes processed/muni_<yr>.rds
#
# Source config.R first.  Depends: data.table
# ============================================================================
library(data.table)
source("config.R")

# raw INEP column -> analysis name (see docs/data_dictionary.md)
RENAME <- c(
  NU_NOTA_MT             = "score_math",
  NU_NOTA_CN             = "score_science",
  NU_NOTA_CH             = "score_human",
  NU_NOTA_LC             = "score_language",
  NU_NOTA_REDACAO        = "score_essay",
  TP_PRESENCA_MT         = "presence_math",
  Q024                   = "q_computer",   # A = "Nao" (no computer)
  Q025                   = "q_internet",   # A = "Nao" (no internet)
  Q006                   = "income_bracket",
  Q001                   = "father_educ",
  Q002                   = "mother_educ",
  TP_COR_RACA            = "race",
  TP_SEXO                = "sex",
  TP_DEPENDENCIA_ADM_ESC = "school_admin",  # 1 Fed, 2 State, 3 Mun, 4 Private
  SG_UF_ESC              = "state"
)

# approximate monetary midpoints (BRL) for Q006 income brackets A..Q, 2019 scheme.
# Brackets are indexed to the minimum wage and shift by year -> treat as a proxy;
# re-map per year if you need exact values (see docs/data_dictionary.md).
INCOME_MIDPOINT <- c(A=0, B=499, C=1248, D=1747, E=2246, F=2745, G=3493, H=4491,
                     I=5489, J=6487, K=7485, L=8483, M=9481, N=10978, O=13473,
                     P=17465, Q=24950)

process_year <- function(yr) {
  f <- micro_path(yr)
  if (!file.exists(f)) { message("skip ", yr, " (not found): ", f); return(NULL) }
  message("processing ", yr, " ...")

  # pick the municipality column: MUN_COL if present, else the fallback
  hdr     <- names(fread(f, sep = ";", encoding = "Latin-1", nrows = 0))
  mun_use <- if (MUN_COL %in% hdr) MUN_COL else if (MUN_COL_FALLBACK %in% hdr) MUN_COL_FALLBACK else
               stop("no municipality column found for ", yr)
  if (mun_use != MUN_COL) message("  note: ", yr, " lacks ", MUN_COL, "; using ", mun_use)

  want <- c(mun_use, names(RENAME))
  dt <- fread(f, sep = ";", encoding = "Latin-1", showProgress = TRUE)
  want <- intersect(want, names(dt)); dt <- dt[, ..want]
  setnames(dt, names(RENAME), unname(RENAME[names(RENAME)]), skip_absent = TRUE)
  setnames(dt, mun_use, "muni_code")
  dt[, muni_code := as.integer(muni_code)]

  # ---- digital access (corrected coding; category A = "Nao") ----
  dt[, digital_access := fcase(
        is.na(q_internet) | q_internet == "A",                         "no_internet",
        q_internet == "B" & (is.na(q_computer) | q_computer == "A"),    "mobile_only",
        q_internet == "B" & q_computer != "A",                         "full_remote",
        default = NA_character_)]

  dt[, is_private := as.integer(school_admin == 4)]
  dt[, present    := as.integer(presence_math == 1)]
  if ("income_bracket" %in% names(dt))
    dt[, income_brl := INCOME_MIDPOINT[as.character(income_bracket)]]

  # ---- aggregate to municipality (among students who sat the exam) ----
  d <- dt[present == 1]
  agg <- d[, .(
      n_students        = .N,
      score_math        = mean(score_math,    na.rm = TRUE),
      score_science     = mean(score_science, na.rm = TRUE),
      score_human       = mean(score_human,   na.rm = TRUE),
      score_language    = mean(score_language,na.rm = TRUE),
      score_essay       = if ("score_essay" %in% names(d)) mean(score_essay, na.rm = TRUE) else NA_real_,
      pct_full_remote   = mean(digital_access == "full_remote", na.rm = TRUE),
      pct_mobile_only   = mean(digital_access == "mobile_only", na.rm = TRUE),
      pct_no_internet   = mean(digital_access == "no_internet", na.rm = TRUE),
      income_mean_brl   = if ("income_brl" %in% names(d)) mean(income_brl, na.rm = TRUE) else NA_real_,
      private_math_mean = mean(score_math[is_private == 1], na.rm = TRUE),
      public_math_mean  = mean(score_math[is_private == 0], na.rm = TRUE),
      n_private         = sum(is_private == 1, na.rm = TRUE),
      n_public          = sum(is_private == 0, na.rm = TRUE),
      state             = state[1]
    ), by = muni_code]
  agg[, year := yr]
  saveRDS(agg, file.path(PROC_DIR, sprintf("muni_%d.rds", yr)))
  message("  -> ", nrow(agg), " municipalities written")
  invisible(agg)
}

invisible(lapply(YEARS, process_year))

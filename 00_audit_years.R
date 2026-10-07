# ============================================================================
# 00_audit_years.R — variable-availability & coding-stability check across years
# Run this BEFORE 01 whenever you add a new edition (e.g. 2022-2024). It reads
# only each file's header plus a small sample, so it is fast, and it flags any
# year whose columns or Q024/Q025 answer codes differ from the rest.
#
# Source config.R first. Depends: data.table.
# ============================================================================
library(data.table)
source("config.R")

# columns the pipeline relies on (01 + 03/04)
NEED <- c("NU_NOTA_MT","NU_NOTA_CN","NU_NOTA_CH","NU_NOTA_LC","NU_NOTA_REDACAO",
          "TP_PRESENCA_MT","Q024","Q025","Q006","Q001","Q002",
          "TP_COR_RACA","TP_SEXO","TP_DEPENDENCIA_ADM_ESC","SG_UF_ESC",
          MUN_COL, MUN_COL_FALLBACK)

cat("== ENEM microdata audit ==\n")
for (yr in YEARS) {
  f <- micro_path(yr)
  if (!file.exists(f)) { cat(sprintf("\n%d  FILE NOT FOUND: %s\n", yr, f)); next }

  hdr  <- names(fread(f, sep = ";", encoding = "Latin-1", nrows = 0))
  miss <- setdiff(NEED, hdr)
  cat(sprintf("\n%d  total_cols=%d  needed_present=%d/%d\n",
              yr, length(hdr), length(NEED) - length(miss), length(NEED)))
  if (length(miss)) cat("   MISSING:", paste(miss, collapse = ", "), "\n")
  cat("   municipality col in use:",
      if (MUN_COL %in% hdr) MUN_COL else if (MUN_COL_FALLBACK %in% hdr)
        paste0(MUN_COL_FALLBACK, " (fallback)") else "NONE", "\n")

  # sample to confirm the digital-access questions still use the same answer codes
  qcols <- intersect(c("Q024","Q025"), hdr)
  if (length(qcols)) {
    smp <- fread(f, sep = ";", encoding = "Latin-1", select = qcols, nrows = 200000L)
    for (q in qcols)
      cat(sprintf("   %s answer codes: %s\n", q,
                  paste(sort(unique(as.character(smp[[q]]))), collapse = " ")))
  }
}
cat("\n>> Expected: Q025 in {A,B} (A = no internet); Q024 in {A,B,C,D,E} (A = no computer).\n",
    "   If a year deviates, adjust the digital_access coding in R/01 for that year.\n")

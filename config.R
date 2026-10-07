# ============================================================================
# config.R — paths and global settings for the ENEM learning-loss pipeline
# Edit the paths, then source this before any numbered script.
# ============================================================================

## --- paths (edit these) ----------------------------------------------------
BASE_DIR   <- "C:/Users/Admin/Desktop/matheus feedbacks"            # project root / outputs
MICRO_DIR  <- "C:/Users/Admin/Desktop/ayristirilmis zip dosyalari"  # unzipped INEP microdata
PROC_DIR   <- file.path(BASE_DIR, "processed")                      # per-year processed files
dir.create(PROC_DIR, showWarnings = FALSE, recursive = TRUE)

## --- global settings -------------------------------------------------------
# YEARS         : every edition to process into a municipality table (01).
# BALANCE_YEARS : the core design years the panel must be balanced on (02).
#                 2022-2024 are post-pandemic RECOVERY years: processed and kept
#                 where available, but NOT required for a municipality to enter
#                 the balanced panel, so adding them never shrinks the core sample.
# ENEM 2020 is deliberately excluded (that edition was administered in early 2021
# and the design treats "2021" as the single pandemic year).
YEARS         <- c(2017L, 2018L, 2019L, 2021L, 2022L, 2023L, 2024L)
BALANCE_YEARS <- c(2017L, 2018L, 2019L, 2021L)
MIN_STUDENTS  <- 100L                           # balanced-panel threshold (per year)

MUN_COL          <- "CO_MUNICIPIO_ESC"          # municipality id used throughout
MUN_COL_FALLBACK <- "CO_MUNICIPIO_PROVA"        # used only if a year lacks MUN_COL

## builds the path to a year's raw microdata CSV from the INEP folder pattern
micro_path <- function(yr)
  file.path(MICRO_DIR, sprintf("microdados_enem_%d", yr),
            "DADOS", sprintf("MICRODADOS_ENEM_%d.csv", yr))

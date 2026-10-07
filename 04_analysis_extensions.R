# ============================================================================
# 04_analysis_extensions.R — triple-differences, IPW, Lee bounds
# Source config.R first. Depends: data.table, fixest.
# Inputs: city_panel.rds (subject means from the pipeline) + raw microdata.
# ============================================================================
library(data.table); library(fixest)
source("config.R")
panel <- as.data.table(readRDS(file.path(BASE_DIR, "city_panel.rds")))
panel[, year := as.integer(year)]
t0 <- unique(panel[, .(muni_code, internet_2017, high_internet)])

## --- A. Triple-differences (uses the panel's own subject means) ------------
subj <- c("score_math", "score_science", "score_human", "score_language")
long <- melt(panel[, c("muni_code","year","internet_2017","n_students", subj), with = FALSE],
             id.vars = c("muni_code","year","internet_2017","n_students"),
             measure.vars = subj, variable.name = "subject", value.name = "score")
long[, susceptible := as.integer(subject %in% c("score_math","score_science"))]
long[, treat_susc  := internet_2017 * susceptible]
ddd <- feols(score ~ i(year, treat_susc, ref = 2019) |
                     muni_code^subject + year^subject + muni_code^year,
             data = long, weights = ~n_students, cluster = ~muni_code)
cat("\n== A. Triple-differences (look at year::2021) ==\n"); print(summary(ddd))

## --- helpers for individual microdata --------------------------------------
read_indiv <- function(yr, cols) {
  dt <- fread(micro_path(yr), sep = ";", encoding = "Latin-1",
              showProgress = TRUE, select = cols)
  setnames(dt, MUN_COL, "muni_code"); dt[, muni_code := as.integer(muni_code)]
  dt[, year := yr]; dt[]
}

## --- B. IPW: reweight present-2021 to the 2019 composition -----------------
cols_B <- c(MUN_COL,"NU_NOTA_MT","TP_PRESENCA_MT","Q006","Q001","Q002",
            "TP_COR_RACA","TP_SEXO","TP_DEPENDENCIA_ADM_ESC")
micro <- rbind(read_indiv(2019L, cols_B), read_indiv(2021L, cols_B))
micro <- micro[TP_PRESENCA_MT == 1 & !is.na(NU_NOTA_MT)]
micro <- merge(micro, t0[, .(muni_code, internet_2017)], by = "muni_code")
micro <- micro[!is.na(internet_2017)]
micro[, post := as.integer(year == 2021L)]
Xv <- c("Q006","Q001","Q002","TP_COR_RACA","TP_SEXO","TP_DEPENDENCIA_ADM_ESC")
micro[, (Xv) := lapply(.SD, as.factor), .SDcols = Xv]
ps <- feglm(post ~ Q006+Q001+Q002+TP_COR_RACA+TP_SEXO+TP_DEPENDENCIA_ADM_ESC,
            data = micro, family = binomial())
micro[, p := predict(ps, type = "response")]; pbar <- mean(micro$post)
micro[, w := fifelse(post == 1L, ((1-p)/p)*(pbar/(1-pbar)), 1)]
micro[, w := pmin(w, quantile(w, 0.99, na.rm = TRUE))]
m_unw <- feols(NU_NOTA_MT ~ internet_2017*post, data = micro, cluster = ~muni_code)
m_ipw <- feols(NU_NOTA_MT ~ internet_2017*post, data = micro, weights = ~w, cluster = ~muni_code)
cat("\n== B. IPW (continuous, per 1 SD access) ==\n")
print(etable(m_unw, m_ipw, headers = c("Unweighted","IPW")))
rm(micro); gc()

## --- C. Lee (2009) bounds on the DiD (binary contrast, by construction) ----
reg <- rbind(read_indiv(2019L, c(MUN_COL,"NU_NOTA_MT","TP_PRESENCA_MT")),
             read_indiv(2021L, c(MUN_COL,"NU_NOTA_MT","TP_PRESENCA_MT")))
reg[, present := as.integer(TP_PRESENCA_MT == 1)]
reg <- merge(reg, t0[, .(muni_code, high_internet)], by = "muni_code")[!is.na(high_internet)]
ret  <- reg[, .(r = mean(present, na.rm = TRUE)), by = .(high_internet, year)]
gety <- function(hi, yr) { v <- reg[high_internet==hi & year==yr & present==1, NU_NOTA_MT]; v[!is.na(v)] }
bound_delta <- function(y19,y21,r19,r21){ q <- abs(r19-r21)/max(r19,r21)
  if (r19>=r21){ up<-mean(y21)-mean(y19[y19<=quantile(y19,1-q)]); lo<-mean(y21)-mean(y19[y19>=quantile(y19,q)]) }
  else        { up<-mean(y21[y21>=quantile(y21,q)])-mean(y19);    lo<-mean(y21[y21<=quantile(y21,1-q)])-mean(y19) }
  c(lo=lo, up=up) }
Dh <- bound_delta(gety(1,2019),gety(1,2021), ret[high_internet==1&year==2019,r], ret[high_internet==1&year==2021,r])
Dl <- bound_delta(gety(0,2019),gety(0,2021), ret[high_internet==0&year==2019,r], ret[high_internet==0&year==2021,r])
cat("\n== C. Lee bounds on the DiD (top-quartile vs rest) ==\n")
cat(sprintf("Naive DiD = %.2f ; Lee bounds = [ %.2f , %.2f ]\n",
    (mean(gety(1,2021))-mean(gety(1,2019)))-(mean(gety(0,2021))-mean(gety(0,2019))),
    Dh["lo"]-Dl["up"], Dh["up"]-Dl["lo"]))

library(tidyverse)
library(haven)
library(labelled)
library(modelsummary)
library(tinytable)

survey <- read_dta('01_Data/metadac_gwas.dta')

sprintf('Number of observations in the survey dataset %d', nrow(survey))
system2('wc', args = c('-l 01_Data/imputation_files/metadac_clean.fam'), stdout = TRUE)

survey <- survey |> rename(yob = c_doby_dv)
survey |> count(is.na(yob))
summary(survey$yob)

survey <- survey |> mutate(a_age = c_age_dv + which(letters == 'a') - 3, 
                           b_age = c_age_dv + which(letters == 'b') - 3, 
                           c_age = c_age_dv + which(letters == 'c') - 3, 
                           d_age = c_age_dv + which(letters == 'd') - 3, 
                           e_age = c_age_dv + which(letters == 'e') - 3, 
                           f_age = c_age_dv + which(letters == 'f') - 3, 
                           g_age = c_age_dv + which(letters == 'g') - 3, 
                           h_age = c_age_dv + which(letters == 'h') - 3, 
                           i_age = c_age_dv + which(letters == 'i') - 3, 
                           j_age = c_age_dv + which(letters == 'j') - 3, 
                           k_age = c_age_dv + which(letters == 'k') - 3, 
                           l_age = c_age_dv + which(letters == 'l') - 3)
survey |> select(matches('[a-z]_age$')) |> summary()

# UK general election dates
survey <- survey |> mutate(b_gedate = ymd('2010-05-06'), 
                           g_gedate = ymd('2015-05-07'), 
                           h_gedate = ymd('2017-06-08'), 
                           i_gedate = ymd('2017-06-08'), 
                           j_gedate = ymd('2017-06-08'), 
                           k_gedate = ymd('2019-12-12'), 
                           l_gedate = ymd('2019-12-12'))

# Age at election
survey <- survey |> mutate(b_age_election = if_else(month(b_gedate) <= 6, year(b_gedate) - yob - 1, year(b_gedate) - yob), 
                           g_age_election = if_else(month(g_gedate) <= 6, year(g_gedate) - yob - 1, year(g_gedate) - yob), 
                           h_age_election = if_else(month(h_gedate) <= 6, year(h_gedate) - yob - 1, year(h_gedate) - yob), 
                           i_age_election = if_else(month(i_gedate) <= 6, year(i_gedate) - yob - 1, year(i_gedate) - yob), 
                           j_age_election = if_else(month(j_gedate) <= 6, year(j_gedate) - yob - 1, year(j_gedate) - yob), 
                           k_age_election = if_else(month(k_gedate) <= 6, year(k_gedate) - yob - 1, year(k_gedate) - yob), 
                           l_age_election = if_else(month(l_gedate) <= 6, year(l_gedate) - yob - 1, year(l_gedate) - yob))

survey |> select(ends_with('age_election')) |> summary()

survey <- survey |> mutate(male = c_sex_dv == 1)
survey |> count(c_sex_dv, male) |> mutate(c_sex_label = to_factor(c_sex_dv)) |> select(c_sex_dv, c_sex_label, male, n)
survey <- survey |> select(-c_sex_dv)

survey <- survey |> mutate(ethnicity = coalesce(c_ethn_dv, d_ethn_dv, e_ethn_dv, f_ethn_dv, g_ethn_dv, h_ethn_dv))
survey <- survey |> select(-matches('[a-z]_ethn_dv'))

survey <- survey |> mutate(hiqual = pmin(c_hiqual_dv, d_hiqual_dv, e_hiqual_dv, f_hiqual_dv, g_hiqual_dv, h_hiqual_dv, na.rm = TRUE))
table(survey$c_hiqual_dv, survey$hiqual, useNA = 'ifany', deparse.level = 2)
survey <- survey |> select(-matches('[a-z]_hiqual_dv'))

survey <- survey |> mutate(degree = if_else(is.na(hiqual), NA, hiqual == 1))

survey <- survey |> mutate(yedu = case_when(hiqual == 9 ~ 7, # Highest qual is none => 7 years
                                            hiqual == 4 ~ 10, # Highest qual is GCSE => 10 years
                                            hiqual == 3 ~ 13, # Highest qual is A-lev => 13 years
                                            hiqual == 5 ~ 15, # Highest qual is other qual => 15 years
                                            hiqual == 2 ~ 19, # Highest qual is other higher degree => 19 years
                                            hiqual == 1 ~ 20, # Highest qual is degree => 20 years
                                            TRUE ~ NA_real_ # Highest qual is missing => NA
                                            ))
survey <- survey |> mutate(yedu_std = scale(yedu, center = TRUE, scale = TRUE)[, 1])


# Load predicted earnings data
pred_earn <- read_dta('01_Data/old/predicted_earnings.dta')

# Merge survey data with predicted earnings
survey <- survey |> left_join(pred_earn %>% select(id, dpv_earn_hat, lwage_hat_45), by = c('id'))
survey <- survey |> mutate(dpv_earn_std = scale(dpv_earn_hat, center = TRUE, scale = TRUE)[, 1])

# Remove extra variables
survey <- survey |> select(-matches('[a-z]_fimnlabgrs_dv'), -matches('[a-z]_jbhrs_dv'), -matches('[a-z]_fimngrs_dv'))

survey <- survey %>%
  mutate(a_ind_pol_support = if_else(!is.na(a_vote1) & a_vote1 %in% c(1, 2), a_vote1 == 1, NA),
         b_ind_pol_support = if_else(!is.na(b_vote1) & b_vote1 %in% c(1, 2), b_vote1 == 1, NA),
         c_ind_pol_support = if_else(!is.na(c_vote1) & c_vote1 %in% c(1, 2), c_vote1 == 1, NA), 
         d_ind_pol_support = if_else(!is.na(d_vote1) & d_vote1 %in% c(1, 2), d_vote1 == 1, NA), 
         e_ind_pol_support = if_else(!is.na(e_vote1) & e_vote1 %in% c(1, 2), e_vote1 == 1, NA), 
         f_ind_pol_support = if_else(!is.na(f_vote1) & f_vote1 %in% c(1, 2), f_vote1 == 1, NA), 
         g_ind_pol_support = if_else(!is.na(g_vote1) & g_vote1 %in% c(1, 2), g_vote1 == 1, NA), 
         i_ind_pol_support = if_else(!is.na(i_vote1) & i_vote1 %in% c(1, 2), i_vote1 == 1, NA), 
         j_ind_pol_support = if_else(!is.na(j_vote1) & j_vote1 %in% c(1, 2), j_vote1 == 1, NA), 
         k_ind_pol_support = if_else(!is.na(k_vote1) & k_vote1 %in% c(1, 2), k_vote1 == 1, NA), 
         l_ind_pol_support = if_else(!is.na(l_vote1) & l_vote1 %in% c(1, 2), l_vote1 == 1, NA), 
         a_ind_pol_isclose = if_else(!is.na(a_vote2) & a_vote2 %in% c(1, 2), a_vote2 == 1, NA), 
         b_ind_pol_isclose = if_else(!is.na(b_vote2) & b_vote2 %in% c(1, 2), b_vote2 == 1, NA), 
         c_ind_pol_isclose = if_else(!is.na(c_vote2) & c_vote2 %in% c(1, 2), c_vote2 == 1, NA), 
         d_ind_pol_isclose = if_else(!is.na(d_vote2) & d_vote2 %in% c(1, 2), d_vote2 == 1, NA), 
         e_ind_pol_isclose = if_else(!is.na(e_vote2) & e_vote2 %in% c(1, 2), e_vote2 == 1, NA), 
         f_ind_pol_isclose = if_else(!is.na(f_vote2) & f_vote2 %in% c(1, 2), f_vote2 == 1, NA), 
         g_ind_pol_isclose = if_else(!is.na(g_vote2) & g_vote2 %in% c(1, 2), g_vote2 == 1, NA), 
         i_ind_pol_isclose = if_else(!is.na(i_vote2) & i_vote2 %in% c(1, 2), i_vote2 == 1, NA), 
         j_ind_pol_isclose = if_else(!is.na(j_vote2) & j_vote2 %in% c(1, 2), j_vote2 == 1, NA), 
         k_ind_pol_isclose = if_else(!is.na(k_vote2) & k_vote2 %in% c(1, 2), k_vote2 == 1, NA), 
         l_ind_pol_isclose = if_else(!is.na(l_vote2) & l_vote2 %in% c(1, 2), l_vote2 == 1, NA)) 
survey <- survey %>%
  mutate(a_ind_pol_aligned = a_ind_pol_support | a_ind_pol_isclose,
         b_ind_pol_aligned = b_ind_pol_support | b_ind_pol_isclose,
         c_ind_pol_aligned = c_ind_pol_support | c_ind_pol_isclose,
         d_ind_pol_aligned = d_ind_pol_support | d_ind_pol_isclose,
         e_ind_pol_aligned = e_ind_pol_support | e_ind_pol_isclose,
         f_ind_pol_aligned = f_ind_pol_support | f_ind_pol_isclose,
         g_ind_pol_aligned = g_ind_pol_support | g_ind_pol_isclose,
         i_ind_pol_aligned = i_ind_pol_support | i_ind_pol_isclose,
         j_ind_pol_aligned = j_ind_pol_support | j_ind_pol_isclose,
         k_ind_pol_aligned = k_ind_pol_support | k_ind_pol_isclose,
         l_ind_pol_aligned = l_ind_pol_support | l_ind_pol_isclose)

survey <- survey %>%
  mutate(b_ind_voted_high = if_else(!is.na(b_vote7) & b_vote7 %in% c(1, 2), b_vote7 == 1, NA),
         g_ind_voted_high = if_else(!is.na(g_vote7) & g_vote7 %in% c(1, 2), g_vote7 == 1, NA),
         h_ind_voted_high = if_else(!is.na(h_vote7) & h_vote7 %in% c(1, 2), h_vote7 == 1, NA),
         i_ind_voted_high = if_else(!is.na(i_vote7) & i_vote7 %in% c(1, 2), i_vote7 == 1, NA),
         j_ind_voted_high = if_else(!is.na(j_vote7) & j_vote7 %in% c(1, 2), j_vote7 == 1, NA),
         k_ind_voted_high = if_else(!is.na(k_vote7) & k_vote7 %in% c(1, 2), k_vote7 == 1, NA),
         l_ind_voted_high = if_else(!is.na(l_vote7) & l_vote7 %in% c(1, 2), l_vote7 == 1, NA))

check_aligned <- lapply(letters[1:12], function(x) {
  pol_var <- paste(x, 'ind_pol_aligned', sep = '_')
  age_var <- paste(x, 'age', sep = '_')
  sum_fml <- reformulate(paste(age_var, '(Mean + SD + Min + Max + N)', sep = ' * '),
                         pol_var)

  if ((pol_var %in% colnames(survey))) {
    survey %>%
      mutate(across(all_of(pol_var),
                    ~factor(., levels = c(TRUE, FALSE), labels = c('Yes', 'No')))) %>%
      datasummary(sum_fml, data = ., output = 'data.frame') %>%
      pivot_longer(all_of(pol_var), names_to = c('wave', '.value'),
                   names_pattern = '([a-z])_(.*)')
  }
})
bind_rows(check_aligned) %>%
  select(wave, ind_pol_aligned, everything()) %>%
  tt()

check_voted <- lapply(letters[1:12], function(x) {
  pol_var <- paste(x, 'ind_voted_high', sep = '_')
  age_var <- paste(x, 'age_election', sep = '_')
  sum_fml <- reformulate(paste(age_var, '(Mean + SD + Min + Max + N)', sep = ' * '),
                         pol_var)

  if ((pol_var %in% colnames(survey))) {
    survey %>%
      mutate(across(all_of(pol_var),
                    ~factor(., levels = c(TRUE, FALSE), labels = c('Yes', 'No')))) %>%
      datasummary(sum_fml, data = ., output = 'data.frame') %>%
      pivot_longer(all_of(pol_var), names_to = c('wave', '.value'),
                   names_pattern = '([a-z])_(.*)')
  }
})
bind_rows(check_voted) %>%
  select(wave, ind_voted_high, everything()) %>%
  tt()

# Extract standardised residuals from each "election"
reg_aligned <- lapply(letters[1:12], function(x) {
  pol_var <- paste(x, 'ind_pol_aligned', sep = '_')
  age_var <- paste(x, 'age', sep = '_')
  age_polynomials <- paste(sprintf('I(%s^%d)', age_var, 1:3), collapse = '+')
  pc_vars <- paste0('PC', 1:20, '_final')
  covars <- paste(paste(pc_vars, collapse = '+'), # First 20 PCs
                  age_polynomials, # 3rd degree polynom in age
                  'male', 
                  paste('male', paste0('(', age_polynomials, ')'), sep = '*'), 
                  sep = '+')
  
  reg_fml <- reformulate(covars, pol_var)

  # Assign individual id as rowname
  survey_reg <- survey |> column_to_rownames('id')
  
  if ((pol_var %in% colnames(survey_reg))) {
    reg_out <- lm(reg_fml, data = survey_reg)
    reg_fit <- broom::augment(reg_out)
    return(reg_fit |> select(.rownames, .std.resid) |> add_column(wave = x))
  }
})

# Calculate average residual across "elections"
avg_res_aligned <- reg_aligned |> 
  bind_rows() |> 
  summarise(avg_res_aligned = mean(.std.resid), .by = .rownames) |> 
  rename(id = .rownames) |> 
  mutate(id = as.numeric(id))

# Add to the survey data
survey <- survey |> left_join(avg_res_aligned, by = join_by(id))

# Extract standardised residuals from each "election"
reg_voted_high <- lapply(letters[1:12], function(x) {
  pol_var <- paste(x, 'ind_voted_high', sep = '_')
  age_var <- paste(x, 'age_election', sep = '_')
  age_polynomials <- paste(sprintf('I(%s^%d)', age_var, 1:3), collapse = '+')
  pc_vars <- paste0('PC', 1:20, '_final')
  covars <- paste(paste(pc_vars, collapse = '+'), # First 20 PCs
                  age_polynomials, # 3rd degree polynom in age
                  'male', 
                  paste('male', paste0('(', age_polynomials, ')'), sep = '*'), 
                  sep = '+')
  
  reg_fml <- reformulate(covars, pol_var)

  # Assign individual id as rowname
  survey_reg <- survey |> column_to_rownames('id')
  
  if ((pol_var %in% colnames(survey_reg))) {
    reg_out <- lm(reg_fml, data = survey_reg)
    reg_fit <- broom::augment(reg_out)
    return(reg_fit |> select(.rownames, .std.resid) |> add_column(wave = x))
  }
})

# Calculate average residual across "elections"
avg_res_voted_high <- reg_voted_high |> 
  bind_rows() |> 
  summarise(avg_res_voted_high = mean(.std.resid), .by = .rownames) |> 
  rename(id = .rownames) |> 
  mutate(id = as.numeric(id))

# Add to the survey data
survey <- survey |> left_join(avg_res_voted_high, by = join_by(id))

# Select vars of interest
survey_out <- survey |> 
  select(IID = id, yob, male, degree, yedu, yedu_std, dpv_earn_std, 
         avg_res_aligned, avg_res_voted_high)

# FID and IID
survey_out <- survey_out |> mutate(FID = IID) |> select(FID, IID, everything())

# Make sure binary variables are 1,0 coded
survey_out <- survey_out |> mutate(male = as.numeric(male), degree = as.numeric(degree))

# Save to white-space-delimited file
survey_out |> 
  write_delim('01_Data/gwas_files/pheno.txt', delim = ' ')

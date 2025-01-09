library(tidyverse)
library(haven)
library(labelled)

survey_old <- read_dta('01_Data/MDAC-2019-0004-03E-ICHINO_20200406/MDAC-2019-0004-03E-ICHINO_sendout.dta')
survey_new <- read_dta('01_Data/MDAC-2019-0004-03E-ICHINO_20230623/MDAC-2019-0004-03E-ICHINO_202306_sendout.dta')
survey <- survey_old %>% left_join(survey_new, by = 'id', suffix = c('', '_new'))

look_for(survey, 'citizen', label = TRUE, values = FALSE, details = 'basic')

survey |> 
  mutate(ever_citizen = pmax(a_citzn1, b_citzn1, c_citzn1, d_citzn1, 
                             e_citzn1, f_citzn1, g_citzn1, h_citzn1, 
                             na.rm = TRUE)) |> 
  count(ever_citizen) |> 
  mutate(freq = n / sum(n) * 100)

survey |> select(contains('_age')) |> var_label()
val_labels(survey$c_age_dv)

survey |> 
  ggplot() + 
  geom_histogram(aes(x = c_age_dv), binwidth = 1) + 
  geom_vline(xintercept = c(15, 91), colour = 'red', linetype = 'dashed') + 
  theme_minimal()

survey |> select(ends_with('vote7')) |> var_label()

survey |> count(b_vote7)

# Eligibility per wave
survey <- survey |> 
  mutate(b_eligible = if_else(!is.na(b_vote7), b_vote7 != 3, 
                              c_age_dv + which(letters == 'b') - 3 >= 18), 
         g_eligible = if_else(!is.na(g_vote7), g_vote7 != 3, 
                              c_age_dv + which(letters == 'g') - 3 >= 18), 
         h_eligible = if_else(!is.na(h_vote7), h_vote7 != 3, 
                              c_age_dv + which(letters == 'h') - 3 >= 18), 
         i_eligible = if_else(!is.na(i_vote7), i_vote7 != 3, 
                              c_age_dv + which(letters == 'i') - 3 >= 18), 
         j_eligible = if_else(!is.na(j_vote7), j_vote7 != 3, 
                              c_age_dv + which(letters == 'j') - 3 >= 18), 
         k_eligible = if_else(!is.na(k_vote7), k_vote7 != 3, 
                              c_age_dv + which(letters == 'k') - 3 >= 18), 
         l_eligible = if_else(!is.na(l_vote7), l_vote7 != 3, 
                              c_age_dv + which(letters == 'l') - 3 >= 18))

# Ever eligible
survey <- survey |> mutate(ever_eligible = pmax(b_eligible, g_eligible, 
                                               h_eligible, i_eligible, 
                                               j_eligible, k_eligible, 
                                               l_eligible, na.rm = TRUE))

survey |> count(ever_eligible)

survey <- survey |> filter(ever_eligible == 1)
survey |> nrow()

system('wc -l 01_Data/MDAC-2019-0004-03E-ICHINO_20200406/MDAC-2019-0004-03E-ICHINO_sendout.bim')

survey |> count(is.na(c_age_dv), is.na(c_sex_dv))

survey <- survey |> filter(!is.na(c_age_dv), !is.na(c_sex_dv))

write_dta(survey, '01_Data/metadac_work.dta')

system('head 01_Data/MDAC-2019-0004-03E-ICHINO_20200406/MDAC-2019-0004-03E-ICHINO_sendout.fam')

survey |> 
  select(fam_id = id) |> 
  mutate(ind_id = fam_id) |> 
  write_delim('01_Data/QC_files/sample_covar_pass.txt', 
              delim = '\t', col_names = FALSE)

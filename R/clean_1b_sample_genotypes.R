library(tidyverse)

plink <- '09_Software/plink_mac_20241022/plink'
system2(plink, args = c('--version'))

plink2 <- '09_Software/plink2'
system2(plink2, args = c('--version'))

gtp_data <- '01_Data/MDAC-2019-0004-03E-ICHINO_20200406/MDAC-2019-0004-03E-ICHINO_sendout'

system2(plink2, 
        args = c('--bfile', gtp_data,  
                 '--keep', '01_Data/QC_files/sample_covar_pass.txt', 
                 '--missing', 'sample-only', 
                 '--genotyping-rate', 
                 '--out', '01_Data/QC_files/sample_genotype_call_rate'))

filter_call <- read_delim('01_Data/QC_files/sample_genotype_call_rate.smiss', 
                          col_names = TRUE)
filter_call <- filter_call |> mutate(pass = F_MISS < 0.05)
filter_call |> count(pass)

system2(plink2, 
        args = c('--bfile', gtp_data, 
                 '--keep', '01_Data/QC_files/sample_covar_pass.txt', 
                 '--mind', 0.05, 
                 '--geno', 0.05, 
                 '--maf', 0.01, 
                 '--max-maf', 0.99, 
                 '--hwe', 1e-6, 
                 '--het', 
                 '--out', '01_Data/QC_files/sample_heterozygosity'))

filter_het <- read_delim('01_Data/QC_files/sample_heterozygosity.het', 
                          col_names = TRUE)
filter_het <- filter_het |> mutate(het_rate = (OBS_CT - `O(HOM)`) / OBS_CT)
filter_het <- filter_het |> 
  mutate(pass = between(het_rate, mean(het_rate) - 3 * sd(het_rate), 
                        mean(het_rate) + 3 * sd(het_rate)))
filter_het |> count(pass)
filter_het |> 
  ggplot() + 
  geom_histogram(aes(x = het_rate), binwidth = 0.0001) + 
  geom_vline(xintercept = c(mean(filter_het$het_rate) - 3 * sd(filter_het$het_rate), 
                            mean(filter_het$het_rate) + 3 * sd(filter_het$het_rate)),
             colour = 'red', linetype = 'dashed') + 
  theme_minimal()

system2(plink, 
        args = c('--bfile', gtp_data, 
                 '--keep', '01_Data/QC_files/sample_covar_pass.txt', 
                 '--check-sex', 
                 '--out', '01_Data/QC_files/sample_sex_check'))

filter_sex <- read_table('01_Data/QC_files/sample_sex_check.sexcheck', 
                         col_names = TRUE)
filter_sex <- filter_sex |> mutate(pass = STATUS == 'OK')
filter_sex |> count(pass)

system2(plink2, 
        args = c('--bfile', gtp_data, 
                 '--keep', '01_Data/QC_files/sample_covar_pass.txt', 
                 '--mind', 0.05, 
                 '--geno', 0.05, 
                 '--maf', 0.01, 
                 '--max-maf', 0.99, 
                 '--hwe', 1e-6, 
                 '--indep-pairwise', 50, 10, 0.1, 
                 '--out', '01_Data/QC_files/sample_relatedness_pruned'))

system2(plink, 
        args = c('--bfile', gtp_data, 
                 '--keep', '01_Data/QC_files/sample_covar_pass.txt', 
                 '--extract', '01_Data/QC_files/sample_relatedness_pruned.prune.in', 
                 '--rel-cutoff', 0.025, 
                 '--out', '01_Data/QC_files/sample_relatedness'))

filter_rel <- read_delim('01_Data/QC_files/sample_relatedness.rel.id', 
                         col_names = c('FID', 'IID'))
filter_rel <- filter_rel |> mutate(pass = TRUE)

filter_all <- bind_rows(filter_call |> select(IID, pass), 
                        filter_het |> select(IID, pass), 
                        filter_sex |> select(IID, pass), 
                        filter_rel |> select(IID, pass), 
                        .id = 'filter')
filter_all <- filter_all |> mutate(filter = case_when(filter == 1 ~ 'call', 
                                                      filter == 2 ~ 'het', 
                                                      filter == 3 ~ 'sex', 
                                                      filter == 4 ~ 'rel'))
filter_all <- filter_all |> pivot_wider(names_from = 'filter', values_from = 'pass')
filter_all <- filter_all |> mutate(rel = if_else(is.na(rel), FALSE, rel))
filter_all <- filter_all |> mutate(pass_all = pmin(call, het, sex, rel, 
                                                   na.rm = FALSE))
filter_all |> count(call, het, sex, rel, pass_all)
filter_all <- filter_all |> filter(pass_all == 1)
filter_all <- filter_all |> distinct(IID)

filter_all |> 
  mutate(FID = IID) |> 
  write_delim('01_Data/QC_files/sample_gtp_pass.txt', 
              delim = '\t', col_names = FALSE)

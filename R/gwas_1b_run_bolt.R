bolt <- '09_Software/BOLT-LMM_v2.3/bolt'
system2(bolt, stdout = TRUE) |> cat(sep = '\n')

library(tidyverse)
grm_bim <- read_table('01_Data/gwas_files/metadac_grm.bim', 
                      col_names = c('chr', 'rsid', 'cm', 'bp', 'a1', 'a2'), 
                      guess_max = 1e5)
grm_bim <- grm_bim |> mutate(ID = str_c(chr, bp, sep = ':'))
grm_bim |> 
  filter(chr %in% 1:22) |> 
  pull(ID) |> 
  write_lines('01_Data/gwas_files/metadac_grm.snps', sep = '\n')

header <- '#!/bin/bash -l
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --mem=60g
#SBATCH --tmp=60g
#SBATCH --mail-type=ALL  
#SBATCH --mail-user=njandaro@umn.edu 
'

wd <- getwd()

cmd_string <- paste(bolt, 
                    '--lmm', 
                    '--bfile', '01_Data/imputation_files/metadac_imputed_clean', 
                    '--phenoFile', '01_Data/gwas_files/pheno.txt', 
                    '--phenoCol', 'avg_res_voted_high', 
                    '--LDscoresFile', '09_Software/BOLT-LMM_v2.3/tables/LDSCORE.1000G_EUR.tab.gz', 
                    '--modelSnps', '01_Data/gwas_files/metadac_grm.snps', 
                    '--statsFile', '01_Data/gwas_files/METADAC.HIGH.stats.20241219', 
                    '--verboseStats',
                    sep = ' ')

script_file <- '01_Data/gwas_files/run_gwas.sh'
  
# Write the script to file
write_lines(header, script_file, append = FALSE)
write_lines(paste('cd', wd), script_file, append = TRUE)
write_lines(cmd_string, script_file, append = TRUE)

# Preview
system2('more', args = c(script_file), stdout = TRUE) |> cat(sep = '\n')

# system2('sbatch',
#         args = c('--job-name', 'gwas-bolt',
#                  script_file), stdout = TRUE) |> cat(sep = '\n')

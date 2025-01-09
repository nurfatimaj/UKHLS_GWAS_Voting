library(tidyverse)
library(haven)
library(labelled)

plink <- '09_Software/plink_mac_20241022/plink'
system2(plink, args = c('--version'))

plink2 <- '09_Software/plink2'
system2(plink2, args = c('--version'))

gtp_data <- '01_Data/MDAC-2019-0004-03E-ICHINO_20200406/MDAC-2019-0004-03E-ICHINO_sendout'

system2(plink2, 
        args = c('--bfile', gtp_data, 
                 '--keep', '01_Data/QC_files/sample_ancestry_pass.txt', 
                 '--mind', 0.05, 
                 '--geno', 0.05, 
                 '--maf', 0.01, 
                 '--max-maf', 0.99, 
                 '--hwe', 1e-6, 
                 '--indep-pairwise', 50, 10, 0.1, 
                 '--out', '01_Data/QC_files/sample_final_pca'))

# system2(plink,
#         args = c('--bfile', gtp_data,
#                  '--keep', '01_Data/QC_files/sample_ancestry_pass.txt',
#                  '--extract', '01_Data/QC_files/sample_final_pca.prune.in',
#                  '--pca',
#                  '--out', '01_Data/QC_files/sample_final_pca'))

pca_eigenvec <- read_table('01_Data/QC_files/sample_final_pca.eigenvec', 
                           col_names = c('FID', 'IID', paste0('PC', 1:20)))
pca_eigenvec <- pca_eigenvec |> rename_with(~str_c(., '_final'), starts_with('PC'))

survey <- read_dta('01_Data/metadac_work.dta')

# Merge
survey <- survey |> 
  left_join(pca_eigenvec, by = join_by(id == IID), suffix = c('_orig', '_final'))

# Remove individuals with missing PCs
survey <- survey |> drop_na(ends_with('_final'))

nrow(survey)

survey |> write_dta('01_Data/metadac_gwas.dta')

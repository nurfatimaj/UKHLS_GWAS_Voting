library(tidyverse)
library(pbapply)

plink <- '/common/software/install/migrated/plink/1.90b6.10/bin/plink'
system2(plink, args = c('--version'), stdout = TRUE) |> cat(sep = '\n')

plink2 <- '09_Software/plink2'
system2(plink2, args = c('--version'), stdout = TRUE) |> cat(sep = '\n')

bcftools <- '/common/software/install/spack/linux-centos7-ivybridge/gcc-8.2.0/bcftools-1.16-5d4xg4yecvcdtx2i7iwsdzwcg3pcfm76/bin/bcftools'
system2(bcftools, args = c('--version'), stdout = TRUE)

# pblapply(1:22, function(c) {
#   iname <- sprintf('01_Data/imputation_files/download/chr%d.dose.vcf.gz', c)
#   oname <- sprintf('01_Data/imputation_files/metadac_imputed_clean_chr%d', c)
#   system2(plink2,
#         args = c('--vcf', iname, 'dosage=HDS',
#                  '--id-delim _',
#                  '--extract-if-info "R2 >= 0.7"',
#                  '--geno', 0.05, 'dosage',
#                  '--maf', 0.01,
#                  '--max-maf', 0.99,
#                  '--hwe', 1e-6,
#                  '--rm-dup', 'exclude-all', 'list',
#                  '--make-bed',
#                  '--out', oname),
#         stdout = TRUE) |>
#     cat(sep = '\n')
# })
# 

# merge_list <- map_chr(1:22,
#                       ~sprintf('01_Data/imputation_files/metadac_imputed_clean_chr%d', .x))
# merge_list |>
#   write_lines('01_Data/imputation_files/metadac_imputed_merge_list.txt', sep = '\n')
# 
# system2(plink2,
#         args = c('--pmerge-list', '01_Data/imputation_files/metadac_imputed_merge_list.txt',
#                  'bfile',
#                  '--make-bed',
#                  '--out', '01_Data/imputation_files/metadac_imputed_clean'))

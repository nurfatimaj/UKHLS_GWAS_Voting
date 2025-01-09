plink <- '09_Software/plink_mac_20241022/plink'
system2(plink, args = c('--version'), stdout = TRUE) |> cat(sep = '\n')

plink2 <- '09_Software/plink2'
system2(plink2, args = c('--version'), stdout = TRUE) |> cat(sep = '\n')

gcta <- '09_Software/gcta-1.94.1'
system2(gcta, args = c('--version'), stdout = TRUE) |> cat(sep = '\n')

system2(plink2, 
        args = c('--bfile', '01_Data/imputation_files/metadac_clean', 
                 '--indep-pairwise', '500kb', 0.2, 
                 '--out', '01_Data/gwas_files/metadac_grm'), 
        stdout = TRUE) |> 
  cat(sep = '\n')

system2(plink2, 
        args = c('--bfile', '01_Data/imputation_files/metadac_clean', 
                 '--extract', '01_Data/gwas_files/metadac_grm.prune.in', 
                 '--make-bed', 
                 '--out', '01_Data/gwas_files/metadac_grm'), 
        stdout = TRUE) |> 
  cat(sep = '\n')

# system2(gcta,
#         args = c('--bfile', '01_Data/gwas_files/metadac_grm',
#                  '--make-grm',
#                  '--out', '01_Data/gwas_files/metadac_grm'))

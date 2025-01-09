library(tidyverse)
library(data.table)
library(pbapply)

plink2 <- '09_Software/plink2'
system2(plink2, args = c('--version'), stdout = TRUE) |> cat(sep = '\n')

gwas_in <- data.table::fread('01_Data/gwas_files/METADAC.HIGH.stats.20241219')

gwas_out <- gwas_in |> 
  select(SNPID = SNP, CHR, BP_b37 = BP, EFFECT_ALLELE = ALLELE1, OTHER_ALLELE = ALLELE0, 
         EAF = A1FREQ, BETA, SE, P = P_BOLT_LMM_INF, F_MISS)
head(gwas_out)

# Extract sample size
gwas_log <- read_lines('01_Data/gwas_files/slurm-28401820.out')
gwas_N <- gwas_log[str_detect(gwas_log, 'Dimension of all-1s proj space')]
gwas_N <- gwas_N[length(gwas_N)] # Select last entry
gwas_N <- str_extract(gwas_N, '[[:digit:]]+$')
gwas_N <- as.integer(gwas_N)
gwas_N <- gwas_N + 1 # because number shown in log is N-1

# Create sample size column (specific to each SNP using F_MISS)
gwas_out <- gwas_out |> mutate(N = round((1 - F_MISS) * gwas_N))
gwas_out <- gwas_out |> select(-F_MISS)
gwas_out |> summary()

# Extract imputation R2
info_list <- pblapply(1:22, function(c) {
  fname <- sprintf('01_Data/imputation_files/download/chr%d.info.gz', c)
  vcf <- read_table(fname, skip = 12, col_types = list(ID = col_character()))
  vcf <- vcf |> filter(ID %in% gwas_out$SNPID)
  vcf <- vcf |> mutate(R2 = str_extract(INFO, '(?<=R2=)[0-9][.[0-9]e-]*'))
  vcf <- vcf |> mutate(R2 = as.numeric(R2))
  return(vcf |> select(ID, REF, ALT, R2))
})
info_list <- bind_rows(info_list)

# Attach to GWAS table
gwas_out <- gwas_out |> 
  left_join(info_list, by = join_by(SNPID == ID, EFFECT_ALLELE == ALT, OTHER_ALLELE == REF))
gwas_out <- gwas_out |> rename(INFO = R2)

gwas_out |> summary()

# Compute HWE p-values
system2(plink2, 
        args = c('--bfile', '01_Data/imputation_files/metadac_clean', 
                 '--hardy', 
                 '--out', '01_Data/gwas_files/metadac_clean'))

# Load
bim <- read_table('01_Data/imputation_files/metadac_clean.bim', 
                  col_names = c('CHR', 'RSID', 'CM', 'BP', 'A1', 'A2'), 
                  col_types = list(CHR = col_character()))
bim <- bim |> mutate(SNPID = str_c(CHR, BP, sep = ':'))
hwe <- read_table('01_Data/gwas_files/metadac_clean.hardy', 
                  col_types = list('#CHROM' = col_character()))
hwe <- hwe |> left_join(bim |> select(RSID, SNPID), by = join_by(ID == RSID))
hwe <- hwe |> mutate(to_keep = 1:n() == 1, .by = c(SNPID, A1, AX))
hwe <- hwe |> mutate(to_keep = if_else(SNPID == '1:206231264' & A1 == 'G', FALSE, to_keep))
hwe <- hwe |> filter(to_keep) |> select(-to_keep)
hwe <- hwe |> select(SNPID, HWE_PVAL = P)

# Merge with GWAS table
gwas_out <- gwas_out |> left_join(hwe, by = 'SNPID')

gwas_out |> summary()

# Compute call rate
system2(plink2, 
        args = c('--bfile', '01_Data/imputation_files/metadac_clean', 
                 '--missing', 'variant-only', 
                 '--out', '01_Data/gwas_files/metadac_clean'))

# Load
vmiss <- read_table('01_Data/gwas_files/metadac_clean.vmiss', 
                  col_types = list('#CHROM' = col_character()))
vmiss <- vmiss |> mutate(CALLRATE = (OBS_CT - MISSING_CT) / OBS_CT)
vmiss <- vmiss |> left_join(bim, by = join_by(ID == RSID))
vmiss <- vmiss |> mutate(to_keep = 1:n() == 1, .by = c(SNPID, A1, A2))
vmiss <- vmiss |> mutate(to_keep = if_else(SNPID == '1:206231264' & A1 == 'G', FALSE, to_keep))
vmiss <- vmiss |> filter(to_keep) |> select(-to_keep)
vmiss <- vmiss |> select(SNPID, CALLRATE)

# Merge with GWAS table
gwas_out <- gwas_out |> left_join(vmiss, by = 'SNPID')

gwas_out |> summary()

gwas_out |> 
  write_delim('01_Data/gwas_files/METADAC.HIGH.association-results.20241219.txt', 
              delim = ' ')

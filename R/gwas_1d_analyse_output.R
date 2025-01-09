library(tidyverse)
library(qqman)
library(data.table)
library(LDlinkR)
library(pbapply)

readRenviron('_environment.local')

gwas <- fread('01_Data/gwas_files/METADAC.HIGH.association-results.20241219.txt')

qq(gwas$P)

manhattan(gwas, chr = 'CHR', bp = 'BP_b37', p = 'P', snp = 'SNPID')

gwas |> filter(P <= 0.05 / max(gwas$N))


# Fetch data from LDTraits tool
sig_ldtraits <- gwas |> 
  filter(P <= 0.05 / N) |> 
  mutate(ldlink_batch = ceiling(row_number(SNPID) / 10)) |> 
  mutate(SNPID = str_c('chr', SNPID)) |> 
  pull(SNPID) |> 
  LDtrait(pop = 'GBR', token = Sys.getenv('LDLINK_TOKEN'))
sig_ldtraits <- sig_ldtraits |> 
  mutate(across(c(R2, `D'`, Effect_Size_95_CI, P_value), as.numeric))

# 1. Direction of effect sizes?!
# For example, query for rs1286757 returns rs1560633 (phenotype: heel bone
# mineral density). All effect sizes in the GWAS Catalog are unit decreases (i.e.,
# negative betas): https://www.ebi.ac.uk/gwas/variants/rs1560633. But the table
# above does not contain information about direction!
# 2. Beta (marginal effect) and OR are lumped together in one column, whereas
# the GWAS catalog differentiates between them. OR < 1 should correspond to
# beta < 0. But we don't know which of the returned results is OR and which is
# beta. This also makes assigning direction difficult.
# So, effect sizes cannot really be used.

# Group the GWAS traits
pol_ldtraits <- pol_ldtraits %>%
  mutate(trait_group = case_when(str_detect(GWAS_Trait, '[Ee]ducation|[Mm]ath') ~ 'Education',
                                 str_detect(GWAS_Trait, '[Cc]ognitive') ~ 'Cognitive ability',
                                 str_detect(GWAS_Trait, '[Ii]ncome') ~ 'Income',
                                 str_detect(GWAS_Trait, '[Hh]eight') ~ 'Height',
                                 str_detect(GWAS_Trait, 'BMI|[Ww]aist|[Hh]ip|[Bb]ody size|[Bb]ody shape|[Bb]ody fat|[Oo]besit|[Uu]nderweight|Weight') ~ 'Body size',
                                 GWAS_Trait == 'Body mass index' ~ 'Body size',
                                 GWAS_Trait == 'Body mass index variance' ~ 'Body size',
                                 str_detect(GWAS_Trait, '[Aa]dventourous|[Ee]xternali|[Rr]isk-|[Rr]isk [Tt]ol|[Ww]orry|[Ff]eeling [Nn]ervous|[Ll]one') ~ 'Personality',
                                 str_detect(GWAS_Trait, '[Aa]lcohol|[Dd]rink|Smok') ~ 'Substance',
                                 str_detect(GWAS_Trait, '[Dd]epression|[Ss]chi') ~ 'Mental health',
                                 TRUE ~ 'Other',
                                 str_detect(GWAS_Trait, '[Nn]onalcoholic fatty liver') ~ 'Other'))

# Merge with pol_gwas results
pol_ldtraits <- pol_ldtraits %>%
  left_join(pol_sig %>% select(ID, DEPVAR), by = c('Query' = 'ID'))

library(tidyverse)
library(pbapply)

plink <- '09_Software/plink_mac_20241022/plink'
system2(plink, args = c('--version'), stdout = TRUE) |> cat(sep = '\n')

plink2 <- '09_Software/plink2'
system2(plink2, args = c('--version'), stdout = TRUE) |> cat(sep = '\n')

bcftools <- '09_Software/bcftools'
system2(bcftools, args = c('--version'), stdout = TRUE) |> cat(sep = '\n')

gtp_data <- '01_Data/MDAC-2019-0004-03E-ICHINO_20200406/MDAC-2019-0004-03E-ICHINO_sendout'

system2(plink2, 
        args = c('--bfile', gtp_data, 
                 '--keep', '01_Data/QC_files/sample_ancestry_pass.txt', 
                 '--mind', 0.05, 
                 '--geno', 0.05, 
                 '--maf', 0.01, 
                 '--max-maf', 0.99, 
                 '--hwe', 1e-6, 
                 '--make-bed', 
                 '--out', '01_Data/imputation_files/metadac_clean'))

system2(plink, 
        args = c('--bfile', '01_Data/imputation_files/metadac_clean', 
                 '--freq', 
                 '--out', '01_Data/imputation_files/metadac_clean'))

# # Download
# site_list_url <- 'ftp://ngs.sanger.ac.uk/production/hrc/HRC.r1-1/HRC.r1-1.GRCh37.wgs.mac5.sites.tab.gz'
# multi_download(site_list_url,
#                '01_Data/HRC1.1/HRC.r1-1.GRCh37.wgs.mac5.sites.tab.gz',
#                resume = TRUE, progress = TRUE)
# 
# # Unzip
# system2('gunzip',
#         args = c('--keep',
#                  '01_Data/HRC1.1/HRC.r1-1.GRCh37.wgs.mac5.sites.tab.gz'))

system2('perl', 
      args = c('09_Software/HRC-1000G-check-bim-v4/HRC-1000G-check-bim.pl', 
               '-b', '01_Data/imputation_files/metadac_clean.bim', 
               '-f', '01_Data/imputation_files/metadac_clean.frq', 
               '-r', '01_Data/HRC1.1/HRC.r1-1.GRCh37.wgs.mac5.sites.tab', 
               '-h', 
               '-l', '09_Software/plink_mac_20241022/plink'))

hrc_plink_commands <- read_lines('01_Data/imputation_files/Run-plink.sh')

# Remove path to project folder (keep only relative paths within project)
hrc_plink_commands <- str_remove_all(hrc_plink_commands, paste0(getwd(), '/'))

# Last command is to remove temporary files
hrc_plink_commands[length(hrc_plink_commands)]
if (hrc_plink_commands[length(hrc_plink_commands)] == 'rm TEMP*') hrc_plink_commands <- hrc_plink_commands[1:(length(hrc_plink_commands)-1)]

map(hrc_plink_commands, system)

# Remove temporary files
file.remove(list.files('01_Data/imputation_files/', 'TEMP*', full.names = TRUE))

pblapply(seq(1, 22), function(chr) {
  # Make sure vcf is sorted
  system2(bcftools, 
          args = c('sort', 
                   sprintf('01_Data/imputation_files/metadac_clean-updated-chr%d.vcf', chr), 
                   '-Oz', 
                   '-o', sprintf('01_Data/imputation_files/upload/metadac_clean-updated-chr%d.vcf.gz', chr)))
})

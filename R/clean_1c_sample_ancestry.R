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
                 '--keep', '01_Data/QC_files/sample_gtp_pass.txt', 
                 '--mind', 0.05, 
                 '--geno', 0.05, 
                 '--maf', 0.01, 
                 '--max-maf', 0.99, 
                 '--hwe', 1e-6, 
                 '--indep-pairwise', 50, 10, 0.1, 
                 '--out', '01_Data/QC_files/sample_ancestry_pruned'))

system2(plink, 
        args = c('--bfile', gtp_data, 
                 '--keep', '01_Data/QC_files/sample_gtp_pass.txt', 
                 '--extract', '01_Data/QC_files/sample_ancestry_pruned.prune.in', 
                 '--pca', 
                 '--out', '01_Data/QC_files/sample_ancestry_pca'))

pca_eigenvec <- read_table('01_Data/QC_files/sample_ancestry_pca.eigenvec', 
                           col_names = c('FID', 'IID', paste0('PC', 1:20)))

survey <- read_dta('01_Data/metadac_work.dta')

survey |> look_for('ethn', labels = FALSE, values = FALSE, details = 'none')
survey |> mutate(ethn_label = to_factor(c_ethn_dv)) |> count(c_ethn_dv, ethn_label)

survey <- survey |> mutate(c_white_british = c_ethn_dv == 1, 
                           d_white_british = d_ethn_dv == 1, 
                           e_white_british = e_ethn_dv == 1, 
                           f_white_british = f_ethn_dv == 1, 
                           g_white_british = g_ethn_dv == 1, 
                           h_white_british = h_ethn_dv == 1)
survey <- survey |> mutate(white_british = pmax(c_white_british, d_white_british, 
                                                e_white_british, f_white_british, 
                                                g_white_british, h_white_british, 
                                                na.rm = TRUE), 
                           white_british = if_else(is.na(white_british), 0, 
                                                   white_british))
survey <- survey |> mutate(white_british = if_else(white_british == 1, 
                                                   'White British', 
                                                   'Other'))
survey |> count(white_british)

pca_eigenvec <- pca_eigenvec |> 
  left_join(survey |> select(id, white_british), 
            by = join_by(IID == id))

pca_eigenvec |> 
  ggplot(aes(x = PC1, y = PC2, colour = white_british, size = white_british)) + 
  geom_point() + 
  scale_size_discrete(range = c(1, 0.1)) + 
  theme_minimal() + 
  theme(legend.position = 'bottom')

pca_eigenvec |> 
  ggplot(aes(x = PC2, y = PC3, colour = white_british, size = white_british)) + 
  geom_point() + 
  scale_size_discrete(range = c(1, 0.1)) + 
  theme_minimal() + 
  theme(legend.position = 'bottom')

pca_eigenvec |> 
  ggplot(aes(x = PC3, y = PC4, colour = white_british, size = white_british)) + 
  geom_point() + 
  scale_size_discrete(range = c(1, 0.1)) + 
  theme_minimal() + 
  theme(legend.position = 'bottom')

pca_eigenvec |> 
  ggplot(aes(x = PC4, y = PC5, colour = white_british, size = white_british)) + 
  geom_point() + 
  scale_size_discrete(range = c(1, 0.1)) + 
  theme_minimal() + 
  theme(legend.position = 'bottom')

filter_ancestry <- pca_eigenvec |> select(IID) |> mutate(FID = IID)

filter_ancestry |> 
  write_delim('01_Data/QC_files/sample_ancestry_pass.txt', 
              delim = '\t', col_names = FALSE)

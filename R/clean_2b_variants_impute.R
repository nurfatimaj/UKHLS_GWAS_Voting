library(tidyverse)
library(httr2)
library(jsonlite)
library(pbapply)

plink <- '09_Software/plink_mac_20241022/plink'
system2(plink, args = c('--version'), stdout = TRUE) |> cat(sep = '\n')

plink2 <- '09_Software/plink2'
system2(plink2, args = c('--version'), stdout = TRUE) |> cat(sep = '\n')

readRenviron('_environment.local')

# base_url <- 'https://imputationserver.sph.umich.edu/api/v2/'
# type_url <- 'jobs/submit/imputationserver2'
# api_token <- Sys.getenv('MIS2_TOKEN')
# gtp_list <- list.files('01_Data/imputation_files/upload/', pattern = '.vcf.gz',
#                        full.names = TRUE)
# 
# mis2_query <- request(base_url = base_url) |>
#   req_url_path_append(type_url) |>
#   req_url_query(mode = 'imputation',
#                 refpanel = 'hrc-r1.1',
#                 phasing = 'eagle',
#                 population = 'eur',
#                 build = 'hg19',
#                 r2Filter = '0') |>
#   req_headers('X-Auth-Token' = api_token) |>
#   req_body_multipart(files = curl::form_file(gtp_list[[1]]),
#                      files = curl::form_file(gtp_list[[2]]),
#                      files = curl::form_file(gtp_list[[3]]),
#                      files = curl::form_file(gtp_list[[4]]),
#                      files = curl::form_file(gtp_list[[5]]),
#                      files = curl::form_file(gtp_list[[6]]),
#                      files = curl::form_file(gtp_list[[7]]),
#                      files = curl::form_file(gtp_list[[8]]),
#                      files = curl::form_file(gtp_list[[9]]),
#                      files = curl::form_file(gtp_list[[10]]),
#                      files = curl::form_file(gtp_list[[11]]),
#                      files = curl::form_file(gtp_list[[12]]),
#                      files = curl::form_file(gtp_list[[13]]),
#                      files = curl::form_file(gtp_list[[14]]),
#                      files = curl::form_file(gtp_list[[15]]),
#                      files = curl::form_file(gtp_list[[16]]),
#                      files = curl::form_file(gtp_list[[17]]),
#                      files = curl::form_file(gtp_list[[18]]),
#                      files = curl::form_file(gtp_list[[19]]),
#                      files = curl::form_file(gtp_list[[20]]),
#                      files = curl::form_file(gtp_list[[21]]),
#                      files = curl::form_file(gtp_list[[22]])) |>
#   req_progress()
# 
# mis2_output <- req_perform(mis2_query)

# request(base_url = base_url) |>
#   req_url_path_append(sprintf('jobs/%s/status',
#                               resp_body_json(mis2_output)$id)) |>
#   req_headers('X-Auth-Token' = api_token) |>
#   req_perform() |>
#   resp_body_json()

This repository contains that codes necessary to implement GWAS of voting behaviour in the UK Household Longitudinal Study (UKHLS). 

The codes are available in two formats: `qmd` and `R`. 
- The original are in `.qmd` format - a dynamic report that combines formatted text with R code cells (see [quarto.org](https://quarto.org)). Thanks to this, the `.qmd` files have extra information that describe the source data, the analysis steps and decisions taken by researcher.  These files can be opened and run in RStudio. 
- The `.R` files contain only the code cells from corresponding `.qmd` files. They are the conventional R scripts that can be run without quarto.

Overview of files in the repository:

`clean_0_overview.qmd`
Overview of cleaning and GWAS steps with detailed information about output of each `.qmd` file. If run with `quarto` it can generate pdf report. 

## Cleaning steps

| File   | Short description  |
|---|---|
| `clean_1a_sample_variables` | Identifies set of sample members with non-missing covariates that were eligible to vote at least once during the survey. |
| `clean_1b_sample_genotypes` | Extracts genotypes of eligible voters, passes standard QC filters based on missingness and heterozygosity. |
| `clean_1c_sample_ancestry` | Examines genetic ancestry based on genetic PCA. |
| `clean_1d_genetic_PCs` | Re-computes genetic PCs using final set of sample members and variants passing standard QC.|
| `clean_2a_variants_genotypes` | Passes standard QC filters on variants based on missingness, allele frequencies, HWE p-values; applies the pre-imputation checks tool that asserts proper alignment with the reference panel and removes palindromic SNPs with MAF > 0.4.|
| `clean_2b_variants_impute` | Attempts to access imputation server via API, but fails. Actual imputation is done by manually interacting with the web platform of the imputation server.|
| `clean_2c_variants_imputedQC` | Passes standard QC filters on post-imputation variants (missingness, MAF, HWE) and keeps well-imputed variants (imputation $R^2$ > 0.7). |

## Phenotypes

| File   | Short description  |
|---|---|
| `clean_1e_sample_phenotypes` | Cleans phenotypes and covariates of interest, aggregates multiple voting observations per person as described in the analysis plan. It also processes additional phenotypes (like general political interest and party affiliation, but these are not used in the GWAS).|
| `clean_1e_sample_descriptives` | Creates a table of sample characteristics. |

## GWAS

| File   | Short description  |
|---|---|
| `gwas_1a_estimate_grm` | Identifies set of clean genotyped variants that can be used in GRM calcuation. |
| `gwas_1b_run_bolt` | Generates script that runs BOLT-LMM. The script is then submitted as a job to the Minnesota supercomptuer. |
| `gwas_1c_format_output` | Formats the GWAS output according to the requirements of the analysis plan. |

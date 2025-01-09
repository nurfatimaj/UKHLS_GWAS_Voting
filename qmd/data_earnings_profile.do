**************************************************************************
********************** PREDICTED LIFETIME EARNINGS ***********************
**************************************************************************

* This do file estimates earnings profiles and generates predicted lifetime
* earnings to be used in subsequent analysis.

* Input files:
* 1. Survey data of genotyped individuals. This dataset is provided by 
*    the METADAC and saved as data/MDAC-2019-0004-03E-ICHINO_sendout.dta.
* 2. ONS CPI index excl. rent, maintenance 
* 	 the excel table is downloaded and converted to Stata dataset in 
* 	 analysis/data_ons_cpi.do. The output is saved in data/cpic.dta.
* 3. Estimation of wage profiles in the full survey dataset. Saved in 
*    data/earn_profile_est.ster file and created by 
*    analysis/data_full_earn_profile.do 

* Output files:
* - data with predicted lifetime earnings saved in data/predicted_earnings.dta

**************************************************************************
**# Setup 
**************************************************************************

clear all
set maxvar 32767
frame reset
cap log close

* Paths
if "`c(username)'" == "rusti001" {
	global projpath "/Users/rusti001/Library/CloudStorage/GoogleDrive-rusti001@umn.edu/My Drive/AResearch/GWAS Political Data"
}
else if "`c(username)'" == "nurfatimaj" {
	global projpath "~/Google Drive/My Drive/Research/GWAS Political Data"
}
else if "`c(username)'" == "pknuja" {
	global project_path "~/Google Drive/My Drive/Research/GWAS Political Data"
}
else {
	di as error "User `c(username)' is unknown"
	exit
}

cd "$projpath"
log using 10_Logs/03_Analysis/data_earnings_profile, replace text

* Discount factor
global delta 0.93

**************************************************************************
**# Data
**************************************************************************
* Load the input dataset
use "01_Data/MDAC-2019-0004-03E-ICHINO_20200406/MDAC-2019-0004-03E-ICHINO_sendout.dta", clear

* Keep working variables
keep id ?_hhid sex c_age_dv c_doby_dv c_intdaty_dv c_intdatm_dv ///
	?_fimngrs_dv ?_fimnlabgrs_dv ?_jbstat ?_jbhrs_dv ?_jbft_dv ///
	?_hiqual_dv ?_ethn_dv

* Convert the interval variables from labelled numeric to string
* The bin thresholds are not the same across waves. For example, group 
* number 10 in a_fimngrs_dv is between 568.75-624 (wave 1) and same group
* in c_fimngrs_dv is between 663-710 (wave 3). If we reshape to long, then
* Stata will use one of the value labels (let's say from first wave) and 
* assign that label to every group 10 in every wave. To avoid this, we 
* convert the binned variables to string variables.
foreach var of varlist ?_fimngrs_dv ?_fimnlabgrs_dv ?_jbhrs_dv {
	rename `var' `var'_orig
	decode `var'_orig, gen(`var')
	drop `var'_orig
}

* Reshape to long
reshape long @hhid @age_dv @intdaty_dv @intdatm_dv @ethn_dv ///
	@fimngrs_dv @fimnlabgrs_dv @jbstat @jbhrs_dv @jbft_dv @hiqual_dv, ///
	i(id) j(wavestring) string

* Convert wave from string to numeric variable
replace wavestring = substr(wavestring, 1, 1)
encode wavestring, gen(wave)

* Remove observations (waves) where individual did not respond at all
drop if missing(hhid)

**## Variables
* Year of birth
clonevar yob = c_doby_dv
label var yob "Year of birth"

* Interview year (increment one year)
tempvar w3year
egen `w3year' = mean(intdaty_dv), by(id)
replace intdaty_dv = `w3year' + wave - 3 if missing(intdaty_dv)
rename intdaty_dv int_year

* Interview month (same as in wave 3)
tempvar w3month
egen `w3month' = mean(intdatm_dv), by(id)
replace intdatm_dv = `w3month' if missing(intdatm_dv)
rename intdatm_dv int_month

* Age (increment one year)
tempvar w3age
egen `w3age' = mean(age_dv), by(id)
replace age_dv = `w3age' + wave - 3 if missing(age_dv)
rename age_dv age

* Gender
gen male = sex == 1 if sex > 0

* Ethnicity (fill in to missing years)
bysort id (wave): replace ethn_dv = ethn_dv[_n - 1] ///
	if missing(ethn_dv) & !missing(ethn_dv[_n - 1])
tempvar negwave
gen `negwave' = -wave
bysort id (`negwave'): replace ethn_dv = ethn_dv[_n - 1] ///
	if missing(ethn_dv) & !missing(ethn_dv[_n - 1])
	
* Degree indicator
gen degree = hiqual_dv == 1 if !missing(hiqual_dv) & hiqual_dv > 0
egen ever_degree = max(degree), by(id)

* Income (interval bounds)
split fimngrs_dv, gen(income) parse(- " or ") limit(2) destring force

* Earnings (interval bounds)
split fimnlabgrs_dv, gen(earn) parse(- " or ") limit(2) destring force

* Work hours (interval bounds)
split jbhrs_dv, gen(hours) parse(- " or ") limit(2) destring force
replace hours2 = 4 if hours1 == 0 & missing(hours2)

// * The earnings bins have a "gap" around zero. The first group is (-inf; 0]
// * and the second group is [0.01; 94), i.e., theoretically there is a gap
// * between (0, 0.01). Practically, it's unlikely that anyone has earnings
// * or income in this range. But setting the upper limit to 0.01 makes it 
// * easier to take log.
// replace earn2 = 0.01 if earn2 == 0
// replace income2 = 0.01 if income2 == 0

* Compute hourly wage based on hours mid-point
egen hours_mid = rowmean(hours1 hours2)
label var hours_mid "Mid-point of usual weekly hours bin"

gen hwage1 = earn1 / (4 * hours_mid)
gen hwage2 = earn2 / (4 * hours_mid)
label var hwage1 "Hourly wage (lower bound)"
label var hwage2 "Hourly wage (upper bound)"

**## Deflate earnings and income 
* Load the CPI data
frame create cpi
frame cpi: use 01_Data/cpic, clear

* Merge working data with CPI index
frlink m:1 int_year int_month, frame(cpi year month) gen(cpilink)
frget cpi = cpic, from(cpilink)

* Deflate the interval thresholds
foreach var of varlist income? earn? hwage? {
	gen r`var' = `var' / cpi * 100
}

* Take log of thresholds
foreach var of varlist income? earn? hwage? {
	gen ln`var' = ln(r`var')
}

**## Working sample
* Remove missing observations
drop if missing(lnhwage1) & missing(lnhwage2)

* Remove observations where hours worked are less than 25 hours
drop if hours_mid < 25

* Remove observations with wages above top-coded limit
drop if hwage2 > 100000 / 12 / (25 * 4) & !missing(hwage2)

* Remove observations at ages below 20 or above 65
drop if age < 20 | age > 65

* Born between 1946 and 1990
keep if inrange(yob, 1946, 1990)

**************************************************************************
**# Predicted earnings
**************************************************************************
* Load estimation results from the full survey data
estimates use 04_Results/earn_profile_est
eststo est_wage

* Extract FE moments
global fe_mean = e(fe_mean_gtp)
global fe_var = e(fe_var_gtp)
global eps_var = e(eps_var_gtp)

* Generate fitted values
gen yhat = _b[_cons]
forvalues a = 20/65 {
	if !inrange(`a', 51, 60) {
		replace yhat = yhat + ///
			_b[`a'.age_dv] + ///
			_b[`a'.age_dv#1.male] * male + ///
			_b[`a'.age_dv#1.college] * ever_degree + ///
			_b[`a'.age_dv#1.male#1.college] * male * ever_degree ///
			if age == `a'
	}
}

gen yhat_time = yhat
forvalues y = 2010/2022 {
	replace yhat_time = yhat_time + _b[`y'.int_year] ///
		if int_year == `y'
}

* Fit interval regression with random effect latent variable
gsem lnhwage1 <- yhat_time@1 RE[id]@1, ///
	nocons family(gaussian, udepvar(lnhwage2)) ///
	var(RE[id]@${fe_var}) mean(RE[id]@${fe_mean_gtp}) ///
	var(e.lnhwage1@${eps_var})

* Predict the random effect latent variable
tempvar temp_re
predict `temp_re' if e(sample), latent(RE[id])
egen re_fit = mean(`temp_re'), by(id)

* I restricted the predictions above to only those observations that were
* used in the estimation. Thus, no random effect prediction is made if
* a) an individual was never observed with positive earnings between ages 
* 	 18 and 65, or
* b) any covariate was missing (in this case only degree may be missing)
* These individuals would not have had FE predicted if we had observed 
* actual earnings and fitted FE regression.

* All in all there are 7695 observations that have missing RE predictions.
* This corresponds to 1148 individuals without RE.
count if missing(re_fit)
tab wave if missing(re_fit)

**## Sanity checks for RE ----
bysort id (wave): gen timeobs = _n

* Distribution
graph twoway (hist re_fit, width(0.1) fcolor(%50)) ///
	(function norm = normalden(x, ${fe_mean}, sqrt(${fe_var})), ///
		range(-4 2)) ///
	if timeobs == 1, ///
	legend(order(1 "Predicted RE" 2 "Theoretical normal density") ///
		rows(1) position(6))

* Correlations
est restore est_wage
mat corr_comp = J(5, 3, .)
mat colnames corr_comp = full genotyped metadac
mat rownames corr_comp = male age college lrearn_ln lrearn_ub

mat corr_comp[1, 1] = e(fe_corr_male_full)
mat corr_comp[2, 1] = e(fe_corr_age_dv_full)
mat corr_comp[3, 1] = e(fe_corr_college_full)
mat corr_comp[4, 1] = e(fe_corr_lrearn_full)
mat corr_comp[5, 1] = e(fe_corr_lrearn_full)

mat corr_comp[1, 2] = e(fe_corr_male_gtp)
mat corr_comp[2, 2] = e(fe_corr_age_dv_gtp)
mat corr_comp[3, 2] = e(fe_corr_college_gtp)
mat corr_comp[4, 2] = e(fe_corr_lrearn_gtp)
mat corr_comp[5, 2] = e(fe_corr_lrearn_gtp)

corr re_fit male if timeobs == 1
mat corr_comp[1, 3] = r(rho)
corr re_fit age if timeobs == 1
mat corr_comp[2, 3] = r(rho)
corr re_fit ever_degree if timeobs == 1
mat corr_comp[3, 3] = r(rho)
corr re_fit lnearn1
mat corr_comp[4, 3] = r(rho)
corr re_fit lnearn2
mat corr_comp[5, 3] = r(rho)

mat list corr_comp

**## Predicted lifetime earnings ----
* Copy the selected variables to cross-sectional frame
frame put id male ever_degree re_fit, into(pred_earn)
frame change pred_earn
duplicates drop

* Remove observations with missing RE
drop if missing(re_fit)

* Remove observations with missing covariates
drop if missing(male)
drop if missing(ever_degree)

* Generate predicted earnings at each age between 18 and 65
est restore est_wage
forvalues a = 20/65 {
	if inrange(`a', 51, 60) {
		gen lwage_hat_`a' = _b[_cons] + re_fit
	}
	else {
		gen lwage_hat_`a' = _b[_cons] + re_fit + ///
			_b[`a'.age_dv] + ///
			_b[`a'.age_dv#1.male] * male + ///
			_b[`a'.age_dv#1.college] * ever_degree + ///
			_b[`a'.age_dv#1.male#1.college] * male * ever_degree
	}
	gen earn_hat_`a' = exp(lwage_hat_`a') * 22 * 8
}

mean lwage_hat*, over(male ever_degree)
marginsplot, plotdimension(ever_degree) bydimension(male) xtitle(Age - 20)

* Compute discounted lifetime earnings
global dpv_exp earn_hat_20 * 12
forvalues a = 21/65 {
	global dpv_exp $dpv_exp + earn_hat_`a' * 12 * (${delta})^(`a' - 20)
}
gen dpv_earn_hat = $dpv_exp

* Save the dataset
save 01_Data/predicted_earnings, replace

/***## Correlations ----
* Merge other characteristics from phenotype table
frame create pheno
frame pheno: use data/pheno, clear

frlink 1:1 id, frame(pheno IID)
frget gscore_std yob, from(pheno)

gen cohort5 = floor(yob / 5) * 5
label var cohort5 "Cohort"

* Simple regressions
poisson dpv_earn_hat male ever_degree i.cohort5
est store simple_earn_mdac

est use results/simple_earn_poisson_full
est store simple_earn_full

est use results/simple_earn_poisson_fullgen
est store simple_earn_fullgen

esttab simple_earn_full simple_earn_fullgen simple_earn_mdac, ///
	b(3) se(3) nobase ///
	rename(ever_degree college) varlabels(1945.cohort5 1945 1950.cohort5 1950 ///
		1955.cohort5 1955 1960.cohort5 1960 1965.cohort5 1965 1970.cohort5 1970 ///
		1975.cohort5 1975 1980.cohort5 1980 1985.cohort5 1985 1990.cohort5 1990) ///
	refcat(1950.cohort5 "Birth cohort", nolabel) ///
	mlabels("All" "Genotyped" "") mgroups("Full sample" "METADAC", pattern(1 0 1))

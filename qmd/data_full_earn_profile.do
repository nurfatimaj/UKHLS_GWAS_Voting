**************************************************************************
************************* CREATE WORKING DATA ****************************
**************************************************************************
* This do file estimates the wage profile from the full survey dataset. 
* This is later used to construct predicted lifetime earnings in the 
* genotyped sample. 

* INPUTS: 
* 1. Understanding Society dataset
* 	 can be downloaded from the ukdataservice.ac.uk website; requires EUL
* 	 set data_path global to the location of the downloaded folder
* 2. ONS CPI index excl. rent, maintenance 
* 	 the excel table is downloaded and converted to Stata dataset in 
* 	 analysis/data_ons_cpi.do. The output is saved in data/cpic.dta.
* 
* OUTPUTS:
* 1. Estimation result saved in data/earn_profile_est.ster

**************************************************************************
**# Set the paths 
**************************************************************************
clear all
frame reset
capture log close _all

* Folders
global current_user `c(username)'
if "$current_user" == "nurfatimaj" {
	global datapath "~/Dropbox/Research/Data/UKDS/UKHLS/stata/stata13_se/"
	global projpath "~/Google Drive/My Drive/Research/GWAS Political Data"
}
else if "$current_user" == "rusti001" {
	global data_path "/Users/rusti001/Library/CloudStorage/Dropbox/UKHLS/stata/stata13_se"
	global projpath  "/Users/rusti001/Library/CloudStorage/GoogleDrive-rusti001@umn.edu/My Drive/AResearch/GWAS Political Data"
}
else if "$current_user" == "aldorustichini" {
	global datapath "~/Dropbox/UKHLS/stata/stata13_se"
	global projpath ""
}
else if "`c(username)'" == "pknuja" {
	global datapath "~/Dropbox/Research/Data/UKDS/UKHLS/stata/stata13_se"
	global projpath "~/Google Drive/My Drive/Research/GWAS Political Data"
}
else {
	di as error "Unknown user $current_user"
	exit
}

cd "$projpath"

* Logging
log using 10_Logs/03_Analysis/data_full_earn_profile.txt, text replace

**************************************************************************
**# Load original data 
**************************************************************************
* Use waves 2 and 3 dataset as the base
use "${datapath}/ukhls/c_indresp.dta", clear
merge 1:1 pidp using ${datapath}/ukhls/b_indresp, ///
	keep(1 2 3) nogen keepusing(*_lw *_xw b_strata b_psu)

* Load the cross-sectional dataset into separate frame
frame create xwave
frame xwave: use "${datapath}/ukhls/xwavedat", clear

* Merge extra variables from other waves
global ukhls_last_wave 12
global vars2merge ?_fimnlabgrs_dv ?_fimnlabnet_dv ?_jbhrs ?_jshrs ///
	?_hiqual_dv ?_age_dv ?_intdaty_dv ?_istrtdaty ?_intdatm_dv ?_istrtdatm
	
forvalues w = 1/$ukhls_last_wave {
	* Skip third wave (alread loaded)
	if `w' == 3 continue
	
	* Find letter prefix of the wave
	local wl: word `w' of `c(alpha)'
	
	* Merge
	if `w' == 1 {
		merge 1:1 pidp using ${datapath}/ukhls/`wl'_indresp, ///
			keep(1 3) nogen keepusing(${vars2merge} *_xw)
	}
	else {
		merge 1:1 pidp using ${datapath}/ukhls/`wl'_indresp, ///
			keep(1 3) nogen keepusing(${vars2merge} *_xw *_lw)
	}
}

* Load the CPI data into separate frame
frame create cpi
frame cpi: use 01_Data/cpic, clear

* Declare survey structure
egen weight = rowlast(b_indinub_xw c_indinub_xw)
egen strata = rowlast(b_strata c_strata)
egen psu = rowlast(b_psu c_psu)
svyset psu [pw = weight], strata(strata) singleunit(scaled)

**************************************************************************
**# Create baisc variables
**************************************************************************
**### Wave info ----------------------------------------------------------
forvalues w = 1/$ukhls_last_wave {
	* Find letter prefix of the wave
	local wl: word `w' of `c(alpha)'
	
	* Interview year
	gen `wl'_int_year = `wl'_intdaty_dv
	qui replace `wl'_int_year = `wl'_istrtdaty ///
		if  (`wl'_int_year < 0 | missing(`wl'_int_year)) & ///
			(`wl'_istrtdaty > 0 & !missing(`wl'_istrtdaty))
			
	* Interview month
	gen `wl'_int_month = `wl'_intdatm_dv
	qui replace `wl'_int_month = `wl'_istrtdatm ///
		if  (`wl'_int_month < 0 | missing(`wl'_int_month)) & ///
			(`wl'_istrtdatm > 0 & !missing(`wl'_istrtdatm))
}

**### Socio-demographic variables ----------------------------------------
* Gender
gen male = c_sex == 1
label def male 0 "Female" 1 "Male"
label values male male
label var male "Male indicator"

* Year of birth
gen yob = c_doby_dv
replace yob = c_birth if c_doby_dv < 0
label var yob "Year of birth"

* Cohort groups (in 15-year bins)
egen cohort = cut(yob), at(1890(15)2015)
label var cohort "15-year birth cohort"

* Age
forvalues w = 1/$ukhls_last_wave {
	* Find letter prefix of the wave
	local wl: word `w' of `c(alpha)'
	
	* Impute age from yob and interview year if age is missing
	replace `wl'_age_dv = `wl'_int_year - yob if `wl'_age_dv < 0 | missing(`wl'_age_dv)
}

* Highest and lowest age observed in survey
egen age_max = rowmax(?_age_dv)
egen age_min = rowmin(?_age_dv)

**### Education -----------------------------------------------------------
* Recode the missing values to Stata format
foreach var of varlist ?_hiqual_dv {
	foreach mv in 1 2 7 8 9 10 11 20 21 {
		* Get the corresponding letter of the alphabet
		local mvl : word `mv' of `c(alpha)'
		
		* Recode missing value
		qui replace `var' = .`mvl' if `var' == -`mv'
	}	
}

* Highest qualification across waves
egen hiqual_dv = rowmin(?_hiqual_dv)
label values hiqual_dv c_hiqual_dv
label var hiqual_dv "Highest qualification in ${ukhls_last_wave} waves"

* Degree indicator
gen college = hiqual_dv == 1 if !missing(hiqual_dv)
label def college 0 "No degree" 1 "Degree"
label values college college
label var college "Degree indicator"

egen ever_college = max(college), by(pidp)

**### Labour market -------------------------------------------------------
forvalues w = 1/$ukhls_last_wave {
	* Find letter prefix of the wave
	local wl: word `w' of `c(alpha)'
	
	* Hours worked (combine employed and self-employed info)
	egen `wl'_hours = rowmax(`wl'_jbhrs `wl'_jshrs)
	label var `wl'_hours "Usual hours worked in a week"
	
	* Recode missing values to Stata format
	foreach mv in 1 2 7 8 9 10 11 20 21 {
		* Get the corresponding letter of the alphabet
		local mvl : word `mv' of `c(alpha)'
		
		* Recode missing value
		qui replace `wl'_hours = .`mvl' if `wl'_hours == -`mv'
	}
	
	* Compute hourly wages
	gen `wl'_hwage = `wl'_fimnlabgrs_dv / (4 * `wl'_hours)
	label var `wl'_hwage "Hourly wages (nominal)"
	
	* Merge with corresponding CPI index
	frlink m:1 `wl'_int_year `wl'_int_month, frame(cpi year month) gen(`wl'_cpilink)
	frget `wl'_cpi = cpic, from(`wl'_cpilink)
	
	* Deflate earnings and hourly wages
	gen `wl'_rearn = `wl'_fimnlabgrs_dv / `wl'_cpi * 100
	gen `wl'_hrwage = `wl'_hwage / `wl'_cpi * 100
	label var `wl'_rearn "Monthly earnings (real)"
	label var `wl'_hrwage "Hourly wages (real)"
	
	* Create log real earnings and log real wages
	gen `wl'_lrearn = log(`wl'_rearn)
	gen `wl'_lrwage = log(`wl'_hrwage)
	label var `wl'_lrearn "Log real monthly earnings"
	label var `wl'_lrwage "Log real hourly wages"
}

* Keep only selected variables
keep pidp psu strata weight *_int_year *_int_month ///
	yob cohort *_age_dv male ///
	college ever_college *_hrwage *_lrwage *_hours *_hwage *_lrearn
	
* Merge genotyped indicator from cross-wave table
frlink m:1 pidp, frame(xwave)
frget genetics, from(xwave)

**************************************************************************
**# Filter sample
**************************************************************************
* Born between 1950 and 1994
keep if inrange(yob, 1945, 1994)

* Non-missing highest qualification
keep if !missing(college)

* Observed at least once between ages 25 and 65
// keep if age_max >= 25 & age_min <= 65

**************************************************************************
**# Predicted wages
**************************************************************************
* Reshape data to long
reshape long @int_year @int_month @age_dv ///
	@hwage @hrwage @lrwage @hours @lrearn, ///
	i(pidp) j(wavestring) string

* Clean up wave information
replace wavestring = substr(wavestring, 1, 1)
encode wavestring, gen(wave)

* Remove missing observations
drop if missing(int_year) | missing(lrwage)

* Remove observations where hours worked are less than 25 hours
drop if hours < 25

* Remove observations with wages above top-coded limit
drop if hwage > 100000 / 12 / (25 * 4)

* Remove observations at ages below 18 or above 65
drop if age_dv < 20 | age_dv > 65

* Declare data to be panel
xtset pidp wave

* Run FE estimation
xtreg lrwage i(20/50)bn.age_dv i(61/65)bn.age_dv ///
	(i(20/50)bn.age_dv i(61/65)bn.age_dv)#(male college) ///
	(i(20/50)bn.age_dv i(61/65)bn.age_dv)#male#college ///
	i.int_year [pw = weight], fe
est sto wage_reg

* Predicted individual fixed effects
predict comp_err, ue
egen fe = mean(comp_err), by(pidp)
gen eps = comp_err - fe

* Compute mean and variance of individual fixed effect
bysort pidp (wave): gen timeobs = _n
svy: mean fe if timeobs == 1
estat sd
global fe_mean_full = r(mean)[1, 1]
global fe_var_full = r(variance)[1, 1]

* Add the moments into estimation to be saved
est restore wage_reg
estadd scalar fe_mean_full = $fe_mean_full
estadd scalar fe_var_full = $fe_var_full

* Compute mean and variance of individual FE in the genotyped subsample
svy, subpop(genetics): mean fe if timeobs == 1
estat sd
global fe_mean_gtp = r(mean)[1, 1]
global fe_var_gtp = r(variance)[1, 1]

* Add the moments into estimation to be saved
est restore wage_reg
estadd scalar fe_mean_gtp = $fe_mean_gtp
estadd scalar fe_var_gtp = $fe_var_gtp

* Similar steps for the error term
svy: mean eps
estat sd
global eps_mean_full = r(mean)[1, 1]
global eps_var_full = r(variance)[1, 1]

svy, subpop(genetics): mean eps
estat sd
global eps_mean_gtp = r(mean)[1, 1]
global eps_var_gtp = r(variance)[1, 1]

est restore wage_reg
estadd scalar eps_mean_full = $eps_mean_full
estadd scalar eps_var_full = $eps_var_full
estadd scalar eps_mean_gtp = $eps_mean_gtp
estadd scalar eps_var_gtp = $eps_var_gtp

* Add a few correlation measures
foreach var of varlist male age college {
	corr fe `var' if timeobs == 1 [aw = weight]
	global corr_fe_`var'_full = r(rho)
	
	corr fe `var' if timeobs == 1 & genetics == 1 [aw = weight]
	global corr_fe_`var'_gtp = r(rho)
	
	est restore wage_reg
	estadd scalar fe_corr_`var'_full = ${corr_fe_`var'_full}
	estadd scalar fe_corr_`var'_gtp = ${corr_fe_`var'_gtp}
}

corr fe lrearn [aw = weight]
global corr_fe_lrearn_full = r(rho)

corr fe lrearn if genetics == 1 [aw = weight]
global corr_fe_lrearn_gtp = r(rho)

est restore wage_reg
estadd scalar fe_corr_lrearn_full = $corr_fe_lrearn_full
estadd scalar fe_corr_lrearn_gtp = $corr_fe_lrearn_gtp

* Save the estimation to disk
est restore wage_reg
estimates save 04_Results/earn_profile_est, replace

graph twoway (hist fe, fcolor(blue%20) width(0.1)) ///
	(hist fe if genetics == 1, fcolor(red%50) width(0.1)) ///
	(function norm = normalden(x, $fe_mean_gtp, sqrt(${fe_var_gtp})), ///
		range(-10 5)) ///
	if timeobs == 1, ///
	legend(order(1 "FE full sample" 2 "FE genotyped subsample" ///
		3 "Theoretical density") position(6) rows(1))
	
**## Generate DPV predicted earnings ----
frame put pidp yob male college weight psu strata genetics fe, ///
	into(pred_earn)
frame change pred_earn
duplicates drop

* Remove observations with missing RE
drop if missing(fe)

* Remove observations with missing covariates
drop if missing(male)
drop if missing(college)

* Generate predicted earnings at each age between 18 and 65
est restore wage_reg
forvalues a = 20/65 {
	if inrange(`a', 51, 60) {
		gen lwage_hat_`a' = _b[_cons] + fe
	}
	else {
		gen lwage_hat_`a' = _b[_cons] + fe + ///
			_b[`a'.age_dv] + ///
			_b[`a'.age_dv#1.male] * male + ///
			_b[`a'.age_dv#1.college] * college + ///
			_b[`a'.age_dv#1.male#1.college] * male * college
	}
	gen earn_hat_`a' = exp(lwage_hat_`a') * 22 * 8
}

mean lwage_hat*, over(male college)
marginsplot, plotdimension(college) bydimension(male) xtitle(Age - 17)

* Compute discounted lifetime earnings
global delta 0.93
global dpv_exp earn_hat_20 * 12
forvalues a = 21/65 {
	global dpv_exp $dpv_exp + earn_hat_`a' * 12 * (${delta})^(`a' - 18)
}
gen dpv_earn_hat = $dpv_exp

gen cohort5 = floor(yob / 5) * 5

* Simple regression
poisson dpv_earn_hat male college i.cohort5
est store simple_earn_full
estimates save 04_Results/simple_earn_poisson_full, replace

poisson dpv_earn_hat male college i.cohort5 if genetics == 1
est store simple_earn_fullgen
estimate save 04_Results/simple_earn_poisson_fullgen, replace

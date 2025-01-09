***************************************************************************
***************************** READ CPI DATA *******************************
***************************************************************************
* This do file reads the CPI data from the excel table published by the ONS.
* Original table can be downloaded here:
* https://www.ons.gov.uk/file?uri=/economy/inflationandpriceindices/adhocs/14926consumerpriceindicesseriesexcludingrentsmaintenancerepairsandwaterchargesfortheperiodjanuary1996tojune2022/cpiseriesexcludingrentsmaintenancerepairsandwaterchargesfortheperiodjanuary1996tojune2022.xls

***************************************************************************
**# Set the paths 
***************************************************************************

clear all
frame reset

* Folders
global current_user `c(username)'
if "$current_user" == "nurfatimaj" {
	global projpath "~/Google Drive/My Drive/Research/GWAS Political Data"
}
else if "$current_user" == "rusti001" {
	global projpath ""
}
else if "$current_user" == "aldorustichini" {
	global projpath ""
}
else {
	di as error "Unknown user $current_user"
	exit
}

* Working directory
cd "$projpath"

* File path
global ons_url "https://www.ons.gov.uk/file?uri=/economy/inflationandpriceindices/adhocs/14926consumerpriceindicesseriesexcludingrentsmaintenancerepairsandwaterchargesfortheperiodjanuary1996tojune2022"
global ons_filename "cpiseriesexcludingrentsmaintenancerepairsandwaterchargesfortheperiodjanuary1996tojune2022.xls"

***************************************************************************
**# Load original data 
***************************************************************************
* Copy excel table from the url to disk
copy "${ons_url}/${ons_filename}" data/$ons_filename, public replace

* Read the excel file
import excel using data/$ons_filename, describe
import excel using data/$ons_filename, sheet("1a") cellrange(A1:B319) ///
	firstrow case(lower) clear

***************************************************************************
**# Format variables
***************************************************************************
gen year = floor(indexdate / 100)
gen month = (indexdate / 100 - year) * 100

* Rename CPI variable
rename cpiindex2015100 cpic

* Keep only clean variables
keep year month cpic

***************************************************************************
**# Save to disk
***************************************************************************
save data/cpic, replace

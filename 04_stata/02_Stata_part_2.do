* PIP Canazei 2025
* Part 2
* Author: Samuel Kofi Tetteh-Baah (stettehbaah@worldbank.org)
* Edited by: Giorgia Cecchinato (gcecchinato@worldbank.org)

// Set-Up
clear all
set more off
// You need to have pip installed! See 01_Stata_part_1.do for details

* 1. Introduction
// See R Quarto Document or Slides for lecture notes.
// Most (almost all) visualizations are also done in R. Sorry!
// The final exercise are only in R.

* 2. Replicate PIP Data for Nigeria (Survey Years)

//////////////////////////////////////////////////////////////////////
/////////  Replicate survey-year poverty estimates for Nigeria //////
//////////////////////////////////////////////////////////////////////
// Sole Author: Samuel Kofi Tetteh-Baah.

** 2.1 Version 1: Using percentiles

/*
How to access percentile data for the survey years
1/ Go to https://pip.worldbank.org/home
2/ Go to Data
3/ Go to Percentiles
4/ Download percentile data expressed in 2017 PPP dollars for the survey years
*/

// Obtain headcount rates in PIP (target values)
pip, clear country(NGA) 
tab year
keep country_code year headcount 
rename headcount hc_pip
isid country_code year 

tempfile hc_pip 
save `hc_pip'

// Obtain data on percentiles (change to right directory)
use "world_100bin.dta", clear 
keep if country_code=="NGA" 
tab year
br 
// Combine data
merge m:1 country_code year using `hc_pip', nogen 
sort country_code year percentile 

// Generate indicator for being poor 
gen poor = (avg_welfare<2.15)
bysort country_code year: egen hc_own = wtmean(poor),weight(pop_share)

collapse (mean) hc_pip (mean) hc_own, by(country_code year)
list 

// Round to the nearest whole number 
replace hc_pip = round(100*hc_pip)
replace hc_own = round(100*hc_own)
list 

** 2.2 Version 2: Using actual microdata

// Obtain headcount rates in PIP (target values)
pip, clear country(NGA) year(last)
tab year
keep country_code year headcount 
rename headcount hc_pip
isid country_code year 

tempfile hc_pip 
save `hc_pip'

// Obtain CPI data
pip tables, table(cpi) clear
rename value cpi
keep country_code year cpi
keep if year==2018
keep if country_code=="NGA"
tempfile cpi 
save `cpi'

// Obtain PPP data
pip tables, table(ppp) clear
rename value ppp
keep country_code ppp
keep if country_code=="NGA"
tempfile ppp 
save `ppp'

// Obtain survey data (you do not have access to this file! See Quarto doc for details)
use "NGA2018.dta", clear
tab year

// Combine data 
merge m:1 country_code year using `cpi', keep(match) nogen 
merge m:1 country_code  using `ppp', keep(match) nogen

// Keep only relevant data 
keep country_code welfare cpi ppp weight year

// Express annual household consumption into daily per capita PPP terms 
gen welf_ppp = welfare * (1/cpi) * (1/ppp) * (1/365)

// Generate a dummy to identify the extreme poor 
gen poor = (welf_ppp<=2.15)

// Compute poverty rate
sum poor [aw=weight]

collapse (mean) poor [aw=weight],by(country_code year)
rename poor hc_own 

merge 1:1 country_code year using `hc_pip', nogen 

// Check if replication was successful 
gen double d_hc = hc_pip/hc_own 
list 

/* Source of PPP data */ 
* Go to https://datanalytics.worldbank.org/PIP-Methodology/convert.html#PPPs
* These PPP data are stored in PIP auxiliary tables. Retrieve these PPPs using [pip tables, clear] and click on the table [ppp]

/* Source of CPI data */ 
*Go to https://datanalytics.worldbank.org/PIP-Methodology/convert.html#CPIs
* These CPI data are stored in PIP auxiliary tables. Retrieve these CPI using [pip tables, clear] and click on the table [cpi]


* 3. Replicate PIP Data for Nigeria (Reference Years)

//////////////////////////////////////////////////////////////////////
/////////Replicate reference-year poverty estimates for Nigeria //////
//////////////////////////////////////////////////////////////////////
// Sole Author: Samuel Kofi Tetteh-Baah.

//Refresh PIP ado
pip cleanup 
global country_code "NGA"

//Load survey poverty estimates 
tempname pip
frame create `pip'
frame `pip' {
  pip, country(${country_code}) clear coverage(national)
  decode welfare_type, gen(wt)
  
}

// Merge with pip results
/* Note the use of [pip tables, clear]  */
pip tables, table(interpolated_means) clear 
keep if country_code=="NGA" 
br  
frlink m:1  country_code welfare_time welfare_type, ///
  frame(`pip' country_code welfare_time wt)

//Poverty line to query
gen double pl_to_query = 2.15 * frval(`pip', mean)/predicted_mean_ppp
keep if pl_to_query  < .

//Weights for interpolated means
gen double interpol_wt   = 1 / abs(welfare_time - year)
egen double interpol_wtt = total(interpol_wt),by(year)
gen double interpol_shr  = interpol_wt/interpol_wtt
gen double survey_year   = floor(welfare_time)  
sort country_code year welfare_time 

keep if inrange(year, 2015, 2020)  // modify to take less time
//Initialize empty data set to store results
tempname results dtloop
frame create `results' str3 country_code double(year hc wgt)
frame copy `c(frame)' `dtloop'
local N = _N
forvalues row=1/`N' {
  
  loc ccc  = _frval(`dtloop', country_code, `row')
  loc yy   = _frval(`dtloop', year, `row')
  loc yyyy = _frval(`dtloop', survey_year, `row')
  loc pl   = _frval(`dtloop', pl_to_query, `row')
  loc wgt  = _frval(`dtloop', interpol_shr, `row')
  
  pip, clear country(`ccc') year(`yyyy') coverage(national) povline(`pl')
  frame post `results' ("`ccc'") (`yy') (headcount[1]) (`wgt')
}

//Apply weights for interpolated poverty estimates
frame `results': collapse  (mean) headcount=hc [w = wgt], by( country_code year)

//Check results 
pip, clear country(${country_code}) fillgaps
keep country_code year headcount
rename headcount hc_target 
frlink 1:1 country_code year, frame(`results')
gen double d_hc = hc_target/frval(`results', headcount, .a)
sum d_hc 




* 4. Estimate Global and Regional Poverty

///////////////////////////////////////////////////////////////////////////
/////////    Replicate regional and global poverty estimates    ///////////
///////////////////////////////////////////////////////////////////////////
// Sole Author: Samuel Kofi Tetteh-Baah.

// Obtain population numbers
pip tables, table(pop) clear  
rename data_level reporting_level 
rename value pop 
keep if reporting_level=="national" | inlist(country_code,"ARG") 
keep if inrange(year,1990,2022)
isid country_code year reporting_level

tempfile pop 
save `pop'

// Obtain country and regional list 
pip tables, table(country_list) clear  
keep region_code region country_code country_name africa_split africa_split_code
rename region region_name  

tempfile countrylist 
save `countrylist'

use `pop', clear
list

// Obtain reference-year poverty estimates
pip, clear fillgaps  
keep country_code year reporting_level headcount 
keep if reporting_level=="national" | inlist(country_code,"ARG") 
keep if inrange(year,1990,2022)
isid country_code year 
rename headcount hc 

// Combine data sets
merge 1:1 country_code year reporting_level using `pop', nogen 
merge m:1 country_code using `countrylist', nogen 

sort country_code year reporting_level

// Get Africa split
preserve 
	keep if inlist(africa_split_code,"AFW","AFE")
	replace region_code = africa_split_code
	gen subregion = 1
	replace region_name = africa_split

	tempfile subreg 
	save `subreg'
restore 

// Append data for Eastern and Southern Africa (AFE) and Western and Central Africa (AFW)
append using `subreg'

// Estimate regional poverty estimates

/* Install wtmean function. Use code below. */
// findit wtmean 

bysort region_code year: egen hc_reg_avg = wtmean(hc),weight(pop)

// For Sub-Saharan Africa split assign overall SSA average to countries with missing data
egen hc_reg_avg_ssa_ = mean(hc_reg_avg) if region_code=="SSA",by(region_code year)
egen hc_reg_avg_ssa = mean(hc_reg_avg_ssa_ ),by(year)
replace hc_reg_avg = hc_reg_avg_ssa if subregion==1

// Assign countries with missing data regional poverty rate
replace hc = hc_reg_avg if missing(hc)&!missing(hc_reg_avg)

drop if inlist(country_code,"ARG") & reporting_level=="national"

// Estimate global poverty
preserve 
drop if subregion==1    // removes duplicates of African countries
	collapse (mean) hc (rawsum) pop [aw=pop],by(year)
	gen region_code = "WLD"
	gen region_name = "World"

	tempfile wld 
	save `wld'
restore 

// Estimate regional poverty rates
collapse (mean) hc (rawsum) pop [aw=pop],by(region_code region_name year)

// Pool together regional and global poverty estimates
append using `wld'

// Rename variables as own 
rename hc hc_own

tempfile hc_own 
save `hc_own'

// Get regional aggregates already calculated in PIP
pip wb, clear  
keep region_code region_name year headcount 
rename headcount hc_pip  // renames variable of interest as estimates from PIP (these are the target estimates)

drop if year<1990 

// Combine data sets
merge 1:1 region_code year using `hc_own'
tab _merge 
drop _merge   

// Check replication 
gen double d_hc = hc_pip/hc_own 
sum d_hc 
assert round(`r(mean)') == 1
drop d_hc



* 5. Calculate the international poverty line

///////////////////////////////////////////////////////////////////////
/////////// I. Derive the international poverty line (IPL) /////////////
////////////////////////////////////////////////////////////////////////
// Sole Author: Samuel Kofi Tetteh-Baah.

/* Goal: Illustrate the use of the [popshare] option in the pip command */

// Create empty data set to save harmonized national poverty lines
capture erase "harmonized_npl.dta"
drop _all
save "harmonized_npl.dta", empty

// Load compiled national poverty rates for low-income countries (change to correct directory)
use "national_poverty_rates_lic.dta", clear
browse 
qui count
local totalobs = `r(N)'

// Loop through all surveys-years 
forvalues obs=1/`totalobs' {

// Display what countries are being processed at the moment
disp in red "Number completed: `obs'"
disp in red "Share completed: `=round(`obs'/`totalobs'*100,0.1)'%"

use	"data/national_poverty_rates_lic", clear
local hc = headcount_nat[`obs']
local cc = country_code[`obs']
local yr = year[`obs']
local wt = welfare_type[`obs']

// Query PIP
pip, clear country(`cc') year(all) popshare(`hc') /*${pip_version}*/
keep if year==`yr' & welfare_type==`wt'
keep country_code region_code year welfare_time headcount poverty_line reporting_level welfare_type
rename poverty_line harm_npl
lab var harm_npl "Harmonized national poverty line"
sleep 500
append using "data/harmonized_npl.dta"
sleep 500
save "harmonized_npl.dta", replace
}

// Obtain the median value of harmonized national poverty line
use "harmonized_npl.dta", clear
egen ipl = median(harm_npl)
tab ipl 
lab var ipl "International poverty line (2017 PPP dollars)"


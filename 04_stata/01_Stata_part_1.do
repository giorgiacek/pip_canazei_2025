* PIP Canazei 2025
* Part 1
* Author: Samuel Kofi Tetteh-Baah (stettehbaah@worldbank.org)
* Edited by: Giorgia Cecchinato (gcecchinato@worldbank.org)

// Set-Up
clear all
set more off

* 1. Introduction
// See R Quarto Document or Slides for lecture notes.
// Most (almost all) visualizations are also done in R. Sorry!


* 2. Accessing PIP in R
// Lastest version of PIP data - March 2024
global pip_version = "server(prod) version(20240326_2017_01_02_PROD)"   


// Install PIP - Approach 1 (from SSC)

/* 
Advantage	: Loads more stable version of PIP.
Disadvantage: Loads a less recent version of PIP.
*/
 
capture ssc uninstall pip  // uninstalls PIP
ssc install pip  
which pip // checks which version of PIP is installed (see first line in the Results window)

// Install PIP - Approach 2 (from GitHub)

/*
Advantage	: Loads a more recent version of PIP
Disadvantage: It may be a version under development, so may be less stable and more likely to have bugs
*/

// Load most recent version
capture ssc uninstall pip  // uninstalls PIP
*net install github, from("https://haghish.github.io/github/")
github install worldbank/pip    // installs most recent version 
which pip 

// Load a specified version
ssc uninstall pip  // uninstalls PIP
github install worldbank/pip, version(0.3.8) // installs a specified version
which pip 

// Go to https://worldbank.github.io/pip/

ssc uninstall pip  // uninstalls PIP
github install worldbank/pip, version(0.10.7.9003) // installs a specified version
which pip 

 
// Obtain complete overview of the functionality of the Stata PIP wrapper, with many examples
help pip 



* 3. County-level estimates

// Default line of code  (the default poverty line is $2.15 (2017 PPP)-- i.e. the international poverty line)
pip, clear  


// What is the dimension of the current version of PIP data?
// + List of variables
describe

// Auxiliary data list of tables:
pip tables

// Example with one table:
pip tables, table(gdp) clear

pip tables, table(incgrp_coverage) clear

// Estimates for a Country (Nigeria)
pip, country(NGA)
keep country_code country_name headcount gini poverty_line
br

// Estimates for a Country with given poverty line
pip, coutry(NGA) povline(1.9)
keep country_code country_name headcount gini poverty_line

// Estimates for a Country with multiple poverty lines
pip, country(NGA) povline(2.15 3.65)



* 4. Advanced Arguments

** 4.1 fillgaps (interpolated values)
pip, clear fillgaps

// Example with ALB:
pip, clear country(ALB) fillgaps    // loads survey-year estimates
keep country_code year poverty_line headcount estimate_type
keep if year > 2005
br

** 4.2 nowcasts (extrapolated values)
pip, clear nowcasts
keep country_code year poverty_line headcount estimate_type
keep if year > 2005
br


** 4.3 Popshare
pip, clear country(ALB) popshare(0.10)
keep country_code year poverty_line headcount
br

** 4.4 Comparability
// Example with CHN
pip, clear country(CHN)
keep if reporting_level == "national"
keep year headcount comparable_spell welfare_type
br

// Example with CHN and fillgaps: in Stata it produces an error!
pip, clear country(CHN) fillgaps
keep if reporting_level == "national"
keep year headcount comparable_spell welfare_type estimate_type // there is no comparable_spell variable
br 

* 5. Global and regional estimates

// Explore aggregated poverty data (regional)
pip wb, clear  
tab region_name
bysort region_name: tab year
br

// Global
pip wb, region_name(WLD)
br






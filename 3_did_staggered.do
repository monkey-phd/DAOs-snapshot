/********************************************************************
 0. Initial Setup and Data Preparation
********************************************************************/
clear all
set more off

* Adjust this path as needed
global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data"

use "$dao_folder/processed/panel_almost_full.dta", clear

// Optional: sample 30% for performance
set seed 123456
sample 0.3

/********************************************************************
 1. Prepare Data for DiD
********************************************************************/
// Identify the first treatment month per voter-space
bysort voter_id space_id (year_month_num): gen voting_change = 0
replace voting_change = 1 if type_single_choice[_n-1]==1 & type_single_choice==0 & _n>1

bysort voter_id space_id (year_month_num): egen treatment_time = min(year_month_num) if voting_change==1
bysort voter_id space_id: egen treatment_time_all = min(treatment_time)

// Shift treatment time forward by one month. Re-labels the shock month as the last pre-treatment month, and makes the actual 
// treatment start from the following month.
replace treatment_time_all = treatment_time_all + 1 if treatment_time_all < .

// Aggregate data to monthly level. Using (mean). 
// For treatment_time_all, use (min), a single scalar per unit.
collapse (mean) voted voter_tenure_space times_voted_space_cum relative_voting_power_act ///
         prps_len prps_choices met_quorum misaligned_c type_single_choice type_approval type_basic ///
         type_quadratic type_ranked_choice type_weighted (min) treatment_time_all, ///
    by(voter_id space_id year_month_num)

// Set panel structure
egen panel_id = group(voter_id space_id)
gen time = year_month_num
isid panel_id time
xtset panel_id time

/********************************************************************
 2. Run Staggered DiD with CSDID
********************************************************************/
// Create a lead variable for voted
by panel_id: gen voted_lead = voted[_n+1]
drop if missing(voted_lead)

// 'treatment_time_all' is lagged by one month to ensure proper identification.
csdid voted_lead voter_tenure_space times_voted_space_cum relative_voting_power_act ///
    prps_len prps_choices met_quorum, ///
    ivar(panel_id) time(time) gvar(treatment_time_all) method(dripw) notyet

// Store number of observations
scalar Nobs = e(N)

/********************************************************************
 3. Obtain and Store Results from estat Commands
********************************************************************/

estat simple, estore(cs_simple)
estat group, estore(cs_group)
estat calendar, estore(cs_calendar)
estat event, estore(cs_event)

* Aggregate ATT
estimates restore cs_simple        
estadd scalar Nobs = Nobs         
esttab cs_simple using "$dao_folder/results/tables/csdid/csdid_main_results_simple_0.3.rtf", ///
    replace title("CSDID Results: Aggregate ATT") star(* 0.10 ** 0.05 *** 0.01) ///
    se label compress noomitted stats(Nobs, labels("Observations"))

* Cohort-specific effects
estimates restore cs_group
estadd scalar Nobs = Nobs
esttab cs_group using "$dao_folder/results/tables/csdid/csdid_main_results_group_0.3.rtf", ///
    replace title("CSDID Results: ATT by Group") star(* 0.10 ** 0.05 *** 0.01) ///
    se label compress noomitted stats(Nobs, labels("Observations"))

* Calendar time effects
estimates restore cs_calendar
estadd scalar Nobs = Nobs
esttab cs_calendar using "$dao_folder/results/tables/csdid/csdid_main_results_calendar_0.3.rtf", ///
    replace title("CSDID Results: Calendar Time Effects") star(* 0.10 ** 0.05 *** 0.01) ///
    se label compress noomitted stats(Nobs, labels("Observations"))

* Event-study style dynamic effects
estimates restore cs_event
estadd scalar Nobs = Nobs
esttab cs_event using "$dao_folder/results/tables/csdid/csdid_main_results_event_0.3.rtf", ///
    replace title("CSDID Results: Event Study") star(* 0.10 ** 0.05 *** 0.01) ///
    se label compress noomitted stats(Nobs, labels("Observations"))

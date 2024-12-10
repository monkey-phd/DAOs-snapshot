/********************************************************************
 0. Initial Setup and Data Preparation
********************************************************************/
clear all
set more off

* Adjust this path as needed
global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data"

use "$dao_folder/processed/panel_almost_full.dta", clear

// Optional: sample x% for performance
set seed 123456
sample 0.4

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
 1.5 Filtering Units with Sufficient Time Variation
********************************************************************/

// Count observations per panel to ensure temporal variation
by panel_id: gen obs_per_panel = _N

// Retain only panels observed in at least two periods.
// This ensures basic temporal variation within each unit.
keep if obs_per_panel >= 2

// Do not exclude units with missing treatment_time_all. keep if !missing(treatment_time_all).
// Retaining never-treated units as controls is advantageous in staggered DiD frameworks.
// These units provide a stable counterfactual reference over time.

// Calculate pre- and post-treatment observations.
// For never-treated units, treatment_time_all is missing, but they still serve as a consistent baseline.
by panel_id: gen pre_treatment = sum(time < treatment_time_all)
by panel_id: gen post_treatment = sum(time >= treatment_time_all)

// Require at least one pre-treatment observation.
// This ensures that treated units have a baseline period prior to treatment.
// It also allows never-treated units—who effectively remain in the "pre" stage indefinitely—to serve as controls.
// Less restrictive than also requiring a post-treatment observation, this approach maximizes data retention. keep if pre_treatment >=1 & post_treatment >=1.
keep if pre_treatment >= 1

/********************************************************************
 2. Lagging the Independent Variables
********************************************************************/
// Lag the independent variables by one period.

sort panel_id time
by panel_id: gen L1_voter_tenure_space = voter_tenure_space[_n-1]
by panel_id: gen L1_times_voted_space_cum = times_voted_space_cum[_n-1]
by panel_id: gen L1_relative_voting_power_act = relative_voting_power_act[_n-1]
by panel_id: gen L1_prps_len = prps_len[_n-1]
by panel_id: gen L1_prps_choices = prps_choices[_n-1]
by panel_id: gen L1_met_quorum = met_quorum[_n-1]

// Drop the first observation per panel since it has no lagged data
drop if missing(L1_voter_tenure_space, L1_times_voted_space_cum, L1_relative_voting_power_act, ///
                L1_prps_len, L1_prps_choices, L1_met_quorum)

// Alternatively, create a lead variable for voted
// by panel_id: gen voted_lead = voted[_n+1]
// drop if missing(voted_lead)				
/********************************************************************
 3. Run Staggered DiD with CSDID using Lagged IVs
********************************************************************/
// Use the lagged IVs in csdid, ensuring they represent conditions prior to the current period's DV
csdid voted L1_voter_tenure_space L1_times_voted_space_cum L1_relative_voting_power_act ///
    L1_prps_len L1_prps_choices L1_met_quorum, ///
    ivar(panel_id) time(time) gvar(treatment_time_all) method(dripw)

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
esttab cs_simple using "$dao_folder/results/tables/csdid/csdid_main_results_simple.rtf", ///
    replace title("CSDID Results: Aggregate ATT") star(* 0.10 ** 0.05 *** 0.01) ///
    se label compress noomitted stats(Nobs, labels("Observations"))

* Cohort-specific effects
estimates restore cs_group
estadd scalar Nobs = Nobs
esttab cs_group using "$dao_folder/results/tables/csdid/csdid_main_results_group.rtf", ///
    replace title("CSDID Results: ATT by Group") star(* 0.10 ** 0.05 *** 0.01) ///
    se label compress noomitted stats(Nobs, labels("Observations"))

* Calendar time effects
estimates restore cs_calendar
estadd scalar Nobs = Nobs
esttab cs_calendar using "$dao_folder/results/tables/csdid/csdid_main_results_calendar.rtf", ///
    replace title("CSDID Results: Calendar Time Effects") star(* 0.10 ** 0.05 *** 0.01) ///
    se label compress noomitted stats(Nobs, labels("Observations"))

* Event-study style dynamic effects
estimates restore cs_event
estadd scalar Nobs = Nobs
esttab cs_event using "$dao_folder/results/tables/csdid/csdid_main_results_event.rtf", ///
    replace title("CSDID Results: Event Study") star(* 0.10 ** 0.05 *** 0.01) ///
    se label compress noomitted stats(Nobs, labels("Observations"))

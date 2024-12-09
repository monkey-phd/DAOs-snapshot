/********************************************************************
 0. Initial Setup and Data Preparation
********************************************************************/
clear all
set more off

* Adjust this path as needed
global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data"

use "$dao_folder/processed/panel_almost_full.dta", clear

* Optional: sample 20% for performance
* set seed 123456
* sample 0.2

/********************************************************************
 1. CEM Matching at Proposal Level
********************************************************************/
bysort proposal_id (vote_datetime): gen prps_first = 1 if _n==1
gen voting_type_nonsc = 0
replace voting_type_nonsc = 1 if type_single_choice == 0

capture which cem
if _rc ssc install cem, replace

cem  ///
    type_approval (#0) ///
    type_basic (#0) ///
    type_quadratic (#0) ///
    type_ranked_choice (#0) ///
    type_weighted (#0) ///
    prps_choices_bin (#0) ///
    prps_rel_quorum (0 0.05 0.1 0.2 0.3 1) ///
    prps_link (#0) ///
    prps_stub (#0) ///
    topic_1 (0 0.02 0.05 0.1 0.2 0.4 1) ///
    topic_2 (0 0.02 0.05 0.1 0.2 0.4 1) ///
    topic_3 (0 0.02 0.05 0.1 0.2 0.4 1) ///
    topic_4 (0 0.02 0.05 0.1 0.2 0.4 1) ///
    topic_5 (0 0.02 0.05 0.1 0.2 0.4 1) ///
    topic_6 (0 0.02 0.05 0.1 0.2 0.4 1) ///
    topic_7 (0 0.02 0.05 0.1 0.2 0.4 1) ///
    topic_8 (0 0.02 0.05 0.1 0.2 0.4 1) ///
    topic_9 (0 0.02 0.05 0.1 0.2 0.4 1) ///
    topic_10 (0 0.02 0.05 0.1 0.2 0.4 1) ///
    topic_11 (0 0.02 0.05 0.1 0.2 0.4 1) ///
    topic_12 (0 0.02 0.05 0.1 0.2 0.4 1) ///
    topic_13 (0 0.02 0.05 0.1 0.2 0.4 1) ///
    topic_14 (0 0.02 0.05 0.1 0.2 0.4 1) ///
    topic_15 (0 0.02 0.05 0.1 0.2 0.4 1) ///
    topic_16 (0 0.02 0.05 0.1 0.2 0.4 1) ///
    topic_17 (0 0.02 0.05 0.1 0.2 0.4 1) ///
    topic_18 (0 0.02 0.05 0.1 0.2 0.4 1) ///
    topic_19 (0 0.02 0.05 0.1 0.2 0.4 1) ///
    if prps_first == 1, tr(voting_type_nonsc) showbreaks autocuts(ss)

keep if cem_weights > 0

/********************************************************************
 2. Prepare Data for DiD After Matching
********************************************************************/
bysort voter_id space_id (year_month_num): gen voting_change = 0
replace voting_change = 1 if type_single_choice[_n-1]==1 & type_single_choice==0 & _n>1

bysort voter_id space_id (year_month_num): egen treatment_time = min(year_month_num) if voting_change==1
bysort voter_id space_id: egen treatment_time_all = min(treatment_time)

collapse (mean) voting_1m voter_tenure_space times_voted_space_cum relative_voting_power_act ///
    prps_len prps_choices met_quorum misaligned_c type_single_choice type_approval type_basic ///
    type_quadratic type_ranked_choice type_weighted (min) treatment_time_all, ///
    by(voter_id space_id year_month_num)

egen panel_id = group(voter_id space_id)
gen time = year_month_num
isid panel_id time
xtset panel_id time

/********************************************************************
 3. Run Staggered DiD with CSDID
********************************************************************/

csdid voting_1m voter_tenure_space times_voted_space_cum relative_voting_power_act ///
    prps_len prps_choices met_quorum ///
    , ivar(panel_id) time(time) gvar(treatment_time_all) method(dripw) notyet
	
// Store number of observations from csdid results
scalar Nobs = e(N)

/********************************************************************
 4. Obtain and Store Results from estat Commands
********************************************************************/

estat simple, estore(cs_simple)
estat group, estore(cs_group)
estat calendar, estore(cs_calendar)
estat event, estore(cs_event)

* Aggregate ATT
estimates restore cs_simple        
estadd scalar Nobs = Nobs         
esttab cs_simple using "$dao_folder/results/tables/csdid/csdid_main_results_simple_matched.rtf", ///
    replace title("CSDID Results: Aggregate ATT") star(* 0.10 ** 0.05 *** 0.01) ///
    se label compress noomitted stats(Nobs, labels("Observations"))

* Cohort-specific effects
estimates restore cs_group
estadd scalar Nobs = Nobs
esttab cs_group using "$dao_folder/results/tables/csdid/csdid_main_results_group_matched.rtf", ///
    replace title("CSDID Results: ATT by Group") star(* 0.10 ** 0.05 *** 0.01) ///
    se label compress noomitted stats(Nobs, labels("Observations"))

* Calendar time effects
estimates restore cs_calendar
estadd scalar Nobs = Nobs
esttab cs_calendar using "$dao_folder/results/tables/csdid/csdid_main_results_calendar_matched.rtf", ///
    replace title("CSDID Results: Calendar Time Effects") star(* 0.10 ** 0.05 *** 0.01) ///
    se label compress noomitted stats(Nobs, labels("Observations"))

* Event-study style dynamic effects
estimates restore cs_event
estadd scalar Nobs = Nobs
esttab cs_event using "$dao_folder/results/tables/csdid/csdid_main_results_event_matched.rtf", ///
    replace title("CSDID Results: Event Study") star(* 0.10 ** 0.05 *** 0.01) ///
    se label compress noomitted stats(Nobs, labels("Observations"))

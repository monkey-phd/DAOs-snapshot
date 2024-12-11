/********************************************************************
 0. Initial Setup and Data Preparation
********************************************************************/
clear all
set more off

global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data"

use "$dao_folder/processed/panel_almost_full.dta", clear

// Optional: sample x% for performance
// set seed 123456
//sample 0.96

// Instead of sampling, we restrict to first x DAOs for testing (224). e.g., space_id >= 100 & space_id <= 224. 
keep if space_id <= 224

/********************************************************************
 1. Prepare Data for DiD at Monthly Level
********************************************************************/
// Identify the first treatment month per voter-space
bysort voter_id space_id (year_month_num): gen voting_change = 0
replace voting_change = 1 if type_single_choice[_n-1] == 1 & type_single_choice == 0 & _n > 1

bysort voter_id space_id (year_month_num): egen treatment_time = min(year_month_num) if voting_change == 1
bysort voter_id space_id: egen treatment_time_all = min(treatment_time)

// Lag treatment time by one month
replace treatment_time_all = treatment_time_all + 1 if treatment_time_all < .

// Aggregate to monthly level, including all variables needed for CEM and DID
collapse (mean) voted voter_tenure_space times_voted_space_cum relative_voting_power_act ///
         prps_len prps_choices prps_choices_bin prps_rel_quorum met_quorum misaligned_c ///
         type_single_choice type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
         prps_link prps_stub ///
         topic_0 topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 topic_9 ///
         topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 topic_17 topic_18 topic_19 ///
         (min) treatment_time_all, by(voter_id space_id year_month_num)

egen panel_id = group(voter_id space_id)
gen time = year_month_num
isid panel_id time
xtset panel_id time

// Save full monthly dataset before CEM
tempfile original
save `original', replace

/********************************************************************
 2. Monthly-Level CEM Matching at Baseline
********************************************************************/
// For treated units: baseline month = treatment_time_all - 1
gen baseline_month = treatment_time_all - 1

// For never-treated units: pick a reference baseline month (median)
summ year_month_num if treatment_time_all==., detail
local refmonth = r(p50)
replace baseline_month = `refmonth' if treatment_time_all==.

// Extract baseline cross-section
tempfile baseline
save `baseline', replace
use `baseline', clear
keep if year_month_num == baseline_month

// Define treated indicator at baseline
gen treated = (treatment_time_all !=. & treatment_time_all > year_month_num)

// Run CEM at monthly level with fewer/coarser criteria
// Adjusting cutpoints: fewer variables or simpler cutpoints to retain never-treated units
cem prps_choices_bin (#0) ///
    prps_rel_quorum (0 0.1 0.3 1) /// Fewer/coarser breakpoints for prps_rel_quorum and topics
    prps_link (#0) prps_stub (#0) /// Simple binary matches for link and stub
    topic_1 (0 0.05 0.2 1) ///
    topic_2 (0 0.05 0.2 1) ///
    topic_3 (0 0.05 0.2 1) ///
    topic_4 (0 0.05 0.2 1) ///
    topic_5 (0 0.05 0.2 1) ///
    , tr(treated) showbreaks

/*// Run CEM at monthly level
cem prps_choices_bin (#0) ///
    prps_rel_quorum (0 0.05 0.1 0.2 0.3 1) ///
    prps_link (#0) prps_stub (#0) ///
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
    , tr(treated) showbreaks
*/

keep if cem_weights > 0
keep voter_id space_id
duplicates drop

tempfile matchedunits
save `matchedunits', replace

/********************************************************************
 Reload Full Dataset and Keep Only Matched Units
********************************************************************/
use `original', clear

// Remove nogenerate so _merge is created
merge m:1 voter_id space_id using `matchedunits'

// Keep only matched observations
keep if _merge == 3
drop _merge

/********************************************************************
 Create Lags and Drop Missing Lags on Matched Sample
********************************************************************/
sort panel_id time

// Create lags for all required variables (already in code)
by panel_id: gen L1_voter_tenure_space = voter_tenure_space[_n-1]
by panel_id: gen L1_times_voted_space_cum = times_voted_space_cum[_n-1]
by panel_id: gen L1_relative_voting_power_act = relative_voting_power_act[_n-1]
by panel_id: gen L1_prps_len = prps_len[_n-1]
by panel_id: gen L1_prps_choices = prps_choices[_n-1]
by panel_id: gen L1_met_quorum = met_quorum[_n-1]

by panel_id: gen L1_type_single_choice = type_single_choice[_n-1]
by panel_id: gen L1_type_approval = type_approval[_n-1]
by panel_id: gen L1_type_basic = type_basic[_n-1]
by panel_id: gen L1_type_quadratic = type_quadratic[_n-1]
by panel_id: gen L1_type_ranked_choice = type_ranked_choice[_n-1]
by panel_id: gen L1_type_weighted = type_weighted[_n-1]

forvalues i=0/19 {
    by panel_id: gen L1_topic_`i' = topic_`i'[_n-1]
}

drop if missing(L1_voter_tenure_space, L1_times_voted_space_cum, L1_relative_voting_power_act, L1_prps_len, L1_prps_choices, L1_met_quorum, L1_type_single_choice, L1_type_approval, L1_type_basic, L1_type_quadratic, L1_type_ranked_choice, L1_type_weighted, L1_topic_0, L1_topic_1, L1_topic_2, L1_topic_3, L1_topic_4, L1_topic_5, L1_topic_6, L1_topic_7, L1_topic_8, L1_topic_9, L1_topic_10, L1_topic_11, L1_topic_12, L1_topic_13, L1_topic_14, L1_topic_15, L1_topic_16, L1_topic_17, L1_topic_18, L1_topic_19)

/********************************************************************
 Filtering Units with Sufficient Time Variation
********************************************************************/
by panel_id: gen obs_per_panel = _N
keep if obs_per_panel >= 2

by panel_id: gen pre_treatment = sum(time < treatment_time_all)
by panel_id: gen post_treatment = sum(time >= treatment_time_all)

count if treatment_time_all != . & pre_treatment >= 1 & post_treatment >= 1
keep if pre_treatment >= 1 

/********************************************************************
 Run Staggered DiD with CSDID using Lagged IVs on Matched Sample
********************************************************************/
csdid voted ///
    L1_voter_tenure_space L1_times_voted_space_cum L1_relative_voting_power_act ///
    L1_prps_len L1_prps_choices L1_met_quorum ///
    L1_type_single_choice L1_type_approval L1_type_basic L1_type_quadratic L1_type_ranked_choice L1_type_weighted ///
    L1_topic_0 L1_topic_1 L1_topic_2 L1_topic_3 L1_topic_4 L1_topic_5 L1_topic_6 L1_topic_7 L1_topic_8 L1_topic_9 ///
    L1_topic_10 L1_topic_11 L1_topic_12 L1_topic_13 L1_topic_14 L1_topic_15 L1_topic_16 L1_topic_17 L1_topic_18 L1_topic_19 ///
    , ivar(panel_id) time(time) gvar(treatment_time_all) method(dripw)

scalar Nobs = e(N)

/********************************************************************
 Post-Estimation and Store Results
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

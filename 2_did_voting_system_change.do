********************************************************************************
* 0. Initial Setup and Data Preparation
********************************************************************************
clear all
set more off
global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data" 

// Load panel data and establish panel structure
use "$dao_folder/processed/panel_almost_full.dta", clear
xtset voter_space_id voter_space_prps_counter

********************************************************************************
* 1. Treatment Definition & Time Variables
********************************************************************************
* Create calendar quarters for fixed effects
gen calendar_quarter = ceil((year_month_num - 725)/3)
label variable calendar_quarter "Calendar quarters (1 = Q1 after month 725)"

* Identify voting system changes
bysort voter_id space_id (year_month_num): gen voting_change = 0
replace voting_change = 1 if type_single_choice[_n-1] == 1 & ///
   type_single_choice == 0 & _n > 1

* Get treatment timing for each voter-DAO pair
bysort voter_id space_id (year_month_num): egen treatment_time = min(year_month_num) if voting_change == 1
bysort voter_id space_id: egen treatment_time_all = min(treatment_time)

********************************************************************************
* 2. Create Time Windows Around Treatment
********************************************************************************
* Calculate relative timing
summarize treatment_time_all if !missing(treatment_time_all), meanonly
local first_treatment = r(min)

gen months_from_treatment = year_month_num - treatment_time_all if !missing(treatment_time_all)
replace months_from_treatment = year_month_num - `first_treatment' if missing(treatment_time_all)

* Convert to quarters relative to treatment
gen rel_quarter = floor(months_from_treatment / 3)
label variable rel_quarter "Quarters relative to treatment"

********************************************************************************
* 3. Define Analysis Sample
********************************************************************************
* Create balanced window
gen in_window = (rel_quarter >= -2 & rel_quarter <= 2)

* Calculate participation measures
bysort voter_id space_id: egen pre_period_votes = sum(voted) if rel_quarter < 0
bysort voter_id space_id: egen post_period_votes = sum(voted) if rel_quarter >= 0
egen pre_votes_max = max(pre_period_votes), by(voter_id space_id)
egen post_votes_max = max(post_period_votes), by(voter_id space_id)

* Define meaningful participation
gen balanced_activity = (pre_votes_max > 0 & post_votes_max > 0)

* Create final analysis sample
gen analysis_sample = (in_window == 1 & balanced_activity == 1)

********************************************************************************
* 4. DiD Setup
********************************************************************************
* Define treatment status
bysort voter_id space_id: egen ever_treated = max(voting_change)
gen treated = (ever_treated == 1)
gen post = (rel_quarter >= 0) if analysis_sample == 1

* Verify structure
display "DiD Structure"
tabulate treated post if analysis_sample == 1, cell row col

********************************************************************************
* 5. Balance Checks
********************************************************************************
/*
* Calculate pre-treatment means
foreach var of varlist voted voter_tenure_space relative_voting_power_act {
    bysort voter_space_id: egen pre_`var' = mean(`var') if rel_quarter < 0
}

* Check balance
display "Pre-treatment Balance"
foreach var of varlist pre_voted pre_voter_tenure_space pre_relative_voting_power_act {
    tabstat `var' if analysis_sample == 1, by(treated) stat(mean sd n)
}
*/
********************************************************************************
* 6. Main Analysis 
********************************************************************************
// Main DiD with 1-month future voting (primary specification)
reghdfe voting_1m i.treated##i.post##c.misaligned_c ///
    voter_tenure_space times_voted_space_cum relative_voting_power_act ///
    prps_len prps_choices met_quorum ///
    if analysis_sample == 1, ///
    absorb(voter_id calendar_quarter) cluster(voter_space_id)
eststo main_1m

// Store marginal effects for interpretation
margins, dydx(treated) at(misaligned_c=(0(0.2)1)) post
eststo marg_1m

********************************************************************************
* 7. Event Study Analysis 
********************************************************************************
// Adjust quarters to be non-negative for factor variables
gen rel_quarter_adj = rel_quarter + 12
label variable rel_quarter_adj "Adjusted quarters relative to treatment"

// Verify distribution
tabulate rel_quarter_adj if analysis_sample == 1

// Run event study with misalignment interaction
reghdfe voting_1m i.treated##i.rel_quarter_adj##c.misaligned_c ///
    voter_tenure_space times_voted_space_cum relative_voting_power_act ///
    prps_len prps_choices met_quorum ///
    if analysis_sample == 1, ///
    absorb(voter_id calendar_quarter) cluster(voter_space_id)
eststo event_1m

********************************************************************************
* 8. Robustness Checks Across Time Horizons
********************************************************************************
// Compare effects across different future voting horizons
foreach horizon in 3m 6m {
    // Main specification for each horizon
    reghdfe voting_`horizon' i.treated##i.post##c.misaligned_c ///
        voter_tenure_space times_voted_space_cum relative_voting_power_act ///
        prps_len prps_choices met_quorum ///
        if analysis_sample == 1, ///
        absorb(voter_id calendar_quarter) cluster(voter_space_id)
    eststo main_`horizon'
    
    // Event study for each horizon
    reghdfe voting_`horizon' i.treated##i.rel_quarter_adj##c.misaligned_c ///
        voter_tenure_space times_voted_space_cum relative_voting_power_act ///
        prps_len prps_choices met_quorum ///
        if analysis_sample == 1, ///
        absorb(voter_id calendar_quarter) cluster(voter_space_id)
    eststo event_`horizon'
    
    // Store marginal effects
    margins, dydx(treated) at(misaligned_c=(0(0.2)1)) post
    eststo marg_`horizon'
}

// Additional window sensitivity checks
foreach window in 1 3 4 {
    foreach horizon in 1m 3m 6m {
        gen in_window_`window'_`horizon' = (rel_quarter >= -`window' & rel_quarter <= `window')
        gen analysis_sample_`window'_`horizon' = (in_window_`window'_`horizon' == 1 & balanced_activity == 1)
        gen post_`window'_`horizon' = (rel_quarter >= 0) if analysis_sample_`window'_`horizon' == 1
        
        reghdfe voting_`horizon' i.treated##i.post_`window'_`horizon'##c.misaligned_c ///
            voter_tenure_space times_voted_space_cum relative_voting_power_act ///
            prps_len prps_choices met_quorum ///
            if analysis_sample_`window'_`horizon' == 1, ///
            absorb(voter_id calendar_quarter) cluster(voter_space_id)
        eststo rob_`horizon'_w`window'
    }
}

********************************************************************************
* 9. Export Results
********************************************************************************
// Main results across time horizons
esttab main_1m main_3m main_6m using "$dao_folder/results/tables/main_future_voting.rtf", ///
    replace title("DiD Results: Effects on Future Voting") ///
    mtitles("1-Month" "3-Month" "6-Month") ///
    star(* 0.10 ** 0.05 *** 0.01) se ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    addnotes("Standard errors clustered at voter-space level") ///
    compress label

// Event study results
esttab event_1m event_3m event_6m using "$dao_folder/results/tables/event_future_voting.rtf", ///
    replace title("Event Study Results: Future Voting Behavior") ///
    mtitles("1-Month" "3-Month" "6-Month") ///
    star(* 0.10 ** 0.05 *** 0.01) se ///
    stats(N r2_a, labels("Observations" "Adjusted R-squared")) ///
    compress label

// Marginal effects
esttab marg_1m marg_3m marg_6m using "$dao_folder/results/tables/margins_future_voting.rtf", ///
    replace title("Marginal Effects at Different Misalignment Levels") ///
    mtitles("1-Month" "3-Month" "6-Month") ///
    star(* 0.10 ** 0.05 *** 0.01) se ///
    compress label

// Robustness checks
esttab rob_1m_* using "$dao_folder/results/tables/robustness_1m.rtf", ///
    replace title("Robustness Checks - 1-Month Future Voting") ///
    star(* 0.10 ** 0.05 *** 0.01) se compress label

esttab rob_3m_* using "$dao_folder/results/tables/robustness_3m.rtf", ///
    replace title("Robustness Checks - 3-Month Future Voting") ///
    star(* 0.10 ** 0.05 *** 0.01) se compress label

esttab rob_6m_* using "$dao_folder/results/tables/robustness_6m.rtf", ///
    replace title("Robustness Checks - 6-Month Future Voting") ///
    star(* 0.10 ** 0.05 *** 0.01) se compress label

/********************************************************************
 0. Initial Setup and Data Preparation
********************************************************************/
clear all
set more off

* Adjust as needed
global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data"

use "$dao_folder/processed/panel_almost_full.dta", clear

// Optional: sample x% for performance
set seed 123456
sample 0.96


/*// Randomly sample by voter
set seed 123456
bysort voter_id: gen double rand_voter = runiform() if _n == 1
by voter_id: replace rand_voter = rand_voter[1]
keep if rand_voter < `fraction'
drop rand_voter
*/

/*// Randomly sample by DAO
set seed 123456
bysort space_id: gen double rand_dao = runiform() if _n == 1
by space_id: replace rand_dao = rand_dao[1]
keep if rand_dao < `fraction'
drop rand_dao
*/

/********************************************************************
 1. Prepare Data for DiD
********************************************************************/
// Identify the first treatment month per voter-space
bysort voter_id space_id (year_month_num): gen voting_change = 0
replace voting_change = 1 if type_single_choice[_n-1] == 1 & type_single_choice == 0 & _n > 1

bysort voter_id space_id (year_month_num): egen treatment_time = min(year_month_num) if voting_change == 1
bysort voter_id space_id: egen treatment_time_all = min(treatment_time)

// Shift treatment time forward by one month
replace treatment_time_all = treatment_time_all + 1 if treatment_time_all < .
		 
// Aggregate data to monthly level:
collapse (mean) voted voter_tenure_space times_voted_space_cum relative_voting_power_act ///
         prps_len prps_choices met_quorum misaligned_c type_single_choice type_approval type_basic ///
         type_quadratic type_ranked_choice type_weighted ///
         topic_0 topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 topic_9 ///
         topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 topic_17 topic_18 topic_19 ///
         (min) treatment_time_all, by(voter_id space_id year_month_num)

// Set panel structure
egen panel_id = group(voter_id space_id)
gen time = year_month_num
isid panel_id time
xtset panel_id time

/********************************************************************
 ***  Create Lags and Drop Missing Lags
********************************************************************/
sort panel_id time

// lags
by panel_id: gen L1_voter_tenure_space = voter_tenure_space[_n-1]
by panel_id: gen L1_times_voted_space_cum = times_voted_space_cum[_n-1]
by panel_id: gen L1_relative_voting_power_act = relative_voting_power_act[_n-1]
by panel_id: gen L1_prps_len = prps_len[_n-1]
by panel_id: gen L1_prps_choices = prps_choices[_n-1]
by panel_id: gen L1_met_quorum = met_quorum[_n-1]

// Lag the voting mechanism variables
by panel_id: gen L1_type_single_choice = type_single_choice[_n-1]
by panel_id: gen L1_type_approval = type_approval[_n-1]
by panel_id: gen L1_type_basic = type_basic[_n-1]
by panel_id: gen L1_type_quadratic = type_quadratic[_n-1]
by panel_id: gen L1_type_ranked_choice = type_ranked_choice[_n-1]
by panel_id: gen L1_type_weighted = type_weighted[_n-1]

// Lag the topic proportions
forvalues i=0/19 {
    by panel_id: gen L1_topic_`i' = topic_`i'[_n-1]
}
				
drop if missing(L1_voter_tenure_space, L1_times_voted_space_cum, L1_relative_voting_power_act, ///
                L1_prps_len, L1_prps_choices, L1_met_quorum, ///
                L1_type_single_choice, L1_type_approval, L1_type_basic, L1_type_quadratic, ///
                L1_type_ranked_choice, L1_type_weighted, ///
                L1_topic_0, L1_topic_1, L1_topic_2, L1_topic_3, L1_topic_4, ///
                L1_topic_5, L1_topic_6, L1_topic_7, L1_topic_8, L1_topic_9, ///
                L1_topic_10, L1_topic_11, L1_topic_12, L1_topic_13, L1_topic_14, ///
                L1_topic_15, L1_topic_16, L1_topic_17, L1_topic_18, L1_topic_19)

/********************************************************************
 1.5 Filtering Units with Sufficient Time Variation (After Lagging)
********************************************************************/

// Count observations per panel again after lagging
by panel_id: gen obs_per_panel = _N
keep if obs_per_panel >= 2

// For never-treated units, treatment_time_all is missing; they serve as baseline controls
by panel_id: gen pre_treatment = sum(time < treatment_time_all)
by panel_id: gen post_treatment = sum(time >= treatment_time_all)

// Require at least one pre-treatment observation (pre_treatment >= 1). We do NOT also enforce post_treatment >= 1 because doing so removes all treated units that never appear post-treatment. Without any treated units observed after treatment, the DiD cannot identify a treatment effect. By not forcing post_treatment >= 1, we ensure that some treated units with post-treatment data remain, allowing for effect estimation. Units without post-treatment observations stay in the dataset but do not harm the analysis.
count if treatment_time_all != . & pre_treatment >= 1 & post_treatment >= 1
keep if pre_treatment >= 1 

/********************************************************************
 3. Run Staggered DiD with CSDID using Lagged IVs
********************************************************************/
csdid voted ///
    L1_voter_tenure_space L1_times_voted_space_cum L1_relative_voting_power_act ///
    L1_prps_len L1_prps_choices L1_met_quorum ///
    L1_type_single_choice L1_type_approval L1_type_basic L1_type_quadratic L1_type_ranked_choice L1_type_weighted ///
    L1_topic_0 L1_topic_1 L1_topic_2 L1_topic_3 L1_topic_4 L1_topic_5 L1_topic_6 L1_topic_7 L1_topic_8 L1_topic_9 ///
    L1_topic_10 L1_topic_11 L1_topic_12 L1_topic_13 L1_topic_14 L1_topic_15 L1_topic_16 L1_topic_17 L1_topic_18 L1_topic_19 ///
    , ivar(panel_id) time(time) gvar(treatment_time_all) method(dripw)

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
esttab cs_simple using "$dao_folder/results/tables/csdid/csdid_main_results_simple_0.96.rtf", ///
    replace title("CSDID Results: Aggregate ATT") star(* 0.10 ** 0.05 *** 0.01) ///
    se label compress noomitted stats(Nobs, labels("Observations"))

* Cohort-specific effects
estimates restore cs_group
estadd scalar Nobs = Nobs
esttab cs_group using "$dao_folder/results/tables/csdid/csdid_main_results_group_0.96.rtf", ///
    replace title("CSDID Results: ATT by Group") star(* 0.10 ** 0.05 *** 0.01) ///
    se label compress noomitted stats(Nobs, labels("Observations"))

* Calendar time effects
estimates restore cs_calendar
estadd scalar Nobs = Nobs
esttab cs_calendar using "$dao_folder/results/tables/csdid/csdid_main_results_calendar_0.96.rtf", ///
    replace title("CSDID Results: Calendar Time Effects") star(* 0.10 ** 0.05 *** 0.01) ///
    se label compress noomitted stats(Nobs, labels("Observations"))

* Event-study style dynamic effects
estimates restore cs_event
estadd scalar Nobs = Nobs
esttab cs_event using "$dao_folder/results/tables/csdid/csdid_main_results_event_0.96.rtf", ///
    replace title("CSDID Results: Event Study") star(* 0.10 ** 0.05 *** 0.01) ///
    se label compress noomitted stats(Nobs, labels("Observations"))

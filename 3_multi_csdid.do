/********************************************************************
 Set fraction and define global folder
********************************************************************/
clear all
set more off

* Set your desired fraction here
local fraction 0.96

* Adjust as needed
global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data"

* Define the list of voting types you want to analyze
local votetypes "type_quadratic type_weighted type_ranked_choice type_approval type_basic"

/********************************************************************
 Loop over each voting type
********************************************************************/
foreach vtype of local votetypes {
    di "=============================================================="
    di "Starting analysis for `vtype' (fraction = `fraction')"
    di "=============================================================="
    
    /********************************************************************
     0. Initial Setup and Data Preparation
    ********************************************************************/
    use "$dao_folder/processed/panel_almost_full.dta", clear

    // Optional: sample x% for performance
    set seed 123456
    sample `fraction'

    // Count unique voters and DAOs before manipulation
    egen tag_voter = tag(voter_id)
    count if tag_voter==1
    drop tag_voter

    egen tag_dao = tag(space_id)
    count if tag_dao==1
    drop tag_dao

    /********************************************************************
     1. Prepare Data for DiD
    ********************************************************************/
    // Identify transitions from single-choice to the specified voting type
    bysort voter_id space_id (year_month_num): gen voting_change = 0
    // For each type, treatment is defined as the first time it changes from single-choice
    replace voting_change = 1 if type_single_choice[_n-1] == 1 & `vtype' == 1 & _n > 1

    // Earliest treatment times
    bysort voter_id space_id (year_month_num): egen treatment_time = min(year_month_num) if voting_change == 1
    bysort voter_id space_id: egen treatment_time_all = min(treatment_time)

    // Shift treatment time by one month
    replace treatment_time_all = treatment_time_all + 1 if treatment_time_all < .

    // Aggregate data to monthly level
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
     Create Lags and Drop Missing Lags
    ********************************************************************/
    sort panel_id time

    // Create lags
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

    // Drop if missing any required lag
    drop if missing(L1_voter_tenure_space, L1_times_voted_space_cum, L1_relative_voting_power_act, ///
                    L1_prps_len, L1_prps_choices, L1_met_quorum, ///
                    L1_type_single_choice, L1_type_approval, L1_type_basic, L1_type_quadratic, ///
                    L1_type_ranked_choice, L1_type_weighted, ///
                    L1_topic_0, L1_topic_1, L1_topic_2, L1_topic_3, L1_topic_4, ///
                    L1_topic_5, L1_topic_6, L1_topic_7, L1_topic_8, L1_topic_9, ///
                    L1_topic_10, L1_topic_11, L1_topic_12, L1_topic_13, L1_topic_14, ///
                    L1_topic_15, L1_topic_16, L1_topic_17, L1_topic_18, L1_topic_19)

    // Keep only panels with at least 2 observations
    by panel_id: gen obs_per_panel = _N
    keep if obs_per_panel >= 2

    // Require at least one pre-treatment observation
    by panel_id: gen pre_treatment = sum(time < treatment_time_all)
    by panel_id: gen post_treatment = sum(time >= treatment_time_all)
    keep if pre_treatment >= 1

    /********************************************************************
     Run Staggered DiD with CSDID
    ********************************************************************/
    capture csdid voted ///
        L1_voter_tenure_space L1_times_voted_space_cum L1_relative_voting_power_act ///
        L1_prps_len L1_prps_choices L1_met_quorum ///
        L1_type_single_choice L1_type_approval L1_type_basic L1_type_quadratic L1_type_ranked_choice L1_type_weighted ///
        L1_topic_0 L1_topic_1 L1_topic_2 L1_topic_3 L1_topic_4 L1_topic_5 L1_topic_6 L1_topic_7 L1_topic_8 L1_topic_9 ///
        L1_topic_10 L1_topic_11 L1_topic_12 L1_topic_13 L1_topic_14 L1_topic_15 L1_topic_16 L1_topic_17 L1_topic_18 L1_topic_19 ///
        , ivar(panel_id) time(time) gvar(treatment_time_all) method(dripw)

    // Check results and export
    scalar Nobs = e(N)
    if Nobs == 0 {
        di "Csdid yields no obs for `vtype'. Check data reduction steps."
    }
    else {
        estat simple, estore(cs_simple)
        estat group, estore(cs_group)
        estat calendar, estore(cs_calendar)
        estat event, estore(cs_event)

        // Create results directory dynamically based on fraction and voting type
        local results_dir "$dao_folder/results/tables/3_csdid_multi/csdid_`vtype'_`fraction'"
        capture mkdir "`results_dir'"

        // Export results to RTF files, naming them based on `fraction` and `vtype`
        estimates restore cs_simple
        estadd scalar Nobs = Nobs
        esttab cs_simple using "`results_dir'/csdid_`vtype'_simple_`fraction'.rtf", ///
            replace title("CSDID Results: `vtype' (`fraction' Data)") ///
            star(* 0.10 ** 0.05 *** 0.01) se label compress noomitted stats(Nobs, labels("Observations"))

        estimates restore cs_group
        estadd scalar Nobs = Nobs
        esttab cs_group using "`results_dir'/csdid_`vtype'_group_`fraction'.rtf", ///
            replace title("CSDID Results: `vtype' by Group (`fraction' Data)") ///
            star(* 0.10 ** 0.05 *** 0.01) se label compress noomitted stats(Nobs, labels("Observations"))

        estimates restore cs_calendar
        estadd scalar Nobs = Nobs
        esttab cs_calendar using "`results_dir'/csdid_`vtype'_calendar_`fraction'.rtf", ///
            replace title("CSDID Calendar Effects: `vtype' (`fraction' Data)") ///
            star(* 0.10 ** 0.05 *** 0.01) se label compress noomitted stats(Nobs, labels("Observations"))

        estimates restore cs_event
        estadd scalar Nobs = Nobs
        esttab cs_event using "`results_dir'/csdid_`vtype'_event_`fraction'.rtf", ///
            replace title("CSDID Event Study: `vtype' (`fraction' Data)") ///
            star(* 0.10 ** 0.05 *** 0.01) se label compress noomitted stats(Nobs, labels("Observations"))

        di "Results stored successfully for `vtype'."
    }

    // Clear data before the next iteration
    clear
}

di "All analyses completed for all specified voting types."

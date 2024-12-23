/***************************************************************************
 0. Basic Setup
***************************************************************************/
clear all
set more off

local fraction 1
local samplingMethods "none" //  none voter dao random
local allFocals "type_quadratic type_weighted type_ranked_choice type_approval type_basic" // type_quadratic type_weighted type_ranked_choice type_approval type_basic

global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data"
use "$dao_folder/processed/panel_almost_full.dta", clear

/***************************************************************************
 Loop over sampling methods, advanced voting types
***************************************************************************/
foreach samplingMethod of local samplingMethods {
    foreach focalType of local allFocals {

        di "=========================================================="
        di "Sampling=`samplingMethod', focal=`focalType', fraction=`fraction'"
        di "=========================================================="

        use "$dao_folder/processed/panel_almost_full.dta", clear

        /*
            1) Apply chosen sampling method using fraction.
               (random, voter, dao, or none)
        */
        if "`samplingMethod'"=="random" {
            set seed 123456
            sample `fraction'
        }
        else if "`samplingMethod'"=="voter" {
            set seed 123456
            bysort voter_id: gen double rand_voter = runiform() if _n==1
            by voter_id: replace rand_voter = rand_voter[1]
            keep if rand_voter < `fraction'
            drop rand_voter
        }
        else if "`samplingMethod'"=="dao" {
            set seed 123456
            bysort space_id: gen double rand_dao = runiform() if _n==1
            by space_id: replace rand_dao = rand_dao[1]
            keep if rand_dao < `fraction'
            drop rand_dao
        }
        else if "`samplingMethod'"=="none" {
            // no sampling, full data
        }
        else {
            di as error "Invalid samplingMethod!"
            exit 1
        }

        /*
            Basic counts of unique voters and DAOs after sampling
        */
        egen tag_voter = tag(voter_id)
        di "Unique voters after sampling:"
        count if tag_voter==1
        drop tag_voter

        egen tag_dao = tag(space_id)
        di "Unique DAOs after sampling:"
        count if tag_dao==1
        drop tag_dao

        /*
            2) Implement single-choice -> `focalType` logic
               using row_focal, row_other, and dao_category
        */
        preserve

        // row_focal=1 if focalType==1 in this row
        gen row_focal = (`focalType' == 1)

        // leftover advanced voting types
        local allAlts "type_approval type_basic type_quadratic type_ranked_choice type_weighted"
        local otherList ""
        foreach alt of local allAlts {
            if "`alt'" != "`focalType'" {
                local otherList "`otherList' `alt'"
            }
        }

        // OR expression => row_other=1 if any leftover advanced is 1
        local expr "0"
        foreach o of local otherList {
            local expr "`expr' | `o'==1"
        }
        gen row_other=0
        replace row_other=1 if (`expr')
		
		/***********************************************************************
		 dao_category=0/1/2/3
		   0 => never adopt any advanced type (single choice only)
		   1 => adopt this focal only
		   2 => adopt other advanced only
		   3 => adopt focal + other
		***********************************************************************/

        bysort space_id: egen ever_focal = max(row_focal)
        bysort space_id: egen ever_other = max(row_other)

        gen dao_category=.
        replace dao_category=0 if ever_focal==0 & ever_other==0
        replace dao_category=1 if ever_focal==1  & ever_other==0
        replace dao_category=2 if ever_focal==0 & ever_other==1
        replace dao_category=3 if ever_focal==1  & ever_other==1

        bysort space_id: gen mark_cat=_n==1
        di "DAO categories for focal=`focalType':"
        tab dao_category if mark_cat==1
        drop mark_cat

        count if dao_category==1
        if r(N)==0 {
            di as error "No DAOs in dao_category=1 for `focalType'. Skipping."
            restore
            continue
        }
		// Keep dao_category 0,1 => single choice or single choice->focal
        keep if inlist(dao_category,0,1)
        drop row_focal row_other ever_focal ever_other

        // earliest usage
        gen row_focal2=(`focalType' == 1)
        bysort space_id year_month_num: egen monthly_focal=max(row_focal2)
        bysort space_id (year_month_num): gen dao_treatment_time=(monthly_focal==1)*year_month_num

        bysort space_id (dao_treatment_time): gen first_treat=dao_treatment_time if dao_treatment_time>0
        bysort space_id: egen final_treat=min(first_treat)
        drop dao_treatment_time first_treat monthly_focal row_focal2

        bysort space_id: gen dao_treatment_time_all=final_treat[1]
        drop final_treat

        // collapse to monthly level
        collapse (mean) voted voter_tenure_space times_voted_space_cum relative_voting_power_act ///
                 prps_len prps_choices met_quorum misaligned_c ///
                 (min) dao_treatment_time_all (max) dao_category, ///
                 by(voter_id space_id year_month_num)

        egen panel_id=group(voter_id space_id)
        gen time=year_month_num
        isid panel_id time
        xtset panel_id time

        sort panel_id time
        by panel_id: gen L1_voter_tenure_space = voter_tenure_space[_n-1]
        by panel_id: gen L1_times_voted_space_cum = times_voted_space_cum[_n-1]
        by panel_id: gen L1_relative_voting_power_act = relative_voting_power_act[_n-1]
        by panel_id: gen L1_prps_len = prps_len[_n-1]
        by panel_id: gen L1_prps_choices = prps_choices[_n-1]
        by panel_id: gen L1_met_quorum = met_quorum[_n-1]
		by panel_id: gen L1_misaligned_c = misaligned_c[_n-1]

        drop if missing(L1_voter_tenure_space, L1_times_voted_space_cum, L1_relative_voting_power_act, ///
                        L1_prps_len, L1_prps_choices, L1_met_quorum, L1_misaligned_c) ///					

        by panel_id: gen obs_per_panel=_N
        keep if obs_per_panel>=2

        gen event_time=time - dao_treatment_time_all if dao_treatment_time_all<.
        gen treatment=(event_time>=0 & event_time!=.)
		gen treat_x_misaligned = treatment * L1_misaligned_c

        // run csdid
        di "=== csdid for single-choice->`focalType' ==="
        csdid voted ///
		    L1_misaligned_c treat_x_misaligned ///
            L1_voter_tenure_space L1_times_voted_space_cum L1_relative_voting_power_act ///
            L1_prps_len L1_prps_choices L1_met_quorum ///
            , ivar(panel_id) time(time) gvar(dao_treatment_time_all) method(dripw)

        local fraction_str : subinstr local fraction "." "", all
        scalar Nobs = e(N)
        if (Nobs == 0) {
            di as error "No obs in final DID sample for `focalType'."
        }
        else {
            local results_dir "$dao_folder/results/tables/3_csdid_multi/csdid_inter_`focalType'_`fraction_str'_`samplingMethod'"
            capture mkdir "`results_dir'"

            local figdir "$dao_folder/results/figures/3_csdid_inter_multi"
            capture mkdir "`figdir'"

            capture estat simple, estore(cs_`focalType')
            if _rc != 0 {
                di as error "estat simple failed. Skipping `focalType'."
                capture restore
                continue
            }

            capture estat group, estore(cs_`focalType'_grp)
            if _rc != 0 {
                di as error "estat group failed. Skipping `focalType'."
                capture restore
                continue
            }
            capture csdid_plot, agg(group)
            if _rc == 0 {
                graph export "`figdir'/`focalType'_group_`fraction_str'_`samplingMethod'.png", replace
            }

            capture estat calendar, estore(cs_`focalType'_cal)
            if _rc != 0 {
                di as error "estat calendar failed. Skipping `focalType'."
                capture restore
                continue
            }
            capture csdid_plot, agg(calendar)
            if _rc == 0 {
                graph export "`figdir'/`focalType'_calendar_`fraction_str'_`samplingMethod'.png", replace
            }

            capture estat event, estore(cs_`focalType'_evt)
            if _rc != 0 {
                di as error "estat event failed. Skipping `focalType'."
                capture restore
                continue
            }
            capture csdid_plot, agg(event)
            if _rc == 0 {
                graph export "`figdir'/`focalType'_event_`fraction_str'_`samplingMethod'.png", replace
            }

            estimates restore cs_`focalType'
            estadd scalar Nobs=Nobs
            esttab cs_`focalType' using "`results_dir'/csdid_`focalType'_simple_`fraction_str'.rtf", replace ///
                title("CSDID: `focalType' (Fraction=`fraction', Sampling=`samplingMethod')") ///
                star(* 0.10 ** 0.05 *** 0.01) se label compress noomitted stats(Nobs, labels("Observations"))

            estimates restore cs_`focalType'_grp
            estadd scalar Nobs=Nobs
            esttab cs_`focalType'_grp using "`results_dir'/csdid_`focalType'_group_`fraction_str'.rtf", replace ///
                title("Group Effects: `focalType' (fraction=`fraction', sampling=`samplingMethod')") ///
                star(* 0.10 ** 0.05 *** 0.01) se label compress noomitted stats(Nobs, labels("Observations"))

            estimates restore cs_`focalType'_cal
            estadd scalar Nobs=Nobs
            esttab cs_`focalType'_cal using "`results_dir'/csdid_`focalType'_calendar_`fraction_str'.rtf", replace ///
                title("Calendar Effects: `focalType' (fraction=`fraction', sampling=`samplingMethod')") ///
                star(* 0.10 ** 0.05 *** 0.01) se label compress noomitted stats(Nobs, labels("Observations"))

            estimates restore cs_`focalType'_evt
            estadd scalar Nobs=Nobs
            esttab cs_`focalType'_evt using "`results_dir'/csdid_`focalType'_event_`fraction_str'.rtf", replace ///
                title("Event Study: `focalType' (fraction=`fraction', sampling=`samplingMethod')") ///
                star(* 0.10 ** 0.05 *** 0.01) se label compress noomitted stats(Nobs, labels("Observations"))

            di "Done with single-choice->`focalType' DID."
        }
        restore
    }
}

di "All focal analyses complete for fraction=`fraction', sampling methods, advanced voting types."


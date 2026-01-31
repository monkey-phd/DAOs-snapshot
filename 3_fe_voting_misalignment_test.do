********************************************************************************
// 1. Setup and Data Preparation
********************************************************************************
clear all
set more off
global dao_folder "C:/Users/hklapper/Dropbox/Empirical Paper on DAOs (MvHxHK)/Data"

// Load data
use "$dao_folder/processed/panel_full.dta", clear

// Setup panel structure    
xtset voter_space_id voter_space_prps_counter

/*
gen prps_len_log = log(prps_len)

label variable prps_len_log "Proposal Length (Log.)"

gen prps_len_adj = prps_len / 10,000
*/

********************************************************************************
// 2. Fixed Effects Analysis - Voting Behavior
********************************************************************************
eststo clear

foreach var in 1m 3m 6m {

	// Model 4: Full specification
	eststo voting_`var': reghdfe voting_`var' ///
	   c.voted ///
	   c.misaligned_wmiss c.misaligned_wmiss#c.prps_misalign ///
	   i.type_approval i.type_basic i.type_quadratic i.type_ranked_choice i.type_weighted ///
	   i.type_approval#c.misaligned_wmiss i.type_basic#c.misaligned_wmiss ///
	   i.type_quadratic#c.misaligned_wmiss i.type_ranked_choice#c.misaligned_wmiss i.type_weighted#c.misaligned_wmiss ///
	   i.type_approval#c.misaligned_wmiss#c.prps_misalign i.type_basic#c.misaligned_wmiss#c.prps_misalign ///
	   i.type_quadratic#c.misaligned_wmiss#c.prps_misalign ///
	   i.type_ranked_choice#c.misaligned_wmiss#c.prps_misalign i.type_weighted#c.misaligned_wmiss#c.prps_misalign ///
		is_majority_win privacy ///
	   c.voter_tenure_space c.times_voted_space_cum ///
	   c.diff_days_last_vote_space c.relative_voting_power_act ///
	   c.votes_dao_cum ///
	   c.prps_len prps_choices_bin c.prps_rel_quorum ///
	   met_quorum privacy ///
	   c.prps_part_rate c.prps_misalign c.votes_proposal_cum ///
	   topic_1-topic_19 ///
	   c.space_age c.space_id_size ///
	   if end_`var' == 0 & own_choice_tied == 0 & own_margin != 0, ///
	   absorb(voter_id year_month_num) vce(cluster voter_space_id)


	********************************************************************************
	// 3. Export Results
	********************************************************************************

}
esttab voting_1m voting_3m voting_6m ///
   using "$dao_folder/results/tables/fe_voting_controversy_triple.rtf", ///
   replace ///
   cells(b(star fmt(3)) se(par fmt(3))) ///
   star(* 0.10 ** 0.05 *** 0.01) ///
   title("Key Effects on Future Voting: `var' horizon") ///
   scalars("r2_a Adjusted R-sq" "N Observations") ///
   note("Standard errors clustered at voter-space level in parentheses" ///
		"* p<0.10, ** p<0.05, *** p<0.01") ///
   label compress


// // Compare across time horizons (full model)
// esttab voting_1m_m4 voting_3m_m4 voting_6m_m4 ///
//    using "$dao_folder/results/tables/fe_comparison_simple.rtf", ///
//    replace ///
//    cells(b(star fmt(3)) se(par fmt(3))) ///
//    star(* 0.10 ** 0.05 *** 0.01) ///
//    title("Effects Across Time Horizons - Full Model") ///
//    mtitles("1-month" "3-month" "6-month") ///
//    scalars("r2_a Adjusted R-sq" "N Observations") ///
//    note("Standard errors clustered at voter-space level in parentheses" ///
//         "* p<0.10, ** p<0.05, *** p<0.01") ///
//    label compress
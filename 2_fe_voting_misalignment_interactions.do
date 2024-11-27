********************************************************************************
// 1. Setup and Data Preparation
********************************************************************************
clear all
set more off
global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data" 

// Required packages
// ssc install reghdfe
// ssc install estout

// Load data
use "$dao_folder/processed/panel_almost_full.dta", clear

// Setup panel structure    
xtset voter_space_id voter_space_prps_counter

// Select 0.1 percent sample
// set seed 123456
// sample 0.1

********************************************************************************
// 2. Fixed Effects Analysis - Voting Misalignment
********************************************************************************
eststo clear
foreach var in 1m 3m 6m {
   
   // Model 1: Basic specification
   eststo voting_`var'_m1: reghdfe voting_`var' ///
       c.voted ///                               // voted in proposal
       c.misaligned_wmiss ///                    // vote differs from outcome
       if end_`var' == 0 & own_choice_tied == 0 & own_margin != 0, ///
       absorb(voter_id year_month_num) vce(cluster voter_space_id)

   // Model 2: Add interactions
   eststo voting_`var'_m2: reghdfe voting_`var' ///
       c.voted ///
       c.misaligned_wmiss ///
       c.voted#c.is_majority_win ///
       c.voted#c.plugin_safesnap ///
       c.voted#c.strategy_delegation /// 
       c.voted#c.privacy /// 
       c.misaligned_wmiss#c.is_majority_win ///
       c.misaligned_wmiss#c.plugin_safesnap ///
       c.misaligned_wmiss#c.strategy_delegation ///
       c.misaligned_wmiss#c.privacy ///
       plugin_safesnap strategy_delegation is_majority_win privacy ///
       if end_`var' == 0 & own_choice_tied == 0 & own_margin != 0, ///
       absorb(voter_id year_month_num) vce(cluster voter_space_id)

   // Model 3: Add voter characteristics
   eststo voting_`var'_m3: reghdfe voting_`var' ///
       c.voted ///
       c.misaligned_wmiss ///
       c.voted#c.is_majority_win ///
       c.voted#c.plugin_safesnap ///
       c.voted#c.strategy_delegation /// 
       c.voted#c.privacy /// 
       c.misaligned_wmiss#c.is_majority_win ///
       c.misaligned_wmiss#c.plugin_safesnap ///
       c.misaligned_wmiss#c.strategy_delegation ///
       c.misaligned_wmiss#c.privacy ///
       plugin_safesnap strategy_delegation is_majority_win privacy ///
       c.voter_tenure_space ///                  // 
       c.times_voted_space_cum ///               // 
       c.diff_days_last_vote_space ///           //
       c.relative_voting_power_act ///           // 
       c.votes_dao_cum ///                       // 
       if end_`var' == 0 & own_choice_tied == 0 & own_margin != 0, ///
       absorb(voter_id year_month_num) vce(cluster voter_space_id)

   // Model 4: Full specification (proposal and dao characteristics)
   eststo voting_`var'_m4: reghdfe voting_`var' ///
       c.voted ///
       c.misaligned_wmiss ///
       c.voted#c.is_majority_win ///
       c.voted#c.plugin_safesnap ///
       c.voted#c.strategy_delegation /// 
       c.voted#c.privacy /// 
       c.misaligned_wmiss#c.is_majority_win ///
       c.misaligned_wmiss#c.plugin_safesnap ///
       c.misaligned_wmiss#c.strategy_delegation ///
       c.misaligned_wmiss#c.privacy ///
       plugin_safesnap strategy_delegation is_majority_win privacy ///
       c.voter_tenure_space c.times_voted_space_cum ///
       c.diff_days_last_vote_space c.relative_voting_power_act ///
       c.votes_dao_cum ///
       type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
       c.prps_len prps_choices_bin c.prps_rel_quorum ///
       plugin_safesnap strategy_delegation ///
       met_quorum is_majority_win privacy ///
       c.prps_part_rate c.prps_misalign c.votes_proposal_cum ///
       topic_1-topic_19 ///
       c.space_age c.space_id_size ///
       if end_`var' == 0 & own_choice_tied == 0 & own_margin != 0, ///
       absorb(voter_id year_month_num) vce(cluster voter_space_id)
}

// FE: voter (individual), proposal (content), year-month (time trends)


********************************************************************************
// 3. Export Results
********************************************************************************
// Results for each time horizon
foreach var in 1m 3m 6m {
   // Full table
   esttab voting_`var'_m1 voting_`var'_m2 voting_`var'_m3 voting_`var'_m4 ///
       using "$dao_folder/results/tables/fe_voting_`var'_misalignment_1a.rtf", ///
       replace ///
       cells(b(star fmt(3)) se(par fmt(3))) ///
       star(* 0.10 ** 0.05 *** 0.01) ///
       title("Misalignment Effects on Future Voting: `var' horizon") ///
       mtitles("Basic" "Vote Inter" "+Voter Char" "Full") ///
       scalars("r2_a Adjusted R-sq" "N Observations") ///
       note("Standard errors clustered at voter-space level in parentheses" ///
            "* p<0.10, ** p<0.05, *** p<0.01") ///
       label compress

esttab voting_`var'_m1 voting_`var'_m2 voting_`var'_m3 voting_`var'_m4 ///
    using "$dao_folder/results/tables/fe_voting_`var'_key_coef_1a.rtf", ///
    replace ///
    cells(b(star fmt(3)) se(par fmt(3))) ///
    keep(voted misaligned_wmiss) ///        // Remove the c. prefix
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Key Effects on Future Voting: `var' horizon") ///
    mtitles("Basic" "Vote Inter" "+Voter Char" "Full") ///
    scalars("r2_a Adjusted R-sq" "N Observations") ///
    note("Standard errors clustered at voter-space level in parentheses" ///
         "* p<0.10, ** p<0.05, *** p<0.01") ///
    label compress
}

// Compare across time horizons (full model)
esttab voting_1m_m4 voting_3m_m4 voting_6m_m4 ///
   using "$dao_folder/results/tables/fe_misalignment_comparison_1a.rtf", ///
   replace ///
   cells(b(star fmt(3)) se(par fmt(3))) ///
   star(* 0.10 ** 0.05 *** 0.01) ///
   title("Misalignment Effects Across Time Horizons - Full Model") ///
   mtitles("1-month" "3-month" "6-month") ///
   scalars("r2_a Adjusted R-sq" "N Observations") ///
   note("Standard errors clustered at voter-space level in parentheses" ///
        "* p<0.10, ** p<0.05, *** p<0.01") ///
   label compress
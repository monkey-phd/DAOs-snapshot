********************************************************************************
// 1. Setup and Data Preparation
********************************************************************************
clear all
set more off
global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data"

// Load data
use "$dao_folder/processed/panel_almost_full.dta", clear

// Setup panel structure
xtset voter_space_id voter_space_prps_counter

// Identify first proposal vote
bysort proposal_id (vote_datetime): gen prps_first = 1 if _n==1

// Create treatment variable (similar to Helge's approach)
gen voting_type_nonsc = 0
replace voting_type_nonsc = 1 if type_single_choice == 0

// Install cem if not already done
ssc install cem, replace

********************************************************************************
// 2. Apply CEM Matching (based on Helge's coarsening choices)
// We match proposals where prps_first == 1, treating voting_type_nonsc as treatment.
********************************************************************************
cem  ///
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

// Keep only matched observations
keep if cem_weights > 0

********************************************************************************
// 3. Fixed Effects Analysis - Voting Behavior on Matched Sample
********************************************************************************
eststo clear
foreach var in 1m 3m 6m {
   
   // Model 1: Basic specification on matched sample
   eststo voting_`var'_m1: reghdfe voting_`var' ///
       c.voted ///
       c.misaligned_wmiss ///
       if end_`var' == 0 & own_choice_tied == 0 & own_margin != 0, ///
       absorb(voter_id year_month_num) vce(cluster voter_space_id)

   // Model 2: Add governance characteristics on matched sample
   eststo voting_`var'_m2: reghdfe voting_`var' ///
       c.voted ///
       c.misaligned_wmiss ///
       type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
       plugin_safesnap strategy_delegation is_majority_win privacy ///
       if end_`var' == 0 & own_choice_tied == 0 & own_margin != 0, ///
       absorb(voter_id year_month_num) vce(cluster voter_space_id)

   // Model 3: Add voter characteristics on matched sample
   eststo voting_`var'_m3: reghdfe voting_`var' ///
       c.voted ///
       c.misaligned_wmiss ///
       type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
       plugin_safesnap strategy_delegation is_majority_win privacy ///
       c.voter_tenure_space c.times_voted_space_cum ///
       c.diff_days_last_vote_space c.relative_voting_power_act ///
       c.votes_dao_cum ///
       if end_`var' == 0 & own_choice_tied == 0 & own_margin != 0, ///
       absorb(voter_id year_month_num) vce(cluster voter_space_id)

   // Model 4: Full specification on matched sample
   eststo voting_`var'_m4: reghdfe voting_`var' ///
       c.voted ///
       c.misaligned_wmiss ///
       type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
       plugin_safesnap strategy_delegation is_majority_win privacy ///
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
}

********************************************************************************
// 4. Export Results (Matched Sample)
********************************************************************************
foreach var in 1m 3m 6m {
   // Full table
   esttab voting_`var'_m1 voting_`var'_m2 voting_`var'_m3 voting_`var'_m4 ///
       using "$dao_folder/results/tables/fe_voting_`var'_simple_matched.rtf", ///
       replace ///
       cells(b(star fmt(3)) se(par fmt(3))) ///
       star(* 0.10 ** 0.05 *** 0.01) ///
       title("Effects on Future Voting: `var' horizon (Matched Sample)") ///
       mtitles("Basic" "Gov Char" "+Voter Char" "Full") ///
       scalars("r2_a Adjusted R-sq" "N Observations") ///
       note("Standard errors clustered at voter-space level in parentheses; Matched sample via CEM." ///
            "* p<0.10, ** p<0.05, *** p<0.01") ///
       label compress

   // Key coefficients table
   esttab voting_`var'_m1 voting_`var'_m2 voting_`var'_m3 voting_`var'_m4 ///
       using "$dao_folder/results/tables/fe_voting_`var'_key_coef_simple_matched.rtf", ///
       replace ///
       cells(b(star fmt(3)) se(par fmt(3))) ///
       keep(voted misaligned_wmiss) ///
       star(* 0.10 ** 0.05 *** 0.01) ///
       title("Key Effects on Future Voting: `var' horizon (Matched Sample)") ///
       mtitles("Basic" "Gov Char" "+Voter Char" "Full") ///
       scalars("r2_a Adjusted R-sq" "N Observations") ///
       note("Standard errors clustered at voter-space level in parentheses; Matched sample via CEM." ///
            "* p<0.10, ** p<0.05, *** p<0.01") ///
       label compress
}

// Compare across time horizons (full model, matched sample)
esttab voting_1m_m4 voting_3m_m4 voting_6m_m4 ///
   using "$dao_folder/results/tables/fe_comparison_simple_matched.rtf", ///
   replace ///
   cells(b(star fmt(3)) se(par fmt(3))) ///
   star(* 0.10 ** 0.05 *** 0.01) ///
   title("Effects Across Time Horizons - Full Model (Matched Sample)") ///
   mtitles("1-month" "3-month" "6-month") ///
   scalars("r2_a Adjusted R-sq" "N Observations") ///
   note("Standard errors clustered at voter-space level in parentheses; Matched sample via CEM." ///
        "* p<0.10, ** p<0.05, *** p<0.01") ///
   label compress

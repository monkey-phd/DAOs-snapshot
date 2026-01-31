use "$dao_folder/processed/panel_full.dta", clear

drop winning_choices lag_times_voted_all_cum vs_types space_no_vot_types
drop active_vp max_times_voted_space year month
drop proposal_end_datetime proposal_end_date voting_period_length
drop dao_creation_date prps_link prps_stub total_votes

// Setup panel structure    
xtset voter_space_id voter_space_prps_counter

by proposal_space_id (vote_datetime), sort: gen first_vote_space = 1 if [_n] == 1

* date of first basic
by space_id (vote_datetime), sort: egen first_basic_space_dummy = min(year_month_num) if type_basic == 1
sum first_basic_space_dummy

order space_id proposal_space_counter vote_datetime first_basic_space_dummy

by space_id (vote_datetime), sort: egen first_basic_space= min(first_basic_space_dummy)
* count 6 months after

order space_id proposal_space_counter vote_datetime first_basic_space first_basic_space_dummy

drop first_basic_space_dummy

gen post_intro_basic = year_month_num - first_basic_space

replace post_intro_basic = 0 if post_intro_basic == .
replace post_intro_basic = 0 if post_intro_basic > 6
replace post_intro_basic = 0 if post_intro_basic < 0


reghdfe voting_1m ///
       c.voted ///
       c.misaligned_wmiss c.misaligned_wmiss##i.type_basic##i.post_intro_basic ///
       type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
        is_majority_win privacy ///
       c.voter_tenure_space c.times_voted_space_cum ///
       c.diff_days_last_vote_space c.relative_voting_power_act ///
       c.votes_dao_cum ///
       if end_3m == 0 & own_choice_tied == 0 & own_margin != 0, ///
       absorb(voter_id year_month_num) vce(cluster voter_space_id)
	   

eststo clear
foreach var in 1m 3m 6m {
   
   // Model 1: Basic specification
   eststo voting_`var'_m1: reghdfe voting_`var' ///
       c.voted ///
		c.misaligned_wmiss c.misaligned_wmiss##i.type_basic##i.post_intro_basic ///
       if end_`var' == 0 & own_choice_tied == 0 & own_margin != 0, ///
       absorb(voter_id year_month_num) vce(cluster voter_space_id)

   // Model 2: Add governance characteristics
   eststo voting_`var'_m2: reghdfe voting_`var' ///
       c.voted ///
		c.misaligned_wmiss c.misaligned_wmiss##i.type_basic##i.post_intro_basic ///
       type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
        is_majority_win privacy ///
       if end_`var' == 0 & own_choice_tied == 0 & own_margin != 0, ///
       absorb(voter_id year_month_num) vce(cluster voter_space_id)

   // Model 3: Add voter characteristics
   eststo voting_`var'_m3: reghdfe voting_`var' ///
       c.voted ///
      c.misaligned_wmiss c.misaligned_wmiss##i.type_basic##i.post_intro_basic ///
       type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
        is_majority_win privacy ///
       c.voter_tenure_space c.times_voted_space_cum ///
       c.diff_days_last_vote_space c.relative_voting_power_act ///
       c.votes_dao_cum ///
       if end_`var' == 0 & own_choice_tied == 0 & own_margin != 0, ///
       absorb(voter_id year_month_num) vce(cluster voter_space_id)

   // Model 4: Full specification
   eststo voting_`var'_m4: reghdfe voting_`var' ///
       c.voted ///
      c.misaligned_wmiss c.misaligned_wmiss##i.type_basic##i.post_intro_basic ///
       type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
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
}

********************************************************************************
// 3. Export Results
********************************************************************************
// Results for each time horizon
foreach var in 1m 3m 6m {
   // Full table
   
   // Key coefficients table
   esttab voting_`var'_m1 voting_`var'_m2 voting_`var'_m3 voting_`var'_m4 ///
       using "$dao_folder/results/tables/fe_voting_`var'_key_coef_basic.rtf", ///
       replace ///
       cells(b(star fmt(3)) se(par fmt(3))) ///
       star(* 0.10 ** 0.05 *** 0.01) ///
       title("Key Effects on Future Voting: `var' horizon") ///
       mtitles("Basic" "Gov Char" "+Voter Char" "Full") ///
       scalars("r2_a Adjusted R-sq" "N Observations") ///
       note("Standard errors clustered at voter-space level in parentheses" ///
            "* p<0.10, ** p<0.05, *** p<0.01") ///
       label compress
	   
	} 
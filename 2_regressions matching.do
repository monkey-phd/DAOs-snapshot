
///voting_1m voting_3m voting_6m end_1m end_3m end_6m
forvalues i = 0(250)250 { 
	use "$dao_folder/processed/panel_almost_full.dta", clear
	
	local j = `i' + 250
	display `i'
	display `j'
	keep if space_id >= `i' & space_id < `j'
	count
	
	xtset voter_space_id voter_space_prps_counter
	
	//bysort proposal_space_id (vote_datetime): gen proposal_first = 1 if [_n] == 1
	
	///Predict propensity to vote with two models
	probit misaligned_wmiss ///
		type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
		prps_len prps_choices_bin prps_rel_quorum prps_link prps_stub ///	
		topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
		topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
		topic_17 topic_18 topic_19 ///
		voter_tenure_space votes_proposal_cum voter_tenure_all ///
		relative_voting_power_pot relative_voting_power_act ///
		i.year_month_num, vce(cluster voter_space_id) iter(20)
	estimates store m1
	predict propensity1
	
	//bysort proposal_space_id: egen prop1 = max(propensity1)

	///Use propensities from both regressions to setup matched sample
	psmatch2 misaligned_wmiss, ///
	pscore(propensity1) outcome(voting_6m) neighbor(1)
	
	
	///prps_rel_quorum
	reghdfe voting_6m ///
		c.voted c.misaligned_wmiss ///
		c.misaligned_wmiss#c.type_basic ///
		c.misaligned_wmiss#c.type_approval ///
		c.misaligned_wmiss#c.type_quadratic  ///
		c.misaligned_wmiss#c.type_ranked_choice  ///
		c.misaligned_wmiss#c.type_weighted ///
		c.misaligned_wmiss#c.prps_choices_bin ///
		c.misaligned_wmiss#c.prps_rel_quorum ///
		type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
		prps_len prps_choices_bin prps_rel_quorum ///	
		topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
		topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
		topic_17 topic_18 topic_19 ///
		relative_voting_power_act if end_6m == 0 & own_choice_tied == 0, ///
		absorb(voter_id year_month_num) vce(cluster voter_space_id)	
	estimates store m1, title("6 months")
		
	reghdfe voting_3m ///
		c.voted c.misaligned_wmiss ///
		c.misaligned_wmiss#c.type_basic ///
		c.misaligned_wmiss#c.type_approval ///
		c.misaligned_wmiss#c.type_quadratic  ///
		c.misaligned_wmiss#c.type_ranked_choice  ///
		c.misaligned_wmiss#c.type_weighted ///
		c.misaligned_wmiss#c.prps_choices_bin ///
		c.misaligned_wmiss#c.prps_rel_quorum ///
		type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
		prps_len prps_choices_bin prps_rel_quorum ///	
		topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
		topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
		topic_17 topic_18 topic_19 ///
		relative_voting_power_act if end_3m == 0 & own_choice_tied == 0, ///
		absorb(voter_id year_month_num) vce(cluster voter_space_id)	
	estimates store m2, title("3 months")	
		
	reghdfe voting_1m ///
		c.voted c.misaligned_wmiss ///
		c.misaligned_wmiss#c.type_basic ///
		c.misaligned_wmiss#c.type_approval ///
		c.misaligned_wmiss#c.type_quadratic  ///
		c.misaligned_wmiss#c.type_ranked_choice  ///
		c.misaligned_wmiss#c.type_weighted ///
		c.misaligned_wmiss#c.prps_choices_bin ///
		c.misaligned_wmiss#c.prps_rel_quorum ///
		type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
		prps_len prps_choices_bin prps_rel_quorum ///	
		topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
		topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
		topic_17 topic_18 topic_19 ///
		relative_voting_power_act if end_1m == 0 & own_choice_tied == 0, ///
		absorb(voter_id year_month_num) vce(cluster voter_space_id)		
	estimates store m3, title("1 month")

	reghdfe voting_6m ///
		c.voted c.misaligned_wmiss ///
		c.misaligned_wmiss#c.type_basic ///
		c.misaligned_wmiss#c.type_approval ///
		c.misaligned_wmiss#c.type_quadratic  ///
		c.misaligned_wmiss#c.type_ranked_choice  ///
		c.misaligned_wmiss#c.type_weighted ///
		c.misaligned_wmiss#c.prps_choices_bin ///
		c.misaligned_wmiss#c.prps_rel_quorum ///
		type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
		prps_len prps_choices_bin prps_rel_quorum ///	
		topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
		topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
		topic_17 topic_18 topic_19 ///
		relative_voting_power_act [aw= _weight] if end_6m == 0 & own_choice_tied == 0, ///
		absorb(voter_id year_month_num) vce(cluster voter_space_id)	
	estimates store m4, title("6 months - Matched")
		
	reghdfe voting_3m ///
		c.voted c.misaligned_wmiss ///
		c.misaligned_wmiss#c.type_basic ///
		c.misaligned_wmiss#c.type_approval ///
		c.misaligned_wmiss#c.type_quadratic  ///
		c.misaligned_wmiss#c.type_ranked_choice  ///
		c.misaligned_wmiss#c.type_weighted ///
		c.misaligned_wmiss#c.prps_choices_bin ///
		c.misaligned_wmiss#c.prps_rel_quorum ///
		type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
		prps_len prps_choices_bin prps_rel_quorum ///	
		topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
		topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
		topic_17 topic_18 topic_19 ///
		relative_voting_power_act [aw= _weight] if end_3m == 0 & own_choice_tied == 0, ///
		absorb(voter_id year_month_num) vce(cluster voter_space_id)	
	estimates store m5, title("3 months - Matched")	
		
	reghdfe voting_1m ///
		c.voted c.misaligned_wmiss ///
		c.misaligned_wmiss#c.type_basic ///
		c.misaligned_wmiss#c.type_approval ///
		c.misaligned_wmiss#c.type_quadratic  ///
		c.misaligned_wmiss#c.type_ranked_choice  ///
		c.misaligned_wmiss#c.type_weighted ///
		c.misaligned_wmiss#c.prps_choices_bin ///
		c.misaligned_wmiss#c.prps_rel_quorum ///
		type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
		prps_len prps_choices_bin prps_rel_quorum ///	
		topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
		topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
		topic_17 topic_18 topic_19 ///
		relative_voting_power_act [aw= _weight] if end_1m == 0 & own_choice_tied == 0, ///
		absorb(voter_id year_month_num) vce(cluster voter_space_id)		
	estimates store m6, title("1 month - Matched")

	
	estfe m*, labels(voter_id "Voter fixed effects" year_month_num 	///
		"Month fixed effects" proposal_id "Proposal fixed effects") 
	
	esttab m1 m2 m3 m4 m5 m6 using "$dao_folder/results/tables/matching_`i'.rtf", ///
		cells(b(fmt(%9.3f)) se(par) p(fmt(3) par([ ]))) ///
		stats(r2 r2_within N, fmt(%9.3f %9.3f %9.0gc) ///
		labels("R-squared overall" "R-squared within" "Observations")) ///
		legend collabels(none) varlabels(_cons Constant) replace compress label  ///
		varwidth(30) modelwidth(10) interaction( " X ") ///
		indicate(`r(indicate_fe)') ///
		nodepvars nonumbers noomitted unstack ///
		addnotes("Clustered standard errors in parentheses; p-values in brackets.")	
			
	eststo clear

}

	

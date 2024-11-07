
///voting_1m voting_3m voting_6m end_1m end_3m end_6m
forvalues i = 0(50)250 { 
	use "$dao_folder/processed/panel_full.dta", clear
	
	xtset voter_space_id voter_space_prps_counter
	local j = `i' + 50
	display `i'
	display `j'
	keep if space_id >= `i' & space_id < `j'
	count
	
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
		relative_voting_power_act if end_6m == 0 & tied == 0, ///
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
		relative_voting_power_act if end_3m == 0 & tied == 0, ///
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
		relative_voting_power_act if end_1m == 0 & tied == 0, ///
		absorb(voter_id year_month_num) vce(cluster voter_space_id)		
	estimates store m3, title("1 month")
	
	reghdfe voting_3m ///
		c.misaligned_wmiss ///
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
		relative_voting_power_act if end_3m == 0 & voted == 1 & tied ==0, ///
		absorb(voter_id year_month_num) vce(cluster voter_space_id)	
	estimates store m4, title("3 months, Only Voted")		
	
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
		relative_voting_power_act if end_3m == 0 & relative_voting_power_act > 0.0004  & tied == 0, ///
		absorb(voter_id year_month_num) vce(cluster voter_space_id)	
	estimates store m5, title("3 months, High power voters")	
	
	reghdfe voting_3m ///
		c.voted c.mal_c_wmiss ///
		c.mal_c_wmiss#c.type_basic ///
		c.mal_c_wmiss#c.type_approval ///
		c.mal_c_wmiss#c.type_quadratic  ///
		c.mal_c_wmiss#c.type_ranked_choice  ///
		c.mal_c_wmiss#c.type_weighted ///
		c.misaligned_wmiss#c.prps_choices_bin ///
		c.misaligned_wmiss#c.prps_rel_quorum ///
		type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
		prps_len prps_choices_bin prps_rel_quorum ///	
		topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
		topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
		topic_17 topic_18 topic_19 ///
		relative_voting_power_act if end_3m == 0  & tied == 0, ///
		absorb(voter_id year_month_num) vce(cluster voter_space_id)	
	estimates store m6, title("3 months, Weighted Misaligned")		
	
	estfe m*, labels(voter_id "Voter fixed effects" year_month_num 	///
		"Month fixed effects" proposal_id "Proposal fixed effects") 
	
	esttab m1 m3 m2 m4 m5 m6 using "$dao_folder/results/tables/a_part_`i'.rtf", ///
		cells(b(fmt(%9.3f)) se(par) p(fmt(3) par([ ]))) ///
		stats(r2 r2_within N, fmt(%9.3f %9.3f %9.0gc) ///
		labels("R-squared overall" "R-squared within" "Observations")) ///
		legend collabels(none) varlabels(_cons Constant) replace compress label  ///
		varwidth(30) modelwidth(10) interaction( " X ") ///
		indicate(`r(indicate_fe)') ///
		nodepvars nonumbers noomitted unstack ///
		addnotes("Clustered standard errors in parentheses; p-values in brackets.")	
			
	eststo clear
	/*
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
		relative_voting_power_act if end_3m == 0 & vs_types > 1  & tied == 0, ///
		absorb(voter_id year_month_num) vce(cluster voter_space_id)	
	estimates store m1, title("2 types")				
			
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
		relative_voting_power_act if end_3m == 0 & vs_types > 2 & tied == 0, ///
		absorb(voter_id year_month_num) vce(cluster voter_space_id)	
	estimates store m2, title("3 types")						

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
		relative_voting_power_act if end_3m == 0 & vs_types > 3 & tied == 0, ///
		absorb(voter_id year_month_num) vce(cluster voter_space_id)	
	estimates store m3, title("4 types")				
	
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
		relative_voting_power_act if end_3m == 0 & vs_types > 4 & tied == 0, ///
		absorb(voter_id year_month_num) vce(cluster voter_space_id)	
	estimates store m4, title("5 types")			
	
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
		relative_voting_power_act if end_3m == 0 & vs_types > 5 & tied == 0, ///
		absorb(voter_id year_month_num) vce(cluster voter_space_id)	
	estimates store m5, title("All types")				
	
	estfe m*, labels(voter_id "Voter fixed effects" year_month_num 	///
		"Month fixed effects" proposal_id "Proposal fixed effects") 
	
	esttab m1 m2 m3 m4 m5 using "$dao_folder/results/tables/a_vot_types_`i'.rtf", ///
		cells(b(fmt(%9.3f)) se(par) p(fmt(3) par([ ]))) ///
		stats(r2 r2_within N, fmt(%9.3f %9.3f %9.0gc) ///
		labels("R-squared overall" "R-squared within" "Observations")) ///
		legend collabels(none) varlabels(_cons Constant) replace compress label  ///
		varwidth(30) modelwidth(10) interaction( " X ") ///
		indicate(`r(indicate_fe)') ///
		nodepvars nonumbers noomitted unstack ///
		addnotes("Clustered standard errors in parentheses; p-values in brackets.")	
	*/
	/*
	binscatter voting_3m rel_own_score if rel_own_score > 0.8 & rel_own_score < 1.2, rd(1.01) ///
	controls(type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
		prps_len prps_choices_bin prps_rel_quorum ///	
		topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
		topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
		topic_17 topic_18 topic_19)
	graph rename m3, replace
	graph export m3.png, width(1200) height(900)

	binscatter voting_6m rel_own_score if rel_own_score > 0.8 & rel_own_score < 1.2, rd(1.01) ///
		controls(type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
			prps_len prps_choices_bin prps_rel_quorum ///	
			topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
			topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
			topic_17 topic_18 topic_19)
	graph rename m6, replace
	graph export m6.png, width(1200) height(900)

	binscatter voting_1m rel_own_score if rel_own_score > 0.8 & rel_own_score < 1.2, rd(1.01) ///
		controls(type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
			prps_len prps_choices_bin prps_rel_quorum ///	
			topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
			topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
			topic_17 topic_18 topic_19)
	graph rename m1, replace
	graph export m1.png, width(1200) height(900)
	*/
}

	

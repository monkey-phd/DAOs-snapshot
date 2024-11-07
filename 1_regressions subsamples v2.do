use "$dao_folder/processed/panel_almost_full.dta", clear

gen active_6m = 0
replace active_6m = 1 if voting_6m > 0

xtset voter_space_id voter_space_prps_counter
	
reghdfe active_6m ///
	c.voted c.misaligned_wmiss  ///
	prps_len prps_choices_bin prps_rel_quorum ///	
	plugin_safesnap strategy_delegation ///
	topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
	topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
	topic_17 topic_18 topic_19 ///
	relative_voting_power_act if end_6m == 0 & own_choice_tied == 0 & own_margin != 0 & type_single_choice == 1,  ///
	absorb(voter_id year_month_num) vce(cluster voter_space_id)	
estimates store m1, title("Single Choice")	

drop if type_single_choice == 1

reghdfe active_6m ///
	c.voted c.misaligned_wmiss  ///
	prps_len prps_choices_bin prps_rel_quorum ///
	plugin_safesnap strategy_delegation ///
	topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
	topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
	topic_17 topic_18 topic_19 ///
	relative_voting_power_act if end_6m == 0 & own_choice_tied == 0 & own_margin != 0 & type_basic == 1,  ///
	absorb(voter_id year_month_num) vce(cluster voter_space_id)	
estimates store m6, title("Basic")	

drop if type_basic == 1

reghdfe active_6m ///
	c.voted c.misaligned_wmiss  ///
	prps_len prps_choices_bin prps_rel_quorum ///	
	plugin_safesnap strategy_delegation ///
	topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
	topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
	topic_17 topic_18 topic_19 ///
	relative_voting_power_act if end_6m == 0 & own_choice_tied == 0 & own_margin != 0 & type_approval == 1,  ///
	absorb(voter_id year_month_num) vce(cluster voter_space_id)	
estimates store m2, title("Approval")	

drop if type_approval == 1

reghdfe active_6m ///
	c.voted c.misaligned_wmiss  ///
	prps_len prps_choices_bin prps_rel_quorum ///	
	plugin_safesnap strategy_delegation ///
	topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
	topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
	topic_17 topic_18 topic_19 ///
	relative_voting_power_act if end_6m == 0 & own_choice_tied == 0 & own_margin != 0 & type_quadratic == 1,  ///
	absorb(voter_id year_month_num) vce(cluster voter_space_id)	
estimates store m3, title("Quadratic")	

drop if type_quadratic == 1

reghdfe active_6m ///
	c.voted c.misaligned_wmiss  ///
	prps_len prps_choices_bin prps_rel_quorum ///
	plugin_safesnap strategy_delegation ///
	topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
	topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
	topic_17 topic_18 topic_19 ///
	relative_voting_power_act if end_6m == 0 & own_choice_tied == 0 & own_margin != 0 & type_ranked_choice == 1,  ///
	absorb(voter_id year_month_num) vce(cluster voter_space_id)	
estimates store m4, title("Ranked")	

drop if type_ranked_choice == 1

reghdfe active_6m ///
	c.voted c.misaligned_wmiss  ///
	prps_len prps_choices_bin prps_rel_quorum ///
	plugin_safesnap strategy_delegation ///
	topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
	topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
	topic_17 topic_18 topic_19 ///
	relative_voting_power_act if end_6m == 0 & own_choice_tied == 0 & own_margin != 0 & type_weighted == 1,  ///
	absorb(voter_id year_month_num) vce(cluster voter_space_id)	
estimates store m5, title("Weighted")	

estfe m*, labels(voter_id "Voter fixed effects" proposal_id "Proposal fixed effects" year_month_num "Month fixed effects") 

esttab m1 m3 m2 m4 m5 m6 using "$dao_folder/results/tables/subsample_type_6m_v2.rtf", ///
	cells(b(fmt(%9.3f)) se(par) p(fmt(3) par([ ]))) ///
	stats(r2 r2_within N, fmt(%9.3f %9.3f %9.0gc) ///
	labels("R-squared overall" "R-squared within" "Observations")) ///
	legend collabels(none) varlabels(_cons Constant) replace compress label  ///
	varwidth(30) modelwidth(10) interaction( " X ") ///
	indicate(`r(indicate_fe)') ///
	nodepvars nonumbers noomitted unstack ///
	addnotes("Clustered standard errors in parentheses; p-values in brackets.")	
		



	

use "$dao_folder/processed/panel_full.dta", clear /// before, panel_almost_full.dta

xtset voter_space_id voter_space_prps_counter
/*
bysort voter_space_id (voter_space_prps_counter): gen voter_active_f1 = f.voter_active


stset voter_space_prps_counter, id(voter_space_id) failure(voter_active_f1==0)
*/

reghdfe  voting_3m ///
	c.voted ///
	c.misaligned_wmiss ///
	c.voted#c.is_majority_win ///
	c.voted#c.plugin_safesnap /// 
	c.voted#c.strategy_delegation /// 
	c.misaligned_wmiss#c.is_majority_win ///
	c.misaligned_wmiss#c.plugin_safesnap ///
	c.misaligned_wmiss#c.strategy_delegation ///
	plugin_safesnap strategy_delegation is_majority_win ///
	type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
	prps_len prps_choices_bin prps_rel_quorum ///	
	topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
	topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
	topic_17 topic_18 topic_19 ///
	relative_voting_power_act if end_3m == 0 & own_choice_tied == 0 & space_id >= 0 & space_id < 20, /// dao_cluster 1,2,3
	absorb(voter_id year_month_num) vce(cluster voter_space_id)	
estimates store m1, title("S1")	

reghdfe voting_3m ///
	c.voted ///
	c.misaligned_wmiss ///
	c.voted#c.is_majority_win ///
	c.voted#c.plugin_safesnap /// 
	c.voted#c.strategy_delegation /// 
	c.misaligned_wmiss#c.is_majority_win ///
	c.misaligned_wmiss#c.plugin_safesnap ///
	c.misaligned_wmiss#c.strategy_delegation ///
	plugin_safesnap strategy_delegation is_majority_win ///
	type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
	prps_len prps_choices_bin prps_rel_quorum ///	
	topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
	topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
	topic_17 topic_18 topic_19 ///
	relative_voting_power_act if end_3m == 0 & own_choice_tied == 0 & space_id >= 0 & space_id < 20, /// dao_cluster 1,2,3
	absorb(voter_id year_month_num) vce(cluster voter_space_id)	
estimates store m2, title("S2")	

reghdfe voting_3m ///
	c.voted ///
	c.misaligned_wmiss ///
	c.voted#c.is_majority_win ///
	c.voted#c.plugin_safesnap /// 
	c.voted#c.strategy_delegation /// 
	c.misaligned_wmiss#c.is_majority_win ///
	c.misaligned_wmiss#c.plugin_safesnap ///
	c.misaligned_wmiss#c.strategy_delegation ///
	plugin_safesnap strategy_delegation is_majority_win ///
	type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
	prps_len prps_choices_bin prps_rel_quorum ///	
	topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
	topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
	topic_17 topic_18 topic_19 ///
	relative_voting_power_act if end_3m == 0 & own_choice_tied == 0 & space_id >= 0 & space_id < 20, /// dao_cluster 1,2,3
	absorb(voter_id year_month_num) vce(cluster voter_space_id)	
estimates store m3, title("S3")	

reghdfe voting_3m ///
	c.voted ///
	c.misaligned_wmiss ///
	c.voted#c.is_majority_win ///
	c.voted#c.plugin_safesnap /// 
	c.voted#c.strategy_delegation /// 
	c.misaligned_wmiss#c.is_majority_win ///
	c.misaligned_wmiss#c.plugin_safesnap ///
	c.misaligned_wmiss#c.strategy_delegation ///
	plugin_safesnap strategy_delegation is_majority_win ///
	type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
	prps_len prps_choices_bin prps_rel_quorum ///	
	topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
	topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
	topic_17 topic_18 topic_19 ///
	relative_voting_power_act if end_3m == 0 & own_choice_tied == 0 & space_id >= 0 & space_id < 20, /// dao_cluster 1,2,3
	absorb(voter_id year_month_num) vce(cluster voter_space_id)	
estimates store m4, title("S4")	

reghdfe voting_3m ///
	c.voted ///
	c.misaligned_wmiss ///
	c.voted#c.is_majority_win ///
	c.voted#c.plugin_safesnap /// 
	c.voted#c.strategy_delegation /// 
	c.misaligned_wmiss#c.is_majority_win ///
	c.misaligned_wmiss#c.plugin_safesnap ///
	c.misaligned_wmiss#c.strategy_delegation ///
	plugin_safesnap strategy_delegation is_majority_win ///
	type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
	prps_len prps_choices_bin prps_rel_quorum ///	
	topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
	topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
	topic_17 topic_18 topic_19 ///
	relative_voting_power_act if end_3m == 0 & own_choice_tied == 0 & space_id >= 0 & space_id < 20, /// dao_cluster 1,2,3
	absorb(voter_id year_month_num) vce(cluster voter_space_id)	
estimates store m5, title("S5")	

/* estfe is not a standard Stata command, custom package?
estfe m*, labels(voter_id "Voter fixed effects" year_month_num 	/// 
	"Month fixed effects" proposal_id "Proposal fixed effects") 
*/

esttab m1 m3 m2 m4 m5 using "$dao_folder/results/tables/subsamples_interactions_1a.rtf", ///
	cells(b(fmt(%9.3f)) se(par) p(fmt(3) par([ ]))) ///
	stats(r2 r2_within N, fmt(%9.3f %9.3f %9.0gc) ///
	labels("R-squared overall" "R-squared within" "Observations")) ///
	legend collabels(none) varlabels(_cons Constant) replace compress label  ///
	varwidth(30) modelwidth(10) interaction( " X ") ///
	indicate(`r(indicate_fe)') ///
	nodepvars nonumbers noomitted unstack ///
	addnotes("Models include voter, proposal and month fixed effects. Clustered standard errors in parentheses; p-values in brackets.")	
		



	


/*
ssc install julia
net install reghdfejl, replace from(https://raw.github.com/droodman/reghdfejl/v1.0.8)
*/

///voting_1m voting_3m voting_6m end_1m end_3m end_6m
forvalues i = 0(250)250 { 
	use "$dao_folder/processed/panel_almost_full_helge.dta", clear
	
	drop winning_choices dao_creation_date proposal_end_datetime proposal_end_date month year times_voted_space_cum max_times_voted_space voter_active proposal_active_voters proposal_total_voted active_vp relative_voting_power_pot proposal_space_id voter_tenure_all times_voted_all_cum diff_days_last_proposal_all lag_times_voted_all_cum diff_days_last_vote_all met_quorum scores_total total_votes diff_days_last_proposal_space lag_times_votes_space_cum diff_days_last_vote_space
	
	local j = `i' + 250
	display `i'
	display `j'
	keep if space_id >= `i' & space_id < `j'
	count
	
	xtset voter_space_id voter_space_prps_counter
	
	gen voting_type_nonsc = 0
	replace voting_type_nonsc = 1 if type_single_choice == 0
	
	bysort proposal_id (vote_datetime): gen prps_first = 1  if [_n] == 1
	
	//bysort proposal_space_id (vote_datetime): gen proposal_first = 1 if [_n] == 1
	
	/*
	
	///Predict propensity to vote with two models
	probit voting_type_nonsc ///
		prps_len prps_choices_bin prps_rel_quorum prps_link prps_stub ///	
		topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
		topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
		topic_17 topic_18 topic_19 , iter(20)
	estimates store m1
	predict propensity1 if prps_first == 1
	
	//bysort proposal_space_id: egen prop1 = max(propensity1)

	///Use propensities from both regressions to setup matched sample
	psmatch2 voting_type_nonsc if prps_first, ///
	pscore(propensity1) outcome(voting_6m) neighbor(1)
	
	by proposal_id, sort: egen _weight_prop = max(_weight)
	
	cem FirmAge (-5 6 12.5 23.5 350) ///
	PreAcquiH1AvgAuthors ///
	PreAcquiH2AvgAuthors ///
	PreAcquiCommitTrend ///
	ProjectAge (0 12 24 36 48 60 150) ///
	AcquisitionPeriodForMatch (0 12 24 36 48 60 72 84 96) ///
	NumEmployeesCoarsened_numeric (0 1.5 2.5 3.5 4.5)  /// 
	CoarsenedFocalShare (0 1.5 2.5 3.5 4.5) ///
	CoarsenedLicense_numeric (0 1.5 2.5 3.5) ///
	CoarsenedPreAcquiH1_numeric (0 1.5 2.5 3.5 4.5 5.5 6.5 7.5 8.5) ///
	CoarsenedPreAcquiH2_numeric (0 1.5 2.5 3.5 4.5 5.5 6.5 7.5 8.5) ///
	, tr(Treated) showbreaks
	*/
	
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
	
	//Rename to Weight, so fits later dataset, and identifying Strata
	by proposal_id, sort: egen _weight_prps = max(cem_weights)
	
	/*
	///prps_rel_quorum
	reghdfe voting_6m ///
		c.voted c.misaligned_wmiss ///
		c.misaligned_wmiss#c.type_basic ///
		c.misaligned_wmiss#c.type_sc_abstain ///		
		c.misaligned_wmiss#c.type_approval ///
		c.misaligned_wmiss#c.type_quadratic  ///
		c.misaligned_wmiss#c.type_ranked_choice  ///
		c.misaligned_wmiss#c.type_weighted ///
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
		c.misaligned_wmiss#c.type_sc_abstain ///		
		c.misaligned_wmiss#c.type_approval ///
		c.misaligned_wmiss#c.type_quadratic  ///
		c.misaligned_wmiss#c.type_ranked_choice  ///
		c.misaligned_wmiss#c.type_weighted ///
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
		c.misaligned_wmiss#c.type_sc_abstain ///		
		c.misaligned_wmiss#c.type_approval ///
		c.misaligned_wmiss#c.type_quadratic  ///
		c.misaligned_wmiss#c.type_ranked_choice  ///
		c.misaligned_wmiss#c.type_weighted ///
		type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
		prps_len prps_choices_bin prps_rel_quorum ///	
		topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
		topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
		topic_17 topic_18 topic_19 ///
		relative_voting_power_act if end_1m == 0 & own_choice_tied == 0, ///
		absorb(voter_id year_month_num) vce(cluster voter_space_id)		
	estimates store m3, title("1 month")
	*/

	reghdfe voting_6m ///
		c.voted c.misaligned_wmiss ///
		c.misaligned_wmiss#c.type_basic ///
		c.misaligned_wmiss#c.type_sc_abstain ///		
		c.misaligned_wmiss#c.type_approval ///
		c.misaligned_wmiss#c.type_quadratic  ///
		c.misaligned_wmiss#c.type_ranked_choice  ///
		c.misaligned_wmiss#c.type_weighted ///
		type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
		prps_len prps_choices_bin prps_rel_quorum ///	
		topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
		topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
		topic_17 topic_18 topic_19 ///
		relative_voting_power_act [aw= _weight_prps] if end_6m == 0 & own_choice_tied == 0, ///
		absorb(voter_id year_month_num) vce(cluster voter_space_id)	
	estimates store m4, title("6 months - Matched")
		
	reghdfe voting_3m ///
		c.voted c.misaligned_wmiss ///
		c.misaligned_wmiss#c.type_basic ///
		c.misaligned_wmiss#c.type_sc_abstain ///		
		c.misaligned_wmiss#c.type_approval ///
		c.misaligned_wmiss#c.type_quadratic  ///
		c.misaligned_wmiss#c.type_ranked_choice  ///
		c.misaligned_wmiss#c.type_weighted ///
		type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
		prps_len prps_choices_bin prps_rel_quorum ///	
		topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
		topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
		topic_17 topic_18 topic_19 ///
		relative_voting_power_act [aw= _weight_prps] if end_3m == 0 & own_choice_tied == 0, ///
		absorb(voter_id year_month_num) vce(cluster voter_space_id)	
	estimates store m5, title("3 months - Matched")	
		
	reghdfe voting_1m ///
		c.voted c.misaligned_wmiss ///
		c.misaligned_wmiss#c.type_basic ///
		c.misaligned_wmiss#c.type_sc_abstain ///		
		c.misaligned_wmiss#c.type_approval ///
		c.misaligned_wmiss#c.type_quadratic  ///
		c.misaligned_wmiss#c.type_ranked_choice  ///
		c.misaligned_wmiss#c.type_weighted ///
		type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
		prps_len prps_choices_bin prps_rel_quorum ///	
		topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
		topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
		topic_17 topic_18 topic_19 ///
		relative_voting_power_act [aw= _weight_prps] if end_1m == 0 & own_choice_tied == 0, ///
		absorb(voter_id year_month_num) vce(cluster voter_space_id)		
	estimates store m6, title("1 month - Matched")

	reghdfe vp_1m_delta ///
		c.voted c.misaligned_wmiss ///
		c.misaligned_wmiss#c.type_basic ///
		c.misaligned_wmiss#c.type_sc_abstain ///		
		c.misaligned_wmiss#c.type_approval ///
		c.misaligned_wmiss#c.type_quadratic  ///
		c.misaligned_wmiss#c.type_ranked_choice  ///
		c.misaligned_wmiss#c.type_weighted ///
		type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
		prps_len prps_choices_bin prps_rel_quorum ///	
		topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
		topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
		topic_17 topic_18 topic_19 ///
		relative_voting_power_act [aw= _weight_prps] if end_1m == 0 & own_choice_tied == 0, ///
		absorb(voter_id year_month_num) vce(cluster voter_space_id)		
	estimates store m7, title("1 month - Matched")	
	
	estfe m*, labels(voter_id "Voter fixed effects" year_month_num 	///
		"Month fixed effects" proposal_id "Proposal fixed effects") 
	
	esttab m4 m5 m6 m7 using "$dao_folder/results/tables/matching_full.rtf", ///
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

	

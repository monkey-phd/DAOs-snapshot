use "$dao_folder/processed/panel_almost_full_helge.dta", clear

gen vp_3m_up = 0
replace vp_3m_up = 1 if vp_3m_delta > 0

gen vp_3m_down = 0
replace vp_3m_down = 1 if vp_3m_delta < 0

gen vp_3m_delta_down = 0
replace vp_3m_delta_down = vp_3m_delta if vp_3m_delta < 0

reghdfe vp_3m_up ///
	c.voted c.misaligned_wmiss ///
	c.misaligned_wmiss#c.type_basic ///
	c.misaligned_wmiss#c.type_sc_abstain ///
	c.misaligned_wmiss#c.type_approval ///
	c.misaligned_wmiss#c.type_quadratic  ///
	c.misaligned_wmiss#c.type_ranked_choice  ///
	c.misaligned_wmiss#c.type_weighted ///
	c.misaligned_wmiss#c.prps_choices_bin ///
	c.misaligned_wmiss#c.prps_rel_quorum ///
	type_approval type_basic type_quadratic type_ranked_choice ///
	type_weighted type_sc_abstain ///
	prps_len prps_choices_bin prps_rel_quorum ///	
	topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
	topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
	topic_17 topic_18 topic_19 ///
	relative_voting_power_act if end_3m == 0 & own_choice_tied == 0, ///
	absorb(voter_id year_month_num) vce(cluster voter_space_id)	

reghdfe vp_3m_down ///
	c.voted c.misaligned_wmiss ///
	c.misaligned_wmiss#c.type_basic ///
	c.misaligned_wmiss#c.type_sc_abstain ///
	c.misaligned_wmiss#c.type_approval ///
	c.misaligned_wmiss#c.type_quadratic  ///
	c.misaligned_wmiss#c.type_ranked_choice  ///
	c.misaligned_wmiss#c.type_weighted ///
	c.misaligned_wmiss#c.prps_choices_bin ///
	c.misaligned_wmiss#c.prps_rel_quorum ///
	type_approval type_basic type_quadratic type_ranked_choice ///
	type_weighted type_sc_abstain ///
	prps_len prps_choices_bin prps_rel_quorum ///	
	topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
	topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
	topic_17 topic_18 topic_19 ///
	relative_voting_power_act if end_3m == 0 & own_choice_tied == 0, ///
	absorb(voter_id year_month_num) vce(cluster voter_space_id)	
	
reghdfe vp_3m_delta_down ///
	c.voted c.misaligned_wmiss ///
	c.misaligned_wmiss#c.type_basic ///
	c.misaligned_wmiss#c.type_sc_abstain ///
	c.misaligned_wmiss#c.type_approval ///
	c.misaligned_wmiss#c.type_quadratic  ///
	c.misaligned_wmiss#c.type_ranked_choice  ///
	c.misaligned_wmiss#c.type_weighted ///
	c.misaligned_wmiss#c.prps_choices_bin ///
	c.misaligned_wmiss#c.prps_rel_quorum ///
	type_approval type_basic type_quadratic type_ranked_choice ///
	type_weighted type_sc_abstain ///
	prps_len prps_choices_bin prps_rel_quorum ///	
	topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
	topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
	topic_17 topic_18 topic_19 ///
	relative_voting_power_act if end_3m == 0 & own_choice_tied == 0, ///
	absorb(voter_id year_month_num) vce(cluster voter_space_id)		
	
xtlogit vp_3m_up ///
	c.voted c.misaligned_wmiss ///
	c.misaligned_wmiss#c.type_basic ///
	c.misaligned_wmiss#c.type_sc_abstain ///
	c.misaligned_wmiss#c.type_approval ///
	c.misaligned_wmiss#c.type_quadratic  ///
	c.misaligned_wmiss#c.type_ranked_choice  ///
	c.misaligned_wmiss#c.type_weighted ///
	c.misaligned_wmiss#c.prps_choices_bin ///
	c.misaligned_wmiss#c.prps_rel_quorum ///
	type_approval type_basic type_quadratic type_ranked_choice ///
	type_weighted type_sc_abstain ///
	prps_len prps_choices_bin prps_rel_quorum ///	
	topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
	topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
	topic_17 topic_18 topic_19 ///
	relative_voting_power_act if end_3m == 0 & own_choice_tied == 0, ///
	fe

xtlogit vp_3m_down ///
	c.voted c.misaligned_wmiss ///
	c.misaligned_wmiss#c.type_basic ///
	c.misaligned_wmiss#c.type_sc_abstain ///
	c.misaligned_wmiss#c.type_approval ///
	c.misaligned_wmiss#c.type_quadratic  ///
	c.misaligned_wmiss#c.type_ranked_choice  ///
	c.misaligned_wmiss#c.type_weighted ///
	c.misaligned_wmiss#c.prps_choices_bin ///
	c.misaligned_wmiss#c.prps_rel_quorum ///
	type_approval type_basic type_quadratic type_ranked_choice ///
	type_weighted type_sc_abstain ///
	prps_len prps_choices_bin prps_rel_quorum ///	
	topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
	topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
	topic_17 topic_18 topic_19 ///
	relative_voting_power_act if end_3m == 0 & own_choice_tied == 0, ///
	fe	
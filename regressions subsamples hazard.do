forvalues i = 0(75)225 { 
	use "$dao_folder/processed/panel_almost_full.dta", clear
	
	local j = `i' + 75
	display `i'
	display `j'
	keep if space_id >= `i' & space_id < `j'
	count

	bysort voter_space_id (voter_space_prps_counter): gen voter_active_f1 = voter_active[_n+1]

	stset voter_space_prps_counter, id(voter_space_id) failure(voter_active_f1==0)

	stcox  	c.misaligned_wmiss ///
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
		relative_voting_power_act , ///
		vce(cluster voter_space_id)	

}


	

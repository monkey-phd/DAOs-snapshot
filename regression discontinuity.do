use "$dao_folder/processed/panel_almost_full.dta", clear



ssc install rdrobust

* Create the treatment indicator
gen aligned = (rel_own_score > 1)


* Run the regression discontinuity
rdrobust vote_3m rel_own_score, covs(type_approval) kernel(triangular) bwselect(mserd)

* To test the moderating effect of type_approval
gen interaction = type_approval * rel_own_score
rdrobust vote_3m rel_own_score interaction, covs(type_approval) kernel(triangular) bwselect(mserd)

xtset voter_space_id voter_space_prps_counter

reghdfe voting_3m ///
	c.voted c.own_margin c.misaligned_wmiss ///
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
	relative_voting_power_act if end_3m == 0 & own_margin > -0.98 & own_margin < 0.98 & own_margin !=0, ///
	absorb(voter_id proposal_id year_month_num) vce(cluster voter_space_id)	

hist own_margin if own_margin < 0.99	
	
binscatter voting_3m own_margin if own_margin > -0.98 & own_margin < 0.98 & own_margin !=0

binscatter voting_3m own_margin if own_margin > -1 & own_margin < 0.98 & own_margin !=0
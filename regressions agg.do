
use "$dao_folder/processed/panel_agg_full.dta", clear

xtset voter_space_id quarter_step
//drop if space_id_size > `i'


reghdfe f.voted c.voted_6m_total voted  ///
	type_approval type_basic type_quadratic type_ranked_choice ///
	type_single_choice type_weighted ///
	voted_weighted voted_quad voted_app voted_basic voted_ranked voted_sc ///
	voted_topic_* topic_*  ///
	times_voted_space_cum times_voted_all_cum  ///
	voter_tenure_space  ///
	relative_voting_power_pot relative_voting_power_act  , ///
	absorb(voter_id quarter_step) vce(cluster voter_id)	
estimates store m1, title("Model 1")

reghdfe f.voted  voted ///
	mal_6m_miss    ///
	voted_weighted voted_quad voted_app voted_basic voted_ranked voted_sc ///
	type_approval type_basic type_quadratic type_ranked_choice ///
	type_single_choice type_weighted ///
	voted_topic_* topic_*  ///
	times_voted_space_cum times_voted_all_cum  ///
	voter_tenure_space  ///
	 relative_voting_power_act , ///
	absorb(voter_id quarter_step) vce(cluster voter_space_id)	
estimates store m2, title("Model 2")

///	voted_weighted voted_quad voted_app voted_basic voted_ranked voted_sc ///
///relative_voting_power_pot c.voted#c.mal_6m_miss

/*
margins, at(voted_6m = (0 0.25 0.5 0.75 1.0) mal_6m_total=(0.1 0.9) ) asbalanced
marginsplot, noci allsimplelabels legend(pos(6) rows(1) ///
subtitle("Misalignment")) title("")
graph export "$dao_folder/results/figures/marginsplot_main_`i'_v3.png", width(1200) replace 	
*/
///	voted_weighted voted_quad voted_app voted_basic voted_ranked voted_sc ///     

xtlogit  f.voted voted ///
	c.mal_6m_miss#c.mal_6m_w ///
	c.mal_6m_miss#c.mal_6m_q ///
	c.mal_6m_miss#c.mal_6m_app ///
	c.mal_6m_miss#c.mal_6m_b ///
	c.mal_6m_miss#c.mal_6m_r ///
	c.mal_6m_miss#c.mal_6m_sc ///
	type_approval type_basic type_quadratic type_ranked_choice ///
	type_single_choice type_weighted ///
	voted_topic_* topic_*  ///
	voter_tenure_space  ///
	relative_voting_power_act i.quarter_step if space_id_size < 100, ///
	pa vce(robust)	

	
fracreg logit f.voted voted ///
	c.mal_6m_miss#c.mal_6m_w ///
	c.mal_6m_miss#c.mal_6m_q ///
	c.mal_6m_miss#c.mal_6m_app ///
	c.mal_6m_miss#c.mal_6m_b ///
	c.mal_6m_miss#c.mal_6m_r ///
	c.mal_6m_miss#c.mal_6m_sc ///
	type_approval type_basic type_quadratic type_ranked_choice ///
	type_single_choice type_weighted ///
	voted_topic_* topic_*  ///
	voter_tenure_space  ///
	relative_voting_power_act i.quarter_step if space_id_size < 100 ///
	,   vce(robust)	

reghdfe f.voted  ///
	c.voted#c.mal_6m_miss ////
	c.voted#c.mal_6m_miss#c.mal_6m_w ///
	c.voted#c.mal_6m_miss#c.mal_6m_q ///
	c.voted#c.mal_6m_miss#c.mal_6m_app ///
	c.voted#c.mal_6m_miss#c.mal_6m_b ///
	c.voted#c.mal_6m_miss#c.mal_6m_r ///
	c.voted#c.mal_6m_miss#c.mal_6m_sc ///
	voted_weighted voted_quad voted_app voted_basic voted_ranked voted_sc ///   
	voted_topic_* ///
	voted_prps_len voted_prps_link voted_prps_choices ///
	voted_prps_stub  relative_voting_power_act, ///
	absorb(voter_id quarter_step) vce(cluster voter_space_id)	
	
reghdfe f.voted  c.voted mal_6m_miss ///
	c.voted#c.mal_6m_miss#c.mal_6m_w ///
	c.voted#c.mal_6m_miss#c.mal_6m_q ///
	c.voted#c.mal_6m_miss#c.mal_6m_app_low  ///
	c.voted#c.mal_6m_miss#c.mal_6m_app_high  ///
	c.voted#c.mal_6m_miss#c.mal_6m_b ///
	c.voted#c.mal_6m_miss#c.mal_6m_r ///
	c.voted#c.mal_6m_miss#c.mal_6m_sc ///	
	c.voted#c.mal_6m_miss#c.voted_prps_misalign ///
	c.voted#c.mal_6m_miss#c.voted_prps_choices ///
	c.voted#c.mal_6m_miss#c.voted_prps_part_rate ///
	c.voted#c.mal_6m_miss#c.prps_misalign ///
	c.voted#c.mal_6m_miss#c.prps_choices ///
	c.voted#c.mal_6m_miss#c.prps_part_rate ///
	voted_topic_* ///
	voted_weighted voted_quad voted_app voted_basic voted_ranked voted_sc ///  
	voted_prps_len voted_prps_link voted_prps_choices ///
	voted_prps_stub ///
	type_approval type_basic type_quadratic type_ranked_choice ///
	type_single_choice type_weighted ///
	prps_part_rate prps_misalign voted_prps_part_rate voted_prps_misalign ///
	topic_*   prps_len  ///
	prps_link prps_stub prps_choices ///
	relative_voting_power_act, ///
	absorb(voter_id quarter_step) vce(cluster voter_space_id)	
estimates store m3, title("Model 3")	

///voted_weighted voted_quad voted_app voted_basic voted_ranked voted_sc ///   

bysort voter_space_id (quarter_step): gen lead_voted = voted[_n+1]

binscatter lead_voted mal_6m_miss if mal_6m_miss > 0

/*
margins,  at( (asobserved) _all  voted_6m=(0 0.25 0.5 0.75 1.0) mal_6m_total=(0.1 0.9) mal_6m_w_total=(0 1)) 
marginsplot, by(mal_6m_q_v2) noci allsimplelabels legend(pos(6) rows(1) ///
	subtitle("Misalignment (Quadratic)")) title("")
graph export "$dao_folder/results/figures/marginsplot_int1_`i'_v2.png", width(1200) replace
*/


reghdfe f.voted c.voted_6m_total voted ///
	c.voted#c.mal_6m_miss  ///
	c.voted#c.mal_6m_miss#c.mal_6m_q_v2 ///
	type_approval type_basic type_quadratic type_ranked_choice ///
	type_single_choice type_weighted ///
	voted_weighted voted_quad voted_app voted_basic voted_ranked voted_sc ///
	voted_topic_* topic_*  ///
	times_voted_space_cum times_voted_all_cum  ///
	voter_tenure_space  ///
	relative_voting_power_pot relative_voting_power_act , ///
	absorb(voter_id quarter_step) vce(cluster voter_id)	
estimates store m4, title("Model 4")

/*
margins, at( (asobserved) _all  voted_6m=(0 0.25 0.5 0.75 1.0) mal_6m_total=(0.1 0.9) mal_6m_w_total=(0 1)) 
marginsplot, by(mal_6m_w_v2) noci allsimplelabels legend(pos(6) rows(1) ///
	subtitle("Misalignment (Weighted)")) title("")
graph export "$dao_folder/results/figures/marginsplot_int2_`i'_v2.png", width(1200) replace
*/
	
estfe m*, labels(voter_id "Voter fixed effects" year_month_num 	///
	"Month fixed effects" proposal_id "Proposal fixed effects") 

esttab m1 m2 m3 m4 using "$dao_folder/results/tables/main_`i'_h.rtf", ///
	cells(b(fmt(%9.3f)) se(par) p(fmt(3) par([ ]))) ///
	stats(r2 r2_within N, fmt(%9.3f %9.3f %9.0gc) ///
	labels("R-squared overall" "R-squared within" "Observations")) ///
	legend collabels(none) varlabels(_cons Constant) replace compress label  ///
	varwidth(30) modelwidth(10) interaction( " X ") ///
	indicate(`r(indicate_fe)') ///
	nodepvars nonumbers noomitted unstack ///
	addnotes("Clustered standard errors in parentheses; p-values in brackets.")	
	
/*	
mkcorr voted_6m mal_6m_miss mal_6m_q_miss mal_6m_w_miss ///
	diff_days_last_vote_all diff_days_last_vote_space ///
	dao_6m_w dao_6m_q dao_6m_app dao_6m_b dao_6m_r  ///
	voted_6m_w voted_6m_q voted_6m_app voted_6m_r voted_6m_b ///
	times_voted_space_cum times_voted_all_cum  ///
	voter_tenure_space votes_dao_cum organization_size ///
	if spc2_id_2 < `i' , ///
	means log("$dao_folder/results/tables/descriptives_`i'.log") ///
	replace cdec(2) mdec(3) lab	
*/

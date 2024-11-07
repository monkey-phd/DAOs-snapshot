use "$dao_folder/processed/data_helge_panel.dta", clear

///Regressions


/*
drop if space_id > 14
*/

bysort space_id: egen space_occ = total(dummy)
bysort space_id: gen first_space = _n ==1
bysort first_space (space_occ): gen spc2_id = sum(dummy) if first_space == 1
bysort space_id: egen spc2_id_2 = min(spc2_id)

xtset voter_space_id proposal_space_counter

////Baseline
///Mis_All_6M
forvalues i = 40(20)180 { 
	display `i'
	
	reghdfe f.voted c.voted_6m   ///
		diff_days_last_vote_all diff_days_last_vote_space ///
		dao_6m_w dao_6m_q dao_6m_app dao_6m_b dao_6m_r  ///
		voted_6m_w voted_6m_q voted_6m_app voted_6m_r  voted_6m_b ///
		times_voted_space_cum times_voted_all_cum  ///
		voter_tenure_space votes_dao_cum organization_size if spc2_id_2 < `i', ///
		absorb(voter_id year_month_num proposal_id) vce(cluster voter_id)	
	estimates store m1, title("Model 1")
	
	reghdfe f.voted c.voted_6m c.mal_6m_miss  c.voted_6m#c.mal_6m_miss  ///
		diff_days_last_vote_all diff_days_last_vote_space ///
		dao_6m_w dao_6m_q dao_6m_app dao_6m_b dao_6m_r  ///
		voted_6m_w voted_6m_q voted_6m_app voted_6m_r  voted_6m_b ///
		times_voted_space_cum times_voted_all_cum  ///
		voter_tenure_space votes_dao_cum organization_size if spc2_id_2 < `i', ///
		absorb(voter_id year_month_num proposal_id) vce(cluster voter_id)	
	estimates store m2, title("Model 2")
	
	/*
	margins, at(voted_6m = (0 0.25 0.5 0.75 1.0) mal_6m_miss=(0.1 0.9) ) asbalanced
	marginsplot, noci allsimplelabels legend(pos(6) rows(1) ///
	subtitle("Misalignment")) title("")
	graph export "$dao_folder/results/figures/marginsplot_main_`i'_v3.png", width(1200) replace 	
	*/
	
	reghdfe f.voted c.voted_6m  mal_6m_q_miss mal_6m_miss c.voted_6m#c.mal_6m_miss  ///
		c.voted_6m#c.mal_6m_q_miss  ///
		diff_days_last_vote_all diff_days_last_vote_space ///
		dao_6m_w dao_6m_q dao_6m_app dao_6m_b dao_6m_r  ///
		voted_6m_w voted_6m_q voted_6m_app voted_6m_r  voted_6m_b ///
		times_voted_space_cum times_voted_all_cum  ///
		voter_tenure_space votes_dao_cum organization_size if spc2_id_2 < `i', ///
		absorb(voter_id year_month_num proposal_id) vce(cluster voter_id)	
	estimates store m4, title("Model 4")	
	
	/*
	margins,  at( (asobserved) _all  voted_6m=(0 0.25 0.5 0.75 1.0) mal_6m_miss=(0.1 0.9) mal_6m_q_v2=(0 1)) 
	marginsplot, by(mal_6m_q_v2) noci allsimplelabels legend(pos(6) rows(1) ///
		subtitle("Misalignment (Quadratic)")) title("")
	graph export "$dao_folder/results/figures/marginsplot_int1_`i'_v2.png", width(1200) replace
	*/
	
	reghdfe f.voted c.voted_6m  mal_6m_w_miss mal_6m_miss c.voted_6m#c.mal_6m_miss  ///
		c.voted_6m#c.mal_6m_w_miss  ///
		diff_days_last_vote_all diff_days_last_vote_space ///
		dao_6m_w dao_6m_q dao_6m_app dao_6m_b dao_6m_r  ///
		voted_6m_w voted_6m_q voted_6m_app voted_6m_r  voted_6m_b ///
		times_voted_space_cum times_voted_all_cum  ///
		voter_tenure_space votes_dao_cum organization_size if spc2_id_2 < `i', ///
		absorb(voter_id year_month_num proposal_id) vce(cluster voter_id)	
	estimates store m3, title("Model 3")
	
	/*
	margins, at( (asobserved) _all  voted_6m=(0 0.25 0.5 0.75 1.0) mal_6m_miss=(0.1 0.9) mal_6m_w_v2=(0 1)) 
	marginsplot, by(mal_6m_w_v2) noci allsimplelabels legend(pos(6) rows(1) ///
		subtitle("Misalignment (Weighted)")) title("")
	graph export "$dao_folder/results/figures/marginsplot_int2_`i'_v2.png", width(1200) replace
	*/
	

	estfe m*, labels(voter_id "Voter fixed effects" year_month_num 	///
		"Month fixed effects" proposal_id "Proposal fixed effects") 
	
	esttab m1 m2 m3 m4 using "$dao_folder/results/tables/main_`i'_v3a.rtf", ///
		cells(b(fmt(%9.3f)) se(par) p(fmt(3) par([ ]))) ///
		stats(r2 r2_within N, fmt(%9.3f %9.3f %9.0gc) ///
		labels("R-squared overall" "R-squared within" "Observations")) ///
		legend collabels(none) varlabels(_cons Constant) replace compress label  ///
		varwidth(30) modelwidth(10) interaction( " X ") ///
		indicate(`r(indicate_fe)') ///
		order(voted_6m mal_6m_miss c.voted_6m#c.mal_6m_miss ///
		mal_6m_w_miss c.voted_6m#c.mal_6m_w_miss ///
		mal_6m_q_miss c.voted_6m#c.mal_6m_q_miss) ///
		nodepvars nonumbers noomitted unstack ///
		addnotes("Clustered standard errors in parentheses; p-values in brackets.")	
}	
/*	
reghdfe f.voted   ///
	diff_days_last_vote_all diff_days_last_vote_space ///
	voted_6m_w voted_6m_q voted_6m_app voted_6m_r voted_6m_sc voted_6m_b ///
	times_voted_space_cum times_voted_all_cum  ///
	voter_tenure_space votes_dao_cum organization_size, ///
	absorb(voter_id year_month_num proposal_id) vce(cluster voter_id)	
	
	
xtreg f.voted i.year_month_num mal_6m_miss mal_6m_w_miss  ///
	diff_days_last_vote_all diff_days_last_vote_space ///
	voted_6m_w voted_6m_q voted_6m_app voted_6m_r voted_6m_sc voted_6m_b ///
	times_voted_space_cum times_voted_all_cum   ///
	voter_tenure_space votes_dao_cum organization_size, ///
	fe vce(cluster voter_id)	

reghdfe f.voted  mal_6m_miss mal_6m_w_miss  ///
	diff_days_last_vote_all diff_days_last_vote_space ///
	voted_6m_w voted_6m_q voted_6m_app voted_6m_r voted_6m_sc voted_6m_b ///
	times_voted_space_cum times_voted_all_cum  ///
	voter_tenure_space votes_dao_cum organization_size, ///
	absorb(voter_id year_month_num proposal_id) vce(cluster voter_id)	
	
reghdfe f.voted  mal_6m_miss mal_6m_q_miss  ///
	diff_days_last_vote_all diff_days_last_vote_space ///
	voted_6m_w voted_6m_q voted_6m_app voted_6m_r voted_6m_sc voted_6m_b ///
	times_voted_space_cum times_voted_all_cum  ///
	voter_tenure_space votes_dao_cum organization_size, ///
	absorb(voter_id year_month_num proposal_id) vce(cluster voter_id)	
	
reghdfe f.voted voted_6m mal_6m_miss   ///
	diff_days_last_vote_all diff_days_last_vote_space ///
	voted_6m_w voted_6m_q voted_6m_app voted_6m_r voted_6m_sc ///
	times_voted_space_cum times_voted_all_cum f.i.type_numeric  ///
	voter_tenure_space votes_dao_cum organization_size, ///
	absorb(voter_id year_month_num) vce(cluster voter_id)	

	proposal_id
//f.i.type_numeric	
	
///Moderator	
reghdfe f.voted  mal_6m_miss  mal_6m_w_miss   ///
	diff_days_last_vote_all diff_days_last_vote_space ///
	voted_6m_w voted_6m_q voted_6m_app voted_6m_r voted_6m_sc voted_6m_b ///
	times_voted_space_cum times_voted_all_cum f.i.type_numeric  ///
	voter_tenure_space votes_dao_cum organization_size, ///
	absorb(voter_id year_month_num ) vce(cluster voter_id)	
//proposal_id
	 
xtreg f.voted  mal_6m_miss  mal_6m_w_miss mal_6m_q_miss  ///
	diff_days_last_vote_all diff_days_last_vote_space ///
	voted_6m_w voted_6m_q voted_6m_app voted_6m_r voted_6m_sc voted_6m_b ///
	dao_6m_w dao_6m_q dao_6m_app dao_6m_b dao_6m_r dao_6m_sc ///
	times_voted_space_cum times_voted_all_cum f.i.type_numeric  ///
	space_age voter_tenure_space votes_dao_cum organization_size, fe vce(cluster voter_id)
		
		
xtreg f.voted mal_6m_miss  mal_6m_w_miss mal_6m_q_miss  ///
	diff_days_last_vote_all diff_days_last_vote_space ///
	voted_6m_w voted_6m_q voted_6m_app voted_6m_r voted_6m_sc ///
	dao_6m_w dao_6m_q dao_6m_app dao_6m_b dao_6m_r dao_6m_sc ///
	times_voted_space_cum times_voted_all_cum f.i.type_numeric  ///
	voter_tenure_space votes_dao_cum organization_size if voted == 1, fe vce(cluster voter_id)	
	

	
xtreg f.voted voted_6m mal_6m_miss  mal_6m_w_miss mal_6m_q_miss  ///
	diff_days_last_vote_all diff_days_last_vote_space ///
	voted_6m_w voted_6m_q voted_6m_app voted_6m_r voted_6m_sc ///
	times_voted_space_cum times_voted_all_cum f.i.type_numeric  ///
	voter_tenure_space votes_dao_cum, fe vce(cluster voter_id)

 		

xtreg f.voted voted_6m mal_6m_miss  mal_6m_w_miss mal_6m_q_miss  ///
	diff_days_last_vote_all diff_days_last_vote_space ///
	voted_6m_w voted_6m_q voted_6m_app voted_6m_r voted_6m_sc ///
	times_voted_space_cum times_voted_all_cum f.i.type_numeric  ///
	voter_tenure_space votes_dao_cum, fe vce(cluster voter_id)
	
xtreg f.voted voted_6m mal_6m_miss  mal_6m_w_miss mal_6m_q_miss  ///
	diff_days_last_vote_all diff_days_last_vote_space ///
	voted_6m_w voted_6m_q voted_6m_app voted_6m_r voted_6m_sc ///
	times_voted_space_cum times_voted_all_cum f.i.type_numeric  ///
	voter_tenure_space votes_dao_cum if voting_power <= X, fe vce(cluster voter_id)	

xtreg f.voted voted_6m mal_6m_miss  mal_6m_w_miss mal_6m_q_miss  ///
	diff_days_last_vote_all diff_days_last_vote_space ///
	voted_6m_w voted_6m_q voted_6m_app voted_6m_r voted_6m_sc ///
	times_voted_space_cum times_voted_all_cum f.i.type_numeric  ///
	voter_tenure_space votes_dao_cum if voting_power > X, fe vce(cluster voter_id)		
	
	
xtreg f.voted voted_6m mal_6m_miss  mal_6m_q_miss  ///
	diff_days_last_vote_all diff_days_last_vote_space voting_power ///
	voted_6m_w voted_6m_q voted_6m_app voted_6m_r voted_6m_sc ///
	times_voted_space_cum times_voted_all_cum f.i.type_numeric  ///
	voter_tenure_space votes_dao_cum, fe vce(cluster voter_id)
	
xtreg f.voted voted_6m mal_6m_miss  mal_w_6m_miss mal_6m_q_miss  ///
	diff_days_last_vote_all diff_days_last_vote_space voting_power ///
	voted_6m_w voted_6m_q voted_6m_app voted_6m_r voted_6m_sc ///
	times_voted_space_cum times_voted_all_cum f.i.type_numeric  ///
	voter_tenure_space votes_dao_cum, fe vce(cluster voter_id)

gen rand_value = runiform()	
	
forvalues i = 0.1(0.1)1.00 { 
	display `i'
	xtset voter_space_id proposal_space_counter
	xtlogit f.voted voted_6m mal_6m_miss  mal_6m_w_miss mal_6m_q_miss  ///
		diff_days_last_vote_all diff_days_last_vote_space voting_power ///
		voted_6m_w voted_6m_q voted_6m_app voted_6m_r voted_6m_sc ///
		times_voted_space_cum times_voted_all_cum f.i.type_numeric  ///
		voter_tenure_space votes_dao_cum if rand_value < `i', vce(bootstrap) fe iterate(30)
	
}	
	
xtlogit f.voted voted_6m mal_6m_miss  mal_w_6m_miss mal_6m_q_miss  ///
	diff_days_last_vote_all diff_days_last_vote_space voting_power ///
	voted_6m_w voted_6m_q voted_6m_app voted_6m_r voted_6m_sc ///
	times_voted_space_cum times_voted_all_cum f.i.type_numeric  ///
	voter_tenure_space votes_dao_cum, fe vce(oim) iterate(50)
*/

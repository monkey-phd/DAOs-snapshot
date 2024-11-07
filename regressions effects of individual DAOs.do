clear frames

frame create coeffs
frame change coeffs

clear 
set obs 230

gen space_id = .
gen voted_coef = .
gen mis_coef = .
gen mis_basic_coef = .
gen mis_app_coef = .
gen mis_q_coef = .
gen mis_rc_coef = .
gen mis_w_coef = .
gen dao_obs = .


frame create iter
frame change iter
use "$dao_folder/processed/panel_almost_full.dta", clear

drop diff_days_last_proposal_space lag_times_votes_space_cum diff_days_last_vote_space proposal_space_counter voting_power misaligned misaligned_c scores_total prps_choices total_votes dao_creation_date proposal_end_datetime proposal_end_date voting_period_length month year space_high_scores times_voted_space_cum max_times_voted_space voter_tenure_space space_age votes_dao_cum votes_proposal_cum proposal_active_voters proposal_total_voted active_vp relative_voting_power_pot voting_6m end_6m proposal_id proposal_space_id dummy first_space space_id_size space_no_vot_types vs_types voter_tenure_all times_voted_all_cum diff_days_last_proposal_all lag_times_voted_all_cum diff_days_last_vote_all voter_space_counter
drop prps_link prps_stub
drop mal_c_wmiss voter_active

xtset voter_space_id voter_space_prps_counter

///voting_1m voting_3m voting_6m end_1m end_3m end_6m
forvalues i = 1(1)224 { 
	display `i'
	tab space_id  if space_id == `i'
	
	drop if space_id < `i'
	
	count if space_id == `i' & end_1m == 0
	local dao_obs = r(N)
	
	frame coeffs: qui replace space_id = `i' if [_n] == `i'
	frame coeffs: qui replace dao_obs = `dao_obs' if [_n] == `i'
		
	if  `dao_obs' < 100 {
		display "Empty DAO"
		continue
	}
	
	if `i' == 103 | `i' == 106 | `i' == 196 | `i' == 208 {
		display "Weird DAO"
		continue
	}
			
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
		relative_voting_power_act if end_1m == 0 & space_id == `i', ///
		absorb(voter_id year_month_num) vce(cluster voter_space_id)	
	
	matrix b = e(b)
	local voted_coef = b[1, "c.voted"]
	local mis_coef = b[1, "c.misaligned_wmiss"]
	local mis_basic_coef = b[1, "c.misaligned_wmiss#c.type_basic"]
	local mis_app_coef = b[1, "c.misaligned_wmiss#c.type_approval"]
	local mis_q_coef = b[1, "c.misaligned_wmiss#c.type_quadratic"]
	local mis_rc_coef = b[1, "c.misaligned_wmiss#c.type_ranked_choice"]
	local mis_w_coef = b[1, "c.misaligned_wmiss#c.type_weighted"]
	
	frame coeffs: qui replace voted_coef = `voted_coef' if [_n] == `i' & `voted_coef' != 0
	frame coeffs: qui replace mis_coef = `mis_coef' if [_n] == `i' & `mis_coef' != 0
	frame coeffs: qui replace mis_basic_coef = `mis_basic_coef' if [_n] == `i' & `mis_basic_coef' != 0
	frame coeffs: qui replace mis_app_coef = `mis_app_coef' if [_n] == `i' & `mis_app_coef' != 0
	frame coeffs: qui replace mis_q_coef = `mis_q_coef' if [_n] == `i' & `mis_q_coef' != 0
	frame coeffs: qui replace mis_rc_coef = `mis_rc_coef' if [_n] == `i' & `mis_rc_coef' != 0
	frame coeffs: qui replace mis_w_coef = `mis_w_coef' if [_n] == `i' & `mis_w_coef' != 0
	
		
}

frame change coeffs

save "$dao_folder/processed/coefficients_daos_1m.dta", replace

twoway histogram voted_coef || kdensity voted_coef, legend(pos(6)) 
graph export "$dao_folder/results/figures/dao_voted_1m.png", replace width(1200) height(900)
twoway histogram mis_coef  || kdensity mis_coef, legend(pos(6)) 
graph export "$dao_folder/results/figures/dao_mis_coef_1m.png", replace width(1200) height(900)
twoway histogram mis_basic_coef  || kdensity mis_basic_coef, legend(pos(6)) 
graph export "$dao_folder/results/figures/dao_mis_basic_coef_1m.png", replace width(1200) height(900)
twoway histogram mis_app_coef  || kdensity mis_app_coef, legend(pos(6)) 
graph export "$dao_folder/results/figures/dao_mis_app_coef_1m.png", replace width(1200) height(900)
twoway histogram mis_q_coef  || kdensity mis_q_coef, legend(pos(6)) 
graph export "$dao_folder/results/figures/dao_mis_q_coef_1m.png", replace width(1200) height(900)
twoway histogram mis_rc_coef  || kdensity mis_rc_coef, legend(pos(6)) 
graph export "$dao_folder/results/figures/dao_mis_rc_coef_1m.png", replace width(1200) height(900)
twoway histogram mis_w_coef  || kdensity mis_w_coef, legend(pos(6)) 
graph export "$dao_folder/results/figures/dao_mis_w_coef_1m.png", replace width(1200) height(900)


twoway histogram voted_coef [fw=dao_obs] || kdensity voted_coef [fw=dao_obs], legend(pos(6)) 
graph export "$dao_folder/results/figures/dao_voted_weighted_1m.png", replace width(1200) height(900)
twoway histogram mis_coef  [fw=dao_obs] || kdensity mis_coef [fw=dao_obs], legend(pos(6)) 
graph export "$dao_folder/results/figures/dao_mis_coef_weighted_1m.png", replace width(1200) height(900)
twoway histogram mis_basic_coef  [fw=dao_obs] || kdensity mis_basic_coef [fw=dao_obs], legend(pos(6)) 
graph export "$dao_folder/results/figures/dao_mis_basic_coef_weighted_1m.png", replace width(1200) height(900)
twoway histogram mis_app_coef [fw=dao_obs]  || kdensity mis_app_coef [fw=dao_obs], legend(pos(6)) 
graph export "$dao_folder/results/figures/dao_mis_app_coef_weighted_1m.png", replace width(1200) height(900)
twoway histogram mis_q_coef [fw=dao_obs] || kdensity mis_q_coef [fw=dao_obs], legend(pos(6)) 
graph export "$dao_folder/results/figures/dao_mis_q_coef_weighted_1m.png", replace width(1200) height(900)
twoway histogram mis_rc_coef [fw=dao_obs] || kdensity mis_rc_coef [fw=dao_obs], legend(pos(6)) 
graph export "$dao_folder/results/figures/dao_mis_rc_coef_weighted_1m.png", replace width(1200) height(900)
twoway histogram mis_w_coef  [fw=dao_obs]|| kdensity mis_w_coef [fw=dao_obs], legend(pos(6)) 
graph export "$dao_folder/results/figures/dao_mis_w_coef_weighted_1m.png", replace width(1200) height(900)
	
/*

		c.misaligned_wmiss#c.type_basic ///
		c.misaligned_wmiss#c.type_approval ///
		c.misaligned_wmiss#c.type_quadratic  ///
		c.misaligned_wmiss#c.type_ranked_choice  ///
		c.misaligned_wmiss#c.type_weighted ///
*/
set seed 8472

//global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data"
global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data"

//ssc install rangestat
//ssc install gtools

//use "$dao_folder/processed/magnus_export.dta", clear
use "$dao_folder/processed/helge_export.dta", clear

drop if space == "aave.eth" 
drop if space == "opcollective.eth" 

tab space if winning_choice == .
drop if winning_choice == .

//////Convert date string to numeric strings
gen vote_datetime = clock(vote_created, "YMDhms")
gen vote_date = date(vote_created, "YMDhms")
format vote_datetime %tc
format vote_date %td
drop vote_created

gen dao_creation_date = date(space_created_at, "YMDhms")
///gen str8 dao_creation_date_short = substr(space_created_at, 1, 10)
///gen dao_creation_date_num = date(dao_creation_date, "YMDhms")
format dao_creation_date %td

//prps_start
//prps_end

//rename proposal_start_date proposal_start_date_str
gen proposal_start_datetime = clock(prps_start, "YMDhms")
format proposal_start_datetime %tc

//rename proposal_end_date proposal_end_date_str
gen proposal_end_datetime = clock(prps_end, "YMDhms")
gen proposal_end_date = date(prps_end, "YMDhms")
format proposal_end_datetime %tc
format proposal_end_date %td

gen voting_period_length = proposal_end_datetime - proposal_start_datetime

drop prps_start prps_end
drop space_created_at

//gen year = real(substr(year_month,1,4))
//gen month = real(substr(year_month,6,2))

gen month=month(vote_date)
gen year=year(vote_date)
gen year_month_num  = ym(year,month)
gen dummy = 1

//drop year_month

/////////Create numeric IDs
gegen voter_id = group(voter)
sort voter voter_id
order voter voter_id

egen space_id = group(space), label

///Space ID according to size
bysort space_id: egen space_occ = total(dummy)
bysort space_id: gen first_space = _n ==1
bysort first_space (space_occ): gen spc2_id = sum(dummy) if first_space == 1
bysort space_id: egen space_id_size = min(spc2_id)

tab space_id_size

keep if space_id_size <= 210
bysort voter_id: egen voter_total_votes = total(dummy)
sum voter_total_votes, detail
tab voter_total_votes if voter_total_votes <= 100
//drop if voter_total_votes <= 2
//keep if space_id == 168

gegen proposal_id  = group(proposal)
drop proposal

gegen proposal_space_id = group(space proposal_id)



sort space_id proposal_start_datetime proposal_space_id  voter_id
order space_id proposal_start_datetime proposal_space_id voter_id proposal_id

bysort space_id proposal_id (proposal_start_datetime): gen proposal_space_dummy = 1 if _n==1
bysort space_id (proposal_start_datetime proposal_id proposal_space_dummy): ///
	gen proposal_space_counter = sum(proposal_space_dummy)
drop proposal_space_dummy
	
/*
keep if space_id == 151
sort space_id proposal_space_counter proposal_id
order space_id proposal_space_counter proposal_id
*/	
	
///Check whether are where are duplicate
duplicates report voter proposal_id

duplicates drop voter proposal_id, force

gegen voter_space_id = group(voter_id space_id)
 
drop choice
//drop scores

/////Convert other strings to numeric
encode type, gen(type_numeric)

tab type, gen(type_)

rename type_1 type_approval
rename type_2 type_basic
rename type_3 type_quadratic
rename type_4 type_ranked_choice
rename type_5 type_single_choice
rename type_6 type_weighted

rename vp voting_power
rename votes total_votes
     
/////Drop unnecessary variables
//drop follower
drop type
drop dummy
drop voter space 
drop vp_by_strategy
drop prps_author
drop strategy_name

//drop participated_before total_decisions_participated time_since_last_vote
//drop Future_Voting_Participation_Prop Future_Voting_Participation_DAO 
//drop future_participation_count cumulative_misaligned
//drop vote_count

/*
drop  total_participation_rate
drop misalignment_rate

drop blockchain_network 

drop ravg_all_mal_1m ravg_all_mal_1m_x_share_a ravg_all_mal_1m_x_share_b ///
	ravg_all_mal_1m_x_share_q ravg_all_mal_1m_x_share_rc ///
	ravg_all_mal_1m_x_share_sc ravg_all_mal_1m_x_share_w ///
	ravg_all_mal_1m_x_type_a ravg_all_mal_1m_x_type_b ///
	ravg_all_mal_1m_x_type_q ravg_all_mal_1m_x_type_rc ///
	ravg_all_mal_1m_x_type_sc ravg_all_mal_1m_x_type_w ravg_all_mal_1q ///
	ravg_all_mal_1q_x_share_a ravg_all_mal_1q_x_share_b ///
	ravg_all_mal_1q_x_share_q ravg_all_mal_1q_x_share_rc ///
	ravg_all_mal_1q_x_share_sc ravg_all_mal_1q_x_share_w ///
	ravg_all_mal_1q_x_type_a ravg_all_mal_1q_x_type_b ///
	ravg_all_mal_1q_x_type_q ravg_all_mal_1q_x_type_rc ///
	ravg_all_mal_1q_x_type_sc ravg_all_mal_1q_x_type_w
	
drop ravg_del_1m ravg_del_1q ravg_mal_a_1m ravg_mal_a_1q ///
	ravg_mal_b_1m ravg_mal_b_1q ravg_mal_q_1m ravg_mal_q_1q ///
	ravg_mal_rc_1m ravg_mal_rc_1q ravg_mal_sc_1m ravg_mal_sc_1q ///
	ravg_mal_w_1m ravg_mal_w_1q	
	
drop shr_a_1m shr_a_1q shr_b_1m shr_b_1q shr_del_1m shr_del_1q ///
	shr_q_1m shr_q_1q shr_rc_1m shr_rc_1q shr_sc_1m shr_sc_1q shr_w_1m shr_w_1q	
	
drop ravg_mal_sc_6m shr_sc_6m ravg_del_6m shr_del_6m ravg_mal_b_6m ///
	shr_b_6m  shr_w_6m ravg_mal_a_6m shr_a_6m ravg_mal_rc_6m ///
	shr_rc_6m ravg_mal_q_6m shr_q_6m
	
drop ravg_all_mal_6m_x_type_b ravg_all_mal_6m_x_share_b ///
	ravg_all_mal_6m_x_type_sc ravg_all_mal_6m_x_share_sc ///
	ravg_all_mal_6m_x_type_w ravg_all_mal_6m_x_share_w ///
	ravg_all_mal_6m_x_type_q ravg_all_mal_6m_x_share_q ///
	ravg_all_mal_6m_x_type_a ravg_all_mal_6m_x_share_a ///
	ravg_all_mal_6m_x_type_rc ravg_all_mal_6m_x_share_rc 	
	
drop share_singlechoice_overall share_basic_overall share_approval_overall ///
	share_weighted_overall share_quadratic_overall share_rankedchoice_overall ///
	Share_singlechoice_individual Share_basic_individual ///
	Share_approval_individual Share_weighted_individual ///
	Share_quadratic_individual Share_rankedchoice_individual
	
drop Topic_0_t1 Topic_1_t1 Topic_2_t1 Topic_3_t1 Topic_4_t1 Topic_5_t1 ///
	Topic_6_t1 Topic_7_t1 Topic_8_t1 Topic_9_t1 Topic_10_t1 Topic_11_t1 ///
	Topic_12_t1 Topic_13_t1 Topic_14_t1 Topic_15_t1 Topic_16_t1 Topic_17_t1 ///
	Topic_18_t1 Topic_19_t1 Topic_20_t1 Topic_21_t1 Topic_22_t1 Topic_23_t1 ///
	Topic_24_t1 Topic_25_t1 Topic_26_t1 Topic_27_t1 Topic_28_t1 Topic_29_t1	
*/
compress	
	
save "$dao_folder/processed/data_helge_small.dta", replace

use "$dao_folder/processed/data_helge_small.dta", clear

bysort space_id: gegen space_weighted_votes_total = total(type_weighted)
bysort space_id: gegen space_quad_votes_total = total(type_quadratic)

gen space_weighted_and_quad_votes = space_weighted_votes_total + space_quad_votes_total

sum space_weighted_and_quad_votes, detail

//For testing

//Drop aave.eth
//keep if space_weighted_and_quad_votes > 8000 & space_weighted_and_quad_votes != 17658
drop not_determined

duplicates report voter_space_id proposal_space_counter
duplicates tag voter_space_id proposal_space_counter , gen(tsfill_tag)

sum tsfill_tag
drop tsfill_tag

sort space_id proposal_space_counter voter_space_id voter_id proposal_start_datetime
order space_id proposal_space_counter voter_space_id voter_id proposal_start_datetime proposal_space_id

gen voted = 1
gen mal_bin = 0
replace mal_bin = 1 if misaligned >= 0.5 & misaligned <= 1
rename misaligned mal_w
rename mal_bin misaligned

gen aligned =  1 - misaligned
gen aligned_w = 1 - mal_w

bysort space_id (proposal_space_counter): gegen last_proposal_space = ///
	max(proposal_space_counter)
bysort voter_space_id (proposal_space_counter): ///
	gen last_voter_space = 1 if _n == _N

sort voter_space_id proposal_space_counter
order voter_space_id proposal_space_counter last_proposal_space last_voter_space

expand 2 if last_voter_space == 1, generate(newv)

///deleting voting information
foreach v of varlist misaligned mal_w  ///
	vote_datetime vote_date voted { 
    replace `v' = . if newv == 1 
}

sort voter_space_id proposal_space_counter
order voter_space_id proposal_space_counter last_proposal_space last_voter_space newv

drop last_voter_space
bysort voter_space_id (proposal_space_counter newv): gen last_voter_space = 1 if _n == _N
order voter_space_id proposal_space_counter last_proposal_space ///
	last_voter_space newv 
replace proposal_space_counter = last_proposal_space if last_voter_space == 1

duplicates tag voter_space_id proposal_space_counter, gen(already_voting_last_proposal)

tab already_voting_last_proposal

order voter_space_id proposal_space_counter last_proposal_space ///
	last_voter_space newv already_voting_last_proposal

drop if already_voting_last_proposal == 1 & newv == 1


duplicates tag voter_space_id proposal_start_datetime, gen(same_start_time)

tab same_start_time

/*
drop already_voting_last_proposal

duplicates tag voter_space_id proposal_space_counter, gen(already_voting_last_proposal)

tab already_voting_last_proposal
*/

drop newv already_voting_last_proposal


//Time-panel order
tsset voter_space_id proposal_space_counter

//Fill in missing values
tsfill

replace voted = 0 if voted == .
gen misaligned_wmiss = misaligned
replace misaligned_wmiss = 0 if misaligned_wmiss == .
gen aligned_wmiss = aligned
replace aligned_wmiss = 0 if aligned == .
gen dummy = 1

//Copying values to newly created observations
sort voter_space_id voter_id

///Constant within voter_space_id
foreach x of varlist voter_id space_id space_id_size voting_power  {
	bysort voter_space_id (`x'): replace `x' = `x'[1] if `x' == .
}

///Constant in DAO
foreach x of varlist dao_creation_date  {
	bysort space_id (`x'): replace `x' = `x'[1] if `x' == .
}

///If we need the strings
/*
foreach x of varlist title voter space_vote {
	gsort voter_space_id -`x'
	by voter_space_id: replace `x' = `x'[1] if `x' == ""
}
*/

///Find proposal id
foreach x of varlist proposal_id   {
	bysort space_id proposal_space_counter (`x'): replace `x' = `x'[1] if `x' == .
}

drop if proposal_id == .
	
///Find other values based on proposal
///Missing: voting_period_length organization_size total_votes_decision
/// Voting_rule_mixed
foreach x of varlist proposal_start_datetime proposal_space_id ///
	winning_choice scores_total ///
	total_votes type_approval type_basic ///
	type_quadratic type_ranked_choice type_single_choice type_weighted ///
	year month year_month_num type_numeric proposal_end_datetime ///
	proposal_end_date topic_0 topic_1 topic_2 topic_3 ///
	topic_4 topic_5 topic_6 topic_7 topic_8 topic_9 topic_10 topic_11 ///
	topic_12 topic_13 topic_14 topic_15 topic_16 topic_17 topic_18 topic_19 ///
	{
	display "`x'"
	bysort proposal_id (`x'): replace `x' = `x'[1] if `x' == .
}

///total_decisions_participated
/*
/// Variables that are 0 if no vote took place 
foreach x of varlist NotDetermined delegated {
	replace `x' = 0 if `x' == .
	}
*/
replace vote_datetime = proposal_end_datetime if vote_datetime == .
replace vote_date = proposal_end_date if vote_date == .

bysort voter_space_id (vote_datetime): gen times_voted_space_cum = sum(voted)
bysort voter_space_id: gegen max_times_voted_space = max(times_voted_space_cum)

gen voter_active = 0
replace voter_active = 1 if times_voted_space_cum < max_times_voted_space 
replace voter_active = 1 if voted == 1

//Drop if never voted before in DAO
drop if times_voted_space_cum == 0
//////////////////////////////////////////////////////
//Check how this can happen! Do we want these votes?
//////////////////////////////////////////////////////

///Days since last vote in space

bysort  voter_space_id  (vote_datetime): ///
	gen diff_days_last_proposal_space = vote_date - vote_date[_n-1]
sort voter_id voter_space_id vote_datetime
	
//replace diff_days_last_proposal_space = 0 if diff_days_last_proposal_space == 0
bysort  voter_space_id  (vote_datetime): ///
	gen lag_times_votes_space_cum = times_voted_space_cum[_n-1]
bysort  voter_space_id lag_times_votes_space_cum (vote_datetime): ///
	gen diff_days_last_vote_space = sum(diff_days_last_proposal_space)

sort voter_id voter_space_id vote_datetime
order voter_id voter_space_id voted vote_date vote_datetime ///
	diff_days_last_proposal_space lag_times_votes_space_cum ///
	lag_times_votes_space_cum diff_days_last_vote


///Days since last vote overall
bysort voter_id (vote_datetime): gen times_voted_all_cum = sum(voted)
bysort  voter_id  (vote_datetime): gen diff_days_last_proposal_all = vote_date - vote_date[_n-1]
bysort  voter_id  (vote_datetime): gen lag_times_voted_all_cum = times_voted_all_cum[_n-1]
//replace diff_days_last_proposal_all = 0 if diff_days_last_proposal_all == 0
bysort  voter_id lag_times_voted_all_cum (vote_datetime): ///
	gen diff_days_last_vote_all = sum(diff_days_last_proposal_all)

drop lag_times_votes_space_cum lag_times_voted_all_cum

///presence_other_organizations
//////Sort by user space time, first == 1, then order by user time and add up
bysort voter_id space_id (vote_datetime): gen voter_space_dummy = 1 if _n==1
bysort voter_id (vote_datetime space_id): 	gen voter_space_counter = sum(voter_space_dummy)

/// voter_experience_days
bysort voter_id : egen voter_first_vote = min(vote_date)
bysort voter_space_id: egen voter_space_first_vote = min(vote_date)

gen voter_tenure_all = vote_date - voter_first_vote
gen voter_tenure_space = vote_date - voter_space_first_vote

//corr voter_experience_days voter_tenure_all voter_tenure_space days_since_earliest

gen space_age = vote_date - dao_creation_date

bysort space_id (vote_datetime): gen votes_dao_cum = sum(voted)

bysort proposal_id (vote_datetime): gen votes_proposal_cum = sum(voted)
bysort space_id proposal_space_counter: gegen proposal_active_voters = total(voter_active)

bysort proposal_id: gegen proposal_total_voted = total(voted)
gen active_vp = voting_power * voter_active
bysort proposal_id: gegen proposal_total_vp = total(active_vp)
gen relative_voting_power_pot = voting_power / proposal_total_vp
gen relative_voting_power_act = voting_power / scores_total

bysort proposal_id (vote_datetime): gen proposal_first_vote = 1 if _n==1
gen proposal_share_voted = proposal_total_voted / proposal_active_voters


///Decision structure in last 6 months of DAO
//Intervael 1.5552e10 is 180 days in miliseconds
rangestat (mean) dao_6m_w = type_weighted, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)
rangestat (mean) dao_6m_q = type_quadratic, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)
rangestat (mean) dao_6m_app = type_approval, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)
rangestat (mean) dao_6m_b = type_basic, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)
rangestat (mean) dao_6m_r = type_ranked_choice, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)
rangestat (mean) dao_6m_sc = type_single_choice, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)

///Decision structure in last 6 months of DAO and participated
gen voted_weighted = voted * type_weighted 
gen voted_quad = voted * type_quadratic
gen voted_app = voted * type_approval
gen voted_basic = voted * type_basic
gen voted_ranked = voted * type_ranked_choice
gen voted_sc = voted * type_single_choice

rangestat (mean) voted_6m_w = voted_weighted, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)
rangestat (mean) voted_6m_q = voted_quad, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)
rangestat (mean) voted_6m_app = voted_app, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)
rangestat (mean) voted_6m_b = voted_basic, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)
rangestat (mean) voted_6m_r = voted_ranked, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)
rangestat (mean) voted_6m_sc = voted_sc, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)

drop voted_weighted voted_quad voted_app voted_basic voted_ranked voted_sc	
	
forvalues i = 0(1)19 {
	display "topic " `i'
	gen voted_topic_`i' = voted * topic_`i'
	rangestat (mean) voted_6m_topic_`i' = voted_topic_`i', ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)
	rangestat (mean) dao_6m_topic_`i' = topic_`i', ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)
	drop voted_topic_`i'
	drop topic_`i'
	}

//prps_len
gen voted_prps_len = prps_len if voted == 1
rangestat (mean) voted_6m_prps_len = voted_prps_len, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)	
rangestat (mean) prps_len_6m = prps_len, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)		
	
///Misalignment
rangestat (mean) voted_6m = voted, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)
rangestat (mean) mal_6m = misaligned, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)
rangestat (mean) malw_6m = mal_w, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)
gen mal_6m_miss = mal_6m
replace mal_6m_miss = 0 if mal_6m_miss == .
	
/*
rangestat (mean) mal_6m_miss = misaligned_wmiss, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)

rangestat (mean) aligned_6m_miss = aligned_wmiss, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)
*/
//Sum instead of average
rangestat (sum) props_6m_total = dummy, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)
rangestat (sum) voted_6m_total = voted, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)	
rangestat (sum) mal_6m_total = misaligned, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)
rangestat (sum) aligned_6m_total = aligned, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)

//rangestat (mean) misaligned_12m = Misaligned, interval(vote_date -360 0) by(voter_space_id)

sort voter_id voter_space_id vote_date year_month_num misaligned mal_6m
order voter_id voter_space_id vote_date year_month_num misaligned mal_6m

//Test whether variable by Magnus and mine "align" (sorry for the pun)
//corr Mis_All_6M misaligned_6m if voted == 1

///Moderators
gen mis_w = 1 if misaligned == 1 & type_weighted == 1
replace mis_w = 0 if misaligned == 0 & type_weighted == 1
gen mis_q = 1 if misaligned == 1 & type_quadratic == 1
replace mis_q = 0 if misaligned == 0 & type_quadratic == 1
gen mis_app = 1 if misaligned == 1 & type_approval == 1
replace mis_app = 0 if misaligned == 0 & type_approval == 1
gen mis_b = 1 if misaligned == 1 & type_basic == 1
replace mis_b = 0 if misaligned == 0 & type_basic == 1
gen mis_r = 1 if misaligned == 1 & type_ranked_choice == 1
replace mis_r = 0 if misaligned == 0 & type_ranked_choice == 1
gen mis_sc = 1 if misaligned == 1 & type_single_choice == 1
replace mis_sc = 0 if misaligned == 0 & type_single_choice == 1


////Main, how much misalignment in voting rule
rangestat (mean) mal_6m_w = mis_w, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)
gen mal_6m_w_miss = mal_6m_w
replace mal_6m_w_miss = 0 if mal_6m_w_miss == .
		
rangestat (mean) mal_6m_q = mis_q, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)
gen mal_6m_q_miss = mal_6m_q
replace mal_6m_q_miss = 0 if mal_6m_q_miss == .


///Alternatives, to add up to 100%
rangestat (sum) mal_6m_w_total = mis_w, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)	
rangestat (sum) mal_6m_q_total = mis_q, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)	
rangestat (sum) mal_6m_app_total = mis_app, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)	
rangestat (sum) mal_6m_b_total = mis_b, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)	
rangestat (sum) mal_6m_r_total = mis_r, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)	
rangestat (sum) mal_6m_sc_total = mis_sc, ///
	interval(vote_datetime -1.5552e10 0) by(voter_space_id)	
	
gen mal_6m_w_v2 = mal_6m_w_total / mal_6m_total
gen mal_6m_q_v2 = mal_6m_q_total / mal_6m_total
gen mal_6m_app_v2 = mal_6m_app_total / mal_6m_total
gen mal_6m_b_v2 = mal_6m_b_total / mal_6m_total
gen mal_6m_r_v2 = mal_6m_r_total / mal_6m_total
gen mal_6m_sc_v2 = mal_6m_sc_total / mal_6m_total

replace mal_6m_w_v2 = 0 if mal_6m_w_v2 == .
replace mal_6m_q_v2 = 0 if mal_6m_q_v2 == .
replace mal_6m_app_v2 = 0 if mal_6m_app_v2 == .
replace mal_6m_b_v2 = 0 if mal_6m_b_v2 == .
replace mal_6m_r_v2 = 0 if mal_6m_r_v2 == .
replace mal_6m_sc_v2 = 0 if mal_6m_sc_v2 == .

sort voter_id voter_space_id vote_datetime    
order voter_id voter_space_id vote_date vote_datetime

drop dummy	
	
label variable voter_id "Voter ID"
label variable voter_space_id "Voter Space ID"
label variable vote_date "Vote Date"
label variable voted "Voted"
label variable misaligned "Misaligned"
label variable mal_6m "Misalignment"
//label variable ravg_all_mal_6m "Running Avg All Misalignment Last 6 Months"
label variable mis_w "Misalignment Weighted"
label variable mal_6m_w "Misalignment - Weighted VR"
//label variable ravg_mal_w_6m "Running Avg Misalignment Weighted Last 6 Months"
label variable type_numeric "Type Numeric"
label variable year_month_num "Year-Month Number"
label variable vote_datetime "Vote DateTime"
label variable diff_days_last_proposal_space "Time Since Last Proposal"
label variable diff_days_last_vote_space "Time Since Last Vote (DAO)"
label variable proposal_space_counter "Proposal Space Counter"
label variable last_proposal_space "Last Proposal Space"
label variable last_voter_space "Last Voter Space"
label variable space_id "DAO ID"
label variable proposal_start_datetime "Proposal Start DateTime"
label variable proposal_space_id "Proposal Space ID"
label variable proposal_id "Proposal ID"
label variable mal_w "Misalignment Weighted"
label variable misaligned_c "Misaligned (C)"
label variable voting_power "Voting Power"
label variable relative_voting_power_act "Relative Voting Power (Actual)"
label variable relative_voting_power_pot "Relative Voting Power (Potential)"
label variable voting_period_length "Voting Period Length"
//label variable organization_size "Organization Size"
label variable total_votes "Total Votes Proposal"
//label variable past_votes_within_dao_proposal "Past Votes within DAO Proposal"
//label variable presence_other_organizations "Presence Other Organizations"
label variable winning_choice "Winning Choice"
//label variable voting_rule_delegation "Voting Rule Delegation"
//label variable vote_count "Vote Count"
//label variable ravg_all_mal "Running Avg All Misalignment"
label variable type_approval "Type Approval"
label variable type_basic "Type Basic"
label variable type_quadratic "Type Quadratic"
label variable type_ranked_choice "Type Ranked Choice"
label variable type_single_choice "Type Single Choice"
label variable type_weighted "Type Weighted"
//label variable full_overlapping "Full Overlapping"
//label variable partial_overlapping "Partial Overlapping"
//label variable non_overlapping "Non Overlapping"
label variable proposal_end_datetime "Proposal End DateTime"
label variable proposal_end_date "Proposal End Date"
label variable month "Month"
label variable year "Year"
label variable space_weighted_votes_total "Space Weighted Votes Total"
label variable space_quad_votes_total "Space Quadratic Votes Total"
label variable space_weighted_and_quad_votes "Space Weighted and Quadratic Votes"
label variable aligned "Aligned"
label variable aligned_w "Aligned Weighted"
label variable same_start_time "Same Start Time"
label variable misaligned_wmiss "Misaligned Weighted Missing"
label variable aligned_wmiss "Aligned Weighted Missing"
label variable times_voted_space_cum "Total Proposals Voted Overall"
label variable times_voted_all_cum "Total Proposals Voted DAO"
label variable diff_days_last_proposal_all "Diff Days Last Proposal All"
label variable diff_days_last_vote_all "Time since last vote"
label variable voter_space_dummy "Voter Space Dummy"
label variable voter_space_counter "Voter Space Counter"
label variable voter_first_vote "Voter First Vote"
label variable voter_space_first_vote "Voter Space First Vote"
label variable voter_tenure_all "Member Tenure Overall"
label variable voter_tenure_space "Member Tenure DAO"
label variable space_age "Age of DAO"
label variable votes_dao_cum "Votes DAO Cumulative"
label variable votes_proposal_cum "Votes Proposal Cumulative"
label variable dao_6m_w "Share of Weighted Votes in DAO"
label variable dao_6m_q "Share of Quadratic Votes in DAO"
label variable dao_6m_app "Share of Approval Votes in DAO"
label variable dao_6m_b "Share of Basic Votes in DAO"
label variable dao_6m_r "Share of Ranked Votes in DAO"
label variable dao_6m_sc "Share of Single Choice Votes in DAO"
//label variable voted_weighted "Voted Weighted"
//label variable voted_quad "Voted Quadratic"
//label variable voted_app "Voted Approval"
//label variable voted_basic "Voted Basic"
//label variable voted_ranked "Voted Ranked"
//label variable voted_sc "Voted Single Choice"
label variable voted_6m_w "Voting Activity (Weighted)"
label variable voted_6m_q "Voting Activity (Quadratic)"
label variable voted_6m_app "Voting Activity (Approval)"
label variable voted_6m_b "Voting Activity (Basic)"
label variable voted_6m_r "Voting Activity (Ranked)"
label variable voted_6m_sc "Voting Activity (Single Choice)"
label variable voted_6m "Voting Activity, Share"
label variable malw_6m "Misalignment Weighted Last 6 Months"
//label variable mal_6m_miss "Misalignment"
//label variable aligned_6m_miss "Aligned Last 6 Months"
label variable mal_6m_total "Misalignment Total Last 6 Months"
label variable aligned_6m_total "Aligned Total Last 6 Months"
label variable mal_6m_w_miss "Misalignment (Weighted)"
label variable mis_q "Misalignment Quadratic"
label variable mal_6m_q "Misalignment - Quadratic VR"
label variable mal_6m_q_miss "Misalignment (Quadratic)"
label variable mal_6m_w_total "Misaligned Votes, Weighted"
label variable mal_6m_q_total "Misaligned Votes, Quadratic"
label variable mal_6m_app_total "Misaligned Votes, Approval"
label variable mal_6m_b_total "Misaligned Votes, Basic"
label variable mal_6m_r_total "Misaligned Votes, Ranked"
label variable mal_6m_sc_total "Misaligned Votes, Single Choice"
label variable voted_6m_total "Voting Activity"
label variable mal_6m_miss "Misalignment"
label variable mal_6m_w_v2 "Misalignment (Weighted)"
label variable mal_6m_q_v2 "Misalignment (Quadratic)"

forvalues i = 0(1)19 {
	label variable voted_6m_topic_`i' "VA Topic `i'"
	}


compress
	
//voter space_vote	
//corr Mis_W_6M mis6m_weighted

save "$dao_folder/processed/data_helge_panel_v2.dta", replace


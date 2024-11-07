set seed 8472

///global dao_folder "C:\Users\hklapper\Dropbox\Empirical Paper on DAOs (MvHxHK)\Data\"
//global dao_folder "C:\Users\helge\Dropbox\Empirical Paper on DAOs (MvHxHK)\Data\"

//ssc install rangestat
//ssc install gtools

import delimited "$dao_folder/input/dao/data_apecoin.eth.csv", ///
	bindquote(strict) case(preserve) maxquotedrows(unlimited) clear

tab space if winning_choice == .
drop if winning_choice == .
drop voter_name

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

sort proposal proposal_start_datetime
gegen proposal_id  = group(proposal)

gegen proposal_space_id = group(space proposal_id)

sort space_id proposal_start_datetime proposal_space_id  voter_id
order space_id proposal_start_datetime proposal_space_id voter_id proposal_id

bysort space_id proposal_id (proposal_start_datetime): gen proposal_space_dummy = 1 if _n==1
bysort space_id (proposal_start_datetime proposal_id proposal_space_dummy): ///
	gen proposal_space_counter_d = sum(proposal_space_dummy) if proposal_space_dummy == 1
bysort proposal_id: egen proposal_space_counter = min(proposal_space_counter_d)
drop proposal_space_dummy proposal_space_counter_d
	
///Check whether are where are duplicate
duplicates report voter proposal_id
duplicates report voter space_id proposal_space_counter

duplicates drop voter proposal_id, force

gegen voter_space_id = group(voter_id space_id)
 
drop choice
//drop scores

/////Convert other strings to numeric
gen type_numeric = 0

gen type_approval = 0
replace type_approval = 1 if type == "approval"
replace type_numeric = 1 if type == "approval"
gen type_basic = 0
replace type_basic = 1 if type == "basic"
replace type_numeric = 2 if type == "basic"
gen type_quadratic = 0
replace type_quadratic = 1 if type == "quadratic"
replace type_numeric = 3 if type == "quadratic"
gen type_ranked_choice = 0
replace type_ranked_choice = 1 if type == "ranked-choice"
replace type_numeric = 4 if type == "ranked-choice"
gen type_single_choice = 0
replace type_single_choice = 1 if type == "single-choice"
replace type_numeric = 5 if type == "single-choice"
gen type_weighted = 0
replace type_weighted = 1 if type == "weighted"
replace type_numeric = 6 if type == "weighted"

rename votes total_votes
	 
/////Drop unnecessary variables
//drop follower
drop type
drop dummy
drop vp_by_strategy
drop prps_author
drop strategy_name

//keep if space_weighted_and_quad_votes > 8000 & space_weighted_and_quad_votes != 17658
drop not_determined

duplicates report voter_space_id proposal_space_counter
duplicates tag voter_space_id proposal_space_counter , gen(tsfill_tag)

tab tsfill_tag
drop tsfill_tag

sort space_id proposal_space_counter voter_space_id voter_id proposal_start_datetime
order space_id proposal_space_counter voter_space_id voter_id proposal_start_datetime proposal_space_id

gen voted = 1

gen aligned =  1 - misaligned
gen aligned_w = 1 - misaligned_c

bysort space_id (proposal_space_counter): gegen last_proposal_space = ///
	max(proposal_space_counter)
bysort voter_space_id (proposal_space_counter): ///
	gen last_voter_space = 1 if _n == _N

sort voter_space_id proposal_space_counter
order voter_space_id proposal_space_counter last_proposal_space last_voter_space

expand 2 if last_voter_space == 1, generate(newv)

///deleting voting information
foreach v of varlist misaligned misaligned_c  ///
	vote_datetime vote_date voted proposal_start_date ///
	proposal_id proposal_space_id voting_power winning_choice ///
	prps_created quorum scores_total total_votes prps_len prps_link ///
	prps_stub topic_0 topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 ///
	topic_7 topic_8 topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 ///
	topic_15 topic_16 topic_17 topic_18 topic_19 start_follow_space ///
	voter_created  voter_about_len voter_avatar_b vote_datetime ///
	vote_date dao_creation_date proposal_end_datetime proposal_end_date ///
	voting_period_length month year year_month_num type_numeric ///
	type_approval type_basic type_quadratic type_ranked_choice ///
	type_single_choice type_weighted  ///
	{ 
	replace `v' = . if newv == 1 
}

foreach v of varlist voter proposal   { 
	replace `v' = "" if newv == 1 
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

/*
drop already_voting_last_proposal

duplicates tag voter_space_id proposal_space_counter, gen(dupl_voting)

by voter_space_id, sort: egen tot_duplicates = total(dupl_voting)
sort tot_duplicates voter_id  proposal_space_counter
order already_voting_last_proposal
sort already_voting_last_proposal voter_id proposal_space_counter

by voter_id, sort: egen duppy_voter = total(already_voting_last_proposal)
sum duppy_voter
*/

//Time-panel order
tsset voter_space_id proposal_space_counter
drop newv last_proposal_space last_voter_space

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
foreach x of varlist voter_id space_id voting_power  {
	bysort voter_space_id (`x'): replace `x' = `x'[1] if `x' == .
}

foreach x of varlist voter {
	gsort voter_id -`x'
	by voter_id: replace `x' = `x'[1] if `x' == ""
}


///Constant in DAO
foreach x of varlist dao_creation_date   {
	bysort space_id (`x'): replace `x' = `x'[1] if `x' == .
}

///If we need the strings

foreach x of varlist space {
	gsort space_id -`x'
	by space_id: replace `x' = `x'[1] if `x' == ""
}



///Find proposal id
foreach x of varlist proposal_id   {
	bysort space_id proposal_space_counter (`x'): replace `x' = `x'[1] if `x' == .
}

foreach x of varlist proposal {
	gsort proposal_id -`x'
	by proposal_id: replace `x' = `x'[1] if `x' == ""
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

///Decision structure in last 6 months of DAO and participated
gen voted_weighted = voted * type_weighted 
gen voted_quad = voted * type_quadratic
gen voted_app = voted * type_approval
gen voted_basic = voted * type_basic
gen voted_ranked = voted * type_ranked_choice
gen voted_sc = voted * type_single_choice

gen voted_prps_len = voted * prps_len
gen voted_prps_link = voted * prps_link
gen voted_prps_stub = voted * prps_stub


	
forvalues i = 0(1)19 {
	display "topic " `i'
	gen voted_topic_`i' = voted * topic_`i'
	}

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

* Create 3-month
gen quarter_step = floor((year_month_num)/3)

/////////////////////////////////////////////
///// collapsing
////////////////////////////////////////////
sort voter_space_id vote_datetime	
drop proposal vote_date vote_datetime diff_days_last_proposal_space ///
	lag_times_votes_space_cum month year year_month_num ///
	diff_days_last_vote_space proposal_space_counter already_voting_last_proposal ///
	proposal_start_datetime space winning_choice prps_created scores_total ///
	voter_first_vote voter_space_first_vote active_vp proposal_total_vp ///
	type_numeric
	
collapse (mean) aligned misaligned misaligned_c voted voting_power quorum /// 
			 type_approval type_basic type_quadratic ///
			type_ranked_choice type_single_choice type_weighted ///
			voted_weighted voted_quad voted_app voted_basic voted_ranked voted_sc ///
			voted_topic_0 voted_topic_1 voted_topic_2 voted_topic_3 voted_topic_4 ///
			voted_topic_5 voted_topic_6 voted_topic_7 voted_topic_8 voted_topic_9 ///
			voted_topic_10 voted_topic_11 voted_topic_12 voted_topic_13 ///
			voted_topic_14 voted_topic_15 voted_topic_16 voted_topic_17 ///
			voted_topic_18 voted_topic_19 ///
			topic_0 topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 ///
			topic_8 topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 ///
			topic_15 topic_16 topic_17 topic_18 topic_19 ///
			voter_tenure_all voter_tenure_space ///
			relative_voting_power_pot relative_voting_power_act ///
			(sum) mis_total=misaligned misaligned_wmiss voted_6m_total=voted ///
			mis_w mis_q mis_app mis_b mis_r mis_sc ///
			total_obs = dummy	///
		 (max) voter_active ///
		 (first) voter_id space_id ///
		 (last) times_voted_space_cum max_times_voted_space space_age ///
		 , by(voter_space_id quarter_step)

gen mal_6m_miss = 	mis_total / voted_6m_total	 
	
gen mal_6m_w_v2 = mis_w / mis_total
gen mal_6m_q_v2 = mis_q / mis_total
gen mal_6m_app_v2 = mis_app / mis_total
gen mal_6m_b_v2 = mis_b / mis_total
gen mal_6m_r_v2 = mis_r / mis_total
gen mal_6m_sc_v2 = mis_sc / mis_total

replace mal_6m_w_v2 = 0 if mal_6m_w_v2 == .
replace mal_6m_q_v2 = 0 if mal_6m_q_v2 == .
replace mal_6m_app_v2 = 0 if mal_6m_app_v2 == .
replace mal_6m_b_v2 = 0 if mal_6m_b_v2 == .
replace mal_6m_r_v2 = 0 if mal_6m_r_v2 == .
replace mal_6m_sc_v2 = 0 if mal_6m_sc_v2 == .
	

///What to do afterwards?
///Concurrent activity across organizations
	
	
compress
	
//voter space_vote	
//corr Mis_W_6M mis6m_weighted

save "$dao_folder/processed/data_helge_panel_agg.dta", replace


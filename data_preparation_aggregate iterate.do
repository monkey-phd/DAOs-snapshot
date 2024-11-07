set seed 8472
clear all
set more off

local date: display %td_CCYY_NN_DD date(c(current_date), "DMY")
local date_string = subinstr(trim("`date'"), " " , "-", .)
local start_time: display %tCCCYY-NN-DD-HH-MM-SS ///
	Clock("`c(current_date)' `c(current_time)'","DMYhms")
local start_time_string = subinstr(trim("`start_time'"), " " , "-", .)
scalar start_time_v2 = c(current_time)

capture log close
log using "$dao_folder/logs/`start_time_string'_data_prep_iter.smcl"
set linesize 200

* Load the master list containing DAO names
import delimited "$dao_folder/input/verified-spaces_almost_full.csv", varnames(1) clear 

* Assuming the column name with the DAO names is 'dao_name'
* Loop through each DAO name and perform operations
levelsof space_name, local(daos)

foreach dao in `daos' {

//use "$dao_folder/processed/magnus_export.dta", clear
    * Start time for the loop
    scalar loop_start = c(current_time)
    local filepath = "$dao_folder/input/dao/data_`dao'.csv"
    * Import the specific dataset for this DAO
	
	capture confirm file "`filepath'"
	if   c(rc) {
		di "`filepath' does not exist. Skipping..."
		continue
	}
	else {
		di "Importing `filepath'"
		import delimited "`filepath'", ///
			bindquote(strict) case(preserve) maxquotedrows(unlimited) clear
	}
	/*
	import delimited "C:/Users/hklapper/Dropbox/Empirical Paper on DAOs (MvHxHK)/Data/input/dao/data_cakevote.eth.csv", ///
		bindquote(strict) case(preserve) maxquotedrows(unlimited) clear
	*/
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

	//drop if voter_total_votes <= 2
	//keep if space_id == 168

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


	duplicates report voter_space_id proposal_space_counter
	duplicates tag voter_space_id proposal_space_counter , gen(tsfill_tag)

	tab tsfill_tag
	drop tsfill_tag

	sort space_id proposal_space_counter voter_space_id voter_id proposal_start_datetime
	order space_id proposal_space_counter voter_space_id voter_id ///
		proposal_start_datetime proposal_space_id

	gen voted = 1
	replace voted = 0 if not_determined == 1
	drop not_determined

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
	//Cakevote is too big for tsfill, so I drop largest vote and voters with
	// two or fewer voters
	if space == "cakevote.eth" {
		gen dummy = 1
		by voter_id, sort: egen voter_total = total(dummy)

		by voter_id, sort: gen voter_first = 1 if _n==1

		sum voter_total if voter_first == 1, detail

		by proposal_id, sort: egen proposal_total = total(dummy)

		by proposal_id, sort: gen proposal_first = 1 if _n==1

		sum proposal_total if proposal_first == 1, detail

		drop if proposal_total == 133611
		drop if voter_total <= 2		
		drop dummy voter_total voter_first proposal_total proposal_first 
	}
	drop newv last_proposal_space last_voter_space

	qui sum voter_id, detail
	display "Number of voters:"
	display r(max)
	
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
	bysort voter_space_id: egen voter_space_first_vote = min(vote_date)
	gen voter_tenure_space = vote_date - voter_space_first_vote

	///Space/DAO stuff
	gen space_age = vote_date - dao_creation_date
	bysort space_id (vote_datetime): gen votes_dao_cum = sum(voted)

	///Proposal stuff
	bysort proposal_id (vote_datetime): gen votes_proposal_cum = sum(voted)
	bysort proposal_id: gegen proposal_active_voters = total(voter_active)
	bysort proposal_id: gegen proposal_total_voted = total(voted)
	gen prps_part_rate = proposal_total_voted / proposal_active_voters
	
	bysort proposal_id: gegen proposal_total_misalign = total(misaligned)
	gen prps_misalign = proposal_total_misalign / proposal_total_voted
	
	* Check how winning choice is calculated.
	* Maybe how close to the rest?
	//gen prps_majority = max_score / scores_total
	//gen prps_controvers = 1 - 2 * abs(prps_majority - 0.5)

	bysort voter_space_id (vote_datetime): gen voter_space_prps_counter = sum(dummy)
		
	gen active_vp = voting_power * voter_active
	bysort proposal_id: gegen proposal_total_vp = total(active_vp)
	gen relative_voting_power_pot = voting_power / proposal_total_vp
	gen relative_voting_power_act = voting_power / scores_total
	replace relative_voting_power_act = 1 if relative_voting_power_act > 1
**# Bookmark #1
	* Check when > 1!
	* Find relevant DAOs from aggregate dataset
	* Then check original scores
	* Potential explanation: Non-voters with high vp and votes with low participation
	bysort proposal_id (vote_datetime): gen proposal_first_vote = 1 if _n==1
	gen proposal_share_voted = proposal_total_voted / proposal_active_voters

	///Decision structure in last 6 months of DAO and participated
	gen voted_weighted = type_weighted if voted == 1
	gen voted_quad = type_quadratic if voted == 1
	gen voted_app = type_approval if voted == 1
	gen voted_basic = type_basic if voted == 1
	gen voted_ranked = type_ranked_choice if voted == 1
	gen voted_sc = type_single_choice if voted == 1

	gen voted_prps_len =  prps_len if voted == 1
	gen voted_prps_link = prps_link if voted == 1
	gen voted_prps_stub = prps_stub if voted == 1
	gen voted_prps_part_rate = prps_part_rate if voted == 1
	gen voted_prps_misalign = prps_misalign if voted == 1
	
	gen voted_prps_choices = prps_choices if voted == 1
		
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
	
	gen mis_app_low_mis = 0
	replace mis_app_low_mis = mis_app if prps_misalign <= 0.1
	gen mis_app_high_mis = 0
	replace mis_app_high_mis = mis_app if prps_misalign > 0.1	
	
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
		proposal_start_datetime winning_choice prps_created scores_total ///
		voter_space_first_vote active_vp proposal_total_vp proposal_space_id ///
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
		voter_tenure_space ///
		relative_voting_power_pot relative_voting_power_act ///
		voted_prps_len prps_len voted_prps_link voted_prps_choices ///
		prps_link voted_prps_stub prps_stub prps_choices ///
		prps_part_rate prps_misalign voted_prps_part_rate voted_prps_misalign ///
		(sum) mis_total=misaligned misaligned_wmiss voted_6m_total=voted ///
		mis_w mis_q mis_app mis_b mis_r mis_sc mis_app_low_mis mis_app_high_mis ///
		total_obs = dummy	///
		(max) voter_active ///
		(first) voter space voter_id space_id ///
		(last) times_voted_space_cum max_times_voted_space space_age ///
		, by(voter_space_id quarter_step)

	gen mal_6m_miss = mis_total / voted_6m_total	 
		
	gen mal_6m_w = mis_w / mis_total
	gen mal_6m_q = mis_q / mis_total
	gen mal_6m_app = mis_app / mis_total
	gen mal_6m_b = mis_b / mis_total
	gen mal_6m_r = mis_r / mis_total
	gen mal_6m_sc = mis_sc / mis_total
	gen mal_6m_app_low = mis_app_low_mis / mis_total
	gen mal_6m_app_high = mis_app_high_mis / mis_total	

	replace mal_6m_w = 0 if mal_6m_w == .
	replace mal_6m_q = 0 if mal_6m_q == .
	replace mal_6m_app = 0 if mal_6m_app == .
	replace mal_6m_b = 0 if mal_6m_b == .
	replace mal_6m_r = 0 if mal_6m_r == .
	replace mal_6m_sc = 0 if mal_6m_sc == .
	replace mal_6m_app_low = 0 if mal_6m_app_low == .
	replace mal_6m_app_high = 0 if mal_6m_app_high == .
	
	qui compress
		
	//voter space_vote	
	//corr Mis_W_6M mis6m_weighted

	drop voter_id
	drop space_id
	drop voter_space_id 


	* End time for the loop
    scalar loop_end = c(current_time)
       
    * Display the time taken for the loop in hh:mm:ss format
    di (clock(loop_end, "hms") - clock(loop_start, "hms")) / 1000 " seconds"
	scalar end_time = c(current_time)

	display (clock(end_time, "hms") - clock(start_time_v2, "hms")) / 1000 " seconds"
	
	save "$dao_folder/processed/dao/agg_panel_`dao'.dta", replace
	}

display "End"

* Loop through files and append them one by one
use "$dao_folder/processed/dao/agg_panel_0xgov.eth.dta", clear

foreach dao in `daos' {
	if "`dao'" == "0xgov.eth" {
		display "first one skip"
		continue			
		}
    * Construct the filename based on the DAO name
    local filepath = "$dao_folder/processed/dao/agg_panel_`dao'.dta"

    * Import the specific dataset for this DAO
	capture confirm file "`filepath'"
	if   c(rc) {
		di "`filepath' does not exist. Skipping..."
	}
	else {
		di "Appending `filepath'"
		append using "`filepath'"
	}

}



//After joining data together

////Create Voter IDs
gegen voter_id = group(voter)
drop voter

egen space_id = group(space), label
drop space

gegen voter_space_id = group(voter_id space_id)

///Space ID according to size
gen dummy = 1
bysort space_id: egen space_occ = total(dummy)
bysort space_id: gen first_space = _n ==1
bysort first_space (space_occ): gen spc2_id = sum(dummy) if first_space == 1
bysort space_id: egen space_id_size = min(spc2_id)

tab space_id_size

///Days since last vote overall
bysort voter_id : egen voter_first_vote = min(quarter_step)
gen voter_tenure_all = quarter_step - voter_first_vote

bysort voter_id (quarter_step): gen times_voted_all_cum = sum(voted_6m_total)

forvalues i = 0(1)19 {
	label variable voted_topic_`i' "VA Topic `i'"
	label variable topic_`i' "DAO Share Topic `i'"
	}

save "$dao_folder/processed/panel_agg_full.dta", replace

* Store the end time for the entire process
scalar end_time = c(current_time)

display (clock(end_time, "hms") - clock(start_time_v2, "hms")) / 1000 " seconds"

translate "$dao_folder/logs/`start_time_string'_data_prep_iter.smcl" ///
	"$dao_folder/logs/`start_time_string'_data_prep_iter.log", replace linesize(150)
log close

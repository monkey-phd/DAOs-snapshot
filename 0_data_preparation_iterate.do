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

local j=r(r)

local i=1

foreach dao in `daos' {
	
//use "$dao_folder/processed/magnus_export.dta", clear
    * Start time for the loop
    scalar loop_start = c(current_time)
    local filepath = "$dao_folder/input/dao/data_`dao'.csv"
    * Import the specific dataset for this DAO
	
	/*
	if "`dao'" != "stgdao.eth" {
		continue
	}
	*/
	
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
	
	display "{bf:DAO `i' out of `j'}"
	local ++i
	
	/*
	import delimited "C:/Users/hklapper/Dropbox/Empirical Paper on DAOs (MvHxHK)/Data/input/dao/data_aave.eth.csv", ///
			bindquote(strict) case(preserve) maxquotedrows(unlimited) clear
	*/
	
	tab space if winning_choice == ""
	qui drop if winning_choice == ""
	qui drop voter_created 
	//qui drop winning_choices
	
	//////Convert date string to numeric strings
	qui  gen vote_datetime = clock(vote_created, "YMDhms")
	qui gen vote_date = date(vote_created, "YMDhms")
	qui format vote_datetime %tc
	qui format vote_date %td
	qui drop vote_created

	qui gen dao_creation_date = date(space_created_at, "YMDhms")
	///gen str8 dao_creation_date_short = substr(space_created_at, 1, 10)
	///gen dao_creation_date_num = date(dao_creation_date, "YMDhms")
	qui format dao_creation_date %td

	//rename proposal_start_date proposal_start_date_str
	qui gen proposal_start_datetime = clock(prps_start, "YMDhms")
	qui format proposal_start_datetime %tc

	//rename proposal_end_date proposal_end_date_str
	qui gen proposal_end_datetime = clock(prps_end, "YMDhms")
	qui gen proposal_end_date = date(prps_end, "YMDhms")
	qui format proposal_end_datetime %tc
	qui format proposal_end_date %td

	qui gen voting_period_length = proposal_end_datetime - proposal_start_datetime

	qui drop prps_start prps_end prps_created space_created_at 

	//gen year = real(substr(year_month,1,4))
	//gen month = real(substr(year_month,6,2))

	qui gen month=month(vote_date)
	qui gen year=year(vote_date)
	qui gen year_month_num  = ym(year,month)
	qui gen dummy = 1

	//drop year_month

	/////////Create numeric IDs
	qui gegen voter_id = group(voter)
	qui sort voter voter_id
	qui order voter voter_id
	
	qui egen space_id = group(space), label

	//drop if voter_total_votes <= 2
	//keep if space_id == 168

	qui sort proposal proposal_start_datetime
	qui gegen proposal_id  = group(proposal)

	qui gegen proposal_space_id = group(space proposal_id)

	qui sort space_id proposal_start_datetime proposal_space_id  voter_id
	qui order space_id proposal_start_datetime proposal_space_id voter_id proposal_id

	//Calculate relative quorum
	egen space_high_scores = record(scores_total), by(space_id) order(proposal_start_date)
	qui gen prps_rel_quorum = quorum / space_high_scores
	qui gen prps_quorum_bin = 0
	replace prps_quorum_bin = 1 if quorum > 0 & quorum != .
	drop quorum
	
	qui bysort space_id proposal_id (proposal_start_datetime): gen proposal_space_dummy = 1 if _n==1
	qui bysort space_id (proposal_start_datetime proposal_id proposal_space_dummy): ///
		gen proposal_space_counter_d = sum(proposal_space_dummy) if proposal_space_dummy == 1
	qui bysort proposal_id: egen proposal_space_counter = min(proposal_space_counter_d)
	qui drop proposal_space_dummy proposal_space_counter_d
		
	///Check whether are where are duplicate
	duplicates report voter proposal_id
	//duplicates report voter space_id proposal_space_counter
	duplicates drop voter proposal_id, force

	qui gegen voter_space_id = group(voter_id space_id)

	
	//drop scores

	/////Convert other strings to numeric
	qui gen type_numeric = 0

	qui gen type_approval = 0
	qui replace type_approval = 1 if type == "approval"
	qui replace type_numeric = 1 if type == "approval"
	qui gen type_basic = 0
	qui replace type_basic = 1 if type == "basic"
	qui replace type_numeric = 2 if type == "basic"
	qui gen type_quadratic = 0
	qui replace type_quadratic = 1 if type == "quadratic"
	qui replace type_numeric = 3 if type == "quadratic"
	qui gen type_ranked_choice = 0
	qui replace type_ranked_choice = 1 if type == "ranked-choice"
	qui replace type_numeric = 4 if type == "ranked-choice"
	qui gen type_single_choice = 0
	qui replace type_single_choice = 1 if type == "single-choice"
	qui replace type_numeric = 5 if type == "single-choice"
	qui gen type_weighted = 0
	qui replace type_weighted = 1 if type == "weighted"
	qui replace type_numeric = 6 if type == "weighted"
	qui gen type_sc_abstain = 0
	qui replace type_sc_abstain = 1 if type == "single-choice-abstain"
	qui replace type_numeric = 7 if type == "single-choice-abstain"

	qui rename votes total_votes
		 
	qui replace prps_choices = 2 if prps_choices == 3 & type_basic == 1
	
	//Binarize choice
	gen prps_choices_bin = 0
	replace prps_choices_bin = 1 if prps_choices > 2
	///drop prps_choices		 
		 
	qui replace misaligned = 0 if not_determined == 1 &  type_basic == 1
	qui replace misaligned_c = 0 if not_determined == 1 &  type_basic == 1
	qui tostring choice, replace
	qui gen abstain = 1 if choice == "3" &  type_basic == 1
	qui drop choice	 
		 
	/////Drop unnecessary variables
	//drop follower
	qui drop type dummy prps_author not_determined

	//duplicates report voter_space_id proposal_space_counter
	duplicates tag voter_space_id proposal_space_counter , gen(tsfill_tag)

	tab tsfill_tag
	drop tsfill_tag

	qui sort space_id proposal_space_counter voter_space_id voter_id proposal_start_datetime
	qui order space_id proposal_space_counter voter_space_id voter_id proposal_start_datetime proposal_space_id
	
	///All observations so far are the votes taking place
	qui gen voted = 1

	qui bysort space_id (proposal_space_counter): gegen last_proposal_space = ///
		max(proposal_space_counter)
	qui bysort voter_space_id (proposal_space_counter): ///
		gen last_voter_space = 1 if _n == _N

	qui sort voter_space_id proposal_space_counter
	qui order voter_space_id proposal_space_counter last_proposal_space last_voter_space

	expand 2 if last_voter_space == 1, generate(newv)

	///deleting voting information
	foreach v of varlist misaligned misaligned_c ///
		vote_datetime vote_date voted proposal_start_date ///
		proposal_id proposal_space_id voting_power abstain ///
		prps_rel_quorum prps_quorum_bin scores_total total_votes prps_len prps_link ///
		prps_stub topic_0 topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 ///
		topic_7 topic_8 topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 ///
		topic_15 topic_16 topic_17 topic_18 topic_19 ///
		vote_datetime prps_choices_bin prps_choices met_quorum own_choice_tied ///
		vote_date dao_creation_date proposal_end_datetime proposal_end_date ///
		voting_period_length month year year_month_num type_numeric ///
		type_approval type_basic type_quadratic type_ranked_choice type_sc_abstain ///
		type_single_choice type_weighted prps_delegate ///
		{ 
		qui replace `v' = . if newv == 1 
	}
	
	foreach v of varlist voter proposal   { 
		qui replace `v' = "" if newv == 1 
	}
	//sort voter_space_id proposal_space_counter
	//order voter_space_id proposal_space_counter last_proposal_space last_voter_space newv

	qui drop last_voter_space
	qui bysort voter_space_id (proposal_space_counter newv): gen last_voter_space = 1 if _n == _N
	qui order voter_space_id proposal_space_counter last_proposal_space ///
		last_voter_space newv 
	qui replace proposal_space_counter = last_proposal_space if last_voter_space == 1

	qui duplicates tag voter_space_id proposal_space_counter, gen(already_voting_last_proposal)

	// tab already_voting_last_proposal

	qui order voter_space_id proposal_space_counter last_proposal_space ///
		last_voter_space newv already_voting_last_proposal

	qui drop if already_voting_last_proposal == 1 & newv == 1

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

		drop if proposal_total > 8000
		drop if voter_total <= 4
		drop if proposal_total <= 10 
		drop dummy voter_total voter_first proposal_total proposal_first 
	}
	qui drop newv last_voter_space already_voting_last_proposal ///
		proposal_start_datetime 
	
	qui sum voter_id, detail
	display "Number of voters:"
	display r(max)
	//Fill in missing values
	tsfill

	qui replace own_choice_tied = 0  if own_choice_tied == .
	qui replace voted = 0 if voted == .
	qui gen misaligned_wmiss = misaligned
	qui replace misaligned_wmiss = 0 if misaligned_wmiss == .
	qui gen abstain_wmiss = abstain
	qui replace abstain_wmiss = 0 if abstain_wmiss == .
	qui gen mal_c_wmiss = misaligned_c
	qui replace mal_c_wmiss = 0 if mal_c_wmiss == .	
	qui gen dummy = 1
	
	///Cleaning up data
	qui replace misaligned = . if prps_choices == 1
	qui replace misaligned_wmiss = . if prps_choices == 1
	
	qui replace misaligned = . if met_quorum == 0
	qui replace misaligned_wmiss = . if met_quorum == 0

	//Copying values to newly created observations
	qui sort voter_space_id voter_id

	///Constant within voter_space_id
	foreach x of varlist voter_id space_id   {
		qui bysort voter_space_id (`x'): replace `x' = `x'[1] if `x' == .
	}
	
	foreach x of varlist voter {
		qui gsort voter_id -`x'
		qui by voter_id: replace `x' = `x'[1] if `x' == ""
	}


	///Constant in DAO
	foreach x of varlist dao_creation_date last_proposal_space  {
		bysort space_id (`x'): replace `x' = `x'[1] if `x' == .
	}

	///If we need the strings

	foreach x of varlist space {
		qui gsort space_id -`x'
		qui by space_id: replace `x' = `x'[1] if `x' == ""
	}


	///Find proposal id
	foreach x of varlist proposal_id   {
		qui bysort space_id proposal_space_counter (`x'): replace `x' = `x'[1] if `x' == .
	}

	foreach x of varlist proposal {
		qui gsort proposal_id -`x'
		qui by proposal_id: replace `x' = `x'[1] if `x' == ""
	}	
	qui drop if proposal_id == .
		
	///Find other values based on proposal
	///Missing: voting_period_length organization_size total_votes_decision
	/// Voting_rule_mixed
	foreach x of varlist  proposal_space_id ///
		scores_total ///
		total_votes type_approval type_basic met_quorum ///
		type_quadratic type_ranked_choice type_sc_abstain type_single_choice type_weighted ///
		year month year_month_num type_numeric proposal_end_datetime ///
		proposal_end_date topic_0 topic_1 topic_2 topic_3 ///
		prps_choices_bin prps_choices prps_len voting_period_length ///
		prps_link prps_stub prps_rel_quorum prps_quorum_bin prps_delegate ///
		topic_4 topic_5 topic_6 topic_7 topic_8 topic_9 topic_10 topic_11 ///
		topic_12 topic_13 topic_14 topic_15 topic_16 topic_17 topic_18 topic_19 ///
		{
		//display "`x'"
		qui bysort proposal_id (`x'): replace `x' = `x'[1] if `x' == .
	}

	///total_decisions_participated
	/*
	/// Variables that are 0 if no vote took place 
	foreach x of varlist NotDetermined delegated {
		replace `x' = 0 if `x' == .
		}
	*/
	qui replace vote_datetime = proposal_end_datetime if vote_datetime == .
	qui replace vote_date = proposal_end_date if vote_date == .

	qui bysort voter_space_id (vote_datetime): gen times_voted_space_cum = sum(voted)
	qui bysort voter_space_id: gegen max_times_voted_space = max(times_voted_space_cum)

	qui gen voter_active = 0
	qui replace voter_active = 1 if times_voted_space_cum < max_times_voted_space 
	qui replace voter_active = 1 if voted == 1
	
	qui gen last_voter_space = 0
	qui replace last_voter_space = 1 if proposal_space_counter == last_proposal_space
	qui drop last_proposal_space
	//Drop if never voted before in DAO
	qui drop if times_voted_space_cum == 0
	//////////////////////////////////////////////////////
	//Check how this can happen! Do we want these votes?
	//////////////////////////////////////////////////////

	///Days since last vote in space

	qui bysort  voter_space_id  (vote_datetime): ///
		gen diff_days_last_proposal_space = vote_date - vote_date[_n-1]
	qui sort voter_id voter_space_id vote_datetime
		
	//replace diff_days_last_proposal_space = 0 if diff_days_last_proposal_space == 0
	qui bysort  voter_space_id  (vote_datetime): ///
		gen lag_times_votes_space_cum = times_voted_space_cum[_n-1]
	qui bysort  voter_space_id lag_times_votes_space_cum (vote_datetime): ///
		gen diff_days_last_vote_space = sum(diff_days_last_proposal_space)

	qui sort voter_id voter_space_id vote_datetime
	qui order voter_id voter_space_id voted vote_date vote_datetime ///
		diff_days_last_proposal_space lag_times_votes_space_cum ///
		lag_times_votes_space_cum diff_days_last_vote

	/// voter_experience_days
	qui bysort voter_space_id: egen voter_space_first_vote = min(vote_date)
	qui gen voter_tenure_space = vote_date - voter_space_first_vote
	drop voter_space_first_vote
		///Space/DAO stuff

	qui gen space_age = vote_date - dao_creation_date

	qui bysort space_id (vote_datetime): gen votes_dao_cum = sum(voted)

	///Proposal stuff
	qui bysort proposal_id (vote_datetime): gen votes_proposal_cum = sum(voted)
	qui bysort proposal_id: gegen proposal_active_voters = total(voter_active)
	qui bysort proposal_id: gegen proposal_total_voted = total(voted)
	qui gen prps_part_rate = proposal_total_voted / proposal_active_voters
	
	qui bysort proposal_id: gegen proposal_total_misalign = total(misaligned)
	qui gen prps_misalign = proposal_total_misalign / proposal_total_voted
	qui drop proposal_total_misalign
	
	* Check how winning choice is calculated.
	* Maybe how close to the rest?
	//gen prps_majority = max_score / scores_total
	//gen prps_controvers = 1 - 2 * abs(prps_majority - 0.5)

	qui bysort voter_space_id (vote_datetime): gen voter_space_prps_counter = sum(dummy)
	
	qui bysort voter_space_id (vote_datetime): replace voting_power = voting_power[_n-1] if voting_power == .
																	  
	qui gen active_vp = voting_power * voter_active
	qui bysort proposal_id: gegen prps_total_vp = total(active_vp)
	qui gen relative_voting_power_pot = voting_power / prps_total_vp
	qui gen relative_voting_power_act = voting_power / scores_total
	qui replace relative_voting_power_act = 1 if relative_voting_power_act > 1
	qui drop prps_total_vp
**# Bookmark #1
	* Check when > 1!
	* Find relevant DAOs from aggregate dataset
	* Then check original scores
	* Potential explanation: Non-voters with high vp and votes with low participation
	//qui bysort proposal_id (vote_datetime): gen proposal_first_vote = 1 if _n==1
	
	* Voting in next 1,3,6 months
	qui rangestat (mean) voting_1m = voted, ///
		interval(vote_datetime 0 2.59e09) by(voter_space_id) excludeself	
	
	qui rangestat (mean) voting_3m = voted, ///
		interval(vote_datetime 0 7.78e09) by(voter_space_id) excludeself
	
	qui rangestat (mean) voting_6m = voted, ///
		interval(vote_datetime 0 1.56e10) by(voter_space_id) excludeself
	
	/*
	* Still active in 1,3,6 months
	qui rangestat (min) voting_active_1m = voter_active, ///
		interval(vote_datetime 0 2.59e09) by(voter_space_id) excludeself	
	
	qui rangestat (min) voting_active_3m = voter_active, ///
		interval(vote_datetime 0 7.78e09) by(voter_space_id) excludeself
	
	qui rangestat (min) voting_active_6m = voter_active, ///
		interval(vote_datetime 0 1.56e10) by(voter_space_id) excludeself
	*/
	
	* End of period
	qui rangestat (max) end_1m = last_voter_space, ///
		interval(vote_datetime 0 2.59e09) by(voter_space_id) excludeself
	
	qui rangestat (max) end_3m = last_voter_space, ///
		interval(vote_datetime 0 7.78e09) by(voter_space_id) excludeself
	
	qui rangestat (max) end_6m = last_voter_space, ///
		interval(vote_datetime 0 1.56e10) by(voter_space_id) excludeself	
		
	drop dummy	last_voter_space
	
	qui compress
		
	//voter space_vote	
	//corr Mis_W_6M mis6m_weighted

	drop voter_id
	drop space_id
	drop proposal_id
	drop voter_space_id
	drop proposal_space_id


	* End time for the loop
    scalar loop_end = c(current_time)
       
    * Display the time taken for the loop in hh:mm:ss format
    display (clock(loop_end, "hms") - clock(loop_start, "hms")) / 1000 " seconds"
	scalar end_time = c(current_time)

	display (clock(end_time, "hms") - clock(start_time_v2, "hms")) / 1000 " seconds"							  
	
	save "$dao_folder/processed/dao/panel_`dao'.dta", replace
	}

display "End"

* Loop through files and append them one by one
use "$dao_folder/processed/dao/panel_0xgov.eth.dta", clear


foreach dao in `daos' {
	if "`dao'" == "0xgov.eth" {
		display "first one skip"
		continue			
		}
    * Construct the filename based on the DAO name
    local filepath = "$dao_folder/processed/dao/panel_`dao'.dta"

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
/*
* Intermediate step, if necessary
save "$dao_folder/processed/panel_full_temp.dta", replace

use "$dao_folder/processed/panel_full_temp.dta", clear
*/


//After joining data together

////Create Voter IDs
gegen voter_id = group(voter)
drop voter

egen space_id = group(space), label
drop space

gegen voter_space_id = group(voter_id space_id)

gegen proposal_id  = group(proposal)
drop proposal

////Create Voter Space ID
gegen proposal_space_id = group(space_id proposal_id)

///Space ID according to size
gen dummy = 1
bysort space_id: egen space_occ = total(dummy)
bysort space_id: gen first_space = _n ==1
bysort first_space (space_occ): gen spc2_id = sum(dummy) if first_space == 1
bysort space_id: egen space_id_size = min(spc2_id)

tab space_id_size
drop spc2_id space_occ

///How many voting types per space
qui bysort space_id: gegen space_type_app = max(type_approval)
qui bysort space_id: gegen space_type_basic = max(type_basic)
qui bysort space_id: gegen space_type_quad = max(type_quadratic)
qui bysort space_id: gegen space_type_ranked = max(type_ranked_choice)
qui bysort space_id: gegen space_type_single = max(type_single_choice)
qui bysort space_id: gegen space_type_weighted = max(type_weighted)

qui gen space_no_vot_types = space_type_app + space_type_basic + ///
	space_type_quad + space_type_ranked + space_type_single + space_type_weighted
	
qui drop space_type_app space_type_basic space_type_quad space_type_ranked ///
	space_type_single space_type_weighted

///How many voting types per voter
qui bysort voter_space_id: gegen vs_type_app = max(type_approval * voted)
qui bysort voter_space_id: gegen vs_type_basic = max(type_basic * voted)
qui bysort voter_space_id: gegen vs_type_quad = max(type_quadratic * voted)
qui bysort voter_space_id: gegen vs_type_ranked = max(type_ranked_choice * voted)
qui bysort voter_space_id: gegen vs_type_single = max(type_single_choice * voted)
qui bysort voter_space_id: gegen vs_type_weighted = max(type_weighted * voted)

qui gen vs_types = vs_type_app + vs_type_basic + ///
	vs_type_quad + vs_type_ranked + vs_type_single + vs_type_weighted
	
qui drop vs_type_app vs_type_basic vs_type_quad vs_type_ranked ///
	vs_type_single vs_type_weighted		

///Days since last vote overall
bysort voter_id : egen voter_first_vote = min(vote_date)
gen voter_tenure_all = vote_date - voter_first_vote

bysort voter_id (vote_datetime): gen times_voted_all_cum = sum(voted)
bysort  voter_id  (vote_datetime): gen diff_days_last_proposal_all = vote_date - vote_date[_n-1]
bysort  voter_id  (vote_datetime): gen lag_times_voted_all_cum = times_voted_all_cum[_n-1]
//replace diff_days_last_proposal_all = 0 if diff_days_last_proposal_all == 0
bysort  voter_id lag_times_voted_all_cum (vote_datetime): ///
	gen diff_days_last_vote_all = sum(diff_days_last_proposal_all)

//drop lag_times_votes_space_cum lag_times_voted_all_cum dummy


///presence_other_organizations
//////Sort by user space time, first == 1, then order by user time and add up
bysort voter_id space_id (vote_datetime): gen voter_space_dummy = 1 if _n==1
bysort voter_id (vote_datetime space_id): 	gen voter_space_counter = sum(voter_space_dummy)

drop voter_space_dummy voter_first_vote vote_date 

order space_id voter_id vote_datetime

compress

label variable space_id "Space ID"
label variable voter_id "Voter ID"
//label variable vote_datetime "Vote DateTime"
label variable voted "Voted"
//label variable diff_days_last_proposal_space "Days Since Last Proposal in Space"
//label variable diff_days_last_vote_space "Days Since Last Vote in Space"
label variable proposal_space_counter "Proposal Space Counter"
//label variable voting_power "Voting Power"
label variable misaligned "Misaligned"
label variable misaligned_c "Misaligned (Weighted)"
label variable prps_rel_quorum "Proposal Quorum"
//label variable scores_total "Total Scores"
label variable prps_choices_bin "Proposal Choices (Bin.)"
label variable prps_choices "Proposal Choices"
//label variable total_votes "Total Votes"
label variable prps_len "Proposal Length"
//label variable prps_link "Proposal Link"
//label variable prps_stub "Proposal Stub"
label variable topic_0 "Topic 0"
label variable topic_1 "Topic 1"
label variable topic_2 "Topic 2"
label variable topic_3 "Topic 3"
label variable topic_4 "Topic 4"
label variable topic_5 "Topic 5"
label variable topic_6 "Topic 6"
label variable topic_7 "Topic 7"
label variable topic_8 "Topic 8"
label variable topic_9 "Topic 9"
label variable topic_10 "Topic 10"
label variable topic_11 "Topic 11"
label variable topic_12 "Topic 12"
label variable topic_13 "Topic 13"
label variable topic_14 "Topic 14"
label variable topic_15 "Topic 15"
label variable topic_16 "Topic 16"
label variable topic_17 "Topic 17"
label variable topic_18 "Topic 18"
label variable topic_19 "Topic 19"
//label variable voting_period_length "Voting Period Length"
//label variable month "Month"
label variable year "Year"
label variable year_month_num "Year-Month Number"
label variable type_numeric "Type Numeric"
label variable type_approval "Approval"
label variable type_basic "Basic"
label variable type_quadratic "Quadratic"
label variable type_ranked_choice "Ranked Choice"
label variable type_single_choice " Single Choice"
label variable type_weighted "Weighted"
label variable misaligned_wmiss "Misaligned"
label variable mal_c_wmiss "Misaligned (Weighted)"
label variable own_margin "Margin"
//label variable times_voted_space_cum "Cumulative Times Voted in Space"
//label variable max_times_voted_space "Max Times Voted in Space"
//label variable voter_active "Voter Active"
label variable voter_tenure_space "Voter Tenure in Space"
//label variable space_age "Space Age"
label variable votes_dao_cum "Cumulative Votes in DAO"
label variable votes_proposal_cum "Cumulative Votes on Proposal"
//label variable proposal_active_voters "Proposal Active Voters"
//label variable proposal_total_voted "Total Voted on Proposal"
label variable prps_part_rate "Proposal Participation Rate"
//label variable proposal_total_misalign "Total Misaligned on Proposal"
label variable prps_misalign "Proposal Misalignment"
label variable voter_space_prps_counter "Voter Space Proposal Counter"
//label variable active_vp "Active Voting Power"
//label variable proposal_total_vp "Total Voting Power on Proposal"
label variable relative_voting_power_pot "Relative Voting Power (Potential)"
label variable relative_voting_power_act "Relative Voting Power (Actual)"
label variable voting_1m "Voting in next 1 Month"
label variable voting_3m "Voting in next 3 Months"
label variable voting_6m "Voting in next 6 Months"
//label variable voting_active_1m "Voting Active in 1 Month"
//label variable voting_active_3m "Voting Active in 3 Months"
//label variable voting_active_6m "Voting Active in 6 Months"
label variable end_1m "End in 1 Month"
label variable end_3m "End in 3 Months"
label variable end_6m "End in 6 Months"
label variable voter_space_id "Voter Space ID"
label variable proposal_id "Proposal ID"
label variable proposal_space_id "Proposal Space ID"
label variable first_space "First Space"
label variable space_id_size "Space ID Size"
label variable voter_tenure_all "Voter Tenure (All)"
label variable times_voted_all_cum "Cumulative Times Voted (All)"
label variable diff_days_last_proposal_all "Days Since Last Proposal (All)"
label variable diff_days_last_vote_all "Days Since Last Vote (All)"
label variable voter_space_counter "Voter Space Counter"

save "$dao_folder/processed/panel_almost_full_helge.dta", replace

* Store the end time for the entire process
scalar end_time = c(current_time)

display (clock(end_time, "hms") - clock(start_time_v2, "hms")) / 1000 " seconds"

translate "$dao_folder/logs/`start_time_string'_data_prep_iter.smcl" ///
	"$dao_folder/logs/`start_time_string'_data_prep_iter.log", replace linesize(150)
log close
*/

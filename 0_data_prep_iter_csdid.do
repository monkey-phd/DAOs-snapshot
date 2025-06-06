*------------------------------------------------------*
* Data Preparation Script for DAO Analysis
*------------------------------------------------------*

global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data" // change with your actual path

* Set seed for reproducibility
set seed 8472

* Clear existing data and settings
clear all
set more off

*------------------------------------------------------*
* 1. Initialize and Set Up Log File
*------------------------------------------------------*

local date: display %td_CCYY_NN_DD date(c(current_date), "DMY")
local date_string = subinstr(trim("`date'"), " " , "-", .)
local start_time: display %tCCCYY-NN-DD-HH-MM-SS ///
	Clock("`c(current_date)' `c(current_time)'","DMYhms")
local start_time_string = subinstr(trim("`start_time'"), " " , "-", .)
scalar start_time_v2 = c(current_time)

capture log close
log using "$dao_folder/logs/`start_time_string'_data_prep_iter.smcl"
set linesize 200
*------------------------------------------------------*
* 2. Load DAO Names and Initialize Loop
*------------------------------------------------------*

* Load the master list containing DAO names
import delimited "$dao_folder/input/verified-spaces.csv", varnames(1) clear /// before, verified-spaces_almost_full.csv

* Extract DAO names into a local macro
levelsof space_name, local(daos)
local j = r(r)
local i = 1

*------------------------------------------------------*
* 3. Loop Through Each DAO and Process Data
*------------------------------------------------------*

foreach dao in `daos' {
    * Start time for the loop
    scalar loop_start = c(current_time)
    local filepath = "$dao_folder/input/dao/data_`dao'.csv"
    
    * Import the specific dataset for this DAO
    capture confirm file "`filepath'"
    if c(rc) {
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
    
    *--------------------------------------------------*
    * 3.1. Data Cleaning and Variable Preparation
    *--------------------------------------------------*
    
    * Drop observations without winning choices
    tab space if winning_choice == ""
    drop if winning_choice == ""
    drop voter_created
    //drop winning_choices (if needed)
    
    *--------------------------------------------------*
    * 3.2. Convert Date Strings to Numeric Formats
    *--------------------------------------------------*
    
    * Convert vote date and time
    qui gen vote_datetime = clock(vote_created, "YMDhms")
    qui gen vote_date = date(vote_created, "YMDhms")
    qui format vote_datetime %tc
    qui format vote_date %td
    qui drop vote_created

    * Convert DAO creation date
    qui gen dao_creation_date = date(space_created_at, "YMDhms")
    qui format dao_creation_date %td

    * Convert proposal start and end dates
    qui gen proposal_start_datetime = clock(prps_start, "YMDhms")
    qui format proposal_start_datetime %tc

    qui gen proposal_end_datetime = clock(prps_end, "YMDhms")
    qui gen proposal_end_date = date(prps_end, "YMDhms")
    qui format proposal_end_datetime %tc
    qui format proposal_end_date %td

    * Calculate voting period length
    qui gen voting_period_length = proposal_end_datetime - proposal_start_datetime

    * Drop redundant date variables
    qui drop prps_start prps_end prps_created space_created_at 

    * Generate month and year variables
    qui gen month = month(vote_date)
    qui gen year = year(vote_date)
    qui gen year_month_num  = ym(year, month)
    qui gen dummy = 1

    *--------------------------------------------------*
    * 3.3. Create Numeric IDs and Group Variables
    *--------------------------------------------------*

    * Create voter ID
    qui gegen voter_id = group(voter)
    qui sort voter voter_id
    qui order voter voter_id
    
    * Create space ID
    qui egen space_id = group(space), label

    * Create proposal ID
    qui sort proposal proposal_start_datetime
    qui gegen proposal_id  = group(proposal)

    * Create proposal-space ID
    qui gegen proposal_space_id = group(space proposal_id)

    * Sort and order data
    qui sort space_id proposal_start_datetime proposal_space_id voter_id
    qui order space_id proposal_start_datetime proposal_space_id voter_id proposal_id

    *--------------------------------------------------*
    * 3.4. Calculate Relative Quorum
    *--------------------------------------------------*

    * Calculate highest scores per space
    egen space_high_scores = record(scores_total), by(space_id) order(proposal_start_date)
    qui gen prps_rel_quorum = quorum / space_high_scores
    qui gen prps_quorum_bin = 0
    replace prps_quorum_bin = 1 if quorum > 0 & quorum != .
    drop quorum

    *--------------------------------------------------*
    * 3.5. Create Proposal Counter
    *--------------------------------------------------*

    * Generate proposal counter within space
    qui bysort space_id proposal_id (proposal_start_datetime): gen proposal_space_dummy = 1 if _n == 1
    qui bysort space_id (proposal_start_datetime proposal_id proposal_space_dummy): ///
        gen proposal_space_counter_d = sum(proposal_space_dummy) if proposal_space_dummy == 1
    qui bysort proposal_id: egen proposal_space_counter = min(proposal_space_counter_d)
    qui drop proposal_space_dummy proposal_space_counter_d

    *--------------------------------------------------*
    * 3.6. Handle Duplicates
    *--------------------------------------------------*

    * Check for duplicates and drop them
    duplicates report voter proposal_id
    duplicates drop voter proposal_id, force

    * Create voter-space ID
    qui gegen voter_space_id = group(voter_id space_id)

    *--------------------------------------------------*
    * 3.7. Convert String Variables to Numeric Dummies
    *--------------------------------------------------*

    * Convert 'type' to numeric and create voting type dummies
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
    
	* Rename votes variable
    qui rename votes total_votes

    * Adjust proposal choices for basic type
    qui replace prps_choices = 2 if prps_choices == 3 & type_basic == 1

    * Binarize proposal choices
    gen prps_choices_bin = 0
    replace prps_choices_bin = 1 if prps_choices > 2

    * Handle misaligned cases and abstentions
    qui replace misaligned = 0 if not_determined == 1 & type_basic == 1
    qui replace misaligned_c = 0 if not_determined == 1 & type_basic == 1
    qui tostring choice, replace
    qui gen abstain = 1 if choice == "3" & type_basic == 1
    qui drop choice

    * Drop unnecessary variables
    qui drop type dummy prps_author not_determined

    *--------------------------------------------------*
    * 3.8. Tag and Handle Duplicate Proposals
    *--------------------------------------------------*

    * Tag duplicates for tsfill
    duplicates tag voter_space_id proposal_space_counter, gen(tsfill_tag)
    drop tsfill_tag

    * Sort data
    qui sort space_id proposal_space_counter voter_space_id voter_id proposal_start_datetime
    qui order space_id proposal_space_counter voter_space_id voter_id proposal_start_datetime proposal_space_id

    *--------------------------------------------------*
    * 3.9. Expand Data to Include Non-Voting Instances
    *--------------------------------------------------*

    * Generate voted indicator
    qui gen voted = 1

    * Identify last proposal in space and last voter instance
    qui bysort space_id (proposal_space_counter): gegen last_proposal_space = max(proposal_space_counter)
    qui bysort voter_space_id (proposal_space_counter): gen last_voter_space = 1 if _n == _N

    * Sort and order data
    qui sort voter_space_id proposal_space_counter
    qui order voter_space_id proposal_space_counter last_proposal_space last_voter_space

    * Expand data to include non-voting instances
    expand 2 if last_voter_space == 1, generate(newv)

    * Delete voting information for new observations
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
        type_single_choice type_weighted /// prps_delegate
        {
        qui replace `v' = . if newv == 1 
    }

    foreach v of varlist voter proposal {
        qui replace `v' = "" if newv == 1 
    }

    * Update last_voter_space indicator
    qui drop last_voter_space
    qui bysort voter_space_id (proposal_space_counter newv): gen last_voter_space = 1 if _n == _N
    qui order voter_space_id proposal_space_counter last_proposal_space last_voter_space newv
    qui replace proposal_space_counter = last_proposal_space if last_voter_space == 1

    * Remove duplicates
    qui duplicates tag voter_space_id proposal_space_counter, gen(already_voting_last_proposal)
    qui drop if already_voting_last_proposal == 1 & newv == 1

    *--------------------------------------------------*
    * 3.10. Set Time-Series Structure and Fill Data
    *--------------------------------------------------*

    * Set time-series structure
    tsset voter_space_id proposal_space_counter

    * If you experience issues, uncomment. Handle large vote (e.g., cakevote.eth)
    if space == "cakevote.eth" {
        gen dummy = 1
        by voter_id, sort: egen voter_total = total(dummy)
        by voter_id, sort: gen voter_first = 1 if _n == 1
        sum voter_total if voter_first == 1, detail
        by proposal_id, sort: egen proposal_total = total(dummy)
        by proposal_id, sort: gen proposal_first = 1 if _n == 1
        sum proposal_total if proposal_first == 1, detail
        drop if proposal_total > 8000
        drop if voter_total <= 4
        drop if proposal_total <= 10 
        drop dummy voter_total voter_first proposal_total proposal_first 
    }

    * Drop temporary variables
    qui drop newv last_voter_space already_voting_last_proposal proposal_start_datetime

    * Display number of voters
    qui sum voter_id, detail
    display "Number of voters:"
    display r(max)

    * Fill in missing values
    tsfill

    * Replace missing values with appropriate defaults
    qui replace own_choice_tied = 0 if own_choice_tied == .
    qui replace voted = 0 if voted == .
    qui gen misaligned_wmiss = misaligned
    qui replace misaligned_wmiss = 0 if misaligned_wmiss == .
    qui gen abstain_wmiss = abstain
    qui replace abstain_wmiss = 0 if abstain_wmiss == .
    qui gen mal_c_wmiss = misaligned_c
    qui replace mal_c_wmiss = 0 if mal_c_wmiss == .    
    qui gen dummy = 1

    *--------------------------------------------------*
    * 3.11. Data Cleaning and Handling Missing Data
    *--------------------------------------------------*

    * Clean up data for misaligned cases
    qui replace misaligned = . if prps_choices == 1
    qui replace misaligned_wmiss = . if prps_choices == 1

    qui replace misaligned = . if met_quorum == 0
    qui replace misaligned_wmiss = . if met_quorum == 0

    *--------------------------------------------------*
    * 3.12. Copy Values to Newly Created Observations
    *--------------------------------------------------*

    * Sort data
    qui sort voter_space_id voter_id

    * Fill in constants within voter_space_id
    foreach x of varlist voter_id space_id voting_power {
        qui bysort voter_space_id (`x'): replace `x' = `x'[1] if `x' == .
    }

    foreach x of varlist voter {
        qui gsort voter_id -`x'
        qui by voter_id: replace `x' = `x'[1] if `x' == ""
    }

    * Fill in constants within DAO
    foreach x of varlist dao_creation_date last_proposal_space {
        bysort space_id (`x'): replace `x' = `x'[1] if `x' == .
    }

    * Fill in space names
    foreach x of varlist space {
        qui gsort space_id -`x'
        qui by space_id: replace `x' = `x'[1] if `x' == ""
    }

    * Fill in proposal IDs
    foreach x of varlist proposal_id {
        qui bysort space_id proposal_space_counter (`x'): replace `x' = `x'[1] if `x' == .
    }

    foreach x of varlist proposal {
        qui gsort proposal_id -`x'
        qui by proposal_id: replace `x' = `x'[1] if `x' == ""
    }

    * Drop observations without proposal IDs
    qui drop if proposal_id == .

    *--------------------------------------------------*
    * 3.13. Fill in Missing Values Based on Proposals
    *--------------------------------------------------*

    * Fill in proposal-related variables
    foreach x of varlist proposal_space_id scores_total total_votes type_approval type_basic met_quorum /// 
        type_quadratic type_ranked_choice type_single_choice type_weighted type_sc_abstain /// 
        year month year_month_num type_numeric proposal_end_datetime ///
        proposal_end_date topic_0 topic_1 topic_2 topic_3 prps_choices_bin prps_choices prps_len ///
        voting_period_length prps_link prps_stub prps_rel_quorum prps_quorum_bin ///
        topic_4 topic_5 topic_6 topic_7 topic_8 topic_9 topic_10 topic_11 ///
        topic_12 topic_13 topic_14 topic_15 topic_16 topic_17 topic_18 topic_19 {
        qui bysort proposal_id (`x'): replace `x' = `x'[1] if `x' == .
    }

    * Adjust vote dates if missing
    qui replace vote_datetime = proposal_end_datetime if vote_datetime == .
    qui replace vote_date = proposal_end_date if vote_date == .

    *--------------------------------------------------*
    * 3.14. Calculate Voting and Participation Metrics
    *--------------------------------------------------*

    * Calculate cumulative votes within space
    qui bysort voter_space_id (vote_datetime): gen times_voted_space_cum = sum(voted)
    qui bysort voter_space_id: gegen max_times_voted_space = max(times_voted_space_cum)

    * Determine if voter is active
    qui gen voter_active = 0
    qui replace voter_active = 1 if times_voted_space_cum < max_times_voted_space 
    qui replace voter_active = 1 if voted == 1

    * Identify last voter in space
    qui gen last_voter_space = 0
    qui replace last_voter_space = 1 if proposal_space_counter == last_proposal_space
    qui drop last_proposal_space

    * Drop voters who never voted before in DAO
    qui drop if times_voted_space_cum == 0

    *--------------------------------------------------*
    * 3.15. Calculate Time Since Last Vote
    *--------------------------------------------------*

    * Calculate days since last proposal in space
    qui bysort voter_space_id (vote_datetime): gen diff_days_last_proposal_space = vote_date - vote_date[_n-1]
    qui sort voter_id voter_space_id vote_datetime

    * Calculate cumulative time since last vote in space
    qui bysort voter_space_id (vote_datetime): gen lag_times_votes_space_cum = times_voted_space_cum[_n-1]
    qui bysort voter_space_id lag_times_votes_space_cum (vote_datetime): gen diff_days_last_vote_space = sum(diff_days_last_proposal_space)

    * Order data
    qui sort voter_id voter_space_id vote_datetime
    qui order voter_id voter_space_id voted vote_date vote_datetime ///
        diff_days_last_proposal_space lag_times_votes_space_cum ///
        lag_times_votes_space_cum diff_days_last_vote

    *--------------------------------------------------*
    * 3.16. Calculate Voter Tenure and DAO Age
    *--------------------------------------------------*

    * Calculate voter's first vote date in space
    qui bysort voter_space_id: egen voter_space_first_vote = min(vote_date)
    qui gen voter_tenure_space = vote_date - voter_space_first_vote
    drop voter_space_first_vote

    * Calculate DAO age at the time of vote
    qui gen space_age = vote_date - dao_creation_date

    * Calculate cumulative votes in DAO
    qui bysort space_id (vote_datetime): gen votes_dao_cum = sum(voted)

    *--------------------------------------------------*
    * 3.17. Calculate Proposal Participation Metrics
    *--------------------------------------------------*

    * Calculate cumulative votes on proposal
    qui bysort proposal_id (vote_datetime): gen votes_proposal_cum = sum(voted)
    qui bysort proposal_id: gegen proposal_active_voters = total(voter_active)
    qui bysort proposal_id: gegen proposal_total_voted = total(voted)
    qui gen prps_part_rate = proposal_total_voted / proposal_active_voters

    * Calculate proposal misalignment
    qui bysort proposal_id: gegen proposal_total_misalign = total(misaligned)
    qui gen prps_misalign = proposal_total_misalign / proposal_total_voted
    qui drop proposal_total_misalign

    * Count proposals per voter in space
    qui bysort voter_space_id (vote_datetime): gen voter_space_prps_counter = sum(dummy)

    *--------------------------------------------------*
    * 3.18. Calculate Voting Power Metrics
    *--------------------------------------------------*

    * Calculate active voting power
    qui gen active_vp = voting_power * voter_active
    qui bysort proposal_id: gegen prps_total_vp = total(active_vp)
    qui gen relative_voting_power_pot = voting_power / prps_total_vp
    qui gen relative_voting_power_act = voting_power / scores_total
    qui replace relative_voting_power_act = 1 if relative_voting_power_act > 1
    qui drop prps_total_vp

    *--------------------------------------------------*
    * 3.19. Calculate Future Voting Behavior
    *--------------------------------------------------*

    * Voting in next 1, 3, and 6 months
    qui rangestat (mean) voting_1m = voted, interval(vote_datetime 0 2.59e09) by(voter_space_id) excludeself
    qui rangestat (mean) voting_3m = voted, interval(vote_datetime 0 7.78e09) by(voter_space_id) excludeself
    qui rangestat (mean) voting_6m = voted, interval(vote_datetime 0 1.56e10) by(voter_space_id) excludeself

    * End of period indicators
    qui rangestat (max) end_1m = last_voter_space, interval(vote_datetime 0 2.59e09) by(voter_space_id) excludeself
    qui rangestat (max) end_3m = last_voter_space, interval(vote_datetime 0 7.78e09) by(voter_space_id) excludeself
    qui rangestat (max) end_6m = last_voter_space, interval(vote_datetime 0 1.56e10) by(voter_space_id) excludeself

    * Drop temporary variables
    drop dummy last_voter_space

    * Compress data
    qui compress

    *--------------------------------------------------*
    * 3.20. Drop IDs (Optional)
    *--------------------------------------------------*

    * You can choose to drop IDs here if needed
    drop voter_id
    drop space_id
    drop proposal_id
    drop voter_space_id
    drop proposal_space_id

    *--------------------------------------------------*
    * 3.21. End of Loop and Save Processed Data
    *--------------------------------------------------*

    * End time for the loop
    scalar loop_end = c(current_time)
       
    * Display the time taken for the loop in seconds
    display (clock(loop_end, "hms") - clock(loop_start, "hms")) / 1000 " seconds"
    scalar end_time = c(current_time)

    * Display cumulative time
    display (clock(end_time, "hms") - clock(start_time_v2, "hms")) / 1000 " seconds"                             

    * Save the processed data for the DAO
    save "$dao_folder/processed/dao/panel_`dao'.dta", replace
}

*------------------------------------------------------*
* 4. End of DAO Loop
*------------------------------------------------------*

display "End"

*------------------------------------------------------*
* 5. Append All DAO Data Files
*------------------------------------------------------*

* Load the first DAO data file
use "$dao_folder/processed/dao/panel_0xgov.eth.dta", clear

foreach dao in `daos' {
    if "`dao'" == "0xgov.eth" {
        display "First one skipped (already loaded)"
        continue
    }

    * Construct the filename based on the DAO name
    local filepath = "$dao_folder/processed/dao/panel_`dao'.dta"

    * Check if the file exists and append if it does
    capture confirm file "`filepath'"
    if c(rc) {
        di "`filepath' does not exist. Skipping..."
    }
    else {
        di "Appending `filepath'"
        append using "`filepath'"
    }
}

*------------------------------------------------------*
* 6. Recreate IDs and Variables
*------------------------------------------------------*

* Recreate voter IDs and drop original variable
gegen voter_id = group(voter)
drop voter

* Recreate space IDs and drop original variable
egen space_id = group(space), label
drop space

* Create voter-space ID
gegen voter_space_id = group(voter_id space_id)

* Recreate proposal IDs and drop original variable
gegen proposal_id = group(proposal)
drop proposal

* Create proposal-space ID
gegen proposal_space_id = group(space_id proposal_id)

*------------------------------------------------------*
* 7. Calculate Additional Metrics After Joining Data
*------------------------------------------------------*

* Calculate space size based on occurrence
gen dummy = 1
bysort space_id: egen space_occ = total(dummy)
bysort space_id: gen first_space = _n == 1
bysort first_space (space_occ): gen spc2_id = sum(dummy) if first_space == 1
bysort space_id: egen space_id_size = min(spc2_id)
drop spc2_id space_occ

* Calculate voting types per space
qui bysort space_id: gegen space_type_app = max(type_approval)
qui bysort space_id: gegen space_type_basic = max(type_basic)
qui bysort space_id: gegen space_type_quad = max(type_quadratic)
qui bysort space_id: gegen space_type_ranked = max(type_ranked_choice)
qui bysort space_id: gegen space_type_single = max(type_single_choice)
qui bysort space_id: gegen space_type_weighted = max(type_weighted)

qui gen space_no_vot_types = space_type_app + space_type_basic + ///
    space_type_quad + space_type_ranked + space_type_single + space_type_weighted

* Drop temporary variables
qui drop space_type_app space_type_basic space_type_quad space_type_ranked ///
    space_type_single space_type_weighted

* Calculate voting types per voter
qui bysort voter_space_id: gegen vs_type_app = max(type_approval * voted)
qui bysort voter_space_id: gegen vs_type_basic = max(type_basic * voted)
qui bysort voter_space_id: gegen vs_type_quad = max(type_quadratic * voted)
qui bysort voter_space_id: gegen vs_type_ranked = max(type_ranked_choice * voted)
qui bysort voter_space_id: gegen vs_type_single = max(type_single_choice * voted)
qui bysort voter_space_id: gegen vs_type_weighted = max(type_weighted * voted)

qui gen vs_types = vs_type_app + vs_type_basic + ///
    vs_type_quad + vs_type_ranked + vs_type_single + vs_type_weighted

* Drop temporary variables
qui drop vs_type_app vs_type_basic vs_type_quad vs_type_ranked ///
    vs_type_single vs_type_weighted

* Calculate days since last vote overall
bysort voter_id: egen voter_first_vote = min(vote_date)
gen voter_tenure_all = vote_date - voter_first_vote

bysort voter_id (vote_datetime): gen times_voted_all_cum = sum(voted)
bysort voter_id (vote_datetime): gen diff_days_last_proposal_all = vote_date - vote_date[_n-1]
bysort voter_id (vote_datetime): gen lag_times_voted_all_cum = times_voted_all_cum[_n-1]
bysort voter_id lag_times_voted_all_cum (vote_datetime): gen diff_days_last_vote_all = sum(diff_days_last_proposal_all)

* Calculate presence in other organizations
bysort voter_id space_id (vote_datetime): gen voter_space_dummy = 1 if _n == 1
bysort voter_id (vote_datetime space_id): gen voter_space_counter = sum(voter_space_dummy)

* Drop temporary variables
drop voter_space_dummy voter_first_vote vote_date

*------------------------------------------------------*
* 8. Label Variables and Save Final Dataset
*------------------------------------------------------*

* Order data and compress
order space_id voter_id vote_datetime
compress

* Label variables
label variable space_id "Space ID"
label variable voter_id "Voter ID"
label variable voted "Voted"
label variable proposal_space_counter "Proposal Space Counter"
label variable misaligned "Misaligned"
label variable misaligned_c "Misaligned (Weighted)"
label variable prps_rel_quorum "Proposal Quorum"
label variable prps_choices_bin "Proposal Choices (Binary)"
label variable prps_choices "Proposal Choices"
label variable prps_len "Proposal Length"
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
label variable year "Year"
label variable year_month_num "Year-Month Number"
label variable type_numeric "Type Numeric"
label variable type_approval "Approval"
label variable type_basic "Basic"
label variable type_quadratic "Quadratic"
label variable type_ranked_choice "Ranked Choice"
label variable type_single_choice "Single Choice"
label variable type_weighted "Weighted"
label variable misaligned_wmiss "Misaligned with Missing"
label variable mal_c_wmiss "Misaligned (Weighted) with Missing"
label variable voter_tenure_space "Voter Tenure in Space"
label variable votes_dao_cum "Cumulative Votes in DAO"
label variable votes_proposal_cum "Cumulative Votes on Proposal"
label variable prps_part_rate "Proposal Participation Rate"
label variable prps_misalign "Proposal Misalignment"
label variable voter_space_prps_counter "Voter Space Proposal Counter"
label variable relative_voting_power_pot "Relative Voting Power (Potential)"
label variable relative_voting_power_act "Relative Voting Power (Actual)"
label variable voting_1m "Voting in Next 1 Month"
label variable voting_3m "Voting in Next 3 Months"
label variable voting_6m "Voting in Next 6 Months"
label variable end_1m "End in Next 1 Month"
label variable end_3m "End in Next 3 Months"
label variable end_6m "End in Next 6 Months"
label variable voter_space_id "Voter Space ID"
label variable proposal_id "Proposal ID"
label variable proposal_space_id "Proposal Space ID"
label variable space_id_size "Space ID Size"
label variable voter_tenure_all "Voter Tenure (All)"
label variable times_voted_all_cum "Cumulative Times Voted (All)"
label variable diff_days_last_proposal_all "Days Since Last Proposal (All)"
label variable diff_days_last_vote_all "Days Since Last Vote (All)"
label variable voter_space_counter "Voter Space Counter"
label variable plugin_safesnap "Safesnap On-chain"
label variable strategy_delegation "Strategy Delegation"

* Save the final dataset
save "$dao_folder/processed/panel_full.dta", replace

/***************************************************************************
SECTION 9: FOCAL VS. NEVER-ADOPT LOGIC (lines ~1–90 integrated)
   - We loop over multiple advanced types
   - For each focalType:
     (a) classify DAOs as 0=never adopt, 1=focal only
     (b) earliest usage => dao_treatment_time_all
     (c) collapse to monthly
     (d) save a new "did_ready_focalType" dataset
***************************************************************************/

* 1) Reload the newly created panel_full
use "$dao_folder/processed/panel_full.dta", clear

* Optionally define a local with your advanced voting types
local allFocals "type_quadratic type_weighted type_ranked_choice type_approval type_basic"

foreach focalType of local allFocals {

    di "--------------------------------------------------------"
    di " Now preparing monthly-collapsed data for `focalType' "
    di "--------------------------------------------------------"

    * Preserve so we can revert after each focal
    preserve

    /*
      (A) Mark row_focal=1 for the current advanced type
          leftover advanced is all other advanced, so row_other=1 if any leftover is 1
    */
    gen row_focal = (`focalType' == 1)

    // Build local expr for row_other = any advanced except focal
    local allAlts "type_approval type_basic type_quadratic type_ranked_choice type_weighted"
    local otherList ""
    foreach alt of local allAlts {
        if "`alt'" != "`focalType'" {
            local otherList "`otherList' `alt'"
        }
    }

    local expr "0"
    foreach o of local otherList {
        local expr "`expr' | `o'==1"
    }
    gen row_other = 0
    replace row_other=1 if (`expr')

    /*
      (B) dao_category = 0/1/2/3
         0 => never adopt advanced
         1 => adopt this focal only
         2 => adopt some other advanced only
         3 => adopt both focal and other
    */
    bysort space_id: egen ever_focal = max(row_focal)
    bysort space_id: egen ever_other = max(row_other)

    gen dao_category = .
    replace dao_category=0 if ever_focal==0 & ever_other==0
    replace dao_category=1 if ever_focal==1  & ever_other==0
    replace dao_category=2 if ever_focal==0 & ever_other==1
    replace dao_category=3 if ever_focal==1  & ever_other==1

    count if dao_category==1
    if (r(N)==0) {
       di as error "No DAOs in dao_category=1 => skipping `focalType'"
       restore
       continue
    }

    * Keep only never(0) or adopt-focal(1)
    keep if inlist(dao_category,0,1)
    drop row_focal row_other ever_focal ever_other

    /*
      (C) earliest usage => dao_treatment_time_all
    */
    gen row_focal2 = (`focalType' == 1)
    bysort space_id year_month_num: egen monthly_focal = max(row_focal2)
    bysort space_id (year_month_num): gen dao_treatment_time = (monthly_focal==1)*year_month_num

    bysort space_id (dao_treatment_time): gen first_treat=dao_treatment_time if dao_treatment_time>0
    bysort space_id: egen final_treat=min(first_treat)
    drop dao_treatment_time first_treat monthly_focal row_focal2

    bysort space_id: gen dao_treatment_time_all=final_treat[1]
    drop final_treat

    /*
      (D) collapse monthly
    */
    collapse (mean) voted voter_tenure_space times_voted_space_cum relative_voting_power_act ///
             prps_len prps_choices met_quorum misaligned_c ///
             (min) dao_treatment_time_all (max) dao_category,
             by(voter_id space_id year_month_num)

    egen panel_id=group(voter_id space_id)
    gen time=year_month_num
    isid panel_id time
    xtset panel_id time

    /*
      Example: generate event_time or do other transformations
      (You can add lag variables here if you want, but typically
       you might do that in your csdid file.)
    */
    gen event_time = time - dao_treatment_time_all if dao_treatment_time_all<.
    gen treatment = (event_time>=0 & event_time!=.)

    /*
      (E) Save a new dataset for `focalType'
          e.g. panel_ + name
    */
    save "$dao_folder/processed/panel_`focalType'_didready.dta", replace

    di "Created monthly-collapsed file for `focalType': panel_`focalType'_didready.dta"

    restore
}

di "All focal vs. never prep done. You have didready sets per focal type!"

*------------------------------------------------------*
* 10. End of Script and Clean Up
*------------------------------------------------------*

* Store the end time for the entire process
scalar end_time = c(current_time)

display (clock(end_time, "hms") - clock(start_time_v2, "hms")) / 1000 " seconds"

translate "$dao_folder/logs/`start_time_string'_data_prep_iter.smcl" ///
	"$dao_folder/logs/`start_time_string'_data_prep_iter.log", replace linesize(150)
log close

*/


/*
End of script.
*/

/*
global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data" // change with whatever path
*------------------------------------------------------*
* Data Preparation Script for DAO Analysis
*------------------------------------------------------*

* Set seed for reproducibility
set seed 8472

* Clear existing data and settings
clear all
set more off

*------------------------------------------------------*
* 1. Initialize and Set Up Log File
*------------------------------------------------------*

* Capture the current date and time
local date: display %td_CCYY_NN_DD date(c(current_date), "DMY")
local date_string = subinstr(trim("`date'"), " " , "-", .)
local start_time: display %tCCCYY-NN-DD-HH-MM-SS Clock("`c(current_date)' `c(current_time)'","DMYhms")
local start_time_string = subinstr(trim("`start_time'"), " " , "-", .)
scalar start_time_v2 = c(current_time)

* Set up the log file
capture log close
log using "$dao_folder/logs/`start_time_string'_data_prep_iter.smcl"
set linesize 200

*------------------------------------------------------*
* 2. Load DAO Names and Initialize Loop
*------------------------------------------------------*

* Load the master list containing DAO names
import delimited "$dao_folder/input/verified-spaces.csv", varnames(1) clear 

* Extract DAO names into a local macro
levelsof space_name, local(daos)
local j = r(r)
local i = 1

*------------------------------------------------------*
* 3. Loop Through Each DAO and Process Data
*------------------------------------------------------*

foreach dao in `daos' {
    * Start time for the loop
    scalar loop_start = c(current_time)
    local filepath = "$dao_folder/input/dao/data_`dao'.csv"
    
    * Import the specific dataset for this DAO
    capture confirm file "`filepath'"
    if c(rc) {
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
    
    *--------------------------------------------------*
    * 3.1. Data Cleaning and Variable Preparation
    *--------------------------------------------------*
    
    * Drop observations without winning choices
    tab space if winning_choices == ""
    drop if winning_choices == ""
    
    *--------------------------------------------------*
    * 3.2. Convert Date Strings to Numeric Formats
    *--------------------------------------------------*
    
    * Convert vote date and time
    qui gen vote_datetime = clock(vote_created, "YMDhms")
    qui gen vote_date = date(vote_created, "YMDhms")
    qui format vote_datetime %tc
    qui format vote_date %td
    qui drop vote_created

    * Convert DAO creation date
    qui gen dao_creation_date = date(space_created_at, "YMDhms")
    qui format dao_creation_date %td

    * Convert proposal start and end dates
    qui gen proposal_start_datetime = clock(prps_start, "YMDhms")
    qui format proposal_start_datetime %tc
    qui gen proposal_end_datetime = clock(prps_end, "YMDhms")
    qui gen proposal_end_date = date(prps_end, "YMDhms")
    qui format proposal_end_datetime %tc
    qui format proposal_end_date %td

    * Calculate voting period length
    qui gen voting_period_length = proposal_end_datetime - proposal_start_datetime

    * Drop redundant date variables
    qui drop prps_start prps_end prps_created space_created_at 

    * Generate month and year variables
    qui gen month = month(vote_date)
    qui gen year = year(vote_date)
    qui gen year_month_num  = ym(year, month)
    qui gen dummy = 1

    *--------------------------------------------------*
    * 3.3. Create Numeric IDs and Group Variables
    *--------------------------------------------------*

    * Create voter ID
    qui gegen voter_id = group(voter)
    qui sort voter voter_id
    qui order voter voter_id
    
    * Create space ID
    qui egen space_id = group(space), label

    * Create proposal ID
    qui sort proposal proposal_start_datetime
    qui gegen proposal_id = group(proposal)

    * Create proposal-space ID
    qui gegen proposal_space_id = group(space proposal_id)

    * Sort and order data
    qui sort space_id proposal_start_datetime proposal_space_id voter_id
    qui order space_id proposal_start_datetime proposal_space_id voter_id proposal_id

    *--------------------------------------------------*
    * 3.4. Calculate Relative Quorum
    *--------------------------------------------------*

    * Calculate highest scores per space
    egen space_high_scores = record(scores_total), by(space_id) order(proposal_start_date)
    qui gen prps_rel_quorum = quorum / space_high_scores
    qui gen prps_quorum_bin = 0
    replace prps_quorum_bin = 1 if quorum > 0 & quorum != .
    drop quorum

    *--------------------------------------------------*
    * 3.5. Create Proposal Counter
    *--------------------------------------------------*

    * Generate proposal counter within space
    qui bysort space_id proposal_id (proposal_start_datetime): gen proposal_space_dummy = 1 if _n == 1
    qui bysort space_id (proposal_start_datetime proposal_id proposal_space_dummy): ///
        gen proposal_space_counter_d = sum(proposal_space_dummy) if proposal_space_dummy == 1
    qui bysort proposal_id: egen proposal_space_counter = min(proposal_space_counter_d)
    qui drop proposal_space_dummy proposal_space_counter_d

    *--------------------------------------------------*
    * 3.6. Handle Duplicates
    *--------------------------------------------------*

    * Check for duplicates and drop them
    duplicates report voter proposal_id
    duplicates drop voter proposal_id, force

    * Create voter-space ID
    qui gegen voter_space_id = group(voter_id space_id)

    *--------------------------------------------------*
    * 3.7. Convert String Variables to Numeric Dummies
    *--------------------------------------------------*

    * Drop unnecessary variables
    qui drop choice

    * Initialize type_numeric
    qui gen type_numeric = 0

    * Create voting type dummies
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

    * Rename votes variable
    qui rename votes total_votes

    * Adjust proposal choices for basic type
    qui replace prps_choices = 2 if prps_choices == 3 & type_basic == 1

    * Binarize proposal choices
    gen prps_choices_bin = 0
    replace prps_choices_bin = 1 if prps_choices > 2

    * Handle misaligned cases
    qui replace misaligned = 1 if not_determined == 1 & type_basic == 1
    qui replace misaligned_c = 0.5 if not_determined == 1 & type_basic == 1

    * Drop unnecessary variables
    qui drop type dummy prps_author not_determined

    *--------------------------------------------------*
    * 3.8. Tag and Handle Duplicate Proposals
    *--------------------------------------------------*

    * Tag duplicates for tsfill
    duplicates tag voter_space_id proposal_space_counter, gen(tsfill_tag)
    tab tsfill_tag
    drop tsfill_tag

    * Sort data
    qui sort space_id proposal_space_counter voter_space_id voter_id proposal_start_datetime
    qui order space_id proposal_space_counter voter_space_id voter_id proposal_start_datetime proposal_space_id

    *--------------------------------------------------*
    * 3.9. Expand Data to Include Non-Voting Instances
    *--------------------------------------------------*

    * Generate voted indicator
    qui gen voted = 1

    * Identify last proposal in space and last voter instance
    qui bysort space_id (proposal_space_counter): gegen last_proposal_space = max(proposal_space_counter)
    qui bysort voter_space_id (proposal_space_counter): gen last_voter_space = 1 if _n == _N

    * Sort and order data
    qui sort voter_space_id proposal_space_counter
    qui order voter_space_id proposal_space_counter last_proposal_space last_voter_space

    * Expand data to include non-voting instances
    expand 2 if last_voter_space == 1, generate(newv)

    * Delete voting information for new observations
    foreach v of varlist misaligned misaligned_c ///
        vote_datetime vote_date voted proposal_start_date ///
        proposal_id proposal_space_id voting_power  ///
        prps_rel_quorum prps_quorum_bin scores_total total_votes prps_len prps_link ///
        prps_stub topic_0 topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 ///
        topic_7 topic_8 topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 ///
        topic_15 topic_16 topic_17 topic_18 topic_19 ///
        vote_datetime prps_choices_bin prps_choices met_quorum own_choice_tied ///
        vote_date dao_creation_date proposal_end_datetime proposal_end_date ///
        voting_period_length month year year_month_num type_numeric ///
        type_approval type_basic type_quadratic type_ranked_choice ///
        type_single_choice type_weighted  {
        qui replace `v' = . if newv == 1 
    }

    foreach v of varlist voter proposal {
        qui replace `v' = "" if newv == 1 
    }

    * Update last_voter_space indicator
    qui drop last_voter_space
    qui bysort voter_space_id (proposal_space_counter newv): gen last_voter_space = 1 if _n == _N
    qui order voter_space_id proposal_space_counter last_proposal_space last_voter_space newv
    qui replace proposal_space_counter = last_proposal_space if last_voter_space == 1

    * Remove duplicates
    qui duplicates tag voter_space_id proposal_space_counter, gen(already_voting_last_proposal)
    qui drop if already_voting_last_proposal == 1 & newv == 1

    *--------------------------------------------------*
    * 3.10. Set Time-Series Structure and Fill Data
    *--------------------------------------------------*

    * Set time-series structure
    tsset voter_space_id proposal_space_counter

    * Handle large datasets (e.g., cakevote.eth)
    if space == "cakevote.eth" {
        gen dummy = 1
        by voter_id, sort: egen voter_total = total(dummy)
        by voter_id, sort: gen voter_first = 1 if _n == 1
        sum voter_total if voter_first == 1, detail
        by proposal_id, sort: egen proposal_total = total(dummy)
        by proposal_id, sort: gen proposal_first = 1 if _n == 1
        sum proposal_total if proposal_first == 1, detail
        drop if proposal_total > 8000
        drop if voter_total <= 4
        drop if proposal_total <= 10 
        drop dummy voter_total voter_first proposal_total proposal_first 
    }

    * Drop temporary variables
    qui drop newv last_voter_space already_voting_last_proposal proposal_start_datetime

    * Display number of voters
    qui sum voter_id, detail
    display "Number of voters:"
    display r(max)

    * Fill in missing values
    tsfill

    * Replace missing values with appropriate defaults
    qui replace own_choice_tied = 0  if own_choice_tied == .
    qui replace voted = 0 if voted == .
    qui gen misaligned_wmiss = misaligned
    qui replace misaligned_wmiss = 0 if misaligned_wmiss == .
    qui gen mal_c_wmiss = misaligned_c
    qui replace mal_c_wmiss = 0 if mal_c_wmiss == .    
    qui gen dummy = 1

    *--------------------------------------------------*
    * 3.11. Data Cleaning and Handling Missing Data
    *--------------------------------------------------*

    * Clean up data for misaligned cases
    qui replace misaligned = . if prps_choices == 1
    qui replace misaligned_wmiss = . if prps_choices == 1
    qui replace misaligned = . if met_quorum == 0
    qui replace misaligned_wmiss = . if met_quorum == 0

    *--------------------------------------------------*
    * 3.12. Copy Values to Newly Created Observations
    *--------------------------------------------------*

    * Sort data
    qui sort voter_space_id voter_id

    * Fill in constants within voter_space_id
    foreach x of varlist voter_id space_id voting_power {
        qui bysort voter_space_id (`x'): replace `x' = `x'[1] if `x' == .
    }

    foreach x of varlist voter {
        qui gsort voter_id -`x'
        qui by voter_id: replace `x' = `x'[1] if `x' == ""
    }

    * Fill in constants within DAO
    foreach x of varlist dao_creation_date last_proposal_space {
        bysort space_id (`x'): replace `x' = `x'[1] if `x' == .
    }

    * Fill in space names
    foreach x of varlist space {
        qui gsort space_id -`x'
        qui by space_id: replace `x' = `x'[1] if `x' == ""
    }

    * Fill in proposal IDs
    foreach x of varlist proposal_id {
        qui bysort space_id proposal_space_counter (`x'): replace `x' = `x'[1] if `x' == .
    }

    foreach x of varlist proposal {
        qui gsort proposal_id -`x'
        qui by proposal_id: replace `x' = `x'[1] if `x' == ""
    }

    * Drop observations without proposal IDs
    qui drop if proposal_id == .

    *--------------------------------------------------*
    * 3.13. Fill in Missing Values Based on Proposals
    *--------------------------------------------------*

    * Fill in proposal-related variables
    foreach x of varlist proposal_space_id scores_total total_votes type_approval type_basic met_quorum ///
        type_quadratic type_ranked_choice type_single_choice type_weighted ///
        year month year_month_num type_numeric proposal_end_datetime ///
        proposal_end_date topic_0 topic_1 topic_2 topic_3 prps_choices_bin prps_choices prps_len ///
        voting_period_length prps_link prps_stub prps_rel_quorum prps_quorum_bin ///
        topic_4 topic_5 topic_6 topic_7 topic_8 topic_9 topic_10 topic_11 ///
        topic_12 topic_13 topic_14 topic_15 topic_16 topic_17 topic_18 topic_19 {
        qui bysort proposal_id (`x'): replace `x' = `x'[1] if `x' == .
    }

    * Adjust vote dates if missing
    qui replace vote_datetime = proposal_end_datetime if vote_datetime == .
    qui replace vote_date = proposal_end_date if vote_date == .

    *--------------------------------------------------*
    * 3.14. Calculate Voting and Participation Metrics
    *--------------------------------------------------*

    * Calculate cumulative votes within space
    qui bysort voter_space_id (vote_datetime): gen times_voted_space_cum = sum(voted)
    qui bysort voter_space_id: gegen max_times_voted_space = max(times_voted_space_cum)

    * Determine if voter is active
    qui gen voter_active = 0
    qui replace voter_active = 1 if times_voted_space_cum < max_times_voted_space 
    qui replace voter_active = 1 if voted == 1

    * Identify last voter in space
    qui gen last_voter_space = 0
    qui replace last_voter_space = 1 if proposal_space_counter == last_proposal_space
    qui drop last_proposal_space

    * Drop voters who never voted before in DAO
    qui drop if times_voted_space_cum == 0

    *--------------------------------------------------*
    * 3.15. Calculate Time Since Last Vote
    *--------------------------------------------------*

    * Calculate days since last proposal in space
    qui bysort voter_space_id (vote_datetime): gen diff_days_last_proposal_space = vote_date - vote_date[_n-1]
    qui sort voter_id voter_space_id vote_datetime

    * Calculate cumulative time since last vote in space
    qui bysort voter_space_id (vote_datetime): gen lag_times_votes_space_cum = times_voted_space_cum[_n-1]
    qui bysort voter_space_id lag_times_votes_space_cum (vote_datetime): gen diff_days_last_vote_space = sum(diff_days_last_proposal_space)

    * Order data
    qui sort voter_id voter_space_id vote_datetime
    qui order voter_id voter_space_id voted vote_date vote_datetime ///
        diff_days_last_proposal_space lag_times_votes_space_cum ///
        lag_times_votes_space_cum diff_days_last_vote

    *--------------------------------------------------*
    * 3.16. Calculate Voter Tenure and DAO Age
    *--------------------------------------------------*

    * Calculate voter's first vote date in space
    qui bysort voter_space_id: egen voter_space_first_vote = min(vote_date)
    qui gen voter_tenure_space = vote_date - voter_space_first_vote
    drop voter_space_first_vote

    * Calculate DAO age at the time of vote
    qui gen space_age = vote_date - dao_creation_date

    * Calculate cumulative votes in DAO
    qui bysort space_id (vote_datetime): gen votes_dao_cum = sum(voted)

    *--------------------------------------------------*
    * 3.17. Calculate Proposal Participation Metrics
    *--------------------------------------------------*

    * Calculate cumulative votes on proposal
    qui bysort proposal_id (vote_datetime): gen votes_proposal_cum = sum(voted)
    qui bysort proposal_id: gegen proposal_active_voters = total(voter_active)
    qui bysort proposal_id: gegen proposal_total_voted = total(voted)
    qui gen prps_part_rate = proposal_total_voted / proposal_active_voters

    * Calculate proposal misalignment
    qui bysort proposal_id: gegen proposal_total_misalign = total(misaligned)
    qui gen prps_misalign = proposal_total_misalign / proposal_total_voted
    qui drop proposal_total_misalign

    * Count proposals per voter in space
    qui bysort voter_space_id (vote_datetime): gen voter_space_prps_counter = sum(dummy)

    *--------------------------------------------------*
    * 3.18. Calculate Voting Power Metrics
    *--------------------------------------------------*

    * Calculate active voting power
    qui gen active_vp = voting_power * voter_active
    qui bysort proposal_id: gegen prps_total_vp = total(active_vp)
    qui gen relative_voting_power_pot = voting_power / prps_total_vp
    qui gen relative_voting_power_act = voting_power / scores_total
    qui replace relative_voting_power_act = 1 if relative_voting_power_act > 1
    qui drop prps_total_vp

    *--------------------------------------------------*
    * 3.19. Calculate Future Voting Behavior
    *--------------------------------------------------*

    * Voting in next 1, 3, and 6 months
    qui rangestat (mean) voting_1m = voted, interval(vote_datetime 0 2.59e09) by(voter_space_id) excludeself
    qui rangestat (mean) voting_3m = voted, interval(vote_datetime 0 7.78e09) by(voter_space_id) excludeself
    qui rangestat (mean) voting_6m = voted, interval(vote_datetime 0 1.56e10) by(voter_space_id) excludeself

    * End of period indicators
    qui rangestat (max) end_1m = last_voter_space, interval(vote_datetime 0 2.59e09) by(voter_space_id) excludeself
    qui rangestat (max) end_3m = last_voter_space, interval(vote_datetime 0 7.78e09) by(voter_space_id) excludeself
    qui rangestat (max) end_6m = last_voter_space, interval(vote_datetime 0 1.56e10) by(voter_space_id) excludeself

    * Drop temporary variables
    drop dummy last_voter_space

    * Compress data
    qui compress

    *--------------------------------------------------*
    * 3.20. Drop IDs
    *--------------------------------------------------*

    drop voter_id
    drop space_id
    drop proposal_id
    drop voter_space_id
    drop proposal_space_id
	
    *--------------------------------------------------*
    * 3.21. End of Loop and Save Processed Data
    *--------------------------------------------------*

    * End time for the loop
    scalar loop_end = c(current_time)
       
    * Display the time taken for the loop in seconds
    display (clock(loop_end, "hms") - clock(loop_start, "hms")) / 1000 " seconds"
    scalar end_time = c(current_time)

    * Display cumulative time
    display (clock(end_time, "hms") - clock(start_time_v2, "hms")) / 1000 " seconds"                             

    * Save the processed data for the DAO
    save "$dao_folder/processed/dao/panel_`dao'.dta", replace
}

*------------------------------------------------------*
* 4. End of DAO Loop
*------------------------------------------------------*

display "End"

*------------------------------------------------------*
* 5. Append All DAO Data Files
*------------------------------------------------------*

* Load the first DAO data file
use "$dao_folder/processed/dao/panel_0xgov.eth.dta", clear

foreach dao in `daos' {
    if "`dao'" == "0xgov.eth" {
        display "First one skipped (already loaded)"
        continue
    }

    * Construct the filename based on the DAO name
    local filepath = "$dao_folder/processed/dao/panel_`dao'.dta"

    * Check if the file exists and append if it does
    capture confirm file "`filepath'"
    if c(rc) {
        di "`filepath' does not exist. Skipping..."
    }
    else {
        di "Appending `filepath'"
        append using "`filepath'"
    }
}

*------------------------------------------------------*
* 6. Recreate IDs and Variables
*------------------------------------------------------*

* Drop existing ID variables to avoid conflicts
drop voter_id
drop space_id
drop voter_space_id
drop proposal_id
drop proposal_space_id

* Recreate voter IDs and drop original variable
gegen voter_id = group(voter)
drop voter

* Recreate space IDs and drop original variable
egen space_id = group(space)
drop space

* Create voter-space ID
gegen voter_space_id = group(voter_id space_id)

* Recreate proposal IDs and drop original variable
gegen proposal_id = group(proposal)
drop proposal

* Create proposal-space ID
gegen proposal_space_id = group(space_id proposal_id)

*------------------------------------------------------*
* 7. Label Variables and Save Final Dataset
*------------------------------------------------------*

* (Variable labels are retained from your original code)
* You can add or adjust labels as needed

* Save the final dataset
save "$dao_folder/processed/panel_almost_full.dta", replace

*------------------------------------------------------*
* 8. End of Script and Clean Up
*------------------------------------------------------*

* Store the end time for the entire process
scalar end_time = c(current_time)

* Display total time taken
display "Total time taken: " ///
    (clock(end_time, "hms") - clock(start_time_v2, "hms")) / 1000 " seconds"

* Convert log file to .log format
translate "$dao_folder/logs/`start_time_string'_data_prep_iter.smcl" ///
    "$dao_folder/logs/`start_time_string'_data_prep_iter.log", replace linesize(150)

* Close the log
log close

/* batches

* (Re)Define the global macro for the data folder if not already defined
global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data"

* Load the list of DAO names from the CSV file using the full path
import delimited "$dao_folder/input/verified-spaces.csv", varnames(1) clear
levelsof space_name, local(daos)

* Start with the first DAO file as the base dataset
use "$dao_folder/processed/dao/panel_0xgov.eth.dta", clear

* Set up counters for batch size and batches
local batch_size 50
local batch 1
local file_counter 1

* Loop through each DAO in the list, skipping the initial base file (0xgov.eth)
foreach dao in `daos' {

    * Skip the base file
    if "`dao'" == "0xgov.eth" {
        display "Skipping the initial file"
        continue
    }

    * Set the file path for the current DAO
    local filepath "$dao_folder/processed/dao/panel_`dao'.dta"

    * Check if the file exists, and if so, append it
    capture confirm file "`filepath'"
    if c(rc) {
        display "`filepath' does not exist. Skipping..."
    }
    else {
        display "Appending `filepath'"
        append using "`filepath'"

        * Increase the file counter after appending
        local file_counter = `file_counter' + 1
    }

    * If we've appended 50 files, save the batch and reset
    if `file_counter' > `batch_size' {
        * Save the current batch
        save "$dao_folder/processed/panel_full_batch_`batch'.dta", replace
        display "Batch `batch' saved."

        * Prepare for the next batch
        local batch = `batch' + 1
        local file_counter = 1

        * Reload the current file as the new base for the next batch
        clear
        use "`filepath'", clear
    }
}



*/

/* all

*------------------------------------------------------*
* 5. Append All DAO Data Files
*------------------------------------------------------*

* Load the first DAO data file
use "$dao_folder/processed/dao/panel_0xgov.eth.dta", clear

foreach dao in `daos' {
    if "`dao'" == "0xgov.eth" {
        display "First one skipped (already loaded)"
        continue
    }

    * Construct the filename based on the DAO name
    local filepath = "$dao_folder/processed/dao/panel_`dao'.dta"

    * Append the specific dataset for this DAO
    capture confirm file "`filepath'"
    if c(rc) {
        di "`filepath' does not exist. Skipping..."
    }
    else {
        di "Appending `filepath'"
        append using "`filepath'"
    }
}

*save "$dao_folder/processed/panel_full.dta", replace

*--------------------------------------------------*
* 6.1. Recreate IDs and Variables
*--------------------------------------------------*

* Drop existing ID variables to avoid conflicts
drop voter_id
drop space_id
drop voter_space_id
drop proposal_id
drop proposal_space_id

* Recreate voter IDs and drop original variable
gegen voter_id = group(voter)
drop voter

* Recreate space IDs and drop original variable
egen space_id = group(space)
drop space

* Create voter-space ID
gegen voter_space_id = group(voter_id space_id)

* Recreate proposal IDs and drop original variable
gegen proposal_id = group(proposal)
drop proposal

* Create proposal-space ID
gegen proposal_space_id = group(space_id proposal_id)

* Create voter-proposal ID
gegen voter_space_id = group(voter_id proposal_id)

*--------------------------------------------------*
* 6.2. Calculate Space Size
*--------------------------------------------------*

* Calculate space size based on occurrence
gen dummy = 1
bysort space_id: egen space_occ = total(dummy)
bysort space_id: gen first_space = _n == 1
bysort first_space (space_occ): gen spc2_id = sum(dummy) if first_space == 1
bysort space_id: egen space_id_size = min(spc2_id)

tab space_id_size
drop spc2_id space_occ

*--------------------------------------------------*
* 6.3. Calculate Relative Own Score
*--------------------------------------------------*

gen rel_own_score = 0
replace rel_own_score = own_score / winning_score if misaligned == 1 & voted == 1
replace rel_own_score = own_score / second_score if misaligned == 0 & voted == 1 

drop winning_score second_score own_score

*--------------------------------------------------*
* 6.4. Calculate Voting Types per Space and Voter
*--------------------------------------------------*

* Calculate voting types per space
qui bysort space_id: gegen space_type_app = max(type_approval)
qui bysort space_id: gegen space_type_basic = max(type_basic)
qui bysort space_id: gegen space_type_quad = max(type_quadratic)
qui bysort space_id: gegen space_type_ranked = max(type_ranked_choice)
qui bysort space_id: gegen space_type_single = max(type_single_choice)
qui bysort space_id: gegen space_type_weighted = max(type_weighted)

qui gen space_no_vot_types = space_type_app + space_type_basic + ///
    space_type_quad + space_type_ranked + space_type_single + space_type_weighted

* Drop temporary variables
qui drop space_type_app space_type_basic space_type_quad space_type_ranked ///
    space_type_single space_type_weighted

* Calculate voting types per voter
qui bysort voter_space_id: gegen vs_type_app = max(type_approval * voted)
qui bysort voter_space_id: gegen vs_type_basic = max(type_basic * voted)
qui bysort voter_space_id: gegen vs_type_quad = max(type_quadratic * voted)
qui bysort voter_space_id: gegen vs_type_ranked = max(type_ranked_choice * voted)
qui bysort voter_space_id: gegen vs_type_single = max(type_single_choice * voted)
qui bysort voter_space_id: gegen vs_type_weighted = max(type_weighted * voted)

qui gen vs_types = vs_type_app + vs_type_basic + ///
    vs_type_quad + vs_type_ranked + vs_type_single + vs_type_weighted

* Drop temporary variables
qui drop vs_type_app vs_type_basic vs_type_quad vs_type_ranked ///
    vs_type_single vs_type_weighted

*--------------------------------------------------*
* 6.5. Calculate Voter Tenure and Voting Metrics
*--------------------------------------------------*

* Calculate voter's first vote date
bysort voter_id: egen voter_first_vote = min(vote_date)
gen voter_tenure_all = vote_date - voter_first_vote

* Calculate cumulative votes and time since last vote
bysort voter_id (vote_datetime): gen times_voted_all_cum = sum(voted)
bysort voter_id (vote_datetime): gen diff_days_last_proposal_all = vote_date - vote_date[_n-1]
bysort voter_id (vote_datetime): gen lag_times_voted_all_cum = times_voted_all_cum[_n-1]
bysort voter_id lag_times_voted_all_cum (vote_datetime): gen diff_days_last_vote_all = sum(diff_days_last_proposal_all)

*--------------------------------------------------*
* 6.6. Calculate Presence in Other Organizations
*--------------------------------------------------*

* Calculate voter-space counter
bysort voter_id space_id (vote_datetime): gen voter_space_dummy = 1 if _n == 1
bysort voter_id (vote_datetime space_id): gen voter_space_counter = sum(voter_space_dummy)

* Drop temporary variables
drop voter_space_dummy
* Do not drop vote_date and vote_datetime
* drop voter_first_vote vote_date vote_datetime

* Order data and compress
order space_id voter_id vote_date
compress

*------------------------------------------------------*
* 7. Label Variables and Save Final Dataset
*------------------------------------------------------*

* (Variable labels are retained from your original code)

* Save the final dataset
save "$dao_folder/processed/panel_full.dta"

*------------------------------------------------------*
* 8. End of Script and Clean Up
*------------------------------------------------------*

* Store the end time for the entire process
scalar end_time = c(current_time)

* Display total time taken
display (clock(end_time, "hms") - clock(start_time_v2, "hms")) / 1000 " seconds"

* Convert log file to .log format
translate "$dao_folder/logs/`start_time_string'_data_prep_iter.smcl" ///
    "$dao_folder/logs/`start_time_string'_data_prep_iter.log", replace linesize(150)

* Close the log
log close

*------------------------------------------------------*
* Additional Comments and Unorganized Code (if any)
*------------------------------------------------------*



/*

End of script.
*/

*/

/* chunks

*------------------------------------------------------*
* Initialize Environment and Load Required Macros
*------------------------------------------------------*

* Set up the global variable for the data folder
global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data"

* Clear existing data and settings
clear all
set more off

* Load the master list containing DAO names
import delimited "$dao_folder/input/verified-spaces.csv", varnames(1) clear

* Extract DAO names into a local macro
levelsof space_name, local(daos)


*------------------------------------------------------*
* 5. Process DAO Data Files and Save by 6-Month Chunks *
*------------------------------------------------------*

* (Re)Define the global macro for the data folder if not already defined
global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data"

* Import DAO names to redefine 'daos' macro
import delimited "$dao_folder/input/verified-spaces.csv", varnames(1) clear 
levelsof space_name, local(daos)

* Create a folder for processed data if it doesn't exist
capture mkdir "$dao_folder/processed"

* Define the chunk boundaries based on 'year_month_num'
* Data spans from July 2020 (ym(2020,7)) to August 2023 (ym(2023,8))

* Calculate the minimum and maximum 'year_month_num'
local min_ymn = `= ym(2020, 7)'
local max_ymn = `= ym(2023, 8)'

* Display the calculated min and max year_month_num
display "Minimum year_month_num: `min_ymn'"
display "Maximum year_month_num: `max_ymn'"

* Define chunk size (6 months)
local chunk_size = 6

* Calculate the number of chunks
local num_chunks = `= ceil((`max_ymn' - `min_ymn' + 1) / `chunk_size')'

* Display the number of chunks
display "Number of chunks: `num_chunks'"

* Initialize chunks macro
local chunks

forvalues c = 1/`num_chunks' {
    local start_ymn = `= `min_ymn' + (`c' - 1) * `chunk_size''
    local end_ymn = `= `min_ymn' + `c' * `chunk_size' - 1'
    if `end_ymn' > `max_ymn' {
        local end_ymn = `max_ymn'
    }
    local chunk_start`c' = `start_ymn'
    local chunk_end`c' = `end_ymn'
    local chunks "`chunks' `c'"
}

* Display the chunk ranges for verification
display "Chunk ranges:"
foreach c of local chunks {
    display "Chunk `c': `chunk_start`c'' to `chunk_end`c''"
}

*------------------------------------------------------*
* 5.1 Loop over each DAO and process data by chunks
*------------------------------------------------------*

* Loop over each DAO
foreach dao in `daos' {
    di "Processing DAO: `dao'"
    
    * Load the processed data file for the current DAO
    capture confirm file "$dao_folder/processed/dao/panel_`dao'.dta"
    if (_rc != 0) {
        di "Data file for `dao' does not exist. Skipping..."
        continue
    }
    use "$dao_folder/processed/dao/panel_`dao'.dta", clear

    * Loop over each chunk
    foreach c of local chunks {
        * Get the start and end 'year_month_num' for this chunk
        local start_ymn = `chunk_start`c''
        local end_ymn = `chunk_end`c''

        * Preserve the dataset to return to this state after processing
        preserve

        * Keep only observations within this chunk's 'year_month_num' range
        keep if year_month_num >= `start_ymn' & year_month_num <= `end_ymn'

        * If there are no observations, skip to next chunk
        count
        if (r(N) == 0) {
            di "No data for chunk `c' in DAO `dao'. Skipping..."
            restore
            continue
        }

        * Define the file path for the current chunk
        local filepath = "$dao_folder/processed/panel_`c'_chunk_6m.dta"

        * Check if the file for this chunk already exists
        capture confirm file "`filepath'"
        if (_rc == 0) {
            * The file exists, so we'll append to it
            di "Appending to `filepath'"

            * Save the current data to a temporary file
            tempfile tempdata
            save "`tempdata'", replace

            * Load the existing chunk file
            use "`filepath'", clear

            * Append the temporary data to the existing chunk file
            append using "`tempdata'"

            * Save the updated chunk file
            save "`filepath'", replace
        }
        else {
            * The file doesn't exist, so we'll create a new one
            di "Creating new file `filepath'"
            save "`filepath'", replace
        }

        * Restore the dataset to its state before 'preserve'
        restore
    }
}


*------------------------------------------------------*
* 5.2 Process Each Chunk File to Create Additional Variables
*------------------------------------------------------*

* Define the global data folder
global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data"

* Ensure 'rangestat' is installed
cap which rangestat
if _rc {
    ssc install rangestat
}

* Get the list of 6-month chunk files
local chunk_files: dir "$dao_folder/processed/time_chunks/" files "panel_*_chunk_6m.dta"

* Display list of chunk files
display "Processing the following chunk files:"
foreach file of local chunk_files {
    display "`file'"
}

foreach file of local chunk_files {
    display "Processing `file'"

    * Build and display the full file path for debugging
    local filepath "$dao_folder/processed/time_chunks/`file'"
    display "Full file path: `filepath'"

    * Use the chunk file (clearing data each time)
    use "`filepath'", clear 

    *--------------------------------------------------*
    * 6.1. Recreate IDs and Variables
    *--------------------------------------------------*

    * Drop existing ID variables to avoid conflicts
    drop voter_id space_id voter_space_id proposal_id proposal_space_id

    * Recreate voter IDs
    egen voter_id = group(voter)
    drop voter

    * Recreate space IDs
    egen space_id = group(space)
    drop space

    * Create voter-space ID
    egen voter_space_id = group(voter_id space_id)

    * Recreate proposal IDs
    egen proposal_id = group(proposal)
    drop proposal

    * Create proposal-space ID
    egen proposal_space_id = group(space_id proposal_id)

    * Create voter-proposal ID
    egen voter_proposal_id = group(voter_id proposal_id)

    *--------------------------------------------------*
    * Add time variables
    *--------------------------------------------------*

    * Ensure data is sorted by voter_id and vote_date for cumulative counting
    sort voter_id vote_date

    * Generate a cumulative counter of proposals per voter
    by voter_id (vote_date): gen voter_prps_counter = _n
	
	bysort voter_id (vote_datetime): gen time = _n
	
    *--------------------------------------------------*
    * 6.2. Calculate Space Size
    *--------------------------------------------------*

    * Calculate space size based on the number of proposals
    by space_id, sort: gen space_size = _N

    *--------------------------------------------------*
    * 6.3. Calculate Relative Own Score
    *--------------------------------------------------*

    * Assuming 'own_score', 'winning_score', 'second_score', 'misaligned', and 'voted' exist
    gen rel_own_score = .
    replace rel_own_score = own_score / winning_score if misaligned == 1 & voted == 1
    replace rel_own_score = own_score / second_score if misaligned == 0 & voted == 1

    * Drop unnecessary variables
    drop winning_score second_score own_score

    *--------------------------------------------------*
    * 6.4. Calculate Voting Types per Space and Voter
    *--------------------------------------------------*

    * Sort data before using by command
    sort space_id
    foreach vtype in type_approval type_basic type_quadratic type_ranked_choice type_single_choice type_weighted {
        by space_id: egen space_`vtype' = max(`vtype')
    }

    * Count the number of voting types per space
    gen space_no_vot_types = 0
    foreach vtype in type_approval type_basic type_quadratic type_ranked_choice type_single_choice type_weighted {
        replace space_no_vot_types = space_no_vot_types + space_`vtype'
    }

    * Drop temporary variables
    drop space_type_*

    * Sort data before calculating types per voter-space
    sort voter_space_id
    foreach vtype in type_approval type_basic type_quadratic type_ranked_choice type_single_choice type_weighted {
        by voter_space_id: egen vs_`vtype' = max(`vtype' * voted)
    }

    * Count the number of voting types per voter-space
    gen vs_types = 0
    foreach vtype in type_approval type_basic type_quadratic type_ranked_choice type_single_choice type_weighted {
        replace vs_types = vs_types + vs_`vtype'
    }

    * Drop temporary variables
    drop vs_type_*

    *--------------------------------------------------*
    * 6.5. Calculate Voter Tenure and Voting Metrics
    *--------------------------------------------------*

    * Sort data before using by command
    sort voter_id vote_date
    by voter_id (vote_date), sort: gen voter_first_vote = vote_date[1]
    gen voter_tenure_all = vote_date - voter_first_vote

    * Sort data before calculating cumulative votes
    sort voter_id vote_date
    by voter_id (vote_date): gen times_voted_all_cum = _n
    by voter_id: gen diff_days_last_vote_all = vote_date - vote_date[_n-1]
    replace diff_days_last_vote_all = . if _n == 1

    *--------------------------------------------------*
    * 6.6. Calculate Presence in Other Organizations
    *--------------------------------------------------*

    * Sort data before counting unique spaces
    sort voter_id space_id
    by voter_id (space_id), sort: gen space_participation = 1 if _n == 1
    by voter_id: egen voter_space_counter = total(space_participation)
    drop space_participation

    *--------------------------------------------------*
    * 6.7. Calculate Misalignment Over the Last 6 Months
    *--------------------------------------------------*

    * Ensure 'vote_date' is a Stata date variable
    format vote_date %td

    * Sort data
    sort voter_id vote_date

    * Use 'rangestat' to calculate misalignment over past 6 months (approx. 182 days)
    rangestat (sum) misaligned_past6 = misaligned, by(voter_id) interval(vote_date -182 -1)

    * Calculate total votes in the past 6 months
    rangestat (sum) votes_past6 = voted, by(voter_id) interval(vote_date -182 -1)

    * Calculate misalignment rate over the past 6 months
    gen misalignment_rate_past6 = misaligned_past6 / votes_past6
    replace misalignment_rate_past6 = . if votes_past6 == 0

    *--------------------------------------------------*
    * 6.8. Calculate Future Voting Behavior
    *--------------------------------------------------*

    * Sort data before calculating future voting behavior
    sort voter_id space_id vote_date
    by voter_id space_id (vote_date): gen future_vote_in_dao = (_n != _N)

    * Also, count the number of future votes in the DAO
    by voter_id space_id (vote_date): gen future_votes_in_dao = _N - _n

    *--------------------------------------------------*
    * 7. Label Variables and Save Final Dataset
    *--------------------------------------------------*

    * Save the updated chunk data
    save "`filepath'", replace
}

*------------------------------------------------------*
* 8. End of Script and Clean Up
*------------------------------------------------------*

* Store the end time for the entire process
scalar end_time = c(current_time)

* Display total time taken
display (clock(end_time, "hms") - clock(start_time_v2, "hms")) / 1000 " seconds"

* Convert log file to .log format
translate "$dao_folder/logs/`start_time_string'_data_prep_iter.smcl" ///
    "$dao_folder/logs/`start_time_string'_data_prep_iter.log", replace linesize(150)

* Close the log
log close

*------------------------------------------------------*
* Additional Comments and Unorganized Code (if any)
*------------------------------------------------------*

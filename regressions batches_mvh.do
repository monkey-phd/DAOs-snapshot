* ssc install rangestat
* ssc install gtools
* ssc install reghdfe, replace
* ssc install ftools, replace

*ssc install reghdfe, replace
*ssc install estout, replace

local model_names

* Loop over chunk numbers from 2 to 6
forvalues chunk_number = 2/6 {
    local file = "panel_`chunk_number'_chunk_6m.dta"
    display "Processing File: `file' (Sample`chunk_number')"

    use "$dao_folder/processed/time_chunks/`file'", clear
    xtset voter_id time

    * Define 'type' variables excluding 'type_single_choice'
    local type_vars "type_basic type_approval type_quadratic type_ranked_choice type_weighted"

    * Define interaction terms between 'misaligned_wmiss' and 'type' variables
    local interaction_terms
    foreach tvar of local type_vars {
        local interaction_terms "`interaction_terms' c.misaligned_wmiss#c.`tvar'"
    }

    reghdfe voting_6m ///
        c.voted c.misaligned_wmiss ///
        `interaction_terms' ///
        c.misaligned_wmiss#c.prps_choices_bin ///
        c.misaligned_wmiss#c.prps_rel_quorum ///
        `type_vars' ///
        prps_len prps_choices_bin prps_rel_quorum ///
        topic_0-topic_19 ///
        relative_voting_power_act ///
        if end_6m == 0 & own_choice_tied == 0 & own_margin != 0, ///
        absorb(voter_id year_month_num) vce(cluster voter_id)

    * Store the estimates
    local model_name = "m`chunk_number'"
    estimates store `model_name', title("Sample`chunk_number'")

    local model_names "`model_names' `model_name'"

    clear
}

* Explicitly reference each stored model in esttab to ensure correct export
local output_file "$dao_folder/results/tables/all_samples_combined_order_voting_6m.rtf"

esttab m2 m3 m4 m5 m6 using "`output_file'", ///
    replace ///
    cells(b(fmt(%9.3f)) se(par) p(fmt(3) par([ ]))) ///
    stats(r2 r2_a N, fmt(%9.3f %9.3f %9.0gc) ///
    labels("R-squared" "Adj. R-squared" "Observations")) ///
    legend collabels(none) varlabels(_cons "Constant") ///
    compress ///
    varwidth(30) modelwidth(10) interaction(" X ") ///
    nodepvars nonumbers noomitted unstack ///
    mtitles("Sample 2" "Sample 3" "Sample 4" "Sample 5" "Sample 6") ///
    addnotes("Models include voter and month fixed effects. Clustered standard errors in parentheses; p-values in brackets.")

display "All regressions processed and results exported to `output_file'"




/*
*------------------------------------------------------*
* regressions manual per chunks
*------------------------------------------------------*

use "$dao_folder/processed/time_chunks/panel_2_chunk_6m.dta", clear

*------------------------------------------------------*
* Set Panel Data Structure
*------------------------------------------------------*
xtset voter_id time

*------------------------------------------------------*
* 1. Main Regression 
*------------------------------------------------------*
reghdfe future_vote_in_dao ///
    c.voted c.misaligned_wmiss ///
    c.misaligned_wmiss#c.type_basic ///
    c.misaligned_wmiss#c.type_approval ///
    c.misaligned_wmiss#c.type_quadratic ///
    c.misaligned_wmiss#c.type_ranked_choice ///
    c.misaligned_wmiss#c.type_weighted ///
    c.misaligned_wmiss#c.prps_choices_bin ///
    c.misaligned_wmiss#c.prps_rel_quorum ///
    type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
    prps_len prps_choices_bin prps_rel_quorum ///
    topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
    topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
    topic_17 topic_18 topic_19 ///
    relative_voting_power_act ///
	if end_6m == 0 & own_choice_tied == 0 & own_margin != 0, ///
    absorb(voter_id year_month_num) vce(cluster voter_id)
estimates store m0, title("Sample")

*------------------------------------------------------*
* 2. Export Regression Results with esttab
*------------------------------------------------------*
* estfe m*, labels(voter_id "Voter fixed effects" proposal_id "Proposal fixed effects" year_month_num "Month fixed effects") 

esttab m0 using "$dao_folder/results/tables/panel_2_chunk_6m.rtf", ///
    cells(b(fmt(%9.3f)) se(par) p(fmt(3) par([ ]))) ///
    stats(r2 r2_a N, fmt(%9.3f %9.3f %9.0gc) ///
    labels("R-squared" "Adj. R-squared" "Observations")) ///
    legend collabels(none) varlabels(_cons "Constant") replace compress label ///
    varwidth(30) modelwidth(10) interaction(" X ") ///
    nodepvars nonumbers noomitted unstack ///
    addnotes("Model includes voter and month fixed effects. Clustered standard errors in parentheses; p-values in brackets.")

* ----- * 


/*
local model_names

* Loop over chunk numbers from 2 to 6
forvalues chunk_number = 2/6 {
    local file = "panel_`chunk_number'_chunk_6m.dta"
    display "Processing File: `file' (Sample`chunk_number')"

    use "$dao_folder/processed/time_chunks/`file'", clear
    xtset voter_id time

    * Define 'type' variables excluding 'type_single_choice'
    local type_vars "type_basic type_approval type_quadratic type_ranked_choice type_weighted"

    * Define interaction terms between 'misaligned_wmiss' and 'type' variables
    local interaction_terms
    foreach tvar of local type_vars {
        local interaction_terms "`interaction_terms' c.misaligned_wmiss#c.`tvar'"
    }

    reghdfe future_vote_in_dao ///
        c.voted c.misaligned_wmiss ///
        `interaction_terms' ///
        c.misaligned_wmiss#c.prps_choices_bin ///
        c.misaligned_wmiss#c.prps_rel_quorum ///
        `type_vars' ///
        prps_len prps_choices_bin prps_rel_quorum ///
        topic_0-topic_19 ///
        relative_voting_power_act ///
        if end_6m == 0 & own_choice_tied == 0 & own_margin != 0, ///
        absorb(voter_id year_month_num) vce(cluster voter_id)

    * Store the estimates
    local model_name = "m`chunk_number'"
    estimates store `model_name', title("Sample`chunk_number'")

    local model_names "`model_names' `model_name'"

    clear
}

* Export all regression results with esttab
local output_file "$dao_folder/results/tables/all_samples_combined.rtf"

esttab `model_names' using "`output_file'", ///
    replace ///
    cells(b(fmt(%9.3f)) se(par) p(fmt(3) par([ ]))) ///
    stats(r2 r2_a N, fmt(%9.3f %9.3f %9.0gc) ///
    labels("R-squared" "Adj. R-squared" "Observations")) ///
    legend collabels(none) varlabels(_cons "Constant") ///
    compress label ///
    varwidth(30) modelwidth(10) interaction(" X ") ///
    nodepvars nonumbers noomitted unstack ///
    addnotes("Models include voter and month fixed effects. Clustered standard errors in parentheses; p-values in brackets.")

display "All regressions processed and results exported to `output_file'"

*/	

/*	
*------------------------------------------------------*
* Define Global Data Folder
*------------------------------------------------------*
global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data"

*------------------------------------------------------*
* List All Panel Chunk Files
*------------------------------------------------------*
* Get the list of .dta files matching the pattern
local chunk_files: dir "$dao_folder/processed/time_chunks/" files "panel_*_chunk_6m.dta"

* Display the list of chunk files (optional)
display "Processing the following chunk files:"
foreach file of local chunk_files {
    display "`file'"
}

* Initialize a local macro to store model names
local model_names

* Initialize a counter for model numbering
local model_counter = 1

*------------------------------------------------------*
* Loop Over Each Panel Chunk File
*------------------------------------------------------*
foreach file of local chunk_files {
    * Extract the chunk number from the file name for labeling (optional)
    local chunk_number = subinstr("`file'", "panel_", "", .)
    local chunk_number = subinstr("`chunk_number'", "_chunk_6m.dta", "", .)
    
    display "Processing File: `file'"
    
    * Load the data
    use "$dao_folder/processed/time_chunks/`file'", clear
    
    *--------------------------------------------------*
    * Set Panel Data Structure
    *--------------------------------------------------*
    xtset voter_id time
    
    *--------------------------------------------------*
    * Run the Regression
    *--------------------------------------------------*
    quietly reghdfe future_vote_in_dao ///
        c.voted c.misaligned_wmiss ///
        c.misaligned_wmiss#c.type_basic ///
        c.misaligned_wmiss#c.type_approval ///
        c.misaligned_wmiss#c.type_quadratic ///
        c.misaligned_wmiss#c.type_ranked_choice ///
        c.misaligned_wmiss#c.type_weighted ///
        c.misaligned_wmiss#c.prps_choices_bin ///
        c.misaligned_wmiss#c.prps_rel_quorum ///
        type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
        prps_len prps_choices_bin prps_rel_quorum ///
        topic_1-topic_19 ///
        relative_voting_power_act, ///
        absorb(voter_id year_month_num) vce(cluster voter_id)
    
    * Check if the regression ran successfully
    if _rc == 0 {
        * Store the estimates with a unique name
        local model_name = "m`model_counter'"
        estimates store `model_name', title("Chunk `chunk_number'")
        
        * Add the model name to the list
        local model_names "`model_names' `model_name'"
        
        * Increment the model counter
        local model_counter = `model_counter' + 1
    }
    else {
        display "Regression failed for file `file'."
    }
    
    * Clear data to free up memory
    clear
}

*------------------------------------------------------*
* Export All Regression Results with esttab
*------------------------------------------------------*
* Specify the output file path
local output_file "$dao_folder/results/tables/all_chunks_combined.rtf"

* Use esttab to export all stored models into one table
esttab `model_names' using "`output_file'", ///
    replace ///
    cells(b(fmt(%9.3f)) se(par) p(fmt(3) par([ ]))) ///
    stats(r2 r2_a N, fmt(%9.3f %9.3f %9.0gc) ///
    labels("R-squared" "Adj. R-squared" "Observations")) ///
    legend collabels(none) varlabels(_cons "Constant") ///
    compress label ///
    varwidth(30) modelwidth(10) interaction(" X ") ///
    nodepvars nonumbers noomitted unstack ///
    addnotes("Models include voter and month fixed effects. Clustered standard errors in parentheses; p-values in brackets.")

* Display a message upon completion
display "All regressions processed and results exported to `output_file'"
	
	
/*
	
*------------------------------------------------------*
* Define Global Data Folder
*------------------------------------------------------*
global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data"

*------------------------------------------------------*
* List All Panel Chunk Files
*------------------------------------------------------*
* Get the list of .dta files matching the pattern
local chunk_files: dir "$dao_folder/processed/time_chunks/" files "panel_*_chunk_6m.dta"

* Initialize a local macro to store model names
local model_names

* Initialize a counter for model numbering
local model_counter = 1

*------------------------------------------------------*
* Loop Over Each Panel Chunk File
*------------------------------------------------------*
foreach file of local chunk_files {
    * Extract the chunk number from the file name for labeling (optional)
    local chunk_number = subinstr("`file'", "panel_", "", .)
    local chunk_number = subinstr("`chunk_number'", "_chunk_6m.dta", "", .)
    
    display "Processing File: `file'"
    
    * Load the data
    use "$dao_folder/processed/time_chunks/`file'", clear
    
    *--------------------------------------------------*
    * Set Panel Data Structure
    *--------------------------------------------------*
    xtset voter_id time
    
    *--------------------------------------------------*
    * Run the Regression
    *--------------------------------------------------*
    quietly reghdfe future_vote_in_dao ///
        c.voted c.misaligned_wmiss ///
        c.misaligned_wmiss#c.type_basic ///
        c.misaligned_wmiss#c.type_approval ///
        c.misaligned_wmiss#c.type_quadratic ///
        c.misaligned_wmiss#c.type_ranked_choice ///
        c.misaligned_wmiss#c.type_weighted ///
        c.misaligned_wmiss#c.prps_choices_bin ///
        c.misaligned_wmiss#c.prps_rel_quorum ///
        type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
        prps_len prps_choices_bin prps_rel_quorum ///
        topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
        topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
        topic_17 topic_18 topic_19 ///
        relative_voting_power_act, ///
        absorb(voter_id year_month_num) vce(cluster voter_id)
    
    * Check if the regression ran successfully
    if _rc == 0 {
        * Store the estimates with a unique name
        local model_name = "m`model_counter'"
        estimates store `model_name', title("Chunk `chunk_number'")
        
        * Add the model name to the list
        local model_names "`model_names' `model_name'"
        
        * Increment the model counter
        local model_counter = `model_counter' + 1
    } else {
        display "Regression failed for file `file'."
    }
    
    * Clear data to free up memory
    clear
}

*------------------------------------------------------*
* Export All Regression Results with esttab
*------------------------------------------------------*
* Specify the output file path
local output_file "$dao_folder/results/tables/all_chunks_combined.rtf"

* Use esttab to export all stored models into one table
esttab `model_names' using "`output_file'", ///
    replace ///
    cells(b(fmt(%9.3f)) se(par) p(fmt(3) par([ ]))) ///
    stats(r2 r2_a N, fmt(%9.3f %9.3f %9.0gc) ///
    labels("R-squared" "Adj. R-squared" "Observations")) ///
    legend collabels(none) varlabels(_cons "Constant") ///
    compress label ///
    varwidth(30) modelwidth(10) interaction(" X ") ///
    nodepvars nonumbers noomitted unstack ///
    addnotes("Models include voter and month fixed effects. Clustered standard errors in parentheses; p-values in brackets.")

* Display a message upon completion
display "All regressions processed and results exported to `output_file'"
	
	
	
	
	
*------------------------------------------------------*
* Define Global Data Folder
*------------------------------------------------------*
global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data"

*------------------------------------------------------*
* List All Panel Chunk Files
*------------------------------------------------------*
* Get the list of .dta files matching the pattern
local chunk_files: dir "$dao_folder/processed/time_chunks/" files "panel_*_chunk_6m.dta"

* Display the list of chunk files (optional)
display "Processing the following chunk files:"
foreach file of local chunk_files {
    display "`file'"
}

* Initialize a local macro to store model names
local model_names

* Initialize a counter for model numbering
local model_counter = 1

*------------------------------------------------------*
* Loop Over Each Panel Chunk File
*------------------------------------------------------*
foreach file of local chunk_files {
    * Extract the chunk number from the file name for labeling (optional)
    local chunk_number = subinstr("`file'", "panel_", "", .)
    local chunk_number = subinstr("`chunk_number'", "_chunk_6m.dta", "", .)
    
    display "Processing File: `file'"
    
    * Load the data
    use "$dao_folder/processed/time_chunks/`file'", clear
    
    *--------------------------------------------------*
    * Set Panel Data Structure
    *--------------------------------------------------*
    xtset voter_id time
    
    *--------------------------------------------------*
    * Run the Regression
    *--------------------------------------------------*
    quietly reghdfe future_vote_in_dao ///
        c.voted c.misaligned_wmiss ///
        c.misaligned_wmiss#c.type_basic ///
        c.misaligned_wmiss#c.type_approval ///
        c.misaligned_wmiss#c.type_quadratic ///
        c.misaligned_wmiss#c.type_ranked_choice ///
        c.misaligned_wmiss#c.type_weighted ///
        c.misaligned_wmiss#c.prps_choices_bin ///
        c.misaligned_wmiss#c.prps_rel_quorum ///
        type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
        prps_len prps_choices_bin prps_rel_quorum ///
        topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
        topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
        topic_17 topic_18 topic_19 ///
        relative_voting_power_act, ///
        absorb(voter_id year_month_num) vce(cluster voter_id)
    
    * Check if the regression ran successfully
    if _rc == 0 {
        * Store the estimates with a unique name
        local model_name = "m`model_counter'"
        estimates store `model_name', title("Chunk `chunk_number'")
        
        * Add the model name to the list
        local model_names "`model_names' `model_name'"
        
        * Increment the model counter
        local model_counter = `model_counter' + 1
    } else {
        display "Regression failed for file `file'."
    }
    
    * Clear data to free up memory
    clear
}

*------------------------------------------------------*
* Export All Regression Results with esttab
*------------------------------------------------------*
* Specify the output file path
local output_file "$dao_folder/results/tables/all_chunks_combined.rtf"

* Use esttab to export all stored models into one table
esttab `model_names' using "`output_file'", ///
    replace ///
    cells(b(fmt(%9.3f)) se(par) p(fmt(3) par([ ]))) ///
    stats(r2 r2_a N, fmt(%9.3f %9.3f %9.0gc) ///
    labels("R-squared" "Adj. R-squared" "Observations")) ///
    legend collabels(none) varlabels(_cons "Constant") ///
    compress label ///
    varwidth(30) modelwidth(10) interaction(" X ") ///
    nodepvars nonumbers noomitted unstack ///
    addnotes("Models include voter and month fixed effects. Clustered standard errors in parentheses; p-values in brackets.")

* Display a message upon completion
display "All regressions processed and results exported to `output_file'"
	
	
	
	
/*

*------------------------------------------------------*
* List All Chunk Files
*------------------------------------------------------*
* Get the list of chunk files matching the pattern
local chunk_files: dir "$dao_folder/processed/time_chunks/" files "panel_*_chunk_6m.dta"

* Display the list of chunk files (optional)
display "Processing the following chunk files:"
foreach file of local chunk_files {
    display "`file'"
}

* Initialize a local macro to store model names
local model_names

* Initialize a counter for model numbering
local model_counter = 1

*------------------------------------------------------*
* Loop Over Each Chunk File
*------------------------------------------------------*
foreach file of local chunk_files {
    * Extract the chunk number from the file name for labeling
    local chunk_number = subinstr("`file'", "panel_", "", .)
    local chunk_number = subinstr("`chunk_number'", "_chunk_6m.dta", "", .)
    
    display "Processing Chunk `chunk_number' - File: `file'"
    
    * Build the full file path
    use "$dao_folder/processed/time_chunks/`file'", clear
    
    *--------------------------------------------------*
    * Set Panel Data Structure
    *--------------------------------------------------*
    
    * Set the panel data structure
    xtset voter_id time
    
    *--------------------------------------------------*
    * Run the Regression
    *--------------------------------------------------*
    * Run the regression and store the estimates
    reghdfe future_vote_in_dao ///
        c.voted c.misaligned_wmiss ///
        c.misaligned_wmiss#c.type_basic ///
        c.misaligned_wmiss#c.type_approval ///
        c.misaligned_wmiss#c.type_quadratic ///
        c.misaligned_wmiss#c.type_ranked_choice ///
        c.misaligned_wmiss#c.type_weighted ///
        c.misaligned_wmiss#c.prps_choices_bin ///
        c.misaligned_wmiss#c.prps_rel_quorum ///
        type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
        prps_len prps_choices_bin prps_rel_quorum ///
        topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
        topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
        topic_17 topic_18 topic_19 ///
        relative_voting_power_act ///
        if end_3m == 0 & tied == 0 & rel_own_score > 0.5 & rel_own_score < 2, ///
        absorb(voter_id year_month_num) vce(cluster voter_id)
    
    * Store the estimates with a unique name
    local model_name = "m`model_counter'"
    estimates store `model_name', title("Chunk `chunk_number'")
    
    * Add the model name to the list
    local model_names "`model_names' `model_name'"
    
    * Increment the model counter
    local model_counter = `model_counter' + 1
    
    * Clear data to free up memory (optional)
    clear
}

*------------------------------------------------------*
* Export All Regression Results with esttab
*------------------------------------------------------*
* Specify the output file path
local output_file "$dao_folder/results/tables/all_chunks_regressions.rtf"

* Use esttab to export all stored models into one table
esttab `model_names' using "`output_file'", ///
    title("Regression Results Across All Chunks") ///
    replace ///
    cells(b(fmt(%9.3f)) se(par) p(fmt(3) par([ ]))) ///
    stats(r2 r2_a N, fmt(%9.3f %9.3f %9.0gc) ///
    labels("R-squared" "Adj. R-squared" "Observations")) ///
    legend collabels(none) varlabels(_cons "Constant") ///
    compress label ///
    varwidth(30) modelwidth(10) interaction(" X ") ///
    nodepvars nonumbers noomitted unstack ///
    addnotes("Models include voter and month fixed effects. Clustered standard errors in parentheses; p-values in brackets.")

* Display a message upon completion
display "All regressions processed and results exported to `output_file'"




use "$dao_folder/processed/time_chunks/panel_2_chunk_6m.dta", clear
*------------------------------------------------------*
* Set Panel Data Structure
*------------------------------------------------------*
xtset voter_id time

*------------------------------------------------------*
* 1. Main Regression on the Full Dataset (No Restrictions)
*------------------------------------------------------*
reghdfe future_vote_in_dao ///
    c.voted c.misaligned_wmiss ///
    c.misaligned_wmiss#c.type_basic ///
    c.misaligned_wmiss#c.type_approval ///
    c.misaligned_wmiss#c.type_quadratic ///
    c.misaligned_wmiss#c.type_ranked_choice ///
    c.misaligned_wmiss#c.type_weighted ///
    c.misaligned_wmiss#c.prps_choices_bin ///
    c.misaligned_wmiss#c.prps_rel_quorum ///
    type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
    prps_len prps_choices_bin prps_rel_quorum ///
    topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
    topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
    topic_17 topic_18 topic_19 ///
    relative_voting_power_act, ///
    absorb(voter_id year_month_num) vce(cluster voter_id)
estimates store m0, title("Full Sample")

*------------------------------------------------------*
* 2. Export Regression Results with esttab
*------------------------------------------------------*
esttab m0 using "$dao_folder/results/tables/panel_2_chunk_6m.rtf", ///
    cells(b(fmt(%9.3f)) se(par) p(fmt(3) par([ ]))) ///
    stats(r2 r2_a N, fmt(%9.3f %9.3f %9.0gc) ///
    labels("R-squared" "Adj. R-squared" "Observations")) ///
    legend collabels(none) varlabels(_cons "Constant") replace compress label ///
    varwidth(30) modelwidth(10) interaction(" X ") ///
    nodepvars nonumbers noomitted unstack ///
    addnotes("Model includes voter and month fixed effects. Clustered standard errors in parentheses; p-values in brackets.")

/*
*------------------------------------------------------*
* 1. Main Regression on the Full Dataset
*------------------------------------------------------*
reghdfe voting_3m ///
    c.voted c.misaligned_wmiss ///
    c.misaligned_wmiss#c.type_basic ///
    c.misaligned_wmiss#c.type_approval ///
    c.misaligned_wmiss#c.type_quadratic ///
    c.misaligned_wmiss#c.type_ranked_choice ///
    c.misaligned_wmiss#c.type_weighted ///
    c.misaligned_wmiss#c.prps_choices_bin ///
    c.misaligned_wmiss#c.prps_rel_quorum ///
    type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
    prps_len prps_choices_bin prps_rel_quorum ///
    topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
    topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
    topic_17 topic_18 topic_19 ///
    relative_voting_power_act ///
    if end_3m == 0 & tied == 0, ///
    absorb(voter_id year_month_num) vce(cluster voter_space_id)
estimates store m0, title("Full Sample")

*------------------------------------------------------*
* 2. Subsample Regressions
*------------------------------------------------------*

* Subsample 1
reghdfe voting_3m ///
    c.voted c.misaligned_wmiss ///
    c.misaligned_wmiss#c.type_basic ///
    c.misaligned_wmiss#c.type_approval ///
    c.misaligned_wmiss#c.type_quadratic ///
    c.misaligned_wmiss#c.type_ranked_choice ///
    c.misaligned_wmiss#c.type_weighted ///
    c.misaligned_wmiss#c.prps_choices_bin ///
    c.misaligned_wmiss#c.prps_rel_quorum ///
    type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
    prps_len prps_choices_bin prps_rel_quorum ///
    topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
    topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
    topic_17 topic_18 topic_19 ///
    relative_voting_power_act ///
    if end_3m == 0 & tied == 0 & space_id >= 0 & space_id < 20, ///
    absorb(voter_id year_month_num) vce(cluster voter_space_id)
estimates store m1, title("S1")

* Subsample 2
reghdfe voting_3m ///
    c.voted c.misaligned_wmiss ///
    c.misaligned_wmiss#c.type_basic ///
    c.misaligned_wmiss#c.type_approval ///
    c.misaligned_wmiss#c.type_quadratic ///
    c.misaligned_wmiss#c.type_ranked_choice ///
    c.misaligned_wmiss#c.type_weighted ///
    c.misaligned_wmiss#c.prps_choices_bin ///
    c.misaligned_wmiss#c.prps_rel_quorum ///
    type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
    prps_len prps_choices_bin prps_rel_quorum ///
    topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
    topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
    topic_17 topic_18 topic_19 ///
    relative_voting_power_act ///
    if end_3m == 0 & tied == 0 & space_id >= 20 & space_id < 57, ///
    absorb(voter_id year_month_num) vce(cluster voter_space_id)
estimates store m2, title("S2")

* Subsample 3
reghdfe voting_3m ///
    c.voted c.misaligned_wmiss ///
    c.misaligned_wmiss#c.type_basic ///
    c.misaligned_wmiss#c.type_approval ///
    c.misaligned_wmiss#c.type_quadratic ///
    c.misaligned_wmiss#c.type_ranked_choice ///
    c.misaligned_wmiss#c.type_weighted ///
    c.misaligned_wmiss#c.prps_choices_bin ///
    c.misaligned_wmiss#c.prps_rel_quorum ///
    type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
    prps_len prps_choices_bin prps_rel_quorum ///
    topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
    topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
    topic_17 topic_18 topic_19 ///
    relative_voting_power_act ///
    if end_3m == 0 & tied == 0 & space_id >= 58 & space_id < 109, ///
    absorb(voter_id year_month_num) vce(cluster voter_space_id)
estimates store m3, title("S3")

* Subsample 4
reghdfe voting_3m ///
    c.voted c.misaligned_wmiss ///
    c.misaligned_wmiss#c.type_basic ///
    c.misaligned_wmiss#c.type_approval ///
    c.misaligned_wmiss#c.type_quadratic ///
    c.misaligned_wmiss#c.type_ranked_choice ///
    c.misaligned_wmiss#c.type_weighted ///
    c.misaligned_wmiss#c.prps_choices_bin ///
    c.misaligned_wmiss#c.prps_rel_quorum ///
    type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
    prps_len prps_choices_bin prps_rel_quorum ///
    topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
    topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
    topic_17 topic_18 topic_19 ///
    relative_voting_power_act ///
    if end_3m == 0 & tied == 0 & space_id >= 110 & space_id < 180, ///
    absorb(voter_id year_month_num) vce(cluster voter_space_id)
estimates store m4, title("S4")

* Subsample 5
reghdfe voting_3m ///
    c.voted c.misaligned_wmiss ///
    c.misaligned_wmiss#c.type_basic ///
    c.misaligned_wmiss#c.type_approval ///
    c.misaligned_wmiss#c.type_quadratic ///
    c.misaligned_wmiss#c.type_ranked_choice ///
    c.misaligned_wmiss#c.type_weighted ///
    c.misaligned_wmiss#c.prps_choices_bin ///
    c.misaligned_wmiss#c.prps_rel_quorum ///
    type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
    prps_len prps_choices_bin prps_rel_quorum ///
    topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
    topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
    topic_17 topic_18 topic_19 ///
    relative_voting_power_act ///
    if end_3m == 0 & tied == 0 & space_id >= 180 & space_id < 229, ///
    absorb(voter_id year_month_num) vce(cluster voter_space_id)
estimates store m5, title("S5")

*------------------------------------------------------*
* 3. Export Regression Results with esttab
*------------------------------------------------------*
esttab m0 m1 m2 m3 m4 m5 using "$dao_folder/results/tables/full_subsamples.rtf", ///
    cells(b(fmt(%9.3f)) se(par) p(fmt(3) par([ ]))) ///
    stats(r2 r2_a N, fmt(%9.3f %9.3f %9.0gc) ///
    labels("R-squared" "Adj. R-squared" "Observations")) ///
    legend collabels(none) varlabels(_cons "Constant") replace compress label ///
    varwidth(30) modelwidth(10) interaction(" X ") ///
    nodepvars nonumbers noomitted unstack ///
    addnotes("All models include voter and month fixed effects. Clustered standard errors in parentheses; p-values in brackets.")




/*
reghdfe voting_3m ///
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
	relative_voting_power_act if end_3m == 0 & tied == 0 & space_id >= 0 & space_id < 20 ///
	& rel_own_score > 0.5 & rel_own_score < 2, ///
	absorb(voter_id year_month_num) vce(cluster voter_space_id)	
estimates store m1, title("S1")	

reghdfe voting_3m ///
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
	relative_voting_power_act if end_3m == 0 & tied == 0 & space_id >= 20 & space_id < 57 ///
	& rel_own_score > 0.5 & rel_own_score < 2, ///
	absorb(voter_id year_month_num) vce(cluster voter_space_id)	
estimates store m2, title("S2")	

reghdfe voting_3m ///
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
	relative_voting_power_act if end_3m == 0 & tied == 0 & space_id >= 58 & space_id < 109 ///
	& rel_own_score > 0.5 & rel_own_score < 2, ///
	absorb(voter_id year_month_num) vce(cluster voter_space_id)	
estimates store m3, title("S3")	

reghdfe voting_3m ///
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
	relative_voting_power_act if end_3m == 0 & tied == 0 & space_id >= 110 & space_id < 180 ///
	& rel_own_score > 0.5 & rel_own_score < 2, ///
	absorb(voter_id year_month_num) vce(cluster voter_space_id)	
estimates store m4, title("S4")	

reghdfe voting_3m ///
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
	relative_voting_power_act if end_3m == 0 & tied == 0 & space_id >= 180 & space_id < 229 ///
	& rel_own_score > 0.5 & rel_own_score < 2, ///
	absorb(voter_id year_month_num) vce(cluster voter_space_id)	
estimates store m5, title("S5")	

*estfe m*, labels(voter_id "Voter fixed effects" year_month_num 	///
*	"Month fixed effects" proposal_id "Proposal fixed effects") 

esttab m1 m3 m2 m4 m5 using "$dao_folder/results/tables/full_subsamples.rtf", ///
	cells(b(fmt(%9.3f)) se(par) p(fmt(3) par([ ]))) ///
	stats(r2 r2_within N, fmt(%9.3f %9.3f %9.0gc) ///
	labels("R-squared overall" "R-squared within" "Observations")) ///
	legend collabels(none) varlabels(_cons Constant) replace compress label  ///
	varwidth(30) modelwidth(10) interaction( " X ") ///
	indicate(`r(indicate_fe)') ///
	nodepvars nonumbers noomitted unstack ///
	addnotes("All models include voter, month, and proposal fixed effects. Clustered standard errors in parentheses; p-values in brackets.")	
		
/*

	

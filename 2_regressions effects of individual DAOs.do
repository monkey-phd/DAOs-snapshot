global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data" // change with whatever path

clear frames

* Create the 'coeffs' frame to store coefficients
frame create coeffs
frame coeffs {
    clear
    set obs 0  // Start with zero observations

    * Define variables to store in 'coeffs' frame
    gen strL space_name = ""  // Store DAO space name
    gen strL file_name = ""   // Store DAO file name
    gen str5 period = ""      // Store period (1m, 3m, 6m)
    gen voted_coef = .
    gen mis_coef = .
    gen mis_basic_coef = .
    gen mis_app_coef = .
    gen mis_q_coef = .
    gen mis_rc_coef = .
    gen mis_w_coef = .
    gen dao_obs = .
}

* Define the DAO folder path
local dao_folder "$dao_folder/processed/dao"

* Get the list of DAO files
local files : dir "`dao_folder'" files "panel_*.dta"


* Set filelist to include all files in the folder
local filelist "`files'"

* Select the first 5 files (adjust as needed)
/*local filelist ""
forval i = 1/5 {
    local filelist "`filelist' `: word `i' of `files''"
}
*/

* Define the list of periods
local periods "1m 3m 6m"

* Loop over the first  DAO files
foreach file of local filelist {
    display "Processing file `file'"

    * Create and switch to the 'iter' frame to process the data
    frame create iter
    frame change iter

    * Load the data
    use "`dao_folder'/`file'", clear

    * Generate IDs if not already present
    egen voter_id = group(voter)
    egen voter_space_id = group(voter_id space)
    egen proposal_id = group(proposal)
    egen proposal_space_id = group(space proposal_id)
    egen voter_proposal_id = group(voter_id proposal_id)

    * Extract the 'space' variable value
    summarize space
    local current_space = space[1]

    * Data cleaning steps (adjust as needed)
    keep voter_space_id voter_proposal_id voter_id space year_month_num ///
        voting_1m voting_3m voting_6m ///
        end_1m end_3m end_6m ///
        voted misaligned_wmiss ///
        type_basic type_approval type_quadratic type_ranked_choice type_weighted ///
        prps_choices_bin prps_rel_quorum prps_len ///
        topic_1-topic_19 relative_voting_power_act voter_space_prps_counter

    * Set the panel structure
    xtset voter_space_id voter_space_prps_counter

    * Loop over periods
    foreach period of local periods {

        * Count observations for the current DAO and period
        count if end_`period' == 0
        local dao_obs = r(N)

        * Skip if not enough observations
        if `dao_obs' < 100 {
            display "Empty DAO: `file' for period `period'"
            continue
        }

        * Initialize coefficient variables outside the capture block
        local voted_coef = .
        local mis_coef = .
        local mis_basic_coef = .
        local mis_app_coef = .
        local mis_q_coef = .
        local mis_rc_coef = .
        local mis_w_coef = .

        * Run the regression and extract coefficients
        capture noisily reghdfe voting_`period' ///
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
            relative_voting_power_act if end_`period' == 0, ///
            absorb(voter_id year_month_num) vce(cluster voter_space_id)

        * Extract coefficient matrix
        matrix b = e(b)

        * Get the names of the coefficients
        local coefnames : colnames b

        * Extract coefficients safely
        foreach coef in "c.voted" "c.misaligned_wmiss" "c.misaligned_wmiss#c.type_basic" ///
                        "c.misaligned_wmiss#c.type_approval" "c.misaligned_wmiss#c.type_quadratic" ///
                        "c.misaligned_wmiss#c.type_ranked_choice" "c.misaligned_wmiss#c.type_weighted" {
            if strpos(" `coefnames' ", " `coef' ") {
                local coef_value = b[1, "`coef'"]
                if "`coef'" == "c.voted" local voted_coef = `coef_value'
                if "`coef'" == "c.misaligned_wmiss" local mis_coef = `coef_value'
                if "`coef'" == "c.misaligned_wmiss#c.type_basic" local mis_basic_coef = `coef_value'
                if "`coef'" == "c.misaligned_wmiss#c.type_approval" local mis_app_coef = `coef_value'
                if "`coef'" == "c.misaligned_wmiss#c.type_quadratic" local mis_q_coef = `coef_value'
                if "`coef'" == "c.misaligned_wmiss#c.type_ranked_choice" local mis_rc_coef = `coef_value'
                if "`coef'" == "c.misaligned_wmiss#c.type_weighted" local mis_w_coef = `coef_value'
            }
        }
		
		* Extract coefficient matrix
		matrix b = e(b)

		* Get the names of the coefficients
		local coefnames : colnames b

		* Display the coefficient names for debugging
		display "Coefficient names: `coefnames'"

		* Adjusted coefficient extraction
		foreach coef in "voted" "misaligned_wmiss" "c.misaligned_wmiss#c.type_basic" ///
						"c.misaligned_wmiss#c.type_approval" "c.misaligned_wmiss#c.type_quadratic" ///
						"c.misaligned_wmiss#c.type_ranked_choice" "c.misaligned_wmiss#c.type_weighted" {
			if strpos(" `coefnames' ", " `coef' ") {
				local coef_value = b[1, "`coef'"]
				if "`coef'" == "voted" local voted_coef = `coef_value'
				if "`coef'" == "misaligned_wmiss" local mis_coef = `coef_value'
				if "`coef'" == "c.misaligned_wmiss#c.type_basic" local mis_basic_coef = `coef_value'
				if "`coef'" == "c.misaligned_wmiss#c.type_approval" local mis_app_coef = `coef_value'
				if "`coef'" == "c.misaligned_wmiss#c.type_quadratic" local mis_q_coef = `coef_value'
				if "`coef'" == "c.misaligned_wmiss#c.type_ranked_choice" local mis_rc_coef = `coef_value'
				if "`coef'" == "c.misaligned_wmiss#c.type_weighted" local mis_w_coef = `coef_value'
			}
		}
				
		
        * Switch back to the default frame to update the 'coeffs' frame
        frame change default

        * Add a new observation to 'coeffs' and assign coefficient values
        frame coeffs {
            * Add a new observation
            quietly set obs `=_N + 1'  // Increase the number of observations by one
            local newobs = _N          // The index of the new observation

            * Assign coefficient values to the new observation
            replace space_name = "`current_space'" in `newobs'  // Use the 'space' variable
            replace file_name = "`file'" in `newobs'            // Store the file name
            replace period = "`period'" in `newobs'
            replace dao_obs = `dao_obs' in `newobs'
            replace voted_coef = `voted_coef' in `newobs'
            replace mis_coef = `mis_coef' in `newobs'
            replace mis_basic_coef = `mis_basic_coef' in `newobs'
            replace mis_app_coef = `mis_app_coef' in `newobs'
            replace mis_q_coef = `mis_q_coef' in `newobs'
            replace mis_rc_coef = `mis_rc_coef' in `newobs'
            replace mis_w_coef = `mis_w_coef' in `newobs'
        }

        * Switch back to 'iter' frame
        frame change iter
    }
    * Drop the 'iter' frame to free up memory
    frame change default
    frame drop iter
}

* Switch to the 'coeffs' frame
frame change coeffs

* Save the coefficients to a .dta file
save "$dao_folder/processed/coefficients_daos.dta", replace

* Generate and export the plots

* Define the list of variables to plot
local coef_vars "voted_coef mis_coef mis_basic_coef mis_app_coef mis_q_coef mis_rc_coef mis_w_coef"

* Define the list of periods
local periods "1m 3m 6m"

* Create the directory for figures if it doesn't exist
cap mkdir "$dao_folder/results/figures"

* Loop over periods
foreach period of local periods {

    * Display the current period
    display "Generating plots for period `period'"

    * Preserve the original data
    preserve

    * Keep data for the current period
    keep if period == "`period'"

    * Loop over variables
    foreach var of local coef_vars {

        * Check if the variable exists
        capture confirm variable `var'
        if _rc {
            display "Variable `var' not found, skipping plot"
            continue
        }

        * Remove missing values for the variable
        drop if missing(`var')

        * Check if there are enough observations
        count
        if r(N) == 0 {
            display "No data for variable `var' in period `period', skipping"
            continue
        }

        * Generate histogram without weighting
        histogram `var', kdensity legend(pos(6)) name(`var'_plot_`period', replace)
        graph export "$dao_folder/results/figures/dao_`var'_`period'.png", replace width(1200) height(900)

        * Generate histogram with weighting by dao_obs
        histogram `var' [fw=dao_obs], kdensity legend(pos(6)) name(`var'_weighted_plot_`period', replace)
        graph export "$dao_folder/results/figures/dao_`var'_weighted_`period'.png", replace width(1200) height(900)
    }

    * Restore the original data before the next period
    restore
}

/*


frame change coeffs


// Define a temporary location for saving files
tempname positive_dao_file negative_dao_file

// Create and save the positive mean list for each coefficient
foreach var in mean_voted_coef mean_mis_coef mean_mis_basic_coef mean_mis_app_coef mean_mis_q_coef mean_mis_rc_coef mean_mis_w_coef {
    * List DAOs with positive mean for `var`
    preserve
    keep if `var' > 0
    keep space_name `var'
    save "`positive_dao_file'_`var'.dta", replace
    export delimited "`positive_dao_file'_`var'.csv", replace
    restore
}

// Create and save the negative mean list for each coefficient
foreach var in mean_voted_coef mean_mis_coef mean_mis_basic_coef mean_mis_app_coef mean_mis_q_coef mean_mis_rc_coef mean_mis_w_coef {
    * List DAOs with negative mean for `var`
    preserve
    keep if `var' < 0
    keep space_name `var'
    save "`negative_dao_file'_`var'.dta", replace
    export delimited "`negative_dao_file'_`var'.csv", replace
    restore
}

*/

/*
// Load the data
use "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data/processed/coefficients_daos/coefficients_daos.dta", clear


// Define a prefix for positive and negative CSV files
local positive_dao_prefix "positive_dao_"
local negative_dao_prefix "negative_dao_"

// Create and save the positive mean list for each coefficient
foreach var in voted_coef mis_coef mis_basic_coef mis_app_coef mis_q_coef mis_rc_coef mis_w_coef {
    // List DAOs with positive mean for each coefficient
    preserve
    keep if `var' > 0
    keep space_name file_name period `var'
    
    // Check if any data remains after filtering
    count
    if r(N) > 0 {
        export delimited using "`positive_dao_prefix'`var'.csv", replace
    }
    
    restore
}

// Create and save the negative mean list for each coefficient
foreach var in voted_coef mis_coef mis_basic_coef mis_app_coef mis_q_coef mis_rc_coef mis_w_coef {
    // List DAOs with negative mean for each coefficient
    preserve
    keep if `var' < 0
    keep space_name file_name period `var'
    
    // Check if any data remains after filtering
    count
    if r(N) > 0 {
        export delimited using "`negative_dao_prefix'`var'.csv", replace
    }
    
    restore
}

// Display messages to confirm where files are saved
display "Positive mean DAO lists saved with the prefix: `positive_dao_prefix'"
display "Negative mean DAO lists saved with the prefix: `negative_dao_prefix'"

*/

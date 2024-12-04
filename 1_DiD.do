
/* Key Analysis Features:
  1. DiD design - DAOs change voting systems at different times
  2. Treatment: Switch from single-choice to other voting systems
  3. Goal: Estimate causal effect of voting system changes on participation

  Critical Aspects:
  - Treatment occurs at different times 
  - Need to observe pre-treatment periods for proper DiD
  - Must account for multiple types of voting system changes
*/

capture which csdid
if _rc ssc install csdid, replace

********************************************************************************
* 1. Initial Setup and Data Preparation
********************************************************************************
clear all
set more off
global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data" 

// Load panel data and establish panel structure
use "$dao_folder/processed/panel_almost_full.dta", clear
xtset voter_space_id voter_space_prps_counter

// Clean slate - remove any existing variables to avoid conflicts
foreach var in baseline_change transition_to_approval transition_to_basic ///
   transition_to_quadratic transition_to_ranked_choice transition_to_weighted ///
   votes_approval votes_basic votes_quadratic votes_ranked_choice ///
   votes_weighted votes_single sufficient_exposure concurrent_daos ///
   change_sequence dao_total_changes first_transition treated post event_time ///
   treated_staggered post_staggered ever_treated {
   capture drop `var'
}

********************************************************************************
* 2. Core Treatment Definition
********************************************************************************
// Key analysis parameters
global min_votes 5      // Minimum votes required to ensure sufficient exposure
global max_changes 1    // Focus on first change to avoid contamination effects

// Ensure proper temporal ordering within voter-DAO pairs
sort voter_id space_id year_month_num

// Step 1: Identify voting system transitions
// This marks exact points where DAOs switch from single-choice voting
// baseline_change = 1 indicates the moment of transition
bysort voter_id space_id (year_month_num): gen baseline_change = 0
replace baseline_change = 1 if type_single_choice[_n-1] == 1 & ///
   type_single_choice == 0 & _n > 1
   
// Step 1b: Identify specific transitions to each voting system
foreach type in approval basic quadratic ranked_choice weighted {
    bysort voter_id space_id (year_month_num): gen transition_to_`type' = 0
    replace transition_to_`type' = 1 if type_single_choice[_n-1] == 1 & ///
        type_`type' == 1 & _n > 1
}

// Step 2: Track change sequence
// Important for:
// 1. Enforcing single-change restriction
// 2. Understanding treatment timing
bysort voter_id space_id (year_month_num): gen change_sequence = sum(baseline_change)
egen dao_total_changes = max(change_sequence), by(voter_id space_id)

********************************************************************************
* 3. DiD Setup 
********************************************************************************
/* Critical: Proper identification strategy for DiD
  Key Requirements:
  1. Identify eventual treatment status
  2. Track specific treatment timing
  3. Ensure proper control group throughout
  4. Observe pre-treatment periods for treated units
  
  setup requires:
  - Global post period based on first treatment
  - Treatment indicator based on eventual treatment status
*/

// Step 1: Identify treatment group membership
// ever_treated = 1 for any voter who experiences voting system change
// This is permanent characteristic, not time-varying
bysort voter_id space_id: egen ever_treated = max(baseline_change)

// Step 2: Track treatment timing
// First, identify specific treatment month for each voter
bysort voter_id space_id (year_month_num): egen individual_treatment_time = min(year_month_num) ///
    if baseline_change == 1
// Propagate treatment time to all observations of treated voters
bysort voter_id space_id: egen individual_treatment_time_all = min(individual_treatment_time)

// Step 3: Define study periods based on first treatment
// Identify earliest treatment (month 737) to establish pre/post periods
summarize individual_treatment_time_all if !missing(individual_treatment_time_all), meanonly
local first_treatment = r(min)

// Create post indicator based on first treatment
// post = 1 for all observations after first DAO adopts (month 737)
// This ensures control units contribute to both pre/post periods
gen post_did = (year_month_num >= `first_treatment')

// Step 4: Define treatment status
// Treatment group includes all eventually-treated units
// This creates proper 2x2 DiD structure:
// 1. Never-treated units: Control group throughout
// 2. Eventually-treated units before treatment: Pre-treatment observations
// 3. Eventually-treated units after treatment: Treatment effect
gen treated_did = (ever_treated == 1)

// Verify 2x2 setup captures proper variation
tabulate treated_did post_did, row col

********************************************************************************
* 4. Control Variables
********************************************************************************
// Calculate voting system experience
// Track participation in each voting system type
foreach type in approval basic quadratic ranked_choice weighted single_choice {
   bysort voter_id type_`type': gen votes_`type' = _N
}

// Generate sufficient exposure indicator
// Only include voters with minimum voting experience (5+ votes)
// This ensures familiarity with voting system
gen sufficient_exposure = 0
foreach type in approval basic quadratic ranked_choice weighted single {
   replace sufficient_exposure = 1 if votes_`type' >= $min_votes
}

********************************************************************************
* 5. Traditional TWFE Analysis
********************************************************************************
// Basic TWFE specification
eststo twfe_basic: reghdfejl voted i.treated_did##i.post_did ///
    if sufficient_exposure == 1 & dao_total_changes <= $max_changes, ///
    absorb(voter_id year_month_num) vce(cluster voter_space_id)

// Full specification with controls
eststo twfe_full: reghdfejl voted i.treated_did##i.post_did ///
    voter_tenure_space times_voted_space_cum relative_voting_power_act ///
    prps_len prps_choices met_quorum ///
    if sufficient_exposure == 1 & dao_total_changes <= $max_changes, ///
    absorb(voter_id year_month_num) vce(cluster voter_space_id)

	
********************************************************************************
* 6. System-Specific Analysis
********************************************************************************


foreach type in approval basic quadratic ranked_choice weighted {
    // First get the earliest treatment time for this specific transition
	// Identify treatment group membership for each type
    bysort voter_id space_id: egen ever_treated_`type' = max(transition_to_`type')

    // Track treatment timing for each type
    bysort voter_id space_id (year_month_num): egen itt_`type' = min(year_month_num) ///
        if transition_to_`type' == 1
    bysort voter_id space_id: egen itt_`type'_all = min(itt_`type')
	
	
    summarize itt_`type'_all if !missing(itt_`type'_all), meanonly
    local first_`type' = r(min)
    
    // Create post period based on first transition of this type
    gen post_`type' = (year_month_num >= `first_`type'')
    
    // Create treatment group for this specific transition
    gen treated_`type' = (ever_treated_`type' == 1)
    
    // Run the regression with consistent clustering
    eststo `type': reghdfejl voted i.treated_`type'##i.post_`type' ///
        voter_tenure_space times_voted_space_cum relative_voting_power_act ///
        prps_len prps_choices met_quorum ///
        if sufficient_exposure == 1 & dao_total_changes <= $max_changes, ///
        absorb(space_id) vce(cluster voter_space_id)
        
    // Clean up
    drop post_`type' treated_`type'
}

********************************************************************************
* 7. Export Results
********************************************************************************
// Main Results Table
esttab twfe_basic twfe_full using "$dao_folder/results/tables/main_results.rtf", ///
    replace b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    noconstant title("Main DiD Results") ///
    mtitles("Base Model" "Full Model") ///
    scalars("N Observations" "r2_a Adjusted R-squared") ///
    addnotes("Standard errors clustered at voter and space level") ///
    label compress

// System-Specific Results
esttab approval basic quadratic ranked_choice weighted ///
    using "$dao_folder/results/tables/system_specific.rtf", ///
    replace b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) ///
    noconstant title("System-Specific Effects") ///
    mtitles("Approval" "Basic" "Quadratic" "Ranked Choice" "Weighted") ///
    scalars("N Observations" "r2_a Adjusted R-squared") ///
    addnotes("Standard errors clustered at voter and space level") ///
    label compress

// Clear stored estimates
eststo clear

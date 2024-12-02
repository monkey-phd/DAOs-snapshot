********************************************************************************
// 1. Setup and Data Preparation
********************************************************************************
clear all
set more off
global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data" // change with your actual path

// Install required packages if needed
ssc install rddensity
ssc install rdrobust

// Load and prepare data
use "$dao_folder/processed/panel_almost_full.dta", clear

// Clear any existing stored estimates
eststo clear

********************************************************************************
// 2. Generate Key Variables 
********************************************************************************
// whale and power-related variables
gen whale = (relative_voting_power_act > 0.01)
gen decisive_whale = (whale == 1 & abs(own_margin) < relative_voting_power_act)

********************************************************************************
// 3. Visualization and Initial Tests 
********************************************************************************
// density test (more observations just above the threshold than below it)
rdrobust voting_3m own_margin, c(0) kernel(triangular) bwselect(mserd)
rddensity own_margin, c(0) plot
graph export "$dao_folder/results/figures/density_test.png", replace

// basic visualization
twoway (histogram own_margin if own_margin > -1 & own_margin < 1, bin(50) color(blue%30)) ///
    (scatteri 0 0 10 0, recast(line) lcolor(red)), ///
    xtitle("Own Margin") ytitle("Density") ///
    title("Distribution around threshold")
graph export "$dao_folder/results/figures/threshold_dist.png", replace

// RD Plot with binscatter. All show "sore loser" (losers vote more) effect across 1m, 3m, and 6m. Effect size decreases with time.
binscatter voting_3m own_margin if own_margin > -0.98 & own_margin < 0.98 & own_margin !=0, ///
    nquantiles(50) rd(0) ///
    title("RD Plot: Voting Behavior around Threshold")
graph export "$dao_folder/results/figures/rd_plot_binscatter.png", replace

********************************************************************************
// 4. Main RDD Analysis
********************************************************************************
// Basic RDD (baseline)
eststo basic: rdrobust voting_3m own_margin, c(0) kernel(triangular) bwselect(mserd)

// RDD with core covariates. Effect size drops yet significant "sore loser" effect remains
eststo covariates: rdrobust voting_3m own_margin, c(0) ///
    covs(type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
         relative_voting_power_act prps_rel_quorum voter_tenure_space) ///
    kernel(triangular) bwselect(mserd)

********************************************************************************
// 5. Heterogeneity Analysis 
********************************************************************************
// By voting type
foreach type in type_approval type_basic type_quadratic type_ranked_choice type_weighted {
    eststo `type': rdrobust voting_3m own_margin if `type' == 1 & !decisive_whale, ///
        c(0) covs(relative_voting_power_act prps_rel_quorum) ///
        kernel(triangular) bwselect(mserd)
}

// By voting power quintiles (changed from quartiles)
xtile vp_quintile = relative_voting_power_act, nq(5)
forvalues q = 1/5 {
    eststo quintile_`q': rdrobust voting_3m own_margin if vp_quintile == `q' & !decisive_whale, ///
        c(0) kernel(triangular) bwselect(mserd)
}

********************************************************************************
// 6. Robustness Checks 
********************************************************************************
// More precise bandwidths (added smaller increments)
foreach h in 5 7.5 10 12.5 15 17.5 20 22.5 25 27.5 30 {
    local h_decimal = `h'/100  // Convert to decimal
    eststo bw_h`h': rdrobust voting_3m own_margin if !decisive_whale, c(0) h(`h_decimal') kernel(triangular)
}

// Full covariate specification
eststo full_covs: rdrobust voting_3m own_margin, c(0) ///
    covs(type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
         relative_voting_power_act prps_rel_quorum voter_tenure_space ///
         prps_len prps_choices_bin ///
         space_age space_id_size ///
    kernel(triangular) bwselect(mserd)

********************************************************************************
// 7. Export Tables
********************************************************************************
// Main results table
esttab basic covariates full_covs using "$dao_folder/results/tables/main_rdd_results_1a.rtf", ///
    replace cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Main RDD Results") ///
    note("Standard errors in parentheses. * p<0.10, ** p<0.05, *** p<0.01")

// Heterogeneity by voting type
esttab type_* using "$dao_folder/results/tables/heterogeneity_votetype_1a.rtf", ///
    replace cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("RDD Results by Voting Type") ///
    note("Standard errors in parentheses. * p<0.10, ** p<0.05, *** p<0.01")

// Heterogeneity by voting power (updated for quintiles)
esttab quintile_* using "$dao_folder/results/tables/heterogeneity_power_1a.rtf", ///
    replace cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("RDD Results by Voting Power Quintile") ///
    note("Standard errors in parentheses. * p<0.10, ** p<0.05, *** p<0.01")

// Bandwidth sensitivity (with more precise bandwidths)
esttab bw_h5 bw_h7_5 bw_h10 bw_h12_5 bw_h15 bw_h17_5 bw_h20 bw_h22_5 bw_h25 bw_h27_5 bw_h30 ///
    using "$dao_folder/results/tables/robustness_bandwidth_1a.rtf", ///
    replace cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("RDD Results with Different Bandwidths") ///
    note("Standard errors in parentheses. * p<0.10, ** p<0.05, *** p<0.01")
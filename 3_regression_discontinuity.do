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

// By voting power quartiles
xtile vp_quartile = relative_voting_power_act, nq(4)
forvalues q = 1/4 {
    eststo quartile_`q': rdrobust voting_3m own_margin if vp_quartile == `q' & !decisive_whale, ///
        c(0) kernel(triangular) bwselect(mserd)
}

********************************************************************************
// 6. Robustness Checks 
********************************************************************************
// Different bandwidths
foreach h in 10 20 30 {
    local h_decimal = `h'/100  // Convert to decimal (0.1, 0.2, 0.3)
    eststo bw_h`h': rdrobust voting_3m own_margin if !decisive_whale, c(0) h(`h_decimal') kernel(triangular)
}

// Full covariate specification
eststo full_covs: rdrobust voting_3m own_margin, c(0) ///
    covs(type_approval type_basic type_quadratic type_ranked_choice type_weighted ///
         relative_voting_power_act prps_rel_quorum voter_tenure_space ///
         prps_len prps_choices_bin ///
         misaligned_wmiss ///
         topic_1 topic_2 topic_3 topic_4 topic_5 topic_6 topic_7 topic_8 ///
         topic_9 topic_10 topic_11 topic_12 topic_13 topic_14 topic_15 topic_16 ///
         topic_17 topic_18 topic_19) ///
    kernel(triangular) bwselect(mserd)

********************************************************************************
// 7. Export Tables
********************************************************************************
// Main results table
esttab basic covariates full_covs using "$dao_folder/results/tables/main_rdd_results.rtf", ///
    replace cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Main RDD Results") ///
    note("Standard errors in parentheses. * p<0.10, ** p<0.05, *** p<0.01")

// Heterogeneity by voting type
esttab type_* using "$dao_folder/results/tables/heterogeneity_votetype.rtf", ///
    replace cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("RDD Results by Voting Type") ///
    note("Standard errors in parentheses. * p<0.10, ** p<0.05, *** p<0.01")

// Heterogeneity by voting power
esttab quartile_* using "$dao_folder/results/tables/heterogeneity_power.rtf", ///
    replace cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("RDD Results by Voting Power Quartile") ///
    note("Standard errors in parentheses. * p<0.10, ** p<0.05, *** p<0.01")

// Bandwidth sensitivity
esttab bw_* using "$dao_folder/results/tables/robustness_bandwidth.rtf", ///
    replace cells(b(star fmt(3)) se(par fmt(3))) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("RDD Results with Different Bandwidths") ///
    note("Standard errors in parentheses. * p<0.10, ** p<0.05, *** p<0.01")

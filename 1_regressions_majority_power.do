
use "$dao_folder/processed/panel_almost_full.dta", clear

// Convert is_majority_win to numeric
encode is_majority_win, generate(is_majority_win_num)

// Set panel structure
xtset voter_space_id voter_space_prps_counter

// Calculate power concentration using existing active_vp
bysort proposal_id: egen total_active_vp = total(active_vp)
gen active_vp_share = active_vp/total_active_vp
bysort proposal_id: egen active_hhi = total(active_vp_share^2)

// 1. Basic Model - By Voting Type
reghdfe is_majority_win_num ///
    c.active_vp c.misaligned_wmiss ///
    type_basic type_approval type_quadratic type_ranked_choice type_weighted ///
    prps_len prps_choices_bin prps_rel_quorum ///
    plugin_safesnap strategy_delegation ///
    topic_1-topic_19 ///
    relative_voting_power_act if own_choice_tied == 0, ///
    absorb(voter_id year_month_num) vce(cluster voter_space_id)
estimates store m1, title("Basic")

// 2. Interaction Model
reghdfe is_majority_win_num ///
    c.active_vp##(type_basic type_approval type_quadratic type_ranked_choice type_weighted) ///
    c.misaligned_wmiss##(type_basic type_approval type_quadratic type_ranked_choice type_weighted) ///
    prps_len prps_choices_bin prps_rel_quorum ///
    plugin_safesnap strategy_delegation ///
    topic_1-topic_19 ///
    relative_voting_power_act if own_choice_tied == 0, ///
    absorb(voter_id year_month_num) vce(cluster voter_space_id)
estimates store m2, title("Interactions")

// 3. Subsample Analysis
foreach type in single_choice basic approval quadratic ranked_choice weighted {
    reghdfe is_majority_win_num ///
        c.active_vp c.misaligned_wmiss ///
        prps_len prps_choices_bin prps_rel_quorum ///
        plugin_safesnap strategy_delegation ///
        topic_1-topic_19 ///
        relative_voting_power_act if type_`type' == 1 & own_choice_tied == 0, ///
        absorb(voter_id year_month_num) vce(cluster voter_space_id)
    estimates store m_`type', title("`type'")
}

// Output initial results
esttab m1 m2 m_single_choice m_basic m_approval m_quadratic m_ranked_choice m_weighted ///
    using "$dao_folder/results/tables/majority_power_analysis_active.rtf", ///
    cells(b(fmt(%9.3f)) se(par) p(fmt(3) par([ ]))) ///
    stats(r2 r2_within N, fmt(%9.3f %9.3f %9.0gc) ///
    labels("R-squared overall" "R-squared within" "Observations")) ///
    legend collabels(none) varlabels(_cons Constant) replace compress label ///
    varwidth(30) modelwidth(10) interaction(" X ") ///
    nodepvars nonumbers noomitted unstack ///
    addnotes("Models include voter and month fixed effects. Clustered standard errors in parentheses; p-values in brackets.")

// Final Active HHI regression and storage
eststo clear
eststo: reghdfe is_majority_win_num ///
    c.active_hhi##(type_basic type_approval type_quadratic type_ranked_choice type_weighted) ///
    c.active_hhi##c.relative_voting_power_act /// 
    prps_len prps_choices_bin prps_rel_quorum ///
    plugin_safesnap strategy_delegation ///
    topic_1-topic_19 ///
    relative_voting_power_act if own_choice_tied == 0, ///
    absorb(voter_id year_month_num) vce(cluster voter_space_id)

// Export to RTF
esttab using "$dao_folder/results/tables/power_concentration_effects_active.rtf", ///
    cells(b(fmt(%9.3f)) se(par) p(fmt(3) par([ ]))) ///
    stats(r2 r2_within N, fmt(%9.3f %9.3f %9.0gc) ///
    labels("R-squared overall" "R-squared within" "Observations")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Effects of Active Voting Power Concentration on Majority-Power Alignment") ///
    note("Standard errors clustered by voter-space ID in parentheses") 
    
// Export to Excel
esttab using "$dao_folder/results/tables/power_concentration_effects_active.csv", ///
    b(3) se(3) wide plain replace

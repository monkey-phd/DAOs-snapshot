*----------------------------------------------
* Initial Setup and Data Loading
*----------------------------------------------
global dao_folder "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data"

use "$dao_folder/processed/panel_almost_full.dta", clear
decode space_id, gen(space_name)

* Create a list of DAO-level variables we'll need
local dao_vars proposal_space_counter space_age votes_dao_cum space_high_scores ///
    space_id_size space_no_vot_types vs_types type_numeric type_approval ///
    type_basic type_quadratic type_ranked_choice type_single_choice ///
    type_weighted prps_rel_quorum prps_quorum_bin dao_creation_date

*----------------------------------------------
* Aggregate Voter Data to Proposal Level
*----------------------------------------------
preserve
    * Keep relevant voter-level variables
    keep space_id space_name proposal_id voter_id ///
        misaligned own_choice_tied misaligned_c ///
        abstain misaligned_wmiss abstain_wmiss mal_c_wmiss
    
    * Remove duplicate voter entries
    bysort space_id proposal_id voter_id: keep if _n == 1
    
    * Calculate mean voter metrics per proposal
    collapse (mean) ///
        mean_misaligned = misaligned ///
        mean_own_choice_tied = own_choice_tied ///
        mean_misaligned_c = misaligned_c ///
        mean_abstain = abstain ///
        mean_misaligned_wmiss = misaligned_wmiss ///
        mean_abstain_wmiss = abstain_wmiss ///
        mean_mal_c_wmiss = mal_c_wmiss, ///
        by(space_id space_name proposal_id)
    tempfile voter_agg
    save `voter_agg'
restore

*----------------------------------------------
* Prepare and Transform Proposal-Level Data
*----------------------------------------------
preserve
    * Keep proposal-specific variables
    keep space_id space_name proposal_id ///
        prps_choices total_votes own_margin prps_len ///
        prps_link prps_stub topic_0-topic_19
    
    * Keep unique proposals
    bysort space_id proposal_id: keep if _n == 1
    
    * Merge with aggregated voter data
    merge 1:1 space_id space_name proposal_id using `voter_agg', assert(match) nogenerate

*----------------------------------------------
* CLR Transformation (compositional nature) of Topic Variables
*----------------------------------------------    
    * Apply CLR transformation
    foreach var of varlist topic_0-topic_19 {
        gen log_`var' = log(`var')
    }
    egen log_sum = rowtotal(log_topic_*)
    gen geom_mean = exp(log_sum / 20)
    
    foreach var of varlist topic_0-topic_19 {
        gen clr_`var' = log(`var'/geom_mean)
    }
    
    * Clean up intermediate variables
    drop log_* log_sum geom_mean
    
    * Aggregate to DAO level
    collapse (mean) clr_topic_*, by(space_id space_name)

*----------------------------------------------
* Cluster Analysis and Validation
*----------------------------------------------
    * Save temporary copy for cluster analysis
    tempfile original_data
    save `original_data'
    
    * Create elbow plot with known CH statistics
    clear
    set obs 9
    gen K = _n + 1
    gen CH_stat = .
    replace CH_stat = 54.34 if K == 2
    replace CH_stat = 37.49 if K == 3
    replace CH_stat = 28.68 if K == 4
    replace CH_stat = 25.77 if K == 5
    replace CH_stat = 22.03 if K == 6
    replace CH_stat = 19.98 if K == 7
    replace CH_stat = 19.50 if K == 8
    replace CH_stat = 15.83 if K == 9
    replace CH_stat = 16.38 if K == 10
    
    * Create and save elbow plot
    twoway connected CH_stat K, ///
        ytitle("Calinski-Harabasz pseudo-F") ///
        xtitle("Number of Clusters (K)") ///
        title("Calinski-Harabasz Statistics by Number of Clusters") ///
        xlabel(2(1)10) ///
        name(ch_plot, replace)
    
    * Return to main analysis
    use `original_data', clear
    
    * Perform hierarchical clustering
    cluster ward clr_topic_*, name(cluster_solution)
    cluster stop cluster_solution, rule(calinski)

*----------------------------------------------
* Final Clustering and Results
*----------------------------------------------    
    * Run k-means clustering with optimal k=3 (based on elbow plot)
    cluster kmeans clr_topic_0-clr_topic_19, k(3) name(final_kmeans)
    rename final_kmeans dao_cluster
    
    * Label the clusters
    label define cluster_labels ///
        1 "Financial and DeFi DAOs" ///
        2 "Gaming, NFTs, and Metaverse DAOs" ///
        3 "Technical and Development-Focused DAOs"
    label values dao_cluster cluster_labels
    
    * Save final clustered dataset
    save "$dao_folder/processed/dao_level_clustered.dta", replace
    
    * Show cluster distribution
    tabulate dao_cluster
    
    * Calculate and display average topic scores by cluster
    preserve
        collapse (mean) clr_topic_0-clr_topic_19, by(dao_cluster)
        list dao_cluster clr_topic_0-clr_topic_19, abbreviate(32)
    restore
restore

/*

"""
Topic 0:
community team support ecosystem development program opportunity product growth cake
Topic 1:
event platform asset offer transfer decentralized key right cover solution
Topic 2:
ipfs link snapshot image en testing type website description page
Topic 3:
nft decentraland grant project experience work funding platform include artist
Topic 4:
member committee content investment council season dao candidate discord choice
Topic 5:
game nft marketing player land metaverse wearable collection dcl world
Topic 6:
risk aave index sell parameter reduce yam product usdt bond
Topic 7:
contract new user smart address revenue use feature set mainnet
Topic 8:
eth treasury fund usdc cost fee team propose mint live
Topic 9:
vote proposal voting option time day month term governance holder
Topic 10:
nfts holder twitter medium social creator sale buy end purchase
Topic 11:
blockchain node year technology network service proof transparency trust policy
Topic 12:
liquidity price market asset protocol token vault increase current emission
Topic 13:
pool gauge lp yield farm frax balancer reward curve incentive
Topic 14:
token reward wallet staking want believe start stake airdrop think
Topic 15:
time make new like space way work help idea open
Topic 16:
project people need month house store world guild magic member
Topic 17:
protocol liquidity chain ethereum crypto token trading fee network uniswap
Topic 18:
dao proposal noun governance month process snapshot multisig specification treasury
Topic 19:
contributor data design development developer bounty phase tool builder resource
"""

Cluster 1
Average Topic Scores for Cluster 1:

Topic	Mean Score
Topic 0	0.1392
Topic 8	0.0748
Topic 11	0.0744
Topic 7	0.0650
Topic 6	0.0642
Topic 5	0.0599
Topic 13	0.0524
Key Topics with Higher Scores in Cluster 1:

Topic 6: Risk Management and Financial Products
Topic 11: Blockchain Technology and Infrastructure
Topic 13: Yield Farming and Liquidity Pools
Topic Keywords:

Topic 6: risk, aave, index, sell, parameter, reduce, yam, product, usdt, bond
Topic 11: blockchain, node, year, technology, network, service, proof, transparency, trust, policy
Topic 13: pool, gauge, lp, yield, farm, frax, balancer, reward, curve, incentive
Interpretation of Cluster 1:

Cluster 1 has higher average scores in topics related to financial services, risk management, blockchain technology, and yield farming. This suggests that DAOs in this cluster focus on:

Decentralized Finance (DeFi): Engaging in activities like yield farming, liquidity provision, and financial product development.
Risk Management: Emphasizing risk parameters and financial security.
Blockchain Infrastructure: Focusing on the underlying technology and network services.
**Label for Cluster 1: Financial and DeFi DAOs

Cluster 2
Average Topic Scores for Cluster 2:

Topic	Mean Score
Topic 0	0.1735
Topic 3	0.1499
Topic 5	0.1131
Topic 14	0.0725
Topic 10	0.0722
Key Topics with Higher Scores in Cluster 2:

Topic 3: NFTs and Funding Projects
Topic 5: Gaming and Metaverse
Topic 10: Social Media and NFTs
Topic 14: Staking and Token Rewards
Topic Keywords:

Topic 3: nft, decentraland, grant, project, experience, work, funding, platform, include, artist
Topic 5: game, nft, marketing, player, land, metaverse, wearable, collection, dcl, world
Topic 10: nfts, holder, twitter, medium, social, creator, sale, buy, end, purchase
Topic 14: token, reward, wallet, staking, want, believe, start, stake, airdrop, think
Interpretation of Cluster 2:

Cluster 2 shows a strong emphasis on NFTs, gaming, metaverse projects, and social media engagement. DAOs in this cluster are likely involved in:

Gaming Platforms: Developing and promoting blockchain-based games and virtual worlds.
NFT Creation and Trading: Focusing on digital collectibles, art, and NFTs.
Community Engagement: Active on social media platforms, fostering creator and user communities.
Token Rewards and Staking: Implementing staking mechanisms and rewarding participants.
Label for Cluster 2: Gaming, NFTs, and Metaverse DAOs

Cluster 3
Average Topic Scores for Cluster 3:

Topic	Mean Score
Topic 0	0.2315
Topic 7	0.1252
Topic 2	0.0725
Topic 8	0.0780
Topic 5	0.0692
Key Topics with Higher Scores in Cluster 3:

Topic 0: Community and Development
Topic 7: Smart Contracts and User Interaction
Topic 2: Technical Details and Testing
Topic Keywords:

Topic 0: community, team, support, ecosystem, development, program, opportunity, product, growth, cake
Topic 7: contract, new, user, smart, address, revenue, use, feature, set, mainnet
Topic 2: ipfs, link, snapshot, image, en, testing, type, website, description, page
Interpretation of Cluster 3:

Cluster 3 is characterized by a strong focus on community building, technical development, and smart contract implementation. DAOs in this cluster likely emphasize:

Technical Development: Working on smart contracts, testing, and deploying technical features.
Community Growth: Building and supporting a community around their projects.
Infrastructure and Tools: Developing tools and resources for the broader ecosystem.
Label for Cluster 3: Technical and Development-Focused DAOs

*/



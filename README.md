# DAOs Snapshot Project

## Overview
This project analyzes voting behavior and governance patterns in Decentralized Autonomous Organizations (DAOs) using data from Snapshot. The analysis combines data from multiple sources to examine voting patterns, proposal outcomes, and governance dynamics across different DAOs.

## Project Structure

### Data Processing Pipeline

#### Python Scripts
1. `1_import_following.py`: Imports and processes DAO following relationships
2. `2_import_spaces.py`: Imports and processes DAO spaces data
3. `3_import_voter.py`: Processes voter-level data and characteristics
4. `4_import_proposals.py`: Imports and processes proposal data including privacy settings
5. `5_import_votes.py`: Processes voting data and participation metrics
6. `6_import_and_merge.py`: Merges various datasets for comprehensive analysis

#### Stata Analysis Scripts
1. Initial Data Preparation:
   - `0_data_prep_iter.do`: Iterative data preparation main
   - `0_data_preparation_iterate.do`: Iterative data preparation 

2. First Analysis:
   - `1_regressions_subsamples.do`: Main subsample analysis
   - `1_regressions_subsamples_v2.do`: Extended subsample analysis
   - `1_regressions_subsamples_hazard.do`: Hazard model analysis
   - `1_regressions_majority_power.do`: Analysis of majority voting power

3. Second Analysis:
   - `2_dao_clusters.do`: DAO clustering analysis
   - `2_regression_discontinuity.do`: Regression discontinuity analysis
   - `2_regressions_effects_of_individual_DAOs.do`: Individual DAO effects
   - `2_regressions_matching.do`: Matching analysis
   - `2_regressions_subsamples.do`: Additional subsample analysis

4. Third Analysis:
   - `3_fe_voting_misalignment.do`: Fixed effects analysis of voting misalignment
   - `3_regression_discontinuity.do`: Additional discontinuity analysis

## Getting Started

### Prerequisites
- Python 3.7+
- Stata 17+
- Required Python packages (install via pip):
  ```bash
  pip install pandas numpy scipy matplotlib seaborn
  ```

### Data Requirements
- Access to Snapshot.org data
- Properly configured environment variables for API access
- Sufficient storage space for data processing

### Running the Analysis
1. Execute Python scripts in numerical order (1-6) to process raw data
2. Run Stata scripts in sequence for analysis
3. Check output folders for results

## Project Organization

```
DAOs-snapshot/
│
├── Python Scripts/          # Data processing and import scripts
├── Stata Scripts/          # Analysis and regression scripts
├── input/                  # Raw data input (not tracked)
├── processed/              # Processed data files (not tracked)
├── output/                 # Analysis output (not tracked)
├── logs/                   # Processing logs (not tracked)
└── results/               # Final results and figures (not tracked)
```

## Contributing
1. Fork the repository
2. Create your feature branch (`git checkout -b feature/YourFeature`)
3. Commit your changes (`git commit -m 'Add YourFeature'`)
4. Push to the branch (`git push origin feature/YourFeature`)
5. Open a Pull Request

## Notes
- Large data files are not tracked in the repository
- Check `.gitignore` for excluded file patterns
- Run scripts sequentially to ensure proper data dependencies
- Temporary files are stored in untracked directories

## Authors and Acknowledgments
- @monkey-phd
- @helgeklapper

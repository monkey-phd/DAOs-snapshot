# DAOs Snapshot Project

## Overview
This project analyzes data related to Decentralized Autonomous Organizations (DAOs). It includes Python and Stata scripts for importing, processing, merging, and analyzing DAO data related to voting, proposals, and other relevant metrics.

## Key Files
- **Python Scripts**:
  - `1_import_following.py`: Script to import and process following data.
  - `2_import_spaces.py`: Script to import and clean spaces data.
  - `3_import_voter.py`: Script to process voter data.
  - `4_import_proposals.py`: Script to import proposal data.
  - `5_import_votes.py`: Script to process vote data.
  - `6_import_and_merge.py`: Script to merge vote data with additional datasets.

- **Stata Files**:
  - `0_data_prep_iter.do`: Prepares data iteratively for analysis.
  - `1_regressions_subsamples_hazard.do`: Runs hazard model on subsamples.
  - `1_regressions_subsamples_v2.do`: Second version of subsample regressions.
  - `1_regressions_subsamples.do`: Runs regressions on subsamples.
  - `2_regression_discontinuity.do`: Applies regression discontinuity analysis.
  - `2_regressions_effects_of_individual_DAOs.do`: Analyzes effects of individual DAOs.
  - `2_regressions_matching.do`: Performs matching regressions.

## Folder Structure
- **Main Directory**: Contains only core scripts (`.py` and `.do` files).
- **Secondary Folders (not tracked)**: Used for organizing temporary or auxiliary files that are not essential to the main analysis.

## Usage
1. **Set up dependencies**: Make sure to install any required Python packages.
2. **Run scripts**: Execute the Python and Stata scripts sequentially as required by the analysis.
3. **Output**: The output files are saved in non-tracked folders for organization.

## Collaboration Guidelines
- **Pull changes** regularly to keep up to date.
- **Only push core files**: Avoid pushing temporary or generated files to keep the repository clean.

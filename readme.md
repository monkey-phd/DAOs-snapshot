# DAOs Snapshot Project

Welcome to the **DAOs Snapshot Project**, where we investigate voting behavior and governance patterns in Decentralized Autonomous Organizations (DAOs). Using data from [Snapshot.org](https://snapshot.org/), we explore how proposals succeed or fail, how members vote, and which governance structures influence outcomes.

---

## Table of Contents

1. [Overview](#overview)  
2. [Key Files & Structure](#key-files--structure)  
3. [Getting Started](#getting-started)  
4. [Contributing](#contributing)  
5. [Authors & Contact](#authors--contact)  
6. [License](#license)

---

## Overview

This repository features both **Python** and **Stata** scripts to:

- **Collect and merge** data on DAOs, proposals, voters, and vote outcomes.  
- **Analyze governance patterns** such as voting alignment, majority power, clustering, and system changes.  
- **Provide statistical insight** through multiple regressions, regression discontinuity, matching approaches, diff-in-diff and more.

---

## Key Files & Structure

Below is a quick guide to the important files in the repo.

### Python Scripts

1. **`1_import_following.py`**  
   - Imports and processes DAO “following” relationships.

2. **`2_import_spaces.py`**  
   - Imports DAO space information from Snapshot.

3. **`3_import_voter.py`**  
   - Processes voter-level data and characteristics.

4. **`4_import_proposals.py`**  
   - Fetches proposal data, including privacy settings.

5. **`5_import_votes.py`**  
   - Processes voting data, focusing on participation metrics.

6. **`6_import_and_merge.py`**  
   - Merges datasets from the above scripts into a final, analysis-ready dataset.

### Stata Scripts

#### Data Preparation

- **`0_data_prep_iter.do`**  
- **`0_data_preparation_iterate.do`**  

Handle iterative data cleaning and basic transformations.

#### Initial Analysis

- **`1_DiD.do`**  
  - A simple difference-in-differences setup.
- **`1_regressions subsamples.do`**  
  - Main subsample analysis.
- **`1_regressions subsamples v2.do`**  
  - Extended subsample analysis.
- **`1_regressions subsamples hazard.do`**  
  - Hazard model approach to voting or proposal duration.
- **`1_regressions_majority_power.do`**  
  - Looks at how majority power influences governance.

#### Second Analysis

- **`2_dao_clusters.do`**  
  - Groups DAOs into clusters based on shared characteristics.
- **`2_DiD_voting_system_change.do`**  
  - Examines changes in voting systems.
- **`2_fe_voting_misalignment_interactions.do`**  
  - Investigates misalignment with fixed effects and interaction terms.
- **`2_fe_voting_misalignment_interactions_matched.do`**  
  - Similar analysis but on a matched dataset.
- **`2_regression discontinuity.do`**  
  - Applies regression discontinuity designs to identify causal effects.
- **`2_regressions effects of individual DAOs.do`**  
  - Isolates the effect of specific DAOs.
- **`2_regressions matching.do`**  
  - Conducts matching-based analyses.
- **`2_regressions subsamples.do`**  
  - Subsample regressions for sensitivity checks.

#### Third Analysis

- **`3_fe_voting_misalignment.do`**  
  - Fixed effects analysis focusing on voting misalignment.
- **`3_fe_voting_misalignment_matched.do`**  
  - Parallel analysis on a matched sample.
- **`3_multi_csdid_interactions.do`**  
  - Multi-voting change DiD approach with interaction terms
- **`3_regression_discontinuity.do`**  
  - Further exploration of regression discontinuity with multiple bandwidths.

---

## Getting Started

### Prerequisites

- **Python 3.7+**  
- **Stata 17+**  
- Python libraries:
  ```bash
  pip install pandas numpy scipy matplotlib seaborn

## Workflow
1. **Run Python scripts** (`1_import_following.py` → `6_import_and_merge.py`) in numerical order.  
2. **Proceed with Stata analysis**, starting with data prep scripts and moving through each analytical script in logical sequence.  
3. **Output** files and results will be stored in your designated output or results directories (not tracked by Git).

## Contributing
We welcome community input—whether bug reports, suggestions, or code contributions.

1. **Fork** the repository.  
2. **Create** a feature branch:
   ```bash
   git checkout -b feature/my-new-feature
3. **Commit your changes**:
    git commit -m "Add a new feature"
4. **Push to the branch**:
    git push origin feature/my-new-feature
5. **Open a Pull Request** to share your improvements with the community.

---

## Authors & Contact
- **@monkey-phd**
- **@helgeklapper**

Feel free to open an issue or PR for any questions, fixes, or ideas!

---

## License
This project is available under the **MIT License**. Please see the license file for more info.

---

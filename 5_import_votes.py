# %%
# Import relevant libraries
import pandas as pd
import numpy as np
import json
import os

# working directory to the parent directory of the script's location
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

votes = pd.read_csv(
    "input/snapshot-hub-mainnet-2023-08-30-votes_0.csv", low_memory=False
)

# Deleting columns that are not useful
del votes["metadata"]
del votes["reason"]
del votes["app"]
del votes["vp_state"]
del votes["cb"]
del votes["ipfs"]
del votes["id"]
# Save the DataFrame as a pickle file
votes.to_pickle("processed/votes_raw.pkl")

verified_dao_spaces = pd.read_csv("input/verified-spaces.csv")
# 2. Extract the unique 'space_name' values into a list
verified_dao_spaces = verified_dao_spaces["space_name"].unique().tolist()

# Count the number of observations per category
counts = votes["space"].value_counts()
print(counts)


# For testing, delete two largest DAOs in terms of votes
# Function to remove 'aave.eth' from lists
# Function to remove a specified string from lists
def remove_string(domain_list, string_to_remove):
    return [domain for domain in domain_list if domain != string_to_remove]


# Apply the function to the 'Domains' column, the four largest
# verified_dao_spaces.remove('aave.eth')
# verified_dao_spaces.remove('opcollective.eth')
# verified_dao_spaces.remove('stgdao.eth')
# verified_dao_spaces.remove('magicappstore.eth')

votes = votes[votes["space"].isin(verified_dao_spaces)]

votes.to_pickle("processed/votes_verified.pkl")

max_rows_votes = len(votes)
print(f"Maximum number of rows in data_basic: {max_rows_votes}")

# %%
# Import relevant libraries
import pandas as pd
import numpy as np
import json

votes = pd.read_pickle("processed/votes_verified.pkl")
props_small = pd.read_pickle("processed/proposals_final.pkl")
# Get winning choice from proposal dataframe
props_small = props_small[["proposal_id", "space", "winning_choices", "type", "scores"]]

votes = votes.merge(
    props_small,
    how="left",
    left_on="proposal",
    right_on="proposal_id",
    suffixes=("", "_space"),
)

del votes["proposal_id"]
del votes["space_space"]

votes.to_pickle("processed/votes_verified_merged.pkl")

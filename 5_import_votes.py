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

max_rows_votes = len(votes)
print(f"Maximum number of rows in data_basic: {max_rows_votes}")

print(votes.columns)

# Filter the dataframe to include only rows where type is 'basic'
basic_votes = votes[votes["type"] == "basic"]

# Count the different numeric choices in the 'choice' column
choice_counts = basic_votes["choice"].value_counts()

print(choice_counts)

# %%
import json
import pandas as pd
import numpy as np

votes = pd.read_pickle("processed/votes_verified_merged.pkl")

# votes = votes[votes['type'] == 'basic']


# Function to determine each voter's alignment with winning choice
def calculate_vote_alignment(data):
    # Mapping each space and proposal to its winning choice
    # winning_choices_by_space_proposal = data.set_index(['space', 'proposal'])['winning_choices'].to_dict()
    Misaligned = []
    Not_Determined = []
    Misaligned_C = []
    Tied = []

    for index, row in data.iterrows():
        voting_type = row.get("type", "")  # Retrieve the voting type if it exists
        winning_choices = row.get("winning_choices", "")

        # Initialize an empty dictionary for voter choices
        # Choice dictionary stores the choice as key and voting power as value
        choice_dict = {}

        # Handle different types of choice
        if isinstance(row["choice"], str):
            if row["choice"].startswith("{") and voting_type in [
                "weighted",
                "quadratic",
            ]:
                # JSON dictionary-like string
                choice_dict = json.loads(row["choice"])
            elif row["choice"].startswith("[") and voting_type in [
                "ranked-choice",
                "approval",
            ]:
                # JSON list-like string for ranked-choice or approval voting
                voter_choices = json.loads(row["choice"])
                if voting_type == "ranked-choice":
                    # Assign weights based on rank position (1st = n, 2nd = n-1, ...)
                    n = len(voter_choices)
                    choice_dict = {
                        str(int(choice)): n - idx
                        for idx, choice in enumerate(voter_choices)
                        if isinstance(choice, (int, str))
                    }
                else:
                    # Approval voting: assign weight of 1 to all choices
                    choice_dict = {
                        str(int(choice)): 1
                        for choice in voter_choices
                        if isinstance(choice, (int, str))
                    }
            else:
                try:
                    # Single choice as a string
                    choice_dict[str(int(row["choice"]))] = 1
                except ValueError:
                    pass
        elif isinstance(row["choice"], (int, float)):
            # Single numeric choice
            choice_dict[str(int(row["choice"]))] = 1

        elif isinstance(row["choice"], list) and voting_type in [
            "ranked-choice",
            "approval",
        ]:
            # List of choices for ranked-choice or approval voting
            if voting_type == "ranked-choice":
                # Assign weights based on rank position (1st = n, 2nd = n-1, ...)
                n = len(row["choice"])
                choice_dict = {
                    str(int(choice)): n - idx
                    for idx, choice in enumerate(row["choice"])
                    if isinstance(choice, (int, str))
                }
            else:
                # Approval voting: assign weight of 1 to all choices
                choice_dict = {
                    str(int(choice)): 1
                    for choice in row["choice"]
                    if isinstance(choice, (int, str))
                }

        if isinstance(winning_choices, list) and len(winning_choices) > 0:
            # Ensure winning_choices is a list of strings to match keys in choice_dict
            if isinstance(winning_choices, str):
                winning_choices = [winning_choices]
            elif isinstance(winning_choices, (int, float)):
                winning_choices = [str(int(winning_choices))]
            elif isinstance(winning_choices, list):
                winning_choices = [
                    str(int(choice))
                    for choice in winning_choices
                    if not pd.isna(choice)
                ]
        # print(winning_choices)

        if voting_type == "basic":
            if not choice_dict:
                Misaligned.append(0)
                Not_Determined.append(1)
                Misaligned_C.append(0)
                Tied.append(0)
                continue
            else:
                basic_choice = list(choice_dict.keys())[0]
                if basic_choice == "3":
                    Misaligned.append(0)
                    Not_Determined.append(1)
                    Misaligned_C.append(0)
                    Tied.append(0)
                    continue

        if isinstance(winning_choices, float) and np.isnan(winning_choices):
            # print('NAN', winning_choices)
            Misaligned.append(0)
            Not_Determined.append(1)
            Misaligned_C.append(0)
            Tied.append(0)
        elif not choice_dict:
            # print('No choice', winning_choices)
            Misaligned.append(0)
            Not_Determined.append(1)
            Misaligned_C.append(0)
            Tied.append(0)
        else:
            # print('Here2')
            total_weight = sum(choice_dict.values())
            # print(winning_choices)
            winning_weight = choice_dict.get(winning_choices[0], 0)

            if total_weight > 0:
                winning_proportion = winning_weight / total_weight
            else:
                winning_proportion = 0

            misalignment_score = 1 - winning_proportion

            # Calculate Misaligned (based on the most weighted choice)
            max_weight = max(choice_dict.values())
            most_weight_choices = [
                choice for choice, weight in choice_dict.items() if weight == max_weight
            ]
            if any(choice in most_weight_choices for choice in winning_choices):
                Misaligned.append(0)  # Fully aligned
            else:
                Misaligned.append(1)  # Fully misaligned

            # Calculate Misaligned_C (based on the proportion of winning choice)
            if winning_proportion > 0:
                Misaligned_C.append(misalignment_score)
            else:
                Misaligned_C.append(
                    1
                )  # Fully misaligned as the winning choice was not selected

            # Calculate Tied (if there are multiple choices with the highest score)
            if len(most_weight_choices) > 1 and any(
                choice in most_weight_choices for choice in winning_choices
            ):
                Tied.append(1)
            else:
                Tied.append(0)

            Not_Determined.append(0)

    return Misaligned, Not_Determined, Misaligned_C, Tied


votes["misaligned"], votes["not_determined"], votes["misaligned_c"], votes["tied"] = (
    calculate_vote_alignment(votes)
)


# %%
import ast


# Function to determine each voter's alignment with winning choice
def calculate_score_own_choice(data):
    # Creating an own score list
    Own_Score_List = []

    for index, row in data.iterrows():
        voting_type = row.get("type", "")  # Retrieve the voting type if it exists
        scores_str = row["scores"]
        # print('Score string', scores_str)
        try:
            scores = ast.literal_eval(scores_str)
            if len(scores) == 0:
                Own_Score_List.append(np.nan)
                continue
        except:
            Own_Score_List.append(np.nan)
            continue
        # print(row['proposal'])
        # print('Scores', scores)

        # Initialize an empty dictionary for voter choices
        # Choice dictionary stores the choice as key and voting power as value
        choice_vp_dict = {}

        if voting_type in ["single-choice", "basic"]:
            # print(voting_type, 'Choice', row['choice'])
            if row["choice"].startswith("{"):
                choice_vp_dict = json.loads(row["choice"])
            elif isinstance(row["choice"], (str)):
                try:
                    choice_vp_dict[str(int(row["choice"]))] = 1
                except:
                    Own_Score_List.append(np.nan)
                    continue
            elif isinstance(row["choice"], (int, float)):
                # Single numeric choice
                choice_vp_dict[str(int(row["choice"]))] = 1

            if voting_type == "basic":
                if not choice_vp_dict:
                    Own_Score_List.append(np.nan)
                    continue
                else:
                    basic_choice = list(choice_vp_dict.keys())[0]
                    if basic_choice == "3":
                        Own_Score_List.append(np.nan)
                        continue
        elif voting_type in ["weighted", "quadratic"]:
            if row["choice"].startswith("{"):
                choice_vp_dict = json.loads(row["choice"])
        elif voting_type == "ranked-choice":
            if row["choice"].startswith("["):
                voter_choices = json.loads(row["choice"])
                n = len(voter_choices)
                choice_vp_dict = {
                    str(int(choice)): n - idx
                    for idx, choice in enumerate(voter_choices)
                    if isinstance(choice, (int, str))
                }
            elif isinstance(row["choice"], list):
                # Assign weights based on rank position (1st = n, 2nd = n-1, ...)
                n = len(row["choice"])
                choice_vp_dict = {
                    str(int(choice)): n - idx
                    for idx, choice in enumerate(row["choice"])
                    if isinstance(choice, (int, str))
                }
            else:
                print("Unknown ", voting_type, " ", row["choice"])
            # Own_Score_List.append(own_score)
        elif voting_type == "approval":
            if row["choice"].startswith("["):
                voter_choices = json.loads(row["choice"])
                n = len(voter_choices)
                choice_vp_dict = {
                    str(int(choice)): 1
                    for choice in voter_choices
                    if isinstance(choice, (int, str))
                }
            elif isinstance(row["choice"], list):
                # Assign weights based on rank position (1st = n, 2nd = n-1, ...)
                n = len(row["choice"])
                choice_vp_dict = {
                    str(int(choice)): 1
                    for choice in row["choice"]
                    if isinstance(choice, (int, str))
                }
            else:
                print("Unknown ", voting_type, " ", row["choice"])
        else:
            # If no known/standard voting type
            Own_Score_List.append(np.nan)
        # print('Choice Dict', choice_vp_dict)
        if not choice_vp_dict:
            Own_Score_List.append(np.nan)
            continue
        own_max_vp = max(choice_vp_dict.values())
        # print('Own max score', own_max_vp)
        own_max_choices = [
            int(key) for key, value in choice_vp_dict.items() if value == own_max_vp
        ]
        own_max_choices = [item - 1 for item in own_max_choices]
        # print('Own max choices', own_max_choices)
        # Select the scores that are voter's max choices
        try:
            own_scores = [scores[index] for index in own_max_choices]
        except:
            Own_Score_List.append(np.nan)
            continue
        # print('Slice of scores', own_scores)
        max_own_score = max(own_scores)
        # print('Max own score', max_own_score)
        Own_Score_List.append(max_own_score)

    return Own_Score_List


votes["own_score"] = calculate_score_own_choice(votes)

# %%
votes["created"] = pd.to_datetime(votes["created"], unit="s")

votes.rename(columns={"created": "vote_created"}, inplace=True)
votes.rename(columns={"vp": "voting_power"}, inplace=True)

print(votes.columns)


# %%
# Select only the specified columns
votes = votes[
    [
        "voter",
        "vote_created",
        "space",
        "proposal",
        "choice",
        "voting_power",
        "vp_by_strategy",
        "winning_choices",
        "type",
        "misaligned",
        "not_determined",
        "scores",
        "misaligned_c",
        "tied",
        "own_score",
    ]
]

# Save the DataFrame as a CSV file
votes.to_csv("processed/votes.csv", index=False)

# Save the DataFrame as a pickle file
votes.to_pickle("processed/votes.pkl")

# %%
import pandas as pd

votes = pd.read_pickle("processed/votes.pkl")

votes.groupby(["type"])["misaligned"].mean()

# %%
import pandas as pd

votes = pd.read_pickle("processed/votes.pkl")

votes = votes[
    [
        "voter",
        "vote_created",
        "space",
        "proposal",
        "choice",
        "voting_power",
        "winning_choices",
        "type",
        "misaligned",
        "misaligned_c",
    ]
]

# votes = pd.read_pickle('processed/votes_verified.pkl')
props_weird = pd.read_pickle("processed/proposals_final.pkl")
# Get winning choice from proposal dataframe
# props_weird = props_small[['proposal_id', 'space', 'winning_choice', 'type']]

props_weird = props_weird[["proposal_id", "quorum", "scores_total", "prps_choices"]]

votes = votes.merge(
    props_weird,
    how="left",
    left_on="proposal",
    right_on="proposal_id",
    suffixes=("", "_space"),
)

votes["rel_vp"] = votes["voting_power"] / votes["scores_total"]

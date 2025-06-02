# Import relevant libraries
import pandas as pd
import numpy as np
import json
import ast
import os

# working directory to the parent directory of the script's location
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


# Function to determine each voter's alignment with winning choice
def calculate_vote_alignment(data):
    Misaligned = []
    Not_Determined = []
    Misaligned_C = []
    Tied = []

    for index, row in data.iterrows():
        space = row["space"]
        proposal = row["proposal"]
        winning_choices = row["winning_choices"]
        voting_type = row.get("type", "")  # Retrieve the voting type if it exists

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

        # print(winning_choices)

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

        if voting_type == "basic" or voting_type == "single-choice-abstain":
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

        if isinstance(winning_choices, list) and len(winning_choices) == 0:
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


def calculate_own_margin(data):
    # Creating an own score list
    own_margin_list = []

    for index, row in data.iterrows():
        voting_type = row.get("type", "")  # Retrieve the voting type if it exists
        margins_list = str(row["margins"])
        # print('Margins string', margins_list)
        try:
            margins = ast.literal_eval(margins_list)
            if len(margins) == 0:
                own_margin_list.append(np.NaN)
                continue
        except:
            own_margin_list.append(np.NaN)
            continue
        # print(row['proposal'])
        # print('Margins', margins)

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
                    own_margin_list.append(np.NaN)
                    continue
            elif isinstance(row["choice"], (int, float)):
                # Single numeric choice
                choice_vp_dict[str(int(row["choice"]))] = 1

            if voting_type == "basic":
                if not choice_vp_dict:
                    own_margin_list.append(np.NaN)
                    continue
                else:
                    basic_choice = list(choice_vp_dict.keys())[0]
                    if basic_choice == "3":
                        own_margin_list.append(np.NaN)
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
                # Assign weights based on 1 for all approved choices
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
            own_margin_list.append(np.NaN)
        # print('Choice Dict', choice_vp_dict)
        if not choice_vp_dict:
            own_margin_list.append(np.NaN)
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
            own_margins = [margins[index] for index in own_max_choices]
        except:
            own_margin_list.append(np.NaN)
            continue
        # print('Slice of scores', own_scores)
        max_own_margin = max(own_margins)
        # print('Max own score', max_own_score)
        own_margin_list.append(max_own_margin)

    return own_margin_list


# Majority vs power winners calculation functions


def parse_vote_choice(choice, vote_type):
    """Parse vote choice into a dictionary {choice: weight} based on the vote type."""
    if pd.isna(choice) or not choice:
        return {}

    # Convert numeric single choices directly
    if isinstance(choice, (int, float)):
        return {str(int(choice)): 1.0}

    # For string inputs:
    if not isinstance(choice, str):
        return {}

    if vote_type in ["basic", "single-choice", "single-choice-abstain"]:
        # Single-choice or basic (including single-choice-abstain):
        # The user selects exactly one option
        try:
            selected_choice = int(float(choice))
            return {str(selected_choice): 1.0}
        except ValueError:
            return {}

    elif vote_type in ["weighted", "quadratic"]:
        # Weighted and quadratic votes: JSON dictionary format
        # The dictionary stores allocated weights or quadratic votes for each choice
        if choice.startswith("{"):
            try:
                weights = json.loads(choice)
                if isinstance(weights, dict):
                    # Convert all keys to strings and values to floats
                    return {
                        str(k): float(v) for k, v in weights.items() if float(v) > 0
                    }
            except:
                return {}
        return {}

    elif vote_type == "approval":
        # Approval voting: the user can approve multiple choices equally
        if choice.startswith("["):
            try:
                approved_choices = json.loads(choice)
                if isinstance(approved_choices, list) and approved_choices:
                    # Each approved choice gets an equal share of weight out of 1
                    weight_per_choice = 1.0 / len(approved_choices)
                    return {
                        str(int(c)): weight_per_choice
                        for c in approved_choices
                        if not pd.isna(c)
                    }
            except:
                return {}
        return {}

    elif vote_type == "ranked-choice":
        # Ranked-choice: the user provides an ordered list of preferences
        if choice.startswith("["):
            try:
                ranked_choices = json.loads(choice)
                if isinstance(ranked_choices, list) and ranked_choices:
                    # Assign descending weights by rank (top choice = n, second = n-1, etc.)
                    n = len(ranked_choices)
                    return {
                        str(int(ch)): float(n - i)
                        for i, ch in enumerate(ranked_choices)
                        if not pd.isna(ch)
                    }
            except:
                return {}
        return {}

    return {}


def calculate_winners_for_proposal(proposal_group):
    """Calculate majority and power-weighted winners for a proposal based on vote type."""
    vote_type = proposal_group["type"].iloc[0]
    raw_vote_counts = {}
    power_sums = {}

    for _, vote in proposal_group.iterrows():
        user_vp = vote.get("vp", 0.0)
        choice_weights = parse_vote_choice(vote.get("choice"), vote_type)

        # Sum of all weights allocated by the user
        total_user_weight = sum(choice_weights.values())

        if total_user_weight <= 0:
            continue

        # Each user contributes to raw votes and power sums based on their choices' proportions
        for ch, wt in choice_weights.items():
            # For raw vote count:
            if vote_type in ["weighted", "quadratic", "ranked-choice", "approval"]:
                # Weighted or Quadratic or ranked-choice or approval scenario
                raw_vote_increment = wt
            else:
                # Single-Choice, Basic, Single-Choice-Abstain:
                fraction = wt / total_user_weight if total_user_weight > 0 else 0
                raw_vote_increment = fraction

            raw_vote_counts[ch] = raw_vote_counts.get(ch, 0.0) + raw_vote_increment

            # For power sums:
            if total_user_weight > 0:
                if vote_type in ["weighted", "quadratic"]:
                    # Weighted or quadratic scenario
                    power_contribution = user_vp * (wt / total_user_weight)
                else:
                    # For other voting types, distribute user power proportionally
                    fraction = wt / total_user_weight
                    power_contribution = user_vp * fraction
            else:
                power_contribution = 0.0

            power_sums[ch] = power_sums.get(ch, 0.0) + power_contribution

    if not raw_vote_counts:
        # If no votes or invalid data, return default values
        return pd.Series(
            {
                "majority_choice": None,
                "majority_votes": 0.0,
                "power_winner": None,
                "total_vp": 0.0,
                "is_majority_win": None,
            }
        )

    # Determine the majority winner (choice with the maximum raw vote count)
    majority_choice, majority_votes = max(raw_vote_counts.items(), key=lambda x: x[1])

    if not power_sums:
        # If no valid power sums data
        return pd.Series(
            {
                "majority_choice": majority_choice,
                "majority_votes": majority_votes,
                "power_winner": None,
                "total_vp": 0.0,
                "is_majority_win": None,
            }
        )

    # Determine the power-weighted winner (choice with the maximum weighted voting power)
    power_winner, total_vp = max(power_sums.items(), key=lambda x: x[1])
    is_majority_win = majority_choice == power_winner
    is_majority_win = 1 if is_majority_win else 0

    return pd.Series(
        {
            "majority_choice": majority_choice,
            "majority_votes": majority_votes,
            "power_winner": power_winner,
            "total_vp": total_vp,
            "is_majority_win": is_majority_win,
        }
    )


proposals = pd.read_pickle("processed/proposals_final.pkl")
spaces = pd.read_pickle("processed/spaces.pkl")
follows = pd.read_pickle("processed/follows.pkl")
users = pd.read_pickle("processed/users.pkl")
votes = pd.read_pickle("processed/votes_verified_merged.pkl")
verified_dao_spaces = pd.read_csv("input/verified-spaces.csv")

# 2. Extract the unique 'space_name' values into a list
verified_dao_spaces = verified_dao_spaces["space_name"].unique().tolist()

for space in verified_dao_spaces:
    votes_small = votes[votes["space"] == space].copy()
    max_rows_votes = len(votes_small)
    print("Maximum number of rows in", space, " :", max_rows_votes)
    if max_rows_votes == 0:
        print("No votes in this DAO ", space)
        continue

    result_comparison = (
        votes_small.groupby("proposal")
        .apply(calculate_winners_for_proposal)
        .reset_index()
    )
    votes_small = votes_small.merge(
        result_comparison[["proposal", "is_majority_win"]], on="proposal", how="left"
    )

    (
        votes_small["misaligned"],
        votes_small["not_determined"],
        votes_small["misaligned_c"],
        votes_small["tied"],
    ) = calculate_vote_alignment(votes_small)
    votes_small["own_margin"] = calculate_own_margin(votes_small)
    votes_small["created"] = pd.to_datetime(votes_small["created"], unit="s")
    votes_small.rename(columns={"created": "vote_created"}, inplace=True)
    votes_small.rename(columns={"vp": "voting_power"}, inplace=True)
    votes_small.rename(columns={"tied": "own_choice_tied"}, inplace=True)

    # Select only the specified columns
    votes_small = votes_small[
        [
            "voter",
            "vote_created",
            "space",
            "proposal",
            "choice",
            "voting_power",
            "vp_by_strategy",
            "margins",
            "misaligned",
            "not_determined",
            "misaligned_c",
            "own_choice_tied",
            "own_margin",
            "is_majority_win",
        ]
    ]
    # Save the DataFrame as a CSV file

    # Sequentially merge dataframes
    merged_df = votes_small.merge(
        proposals,
        how="left",
        left_on="proposal",
        right_on="proposal_id",
        suffixes=("", "_proposal"),
    )
    merged_df = merged_df.merge(
        spaces,
        how="left",
        left_on="space",
        right_on="space_id",
        suffixes=("", "_space"),
    )
    merged_df = merged_df.merge(
        follows,
        how="left",
        left_on=["voter", "space"],
        right_on=["follower", "space"],
        suffixes=("", "_follow"),
    )
    merged_df = merged_df.merge(
        users, how="left", left_on="voter", right_on="voter_id", suffixes=("", "_user")
    )

    # Keep these columns and drop the rest for performance improvement
    required_columns = [
        "voter",
        "vote_created",
        "space",
        "proposal",
        "choice",
        "voting_power",
        "misaligned",
        "not_determined",
        "own_choice_tied",
        "misaligned_c",
        "prps_author",
        "prps_created",
        "type",
        "prps_safesnap",
        "prps_delegation",
        "prps_start",
        "prps_end",
        "quorum",
        "met_quorum",
        "scores_total",
        "prps_choices",
        "votes",
        "own_margin",
        "prps_len",
        "prps_link",
        "prps_stub",
        "privacy",
        "topic_0",
        "topic_1",
        "topic_2",
        "topic_3",
        "topic_4",
        "topic_5",
        "topic_6",
        "topic_7",
        "topic_8",
        "topic_9",
        "topic_10",
        "topic_11",
        "topic_12",
        "topic_13",
        "topic_14",
        "topic_15",
        "topic_16",
        "topic_17",
        "topic_18",
        "topic_19",
        "space_created_at",
        "voter_created",
        "winning_choices",
        "is_majority_win",
    ]

    # Only keep required columns
    merged_df = merged_df[required_columns]

    file_string = "input/dao/data_" + space + ".csv"

    # Save the DataFrame as a CSV file
    merged_df.to_csv(file_string, index=False)

print("Done")

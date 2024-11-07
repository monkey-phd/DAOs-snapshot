# %%
import pandas as pd
import numpy as np
import json
from itertools import zip_longest

# Read in the tables from CSV files
votes = pd.read_pickle("processed/votes.pkl")
proposals = pd.read_pickle("processed/proposals_final.pkl")
spaces = pd.read_pickle("processed/spaces.pkl")
follows = pd.read_pickle("processed/follows.pkl")
users = pd.read_pickle("processed/users.pkl")

# Sequentially merge dataframes
merged_df = votes.merge(
    proposals,
    how="left",
    left_on="proposal",
    right_on="proposal",
    suffixes=("", "_proposal"),
)
merged_df = merged_df.merge(
    spaces, how="left", left_on="space", right_on="space_id", suffixes=("", "_space")
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

print(merged_df.columns)

# %%
# Keep these columns and drop the rest for performance improvement
required_columns = [
    "voter",
    "vote_created",
    "space",
    "proposal",
    "choice",
    "voting_power",
    "vp_by_strategy",
    "winning_choices",
    "misaligned",
    "not_determined",
    "misaligned_c",
    "prps_author",
    "prps_created",
    "type",
    "prps_start",
    "prps_end",
    "quorum",
    "scores_total",
    "votes",
    "strategy_name",
    "prps_len",
    "prps_link",
    "prps_stub",
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
    "start_follow_space",
    "voter_created",
    "voter_name",
    "voter_about_len",
    "voter_avatar_b",
]

# Only keep required columns
merged_df = merged_df[required_columns]

# Save the DataFrame as a CSV file
merged_df.to_csv("input/data_clean.csv", index=False)
merged_df.to_pickle("input/data_clean.pkl")


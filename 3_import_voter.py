import os
# Import relevant libraries
import pandas as pd
import json

# working directory to the parent directory of the script's location
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Load the users CSV file into a DataFrame
users = pd.read_csv("input/snapshot-hub-mainnet-2023-08-30-users_0.csv")


# Function to parse the JSON field in the 'profile' column
def parse_json(json_str):
    try:
        json_data = json.loads(json_str)
        name = json_data.get("name", "").strip()
        about = json_data.get("about", "").strip()
        avatar = json_data.get("avatar", "").strip()
        return name, about, avatar
    except json.JSONDecodeError:
        return None, None, None


# Apply the function to the 'profile' column and create new columns
users[["voter_name", "about", "avatar"]] = users["profile"].apply(
    lambda x: pd.Series(parse_json(x))
)

# Create binary column 'voter_avatar_b' to indicate if 'avatar' is not empty
users["voter_avatar_b"] = users["avatar"].apply(lambda x: 1 if x else 0)

# Create 'voter_about_len' column to measure the length of the 'about' column
users["voter_about_len"] = users["about"].str.len()

# Rename remaining columns in a single step
users.rename(columns={"id": "voter_id", "created": "voter_created"}, inplace=True)

# Select only the specified columns
selected_columns = users[
    ["voter_id", "voter_created", "voter_name", "voter_about_len", "voter_avatar_b"]
]

# Save the DataFrame as CSV and Pickle files
selected_columns.to_csv("processed/users.csv", index=False)
selected_columns.to_pickle("processed/users.pkl")

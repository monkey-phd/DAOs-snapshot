# %%
# Import relevant libraries
import pandas as pd
import numpy as np
import json

# working directory to the parent directory of the script's location
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Load the CSV file
spaces = pd.read_csv("input/snapshot-hub-mainnet-2023-08-30-spaces_0.csv")


def parse_json_column_to_columns(df, column_name):
    """
    Parse a column containing JSON-formatted strings into a dictionary
    and expand the JSON data into separate columns.

    Args:
        df (pd.DataFrame): The DataFrame containing the column to parse.
        column_name (str): The name of the column containing JSON strings.

    Returns:
        pd.DataFrame: A DataFrame with the original data and new columns
                      generated from the JSON fields.
    """
    # Parse JSON strings into dictionaries
    df[column_name] = df[column_name].apply(json.loads)

    # Expand the parsed JSON column into separate columns
    json_expanded_df = pd.json_normalize(df[column_name])

    # Concatenate the original DataFrame with the expanded JSON DataFrame
    df = pd.concat([df.drop(columns=[column_name]), json_expanded_df], axis=1)

    # Remove columns that have at most one non-NaN value
    df = df.loc[:, df.notna().sum() > 2]

    return df


# Parse the 'settings' column
spaces = parse_json_column_to_columns(spaces, "settings")

# Remove duplicated columns
spaces = spaces.loc[:, ~spaces.columns.duplicated()]

# Print the number of rows and columns
max_rows_votes = len(spaces)
print(f"Maximum number of rows in dataframe: {max_rows_votes}")
print(spaces.columns)

# %%
# Rename columns for clarity
spaces.rename(
    columns={"id": "space_id", "created_at": "space_created_at"}, inplace=True
)

# Convert 'space_created_at' to datetime format
spaces["space_created_at"] = pd.to_datetime(spaces["space_created_at"], unit="s")

# Select only the specified columns
spaces = spaces[["space_id", "space_created_at"]]

# Save the DataFrame as a CSV file
spaces.to_csv("processed/spaces.csv", index=False)

# Save the DataFrame as a pickle file
spaces.to_pickle("processed/spaces.pkl")

# Filter for DAO Verified Spaces only
# Load the CSV file containing the verified DAO spaces
verified_daos = pd.read_csv("input/verified-spaces.csv")

# Extract the unique 'space_name' values into a list
verified_dao_list = verified_daos["space_name"].unique().tolist()

# Use the list to filter rows in 'spaces'
spaces_verified = spaces[spaces["space_id"].isin(verified_dao_list)]

# Save the verified DAO spaces DataFrame as a CSV file
spaces_verified.to_csv("processed/spaces_verified.csv", index=False)

# Save the verified DAO spaces DataFrame as a pickle file
spaces_verified.to_pickle("processed/spaces_verified.pkl")

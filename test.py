


#%%

import pandas as pd
import pyreadstat
import numpy as np
import os

# Define the path to your data folder
dao_folder = "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data"

# Define the path to your large .dta file
data_path = os.path.join(dao_folder, "processed", "panel_full.dta")

# Define the directory where you want to save the split files
output_dir = os.path.join(dao_folder, "processed", "split_files")

# Create the output directory if it doesn't exist
if not os.path.exists(output_dir):
    os.makedirs(output_dir)

# Define the maximum number of rows per chunk (adjust as needed)
max_rows_per_chunk = 10_000_000  # For example, 10 million rows per chunk

# Initialize variables
chunk_list = []  # To store data chunks
total_rows = 0
file_number = 1

# Create an empty DataFrame to track panel IDs assigned to each file
panel_id_assignments = pd.DataFrame(columns=["voter_space_id", "file_number"])

# Use pyreadstat to read the .dta file in chunks
reader = pyreadstat.read_file_in_chunks(
    pyreadstat.read_dta, data_path, chunksize=1_000_000
)

for df_chunk, meta in reader:
    # Append chunk to the list
    chunk_list.append(df_chunk)
    total_rows += len(df_chunk)

    # If total_rows exceeds max_rows_per_chunk, process and save the data
    if total_rows >= max_rows_per_chunk:
        # Concatenate all chunks
        df_concat = pd.concat(chunk_list)

        # Determine which voter_space_ids are in this chunk
        voter_space_ids = df_concat["voter_space_id"].unique()

        # Assign voter_space_ids to this file_number
        assignments = pd.DataFrame(
            {"voter_space_id": voter_space_ids, "file_number": file_number}
        )
        panel_id_assignments = pd.concat([panel_id_assignments, assignments])

        # Filter the DataFrame to include only voter_space_ids assigned to this file
        df_concat = df_concat[df_concat["voter_space_id"].isin(voter_space_ids)]

        # Save the concatenated DataFrame to a .dta file
        output_file = os.path.join(output_dir, f"panel_full_chunk_{file_number}.dta")
        pyreadstat.write_dta(df_concat, output_file)
        print(f"Saved chunk {file_number} to {output_file}")

        # Reset variables for the next chunk
        chunk_list = []
        total_rows = 0
        file_number += 1

# Handle any remaining data in chunk_list after the loop
if chunk_list:
    df_concat = pd.concat(chunk_list)
    voter_space_ids = df_concat["voter_space_id"].unique()
    assignments = pd.DataFrame(
        {"voter_space_id": voter_space_ids, "file_number": file_number}
    )
    panel_id_assignments = pd.concat([panel_id_assignments, assignments])
    output_file = os.path.join(output_dir, f"panel_full_chunk_{file_number}.dta")
    pyreadstat.write_dta(df_concat, output_file)
    print(f"Saved final chunk {file_number} to {output_file}")

# Save panel_id_assignments for reference
assignments_file = os.path.join(output_dir, "panel_id_assignments.csv")
panel_id_assignments.to_csv(assignments_file, index=False)
print(f"Saved panel ID assignments to {assignments_file}")

import pyreadstat

# Replace with the path to one of your chunked .dta files
chunk_file = "processed/split_files/panel_full_chunk_1.dta"

# Read the .dta file
df_chunk, meta = pyreadstat.read_dta(chunk_file)

# Get the number of variables
num_variables = len(df_chunk.columns)
print(f"The dataset has {num_variables} variables.")

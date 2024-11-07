# %%
import pandas as pd

# Load the proposal data
props = pd.read_pickle("processed/proposals_final_verified.pkl")
print(props.columns)

# Set display options to show all columns in a cleaner format
pd.set_option("display.max_columns", None)  # Display all columns
pd.set_option("display.max_rows", 20)  # Adjust the number of rows to display
props.head(10)

# %%

import pandas as pd
from sklearn.cluster import KMeans
import matplotlib.pyplot as plt
from sklearn.metrics import silhouette_score

# Load the proposal data
props = pd.read_pickle("processed/proposals_final_verified.pkl")

# Step 1: Aggregate topic scores by DAO (space) to get a topic distribution profile
dao_topic_profile = props.groupby("space")[[f"topic_{i}" for i in range(20)]].mean()
print("Topic Distribution Profile per DAO:")
print(dao_topic_profile.head())

# Step 2: Perform clustering on the topic distribution profiles
# Determine optimal number of clusters using the Elbow Method and Silhouette Score
sse = []
silhouette_scores = []

for k in range(2, 10):  # Test different numbers of clusters
    kmeans = KMeans(n_clusters=optimal_k, random_state=42, n_init=10)
    kmeans.fit(dao_topic_profile)
    sse.append(kmeans.inertia_)  # Sum of squared errors
    silhouette_scores.append(silhouette_score(dao_topic_profile, kmeans.labels_))

# Plot the Elbow Method and Silhouette Score
plt.figure(figsize=(14, 6))
plt.subplot(1, 2, 1)
plt.plot(range(2, 10), sse, marker="o")
plt.xlabel("Number of Clusters")
plt.ylabel("SSE")
plt.title("Elbow Method for Optimal k")

plt.subplot(1, 2, 2)
plt.plot(range(2, 10), silhouette_scores, marker="o")
plt.xlabel("Number of Clusters")
plt.ylabel("Silhouette Score")
plt.title("Silhouette Scores for Different k Values")

plt.tight_layout()
plt.show()

# Step 3: Cluster with the chosen number of clusters (optimal_k from analysis)
optimal_k = 4  # Adjust based on Elbow and Silhouette analysis
kmeans = KMeans(n_clusters=optimal_k, random_state=42)
dao_topic_profile["cluster"] = kmeans.fit_predict(dao_topic_profile)

# View clustering results
print("DAO Clusters:")
print(dao_topic_profile[["cluster"]].head())

# Display the full DAO clusters in a scrollable table format
dao_profile.reset_index(inplace=True)  # Reset index to make 'space' a column
dao_profile[
    ["space", "cluster"]
]  # Display only 'space' and 'cluster' columns for clarity

# If you want a more interactive or larger view:
from IPython.display import display, HTML

display(
    HTML(dao_profile.to_html(max_rows=100, max_cols=20))
)  # Adjust `max_rows` as needed


# %%
from IPython.display import display, HTML

# Identify the dominant topic for each proposal
props["dominant_topic"] = props[[f"topic_{i}" for i in range(20)]].idxmax(axis=1)

# Count occurrences of each dominant topic within each DAO
topic_dominance = (
    props.groupby(["space", "dominant_topic"]).size().unstack(fill_value=0)
)
print("Topic Dominance per DAO:")
print(topic_dominance.head())

# Display as an HTML table
display(HTML(topic_dominance.to_html(max_rows=10, max_cols=20)))


# %% load the data and focus only on verified spaces

# Step 1: Load the proposal data
props = pd.read_pickle("processed/proposals_final.pkl")

# Display the first few rows and column headers to inspect the data
print("Initial Data Sample:")
print(props.head())

print("\nColumn Headers:")
print(props.columns)

# Step 2: Display specific columns to get a sense of data structure
print("\nSpace, ID, and Body Columns:")
print(props[["space", "id", "body"]].head())

# Step 3: Count the number of unique spaces in the original data
initial_unique_spaces = props["space"].nunique()
print(f"\nInitial Unique Spaces: {initial_unique_spaces}")

# Step 4: Load the verified spaces CSV file and rename the column to match 'space'
spaces = pd.read_csv("input/verified-spaces.csv")
spaces = spaces.rename(columns={"space_name": "space"})

# Step 5: Filter the proposals DataFrame to retain only verified spaces
props = props[props["space"].isin(spaces["space"])]

# Step 6: Count the number of unique spaces after filtering
final_unique_spaces = props["space"].nunique()
print(f"\nFiltered Unique Spaces: {final_unique_spaces}")

# Optional: Save the filtered data as a new pickle file if you plan to use it later
props.to_pickle("processed/proposals_final_verified.pkl")

# Display a sample of the filtered DataFrame
print("\nFiltered Data Sample:")
print(props.head())

# %%
# Import relevant libraries
import pandas as pd
import numpy as np
import json

# working directory to the parent directory of the script's location
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Now your original line will work as expected
props = pd.read_csv(
    "input/snapshot-hub-mainnet-2023-08-30-proposals_0.csv", low_memory=False
)


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


# spaces = parse_json_column_to_columns(spaces, 'settings')
max_rows_votes = len(props)
print(f"Maximum number of rows in dataframe: {max_rows_votes}")

# Drop proposals that have only one voter
props = props[props["votes"] > 1]

print(props.columns)

max_rows_votes = len(props)
print(f"Maximum number of rows in dataframe: {max_rows_votes}")


# %%
import ast
import pandas as pd
import numpy as np


def determine_winning_choice_and_score(row):
    # Extracting scores
    scores = row["scores"]
    voting_type = row.get("type", "")  # Retrieve the voting type if it exists
    quorum = row["quorum"]
    scores_total = row["scores_total"]

    # Check if scores is not null and not empty
    if not (pd.isnull(scores)) and scores:
        # Decoding the stringified lists
        scores_list = ast.literal_eval(scores)

        # Convert all elements to integers
        scores_list = [
            int(x) if isinstance(x, str) and x.isdigit() else x for x in scores_list
        ]

        # Check if scores_list is not empty
        if scores_list:
            # If voting type is 'basic', ignore the score for option 3
            if voting_type == "basic" and len(scores_list) >= 3:
                scores_list = scores_list[:2]
            # Find the maximum score and its indexes
            max_score = max(scores_list)
            max_indexes = [
                i + 1 for i, score in enumerate(scores_list) if score == max_score
            ]  # Add 1 to make it start from 1

            # Remove only one instance of the maximum score to find the second highest score
            scores_list.remove(max_score)
            second_max_score = max(scores_list) if scores_list else None

            # Check for multiple winning choices
            if scores_total >= quorum:
                met_quorum = 1
            else:
                met_quorum = 0

            return max_indexes, max_score, second_max_score, met_quorum
    return None, None, None, None


# Apply the function to the filtered dataset data_basic
props[["winning_choices", "winning_score", "second_score", "met_quorum"]] = props.apply(
    determine_winning_choice_and_score, axis=1, result_type="expand"
)

# Number of choices
props["choices"] = props["choices"].apply(ast.literal_eval)
props["prps_choices"] = props["choices"].apply(len)


# %%
# Strategy mapping
# Function to parse the JSON field in the data
def extract_first_field(json_str):
    try:
        # Parse the JSON string into a dictionary or list of dictionaries
        data = json.loads(json_str)
        # Handle dictionary case
        if isinstance(data, dict):
            if data:
                first_key = next(iter(data))  # Get the first key
                return data[first_key]  # Return the first key-value pair
        # Handle list of dictionaries case
        elif isinstance(data, list) and len(data) > 0 and isinstance(data[0], dict):
            first_dict = data[0]  # Get the first dictionary in the list
            if first_dict:
                first_key = next(iter(first_dict))  # Get the first key
                return first_dict[first_key]  # Return the first key-value pair
        return None
    except json.JSONDecodeError:
        return None


props["strategy_name"] = props["strategies"].apply(extract_first_field)

# Parse 'plugins' and 'strategies' columns
props["plugins"] = props["plugins"].apply(
    lambda x: json.loads(x) if isinstance(x, str) and x.strip() != "" else {}
)
props["strategies"] = props["strategies"].apply(
    lambda x: json.loads(x) if isinstance(x, str) and x.strip() != "" else []
)

# Create indicator columns
props["plugin_safesnap"] = props["plugins"].apply(lambda x: 1 if "safeSnap" in x else 0)
props["strategy_delegation"] = props["strategies"].apply(
    lambda x: 1
    if any("delegation" in strategy.get("name", "") for strategy in x)
    else 0
)

# %%
# Determine whether overlapping
# Check whether prior proposals end time is later than current proposals start time
# Sort the DataFrame by Category, Space, and StartTime
props = props.sort_values(by=["space", "start"])

# Shift the EndTime column within each group
props["prior_end"] = props.groupby("space")["end"].shift()

# Create the overlap column
props["overlap"] = (props["start"] > props["prior_end"]).astype(int)

del props["prior_end"]
# Save the DataFrame as a pickle file
props.to_pickle("processed/proposals.pkl")

# %%
import pandas as pd
import json
from itertools import zip_longest

props_text = props["body"]
props_text.to_csv("processed/proposal_text.csv", index=False)
# What about foreign languages?
# Just use length
# discussion link
# How many section

# %%
import pandas as pd
from sklearn.feature_extraction.text import CountVectorizer
from nltk.corpus import stopwords
from nltk.stem import WordNetLemmatizer
from nltk.tokenize import word_tokenize
import nltk
import re
from langdetect import detect, DetectorFactory
from langdetect.lang_detect_exception import LangDetectException

nltk.download("punkt")
nltk.download("stopwords")
nltk.download("wordnet")
nltk.download("punkt_tab")
# Check

# Ensure consistent results
DetectorFactory.seed = 0

props = pd.read_pickle("processed/proposals.pkl")

# Assuming data_clean contains 'title' and 'body' columns
# Combine titles and bodies with a space in between and ensure all are strings
props["body"] = props["body"].astype(str)


# Function to check for links and remove them
def process_text(text):
    url_pattern = re.compile(r"http[s]?://\S+")
    has_link = bool(url_pattern.search(text))
    cleaned_text = url_pattern.sub("", text)
    return has_link, cleaned_text


def remove_non_english(text):
    try:
        # Detect the language of the text
        lang = detect(text)
        # If the detected language is not English, return an empty string
        if lang != "en":
            return ""
        return text
    except LangDetectException:
        # If language detection fails, return the original text
        return text


# Function to keep only specific Unicode characters in the text
def keep_specific_unicode_characters(text):
    return re.sub(r"[^\u0000-\u0370]", "", text)


props["prps_len"] = props["body"].apply(len)

# Apply the function to the dataframe
props[["prps_link", "body"]] = props["body"].apply(lambda x: pd.Series(process_text(x)))

# Convert the boolean prps_link to integer
props["prps_link"] = props["prps_link"].astype(int)

# Update prps_link to 1 if discussion is not empty and is a string with length > 5
props["discussion"] = props["discussion"].astype(str)
props["prps_link"] = props.apply(
    lambda row: 1
    if isinstance(row["discussion"], str) and len(row["discussion"]) > 5
    else row["prps_link"],
    axis=1,
)

# Delete texts if they are shorter than 15 characters
props["prps_stub"] = props["body"].apply(lambda x: 1 if len(x) < 15 else 0)

props.loc[props["prps_stub"] == 1, "body"] = ""

# Remove non-English parts of the text
props["body"] = props["body"].apply(remove_non_english)

# Keep only specific Unicode characters in the text
props["body"] = props["body"].apply(keep_specific_unicode_characters)

# Tokenization, removing stop words, and lemmatization
stop_words = set(stopwords.words("english"))
lemmatizer = WordNetLemmatizer()


def preprocess_text(text):
    # Tokenize
    tokens = word_tokenize(text)
    # Remove stop words and lemmatize
    lemmatized_tokens = [
        lemmatizer.lemmatize(word.lower())
        for word in tokens
        if word.isalpha() and word.lower() not in stop_words
    ]
    return " ".join(lemmatized_tokens)


# Save the DataFrame as a pickle file
props.to_pickle("processed/proposals_formatted.pkl")

# Apply the preprocessing to each combined text
proposal_text = props["body"].apply(preprocess_text)

# Now, let's vectorize the preprocessed text
vectorizer = CountVectorizer(max_df=0.95, min_df=2, stop_words="english")
dtm = vectorizer.fit_transform(proposal_text)


# %%
from sklearn.decomposition import LatentDirichletAllocation
from tqdm import tqdm

# Number of topics
n_topics = 20


# Create and fit the LDA model
class ProgressBarLDA(LatentDirichletAllocation):
    def fit(self, X, y=None):
        with tqdm(total=self.max_iter) as pbar:
            for i in range(self.max_iter):
                super(ProgressBarLDA, self).partial_fit(X, y)
                pbar.update(1)
        return self


lda = ProgressBarLDA(
    n_components=n_topics, max_iter=10, learning_method="online", random_state=42
)
lda.fit(dtm)


# Function to display the top words in each topic
def display_topics(model, feature_names, no_top_words):
    for topic_idx, topic in enumerate(model.components_):
        print("Topic %d:" % (topic_idx))
        print(
            " ".join(
                [feature_names[i] for i in topic.argsort()[: -no_top_words - 1 : -1]]
            )
        )


no_top_words = 10
display_topics(lda, vectorizer.get_feature_names_out(), no_top_words)


# %%
# Generate topic distributions
topic_distributions = lda.transform(dtm)

# Convert topic distributions to a DataFrame
topics = pd.DataFrame(
    topic_distributions,
    columns=[f"Topic {i}" for i in range(topic_distributions.shape[1])],
)

# Save the DataFrame as a pickle file
topics.to_pickle("processed/topics.pkl")

# Compute the correlation matrix
correlation_matrix = topics.corr()

# Display the correlation matrix
print(correlation_matrix)

print(topics.columns)

# %%
import pandas as pd

# Load 'data_clean_drop' and 'topic_title_body_df' DataFrame from the pickle file
props = pd.read_pickle("processed/proposals_formatted.pkl")
topics = pd.read_pickle("processed/topics.pkl")

# %%
# Extract only the topic columns from topic_title_body_df
topic_columns = [col for col in topics.columns if col.startswith("Topic ")]
topics = topics[topic_columns]

# Ensure the indices match before concatenation
props = props.reset_index(drop=True)
topics = topics.reset_index(drop=True)

# Concatenate the topic columns with data_clean_drop
props = pd.concat([props, topics], axis=1)

# Rename topic columns in data_clean_drop
for i in range(31):
    props.rename(columns={f"Topic {i}": f"topic_{i}"}, inplace=True)


# %%
props.rename(columns={"id": "proposal_id"}, inplace=True)
props.rename(columns={"author": "prps_author"}, inplace=True)
props.rename(columns={"created": "prps_created"}, inplace=True)
props.rename(columns={"start": "prps_start"}, inplace=True)
props.rename(columns={"end": "prps_end"}, inplace=True)

# Convert to datetime
props["prps_start"] = pd.to_datetime(props["prps_start"], unit="s")
props["prps_end"] = pd.to_datetime(props["prps_end"], unit="s")

print(props.columns)

# %%
# Select only the specified columns
props = props[
    [
        "proposal_id",
        "prps_author",
        "prps_created",
        "space",
        "type",
        "plugin_safesnap",
        "strategy_delegation",
        "prps_start",
        "prps_end",
        "quorum",
        "scores_total",
        "prps_choices",
        "scores",
        "votes",
        "winning_choices",
        "met_quorum",
        "second_score",
        "winning_score",
        "strategy_name",
        "overlap",
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
    ]
]

# Save the DataFrame as a CSV file
props.to_csv("processed/proposals.csv", index=False)

# Save the DataFrame as a pickle file
props.to_pickle("processed/proposals_final.pkl")

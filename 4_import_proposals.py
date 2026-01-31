import pandas as pd
import numpy as np
import json
import os
import ast
from itertools import zip_longest
from sklearn.feature_extraction.text import CountVectorizer
from nltk.corpus import stopwords
from nltk.stem import WordNetLemmatizer
from nltk.tokenize import word_tokenize
import nltk
import re
from langdetect import detect, DetectorFactory
from langdetect.lang_detect_exception import LangDetectException
from sklearn.decomposition import LatentDirichletAllocation
from tqdm import tqdm

nltk.download("punkt")
nltk.download("stopwords")
nltk.download("wordnet")
nltk.download("punkt_tab")

# Ensure consistent results
DetectorFactory.seed = 0

# Number of topics
n_topics = 20

no_top_words = 10

# working directory to the parent directory of the script's location
# os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# load propos
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


# Function to extract the first strategy name
def extract_first_strategy_name(strategy_str):
    # Find all complete JSON objects in the string
    strategies = list()
    # print(strategy_str)
    matches = re.findall(r"\{.*?\}", strategy_str)
    if matches:
        for match in matches:
            # print(match)
            # Parse the first matched JSON object
            strat = re.search(r'"name":"(.*?)"', strategy_str)
            # print(stra.group(1))
            # Return the first name found
            new_strat = strat.group(1)
            if new_strat not in strategies:
                strategies.append(new_strat)
    return strategies


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


# Function to display the top words in each topic
def display_topics(model, feature_names, no_top_words):
    for topic_idx, topic in enumerate(model.components_):
        print("Topic %d:" % (topic_idx))
        print(
            " ".join(
                [feature_names[i] for i in topic.argsort()[: -no_top_words - 1 : -1]]
            )
        )


# spaces = parse_json_column_to_columns(spaces, 'settings')
max_rows_votes = len(props)
print(f"Maximum number of rows in dataframe: {max_rows_votes}")

# Drop proposals that have only one voter
props = props[props["votes"] > 1]

print(props.columns)

max_rows_votes = len(props)
print(f"Maximum number of rows in dataframe: {max_rows_votes}")

# Apply the function to the filtered dataset data_basic
props[["winning_choices", "winning_score", "second_score", "met_quorum"]] = props.apply(
    determine_winning_choice_and_score, axis=1, result_type="expand"
)

# Number of choices
props["choices"] = props["choices"].apply(ast.literal_eval)

props["prps_choices"] = props["choices"].apply(len)


# Winning- / losing-margin per option (normalised by total votes)
def calculate_margins(row):
    scores_json, total = row["scores"], row["scores_total"]
    if total == 0 or pd.isna(scores_json) or not scores_json:
        return None  # no votes => no margins

    scores = [float(x) for x in ast.literal_eval(scores_json)]
    norm = [s / total for s in scores]  # 0-1 scale
    top = max(norm)
    second = sorted(norm, reverse=True)[1] if len(norm) > 1 else 0
    win_mar = top - second  # winner’s margin

    # winner gets its own margin (positive); all others negative
    return [(s - top) if s != top else win_mar for s in norm]


# column with a list of margins (same order as proposal["choices"])
props["margins"] = props.apply(calculate_margins, axis=1)

# Apply the function to create a new column
props["first_strategy_names"] = props["strategies"].apply(extract_first_strategy_name)

# Count unique values in column 'A'
value_counts = props["first_strategy_names"].value_counts()

print(value_counts)

props["first_strategy_name"] = props["first_strategy_names"].astype(str)

del props["first_strategy_names"]

props["delegation"] = props["first_strategy_name"].apply(
    lambda x: 1 if "delegat" in x else 0
)

# Ensure "choices" is treated as a string and check for "abstain" in any capitalization
props.loc[
    (props["type"] == "single-choice")
    & (props["prps_choices"] == 3)
    & (props["choices"].astype(str).str.contains("abstain", case=False, na=False)),
    "type",
] = "single-choice-abstain"

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

props_text = props["body"]
props_text.to_csv("processed/proposal_text.csv", index=False)
# What about foreign languages?

props = pd.read_pickle("processed/proposals.pkl")

# Assuming data_clean contains 'title' and 'body' columns
# Combine titles and bodies with a space in between and ensure all are strings
props["body"] = props["body"].astype(str)

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

# Save the DataFrame as a pickle file
props.to_pickle("processed/proposals_formatted.pkl")

# Apply the preprocessing to each combined text
proposal_text = props["body"].apply(preprocess_text)

# Now, let's vectorize the preprocessed text
vectorizer = CountVectorizer(max_df=0.95, min_df=2, stop_words="english")
dtm = vectorizer.fit_transform(proposal_text)


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

display_topics(lda, vectorizer.get_feature_names_out(), no_top_words)

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

# Load 'data_clean_drop' and 'topic_title_body_df' DataFrame from the pickle file
props = pd.read_pickle("processed/proposals_formatted.pkl")
topics = pd.read_pickle("processed/topics.pkl")

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

props.rename(columns={"id": "proposal_id"}, inplace=True)
props.rename(columns={"author": "prps_author"}, inplace=True)
props.rename(columns={"created": "prps_created"}, inplace=True)
props.rename(columns={"start": "prps_start"}, inplace=True)
props.rename(columns={"end": "prps_end"}, inplace=True)
props.rename(columns={"first_strategy_name": "prps_strategy"}, inplace=True)
props.rename(columns={"plugin_safesnap": "prps_safesnap"}, inplace=True)
props.rename(columns={"strategy_delegation": "prps_delegation"}, inplace=True)
props.rename(columns={"quorum": "prps_quorum"}, inplace=True)

# Convert to datetime
props["prps_start"] = pd.to_datetime(props["prps_start"], unit="s")
props["prps_end"] = pd.to_datetime(props["prps_end"], unit="s")

# privacy column contains 'shutter' if privacy is enabled
props["privacy"] = props["privacy"].map({"shutter": 1}).fillna(0).astype(int)

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
        "prps_safesnap",
        "prps_delegation",
        "prps_strategy",
        "prps_start",
        "prps_end",
        "prps_quorum",
        "scores_total",
        "prps_choices",
        "scores",
        "votes",
        "winning_choices",
        "margins",
        "met_quorum",
        "second_score",
        "winning_score",
        "overlap",
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
    ]
]

# Save the DataFrame as a CSV file
props.to_csv("processed/proposals.csv", index=False)

# Save the DataFrame as a pickle file
props.to_pickle("processed/proposals_final.pkl")

props = pd.read_pickle("processed/proposals_final.pkl")

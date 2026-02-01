# 6_import_and_merge.py
import os
import sys
import json
import ast
import multiprocessing
from pathlib import Path
from concurrent.futures import ProcessPoolExecutor, as_completed
import re
import html as html_lib

import pandas as pd
import numpy as np


# ------------------------------------------------------------
# 0. Setup
# ------------------------------------------------------------
# run relative to repo root (…/Data)
os.chdir(Path(__file__).resolve().parent.parent)

# Global caches (important for multiprocessing robustness)
proposals = None
spaces_df = None
follows_df = None
users_df = None
votes_df = None

_WARNED_MISSING_COLS = set()

# ------------------------------------------------------------
# Rebuild controls
# ------------------------------------------------------------
# If True: rebuild ALL DAO csvs even if they exist.
OVERWRITE_EXISTING = True

# If True: reprocess existing DAO csv if its header != required_columns (recommended after schema change)
REPROCESS_IF_SCHEMA_MISMATCH = True


# ------------------------------------------------------------
# Keep-only column whitelist (Stata output)
# ------------------------------------------------------------
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
    "prps_quorum",
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

# ------------------------------------------------------------
# PARSIMONIOUS Discourse vars to export
# ------------------------------------------------------------
# These are the only ones you need for: misalignment → engagement, moderated by fairness/credibility.
DISCOURSE_KEEP_COLS = [
    "disc_has_thread",
    "disc_posts_count",
    "disc_posts_text_n",
    "disc_fairness_pp",
    "disc_cred_undermine_pp",
]

required_columns += DISCOURSE_KEEP_COLS


# ------------------------------------------------------------
# 1) Vote alignment + margins
# ------------------------------------------------------------
def calculate_vote_alignment(data: pd.DataFrame):
    Misaligned, Not_Determined, Misaligned_C, Tied = [], [], [], []

    for row in data.itertuples():
        winning_choices = row.winning_choices
        voting_type = row.type if "type" in dir(row) else ""

        choice_dict = {}

        if isinstance(row.choice, str):
            if row.choice.startswith("{") and voting_type in ["weighted", "quadratic"]:
                try:
                    choice_dict = json.loads(row.choice)
                except Exception:
                    choice_dict = {}
            elif row.choice.startswith("[") and voting_type in [
                "ranked-choice",
                "approval",
            ]:
                try:
                    voter_choices = json.loads(row.choice)
                except Exception:
                    voter_choices = []
                if voting_type == "ranked-choice":
                    n = len(voter_choices)
                    choice_dict = {
                        str(int(choice)): n - idx
                        for idx, choice in enumerate(voter_choices)
                        if isinstance(choice, (int, str))
                    }
                else:
                    choice_dict = {
                        str(int(choice)): 1
                        for choice in voter_choices
                        if isinstance(choice, (int, str))
                    }
            else:
                try:
                    choice_dict[str(int(row.choice))] = 1
                except Exception:
                    pass

        elif isinstance(row.choice, (int, float)):
            try:
                choice_dict[str(int(row.choice))] = 1
            except Exception:
                pass

        elif isinstance(row.choice, list) and voting_type in [
            "ranked-choice",
            "approval",
        ]:
            if voting_type == "ranked-choice":
                n = len(row.choice)
                choice_dict = {
                    str(int(choice)): n - idx
                    for idx, choice in enumerate(row.choice)
                    if isinstance(choice, (int, str))
                }
            else:
                choice_dict = {
                    str(int(choice)): 1
                    for choice in row.choice
                    if isinstance(choice, (int, str))
                }

        # normalize winning_choices
        if isinstance(winning_choices, list) and len(winning_choices) > 0:
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

        # basic abstain treatment
        if voting_type in ["basic", "single-choice-abstain"]:
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

        if winning_choices is None or (
            isinstance(winning_choices, float) and np.isnan(winning_choices)
        ):
            Misaligned.append(0)
            Not_Determined.append(1)
            Misaligned_C.append(0)
            Tied.append(0)
            continue

        if not choice_dict:
            Misaligned.append(0)
            Not_Determined.append(1)
            Misaligned_C.append(0)
            Tied.append(0)
            continue

        total_weight = sum(choice_dict.values())
        winning_weight = (
            choice_dict.get(winning_choices[0], 0)
            if isinstance(winning_choices, list)
            else 0
        )
        winning_proportion = winning_weight / total_weight if total_weight > 0 else 0
        misalignment_score = 1 - winning_proportion

        max_weight = max(choice_dict.values())
        most_weight_choices = [
            choice for choice, weight in choice_dict.items() if weight == max_weight
        ]

        if isinstance(winning_choices, list) and any(
            choice in most_weight_choices for choice in winning_choices
        ):
            Misaligned.append(0)
        else:
            Misaligned.append(1)

        Misaligned_C.append(misalignment_score if winning_proportion > 0 else 1)

        if (
            len(most_weight_choices) > 1
            and isinstance(winning_choices, list)
            and any(choice in most_weight_choices for choice in winning_choices)
        ):
            Tied.append(1)
        else:
            Tied.append(0)

        Not_Determined.append(0)

    return Misaligned, Not_Determined, Misaligned_C, Tied


def calculate_own_margin(df: pd.DataFrame) -> pd.Series:
    out = []
    for row in df.itertuples():
        own_margin = np.nan

        try:
            margins = ast.literal_eval(str(row.margins))
        except Exception:
            margins = []
        if not margins:
            out.append(own_margin)
            continue

        voting_type = row.type if "type" in dir(row) else ""
        choice_vp = {}

        try:
            if voting_type in ["single-choice", "basic"]:
                if isinstance(row.choice, str) and row.choice.startswith("{"):
                    choice_vp = json.loads(row.choice)
                else:
                    choice_vp[str(int(float(row.choice)))] = 1

                if voting_type == "basic" and list(choice_vp.keys())[0] == "3":
                    out.append(own_margin)
                    continue

            elif voting_type in ["weighted", "quadratic"]:
                if isinstance(row.choice, str) and row.choice.startswith("{"):
                    choice_vp = json.loads(row.choice)

            elif voting_type == "ranked-choice":
                seq = None
                if isinstance(row.choice, str) and row.choice.startswith("["):
                    seq = json.loads(row.choice)
                elif isinstance(row.choice, list):
                    seq = row.choice
                if seq:
                    n = len(seq)
                    choice_vp = {str(int(ch)): n - i for i, ch in enumerate(seq)}

            elif voting_type == "approval":
                seq = None
                if isinstance(row.choice, str) and row.choice.startswith("["):
                    seq = json.loads(row.choice)
                elif isinstance(row.choice, list):
                    seq = row.choice
                if seq:
                    choice_vp = {str(int(ch)): 1 for ch in seq}

        except Exception:
            pass

        if not choice_vp:
            out.append(own_margin)
            continue

        try:
            top_vp = max(choice_vp.values())
            top_choices = [int(k) - 1 for k, v in choice_vp.items() if v == top_vp]
            own_margin = max(margins[i] for i in top_choices)
        except Exception:
            pass

        out.append(own_margin)

    return pd.Series(out, index=df.index)


# ------------------------------------------------------------
# 2) Majority vs power winner
# ------------------------------------------------------------
def parse_vote_choice(choice, vote_type):
    if pd.isna(choice) or not choice:
        return {}

    if isinstance(choice, (int, float)):
        return {str(int(choice)): 1.0}

    if not isinstance(choice, str):
        return {}

    if vote_type in ["basic", "single-choice", "single-choice-abstain"]:
        try:
            selected_choice = int(float(choice))
            return {str(selected_choice): 1.0}
        except ValueError:
            return {}

    elif vote_type in ["weighted", "quadratic"]:
        if choice.startswith("{"):
            try:
                weights = json.loads(choice)
                if isinstance(weights, dict):
                    return {
                        str(k): float(v) for k, v in weights.items() if float(v) > 0
                    }
            except Exception:
                return {}
        return {}

    elif vote_type == "approval":
        if choice.startswith("["):
            try:
                approved_choices = json.loads(choice)
                if isinstance(approved_choices, list) and approved_choices:
                    weight_per_choice = 1.0 / len(approved_choices)
                    return {
                        str(int(c)): weight_per_choice
                        for c in approved_choices
                        if not pd.isna(c)
                    }
            except Exception:
                return {}
        return {}

    elif vote_type == "ranked-choice":
        if choice.startswith("["):
            try:
                ranked_choices = json.loads(choice)
                if isinstance(ranked_choices, list) and ranked_choices:
                    n = len(ranked_choices)
                    return {
                        str(int(ch)): float(n - i)
                        for i, ch in enumerate(ranked_choices)
                        if not pd.isna(ch)
                    }
            except Exception:
                return {}
        return {}

    return {}


def calculate_winners_for_proposal(proposal_group: pd.DataFrame):
    vote_type = proposal_group["type"].iloc[0]
    raw_vote_counts = {}
    power_sums = {}

    for vote in proposal_group.itertuples():
        user_vp = vote.vp if "vp" in dir(vote) else 0.0
        choice_weights = parse_vote_choice(vote.choice, vote_type)
        total_user_weight = sum(choice_weights.values())
        if total_user_weight <= 0:
            continue

        for ch, wt in choice_weights.items():
            raw_vote_counts[ch] = raw_vote_counts.get(ch, 0.0) + wt

            frac = wt / total_user_weight if total_user_weight > 0 else 0.0
            power_sums[ch] = power_sums.get(ch, 0.0) + user_vp * frac

    if not raw_vote_counts or not power_sums:
        return pd.Series({"is_majority_win": None})

    majority_choice = max(raw_vote_counts.items(), key=lambda x: x[1])[0]
    power_winner = max(power_sums.items(), key=lambda x: x[1])[0]
    return pd.Series({"is_majority_win": 1 if majority_choice == power_winner else 0})


# ------------------------------------------------------------
# 3) Discourse integration (ONLY the few vars we need)
# ------------------------------------------------------------
_TAG_RE = re.compile(r"<[^>]+>")
_BLOCKQUOTE_RE = re.compile(r"<blockquote.*?</blockquote>", flags=re.I | re.S)
_WS_RE = re.compile(r"\s+")


def cooked_to_text(cooked) -> str:
    if cooked is None or (isinstance(cooked, float) and np.isnan(cooked)):
        return ""
    s = html_lib.unescape(str(cooked))
    s = _BLOCKQUOTE_RE.sub(" ", s)  # remove quotes to reduce false positives
    s = _TAG_RE.sub(" ", s)
    s = _WS_RE.sub(" ", s).strip()
    return s


GOV = re.compile(
    r"\b(vote|voting|voter|voters|proposal|governance|quorum|snapshot|tally|result|results|outcome|outcomes)\b",
    re.I,
)
FAIR = re.compile(
    r"\b(unfair|not fair|unjust|injustice|biased|bias|unfairly|procedur\w* justice|due process|rights?|legitimacy)\b",
    re.I,
)

INTEGRITY_TERMS = re.compile(
    r"\b(fraud(ulent)?|corrupt\w*|scam|illegitim\w*|stolen|invalid)\b", re.I
)
MANIP_VOTE = re.compile(
    r"\bmanipulat\w*\b.{0,30}\b(vote|voting|voter|voters|result|outcome)\b|"
    r"\b(vote|voting|voter|voters|result|outcome)\b.{0,30}\bmanipulat\w*\b",
    re.I,
)
RISK_STRUCT = re.compile(r"\b(bot|bots|sybil|sybils|whale|whales)\b", re.I)
FUTILITY = re.compile(
    r"\b(pointless|meaningless|no point|waste of time|doesn'?t matter|does not matter|nothing will change|never happen|just for show|theatre|theater)\b",
    re.I,
)


def build_discourse_features_by_proposal(
    topics_path="csvs/discourse_topics_core_by_proposal.csv",
    posts_path="csvs/discourse_posts_final.csv",
    cache_path="processed/discourse_features_by_proposal_min.pkl",
    force_rebuild=False,
) -> pd.DataFrame:
    cache_path = Path(cache_path)

    expected = [
        "proposal_id",
        "disc_has_thread",
        "disc_posts_count",
        "disc_posts_text_n",
        "disc_fairness_pp",
        "disc_cred_undermine_pp",
    ]

    if cache_path.exists() and not force_rebuild:
        df = pd.read_pickle(cache_path)
        if set(expected).issubset(df.columns):
            return df

    # ---- topics (proposal_id -> topic_id, posts_count) ----
    t = pd.read_csv(topics_path, low_memory=False)
    t["proposal_id"] = t["proposal_id"].astype(str).str.strip()

    # topic_id must be numeric to match posts
    t["topic_id"] = pd.to_numeric(t["topic_id"], errors="coerce")
    t["posts_count"] = pd.to_numeric(t["posts_count"], errors="coerce").fillna(0.0)

    core = t.drop_duplicates(subset=["proposal_id"]).copy()
    core["disc_has_thread"] = core["topic_id"].notna().astype(int)
    core["disc_posts_count"] = core["posts_count"]

    # defaults
    core["disc_posts_text_n"] = 0.0
    core["disc_fairness_pp"] = 0.0
    core["disc_cred_undermine_pp"] = 0.0

    posts_path = Path(posts_path)
    if not posts_path.exists():
        out = core[expected].copy()
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        out.to_pickle(cache_path)
        return out

    # ---- posts (topic_id + cooked) ----
    header = pd.read_csv(posts_path, nrows=0).columns.tolist()
    need = ["topic_id", "post_id", "cooked"]
    missing = [c for c in need if c not in header]
    if missing:
        raise ValueError(f"posts file missing columns: {missing}")

    p = pd.read_csv(posts_path, usecols=need, low_memory=False)

    # Dedupe posts
    p = p.drop_duplicates(subset=["post_id"]).copy()

    # Ensure numeric topic_id
    p["topic_id"] = pd.to_numeric(p["topic_id"], errors="coerce")
    p = p[p["topic_id"].notna()].copy()

    # Ensure cooked is string
    p["cooked"] = p["cooked"].fillna("").astype(str)
    p["text"] = p["cooked"].apply(cooked_to_text)

    print(
        f"[DISCOURSE DEBUG] posts loaded: {len(p):,}  unique topics: {p['topic_id'].nunique():,}"
    )
    print(
        f"[DISCOURSE DEBUG] non-empty text posts: {(p['text'].str.len() > 0).sum():,}"
    )

    # ---- flags ----
    p["fair_flag"] = p["text"].apply(
        lambda s: int(bool(s and FAIR.search(s) and GOV.search(s)))
    )

    def cred_undermine_flag(s: str) -> int:
        if not s:
            return 0
        integrity = bool(
            (INTEGRITY_TERMS.search(s) and GOV.search(s)) or MANIP_VOTE.search(s)
        )
        risk = bool(
            RISK_STRUCT.search(s)
            and re.search(r"\b(vote|voting|voter|voters)\b", s, flags=re.I)
        )
        futility = bool(FUTILITY.search(s) and GOV.search(s))
        return int(integrity or risk or futility)

    p["cred_und_flag"] = p["text"].apply(cred_undermine_flag)

    g = p.groupby("topic_id", as_index=False).agg(
        disc_posts_text_n=("post_id", "count"),
        disc_fair_n=("fair_flag", "sum"),
        disc_cred_und_n=("cred_und_flag", "sum"),
    )

    denom = g["disc_posts_text_n"].replace({0: np.nan})
    g["disc_fairness_pp"] = 100 * g["disc_fair_n"] / denom
    g["disc_cred_undermine_pp"] = 100 * g["disc_cred_und_n"] / denom

    print(
        f"[DISCOURSE DEBUG] topic aggregates: {len(g):,}  topics w fairness>0: {(g['disc_fairness_pp'] > 0).sum():,}  topics w cred>0: {(g['disc_cred_undermine_pp'] > 0).sum():,}"
    )

    feat = core.merge(g, on="topic_id", how="left", suffixes=("_core", ""))

    # After merge, prefer the computed columns from g if present.
    # If a column was already in core, it will be named like disc_posts_text_n_core.
    for c in ["disc_posts_text_n", "disc_fairness_pp", "disc_cred_undermine_pp"]:
        if c not in feat.columns:
            # If pandas suffixed it, it will have _x/_y; handle that too
            if f"{c}_y" in feat.columns:
                feat[c] = feat[f"{c}_y"]
            elif f"{c}_x" in feat.columns:
                feat[c] = feat[f"{c}_x"]
            else:
                feat[c] = 0.0

        feat[c] = feat[c].fillna(0.0)

    out = feat[expected].copy()

    cache_path.parent.mkdir(parents=True, exist_ok=True)
    out.to_pickle(cache_path)
    return out


def attach_discourse_to_proposals(proposals_df: pd.DataFrame) -> pd.DataFrame:
    disc_feat = build_discourse_features_by_proposal()

    out = proposals_df.copy()
    out["proposal_id"] = out["proposal_id"].astype(str).str.strip()
    disc_feat["proposal_id"] = disc_feat["proposal_id"].astype(str).str.strip()

    out = out.merge(disc_feat, on="proposal_id", how="left")

    # Fill 0 for proposals without discourse
    if "disc_has_thread" in out.columns:
        out["disc_has_thread"] = out["disc_has_thread"].fillna(0).astype(int)

    for c in [
        "disc_posts_count",
        "disc_posts_text_n",
        "disc_fairness_pp",
        "disc_cred_undermine_pp",
    ]:
        if c in out.columns:
            out[c] = out[c].fillna(0.0)

    return out


# ------------------------------------------------------------
# 4) Robust global loader (fixes NameError under spawn)
# ------------------------------------------------------------
def ensure_globals_loaded() -> None:
    global proposals, spaces_df, follows_df, users_df, votes_df

    if proposals is None:
        proposals = pd.read_pickle("processed/proposals_final.pkl")
        proposals = attach_discourse_to_proposals(proposals)

    if spaces_df is None:
        spaces_df = pd.read_pickle("processed/spaces.pkl")

    if follows_df is None:
        follows_df = pd.read_pickle("processed/follows.pkl")

    if users_df is None:
        users_df = pd.read_pickle("processed/users.pkl")

    if votes_df is None:
        votes_df = pd.read_pickle("processed/votes_verified_merged.pkl")


def ensure_required_columns_exist(df: pd.DataFrame) -> pd.DataFrame:
    global _WARNED_MISSING_COLS
    missing = [c for c in required_columns if c not in df.columns]
    if missing:
        key = tuple(sorted(missing))
        if key not in _WARNED_MISSING_COLS:
            _WARNED_MISSING_COLS.add(key)
            print(f"⚠ Adding missing columns with NaN: {missing}")
        for c in missing:
            df[c] = np.nan
    return df


# ------------------------------------------------------------
# 5) Per-DAO worker
# ------------------------------------------------------------
def should_skip_space(space: str, out_path: Path) -> bool:
    if not out_path.exists():
        return False
    if OVERWRITE_EXISTING:
        return False

    if not REPROCESS_IF_SCHEMA_MISMATCH:
        print(f"✔ {space} already processed — skipping")
        return True

    try:
        existing_cols = pd.read_csv(out_path, nrows=0).columns.tolist()
    except Exception as e:
        print(f"↻ {space} exists but header read failed ({e}). Reprocessing…")
        return False

    missing = [c for c in required_columns if c not in existing_cols]
    extra = [c for c in existing_cols if c not in required_columns]

    if missing or extra:
        print(
            f"↻ {space} exists but schema mismatch (missing {len(missing)}, extra {len(extra)}). Reprocessing…"
        )
        return False

    print(f"✔ {space} already processed — skipping")
    return True


def process_space(space: str) -> str:
    ensure_globals_loaded()

    out_path = Path(f"input/dao/data_{space}.csv")
    if should_skip_space(space, out_path):
        return space

    if "space" not in votes_df.columns:
        raise ValueError("votes_df missing required column 'space'")

    v = votes_df[votes_df["space"] == space].copy()
    if v.empty:
        print(f"⚠ {space}: zero votes — skipped")
        return space

    # Majority vs power winner (proposal-level)
    comp = (
        v.groupby("proposal")
        .apply(calculate_winners_for_proposal, include_groups=False)
        .reset_index()
    )

    v = v.merge(comp[["proposal", "is_majority_win"]], on="proposal", how="left")

    # alignment — preserve winning_choices from votes merge
    if "winning_choices" not in v.columns:
        raise RuntimeError(
            f"winning_choices missing in votes_df for space {space}. "
            "This indicates an upstream merge failure in 5_import_votes.py."
        )

    v["misaligned"], v["not_determined"], v["misaligned_c"], v["tied"] = (
        calculate_vote_alignment(v)
    )
    v["own_margin"] = calculate_own_margin(v)

    # timestamps
    if "created" in v.columns:
        v["created"] = pd.to_datetime(v["created"], unit="s", errors="coerce")
        v.rename(columns={"created": "vote_created"}, inplace=True)
    else:
        v["vote_created"] = pd.NaT

    # rename expected columns
    if "vp" in v.columns:
        v.rename(columns={"vp": "voting_power"}, inplace=True)
    if "tied" in v.columns:
        v.rename(columns={"tied": "own_choice_tied"}, inplace=True)
    else:
        v["own_choice_tied"] = np.nan

    # ensure base cols exist
    for c in ["voter", "space", "proposal", "choice", "type", "voting_power"]:
        if c not in v.columns:
            v[c] = np.nan

    base_cols = [
        "voter",
        "vote_created",
        "space",
        "proposal",
        "choice",
        "voting_power",
        "misaligned",
        "not_determined",
        "misaligned_c",
        "own_choice_tied",
        "own_margin",
        "is_majority_win",
        "type",
        "winning_choices",
    ]
    v = v[[c for c in base_cols if c in v.columns]].copy()

    merged = v.merge(
        proposals,
        how="left",
        left_on="proposal",
        right_on="proposal_id",
        suffixes=("_v", "_p"),
    )

    # Ensure winning_choices comes from votes, not proposals
    if "winning_choices_v" in merged.columns:
        merged["winning_choices"] = merged["winning_choices_v"]

    # Ensure expected space suffix exists for downstream merges
    if "space_v" not in merged.columns:
        if "space" in merged.columns:
            merged = merged.rename(columns={"space": "space_v"})
        elif "space_p" in merged.columns:
            merged = merged.rename(columns={"space_p": "space_v"})

    merged = (
        merged.merge(
            spaces_df,
            how="left",
            left_on="space_v",
            right_on="space_id",
            suffixes=("_v", "_s"),
        )
        .merge(
            follows_df,
            how="left",
            left_on=["voter", "space_v"],
            right_on=["follower", "space"],
            suffixes=("_v", "_f"),
        )
        .merge(
            users_df,
            how="left",
            left_on="voter",
            right_on="voter_id",
            suffixes=("_v", "_u"),
        )
    )

    # Ensure 'space' in output is the DAO space id (not dependent on follows merge)
    if "space" not in merged.columns:
        merged["space"] = merged["space_v"]
    else:
        merged["space"] = merged["space"].fillna(merged["space_v"])

    # standardize type column name (type_v overwrites sometimes)
    if "type_v" in merged.columns:
        merged = merged.rename(columns={"type_v": "type"})

    merged = ensure_required_columns_exist(merged)
    merged = merged[required_columns].copy()

    out_path.parent.mkdir(parents=True, exist_ok=True)
    merged.to_csv(out_path, index=False)
    return space


# ------------------------------------------------------------
# 6) Main launcher
# ------------------------------------------------------------
def get_mp_context():
    if sys.platform == "win32":
        return multiprocessing.get_context("spawn")
    try:
        return multiprocessing.get_context("fork")
    except ValueError:
        return multiprocessing.get_context("spawn")


if __name__ == "__main__":
    verified_dao_spaces = (
        pd.read_csv("input/verified-spaces.csv")["space_name"].unique().tolist()
    )

    workers = max(1, multiprocessing.cpu_count() - 1)
    print(f"Launching {workers} worker processes …")

    # Pre-load once in parent (also builds discourse cache)
    ensure_globals_loaded()

    ctx = get_mp_context()

    with ProcessPoolExecutor(max_workers=workers, mp_context=ctx) as ex:
        futs = [ex.submit(process_space, sp) for sp in verified_dao_spaces]
        for fut in as_completed(futs):
            try:
                print(f"✓ finished {fut.result()}")
            except Exception as e:
                print(f"✗ worker failed: {e}")
                raise

    print("All DAO spaces processed.")

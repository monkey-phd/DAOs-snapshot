# 5a_discourse_extract_core.py
# Purpose:
#   Extract core Discourse thread variables,
#   and RETAIN Snapshot proposal_id by joining proposals['discussion'] to discourse['url'].
#
# Inputs:
#   - csvs/discourse.csv  (expects columns: url + json OR discourse_json)
#   - input/...proposals_0.csv (expects columns: id + discussion; optionally space)
#
# Outputs:
#   - csvs/discourse_topics_core_by_proposal.csv
#   - csvs/discourse_users_core_by_proposal.csv

import json
import re
import os
from collections import defaultdict
from pathlib import Path

import numpy as np
import pandas as pd

# -----------------------------
# URL canonicalization (for reliable join)
# -----------------------------
repo_root = Path(__file__).resolve().parent
os.chdir(repo_root)
Path("csvs").mkdir(parents=True, exist_ok=True)

def canonicalize_url(u) -> str:
    if u is None:
        return ""
    if isinstance(u, float) and np.isnan(u):
        return ""
    if not isinstance(u, str):
        return ""
    u = u.strip()
    if not u:
        return ""

    # Drop fragment/query and trailing slash
    u = re.sub(r"#.*$", "", u)
    u = re.sub(r"\?.*$", "", u)
    u = u.rstrip("/")

    # Lowercase scheme + host
    m = re.match(r"^(https?://)([^/]+)(/.*)?$", u, flags=re.I)
    if m:
        scheme = m.group(1).lower()
        host = m.group(2).lower()
        path = m.group(3) or ""
        u = f"{scheme}{host}{path}".rstrip("/")

    # Discourse: /t/slug/318/1 -> /t/slug/318
    u = re.sub(r"(/t/[^/]+/\d+)/\d+$", r"\1", u)
    u = re.sub(r"(/t/\d+)/\d+$", r"\1", u)

    return u.rstrip("/")


# -----------------------------
# Lightweight HTML -> word/link counts (no external deps)
# -----------------------------
_TAG_RE = re.compile(r"<[^>]+>")
_WORD_RE = re.compile(r"\b\w+\b")
_HREF_RE = re.compile(r'href="http', flags=re.I)

def word_count_from_html(html: str) -> int:
    if not isinstance(html, str) or not html:
        return 0
    txt = re.sub(r"\s+", " ", _TAG_RE.sub(" ", html)).strip()
    return len(_WORD_RE.findall(txt)) if txt else 0

def link_count_from_html(html: str) -> int:
    if not isinstance(html, str) or not html:
        return 0
    return len(_HREF_RE.findall(html))


def is_staff_post(p: dict) -> bool:
    # Discourse post flags commonly present
    return bool(p.get("admin") or p.get("moderator") or p.get("staff"))


def parse_dt(s):
    try:
        return pd.to_datetime(s, utc=True)
    except Exception:
        return pd.NaT


# -----------------------------
# Parse one topic JSON into:
#   - topic-level row (core identifiers + trace primitives)
#   - user-level rows (per-user contribution summary)
# -----------------------------
def parse_topic(topic_json: dict, url_from_csv: str):
    # Use url from CSV; fallback to topic_json['url'] when present
    url = url_from_csv if isinstance(url_from_csv, str) and url_from_csv.strip() else topic_json.get("url", "")
    url_canon = canonicalize_url(url)

    # --- Core identifiers requested ---
    topic_id = topic_json.get("id")
    title = topic_json.get("title")
    category_id = topic_json.get("category_id")
    created_at = topic_json.get("created_at")
    last_posted_at = topic_json.get("last_posted_at")
    views = topic_json.get("views")
    posts_count = topic_json.get("posts_count")
    reply_count = topic_json.get("reply_count")
    like_count = topic_json.get("like_count")

    # --- Posts stream ---
    posts = topic_json.get("post_stream", {}).get("posts", [])
    n_posts_total = len(posts)

    # Regular posts are post_type == 1
    reg = [p for p in posts if p.get("post_type") == 1]
    n_posts_regular = len(reg)
    n_posts_system = n_posts_total - n_posts_regular
    system_post_ratio = (n_posts_system / n_posts_regular) if n_posts_regular else np.nan

    # OP = post_number == 1 among regular posts (if present)
    op = None
    for p in reg:
        if p.get("post_number") == 1:
            op = p
            break

    op_user_id = op.get("user_id") if op else None
    op_is_staff = int(is_staff_post(op)) if op else np.nan
    op_word_count = word_count_from_html(op.get("cooked", "")) if op else 0
    op_link_count = link_count_from_html(op.get("cooked", "")) if op else 0
    op_created_at = parse_dt(op.get("created_at")) if op else pd.NaT

    # Participation
    user_ids = [p.get("user_id") for p in reg if p.get("user_id") is not None]
    unique_users = set(user_ids)
    n_users_regular = len(unique_users)

    staff_user_ids = set(
        p.get("user_id") for p in reg
        if p.get("user_id") is not None and is_staff_post(p)
    )
    n_users_staff_regular = len(staff_user_ids)
    n_users_nonstaff_regular = len(unique_users - staff_user_ids)

    nonstaff_share_users = (n_users_nonstaff_regular / n_users_regular) if n_users_regular else np.nan

    n_staff_posts_regular = sum(1 for p in reg if is_staff_post(p))
    staff_post_share_regular = (n_staff_posts_regular / n_posts_regular) if n_posts_regular else np.nan

    # Reply structure primitives
    n_reply_posts_regular = sum(1 for p in reg if p.get("reply_to_post_number") is not None)
    reply_ratio_regular = (n_reply_posts_regular / n_posts_regular) if n_posts_regular else np.nan

    # Timing primitives (for later "responsiveness/correctability")
    reg_times = [parse_dt(p.get("created_at")) for p in reg if p.get("created_at")]
    reg_times = [t for t in reg_times if not pd.isna(t)]
    if len(reg_times) >= 2:
        thread_duration_hours = float((max(reg_times) - min(reg_times)).total_seconds() / 3600.0)
    elif len(reg_times) == 1:
        thread_duration_hours = 0.0
    else:
        thread_duration_hours = np.nan

    # First response hours: time from OP to first non-OP regular post (if any)
    first_response_hours = np.nan
    if op_user_id is not None and not pd.isna(op_created_at):
        non_op_times = []
        for p in reg:
            if p.get("user_id") is None:
                continue
            if p.get("user_id") == op_user_id:
                continue
            t = parse_dt(p.get("created_at"))
            if not pd.isna(t):
                non_op_times.append(t)
        if non_op_times:
            first_response_hours = float((min(non_op_times) - op_created_at).total_seconds() / 3600.0)
            if first_response_hours < 0:
                # guard against clock/order artifacts
                first_response_hours = np.nan

    # --- Topic-level row ---
    topic_row = {
        # proposal join key will be added later
        "url": url,
        "url_canon": url_canon,

        # required identifiers (exactly as requested)
        "topic_id": topic_id,
        "title": title,
        "category_id": category_id,
        "created_at": created_at,
        "last_posted_at": last_posted_at,
        "views": views,
        "posts_count": posts_count,
        "reply_count": reply_count,
        "like_count": like_count,

        # core trace primitives (for later VR/ND/CR construction)
        "n_posts_total": n_posts_total,
        "n_posts_regular": n_posts_regular,
        "n_posts_system": n_posts_system,
        "system_post_ratio": system_post_ratio,

        "n_users_regular": n_users_regular,
        "n_users_staff_regular": n_users_staff_regular,
        "n_users_nonstaff_regular": n_users_nonstaff_regular,
        "nonstaff_share_users": nonstaff_share_users,

        "n_staff_posts_regular": n_staff_posts_regular,
        "staff_post_share_regular": staff_post_share_regular,

        "n_reply_posts_regular": n_reply_posts_regular,
        "reply_ratio_regular": reply_ratio_regular,

        "op_user_id": op_user_id,
        "op_is_staff": op_is_staff,
        "op_word_count": op_word_count,
        "op_link_count": op_link_count,

        "first_response_hours": first_response_hours,
        "thread_duration_hours": thread_duration_hours,
    }

    # --- User-level rows (minimal) ---
    agg = defaultdict(lambda: {
        "is_staff": 0,
        "n_posts": 0,
        "n_replies": 0,
        "total_words": 0,
        "total_links": 0,
        "first_at": pd.NaT,
        "last_at": pd.NaT,
    })

    for p in reg:
        uid = p.get("user_id")
        if uid is None:
            continue

        a = agg[uid]
        a["is_staff"] = int(a["is_staff"] or is_staff_post(p))
        a["n_posts"] += 1
        a["n_replies"] += int(p.get("reply_to_post_number") is not None)

        cooked = p.get("cooked", "")
        a["total_words"] += word_count_from_html(cooked)
        a["total_links"] += link_count_from_html(cooked)

        t = parse_dt(p.get("created_at"))
        if not pd.isna(t):
            if pd.isna(a["first_at"]) or t < a["first_at"]:
                a["first_at"] = t
            if pd.isna(a["last_at"]) or t > a["last_at"]:
                a["last_at"] = t

    user_rows = []
    for uid, a in agg.items():
        user_rows.append({
            # proposal join key will be added later
            "url_canon": url_canon,
            "topic_id": topic_id,
            "user_id": uid,
            "is_staff": a["is_staff"],
            "n_posts_regular": a["n_posts"],
            "n_replies_regular": a["n_replies"],
            "total_words_regular": a["total_words"],
            "total_links_regular": a["total_links"],
            "first_post_at": a["first_at"].isoformat() if not pd.isna(a["first_at"]) else None,
            "last_post_at": a["last_at"].isoformat() if not pd.isna(a["last_at"]) else None,
        })

    return topic_row, user_rows


def main(
    proposals_csv="input/snapshot-hub-mainnet-2023-08-30-proposals_0.csv",
    discourse_csv="csvs/discourse.csv",
    out_topics="csvs/discourse_topics_core_by_proposal.csv",
    out_users="csvs/discourse_users_core_by_proposal.csv",
):
    # --- 1) Load proposals mapping: retain proposal_id ---
    props = pd.read_csv(proposals_csv, low_memory=False)

    if "id" not in props.columns or "discussion" not in props.columns:
        raise ValueError("Proposals CSV must contain columns: 'id' and 'discussion'.")

    if "space" not in props.columns:
        props["space"] = np.nan

    prop_map = props.dropna(subset=["discussion"]).copy()
    prop_map["proposal_id"] = prop_map["id"]
    prop_map["discussion_url"] = prop_map["discussion"]
    prop_map["url_canon"] = prop_map["discussion_url"].apply(canonicalize_url)
    prop_map = prop_map[["proposal_id", "space", "discussion_url", "url_canon"]]

    # --- 2) Load discourse.csv (support json or discourse_json) ---
    disc = pd.read_csv(discourse_csv, low_memory=False)

    if "url" not in disc.columns:
        raise ValueError("Discourse CSV must contain column 'url'.")

    json_col = None
    for c in ["json", "discourse_json"]:
        if c in disc.columns:
            json_col = c
            break
    if json_col is None:
        raise ValueError("Discourse CSV must contain a JSON column: 'json' or 'discourse_json'.")

    # --- 3) Parse discourse topics to topic/user tables keyed by url_canon ---
    topic_rows = []
    user_rows_all = []

    for r in disc.itertuples(index=False):
        url = getattr(r, "url")
        raw = getattr(r, json_col)

        if not isinstance(raw, str) or not raw.strip():
            continue
        try:
            topic_json = json.loads(raw)
        except Exception:
            continue

        trow, urows = parse_topic(topic_json, url)
        topic_rows.append(trow)
        user_rows_all.extend(urows)

    topics = pd.DataFrame(topic_rows)
    users = pd.DataFrame(user_rows_all)

    # Deduplicate topics by canonical url (one JSON per forum URL)
    if not topics.empty:
        topics = topics.drop_duplicates(subset=["url_canon"]).reset_index(drop=True)

    # --- 4) Merge to retain proposal_id for each forum thread ---
    topics_by_proposal = prop_map.merge(
        topics,
        on="url_canon",
        how="left",
        validate="m:1",  # many proposals can map to one thread URL
    )

    users_by_proposal = prop_map.merge(
        users,
        left_on="url_canon",
        right_on="url_canon",
        how="left",
        validate="m:m",
    )

    # Add proposal_id + space to user rows
    # (already in users_by_proposal from prop_map side)
    topics_by_proposal.to_csv(out_topics, index=False)
    users_by_proposal.to_csv(out_users, index=False)

    print("DONE")
    print(f"Parsed discourse threads (unique url): {len(topics):,}")
    print(f"Proposals with discussion URL: {len(prop_map):,}")
    print(f"Matched proposals to discourse threads: {topics_by_proposal['topic_id'].notna().sum():,}")
    print(f"Wrote:\n  {out_topics}\n  {out_users}")


if __name__ == "__main__":
    main()

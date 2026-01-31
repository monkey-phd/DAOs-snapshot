# verify_outcome_credibility_discourse.py
import re
import html as html_lib
import numpy as np
import pandas as pd
from bs4 import BeautifulSoup
from scipy.stats import chi2_contingency
import statsmodels.formula.api as smf

# -----------------------------
# 1) Load
# -----------------------------
posts_path = "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data/csvs/discourse_posts_final.csv"
topics_path = "/Users/magnusvanhaaren/Erasmus Universiteit Rotterdam Dropbox/Magnus van Haaren/Empirical Paper on DAOs/Empirical Paper on DAOs (MvHxHK)/Data/csvs/discourse_topics_core_by_proposal.csv"


posts = pd.read_csv(posts_path)
topics = pd.read_csv(topics_path)

print("posts rows:", len(posts))
print("unique post_id:", posts["post_id"].nunique())
print("duplicate rows:", len(posts) - posts["post_id"].nunique())

# Deduplicate
posts = posts.drop_duplicates(subset=["post_id"]).copy()

# Map topic_id -> space (proposal mapping has duplicates but space is stable)
topics_map = topics[topics["topic_id"].notna()].copy()
topics_map["topic_id"] = topics_map["topic_id"].astype(int)

posts["topic_id"] = posts["topic_id"].astype(int)
posts = posts.merge(topics_map[["topic_id", "space"]], on="topic_id", how="left")


# -----------------------------
# 2) Cooked HTML -> plain text
# -----------------------------
def html_to_text(cooked: str) -> str:
    if cooked is None or (isinstance(cooked, float) and np.isnan(cooked)):
        return ""
    s = html_lib.unescape(str(cooked))
    soup = BeautifulSoup(s, "html.parser")
    txt = soup.get_text(separator=" ", strip=True)
    txt = re.sub(r"\s+", " ", txt).strip()
    return txt


posts["text"] = posts["cooked"].apply(html_to_text)

# -----------------------------
# 3) Text measures
# -----------------------------
# Governance context
GOV = re.compile(
    r"\b(vote|voting|voter|voters|proposal|governance|quorum|snapshot|tally|result|results|outcome|outcomes)\b",
    re.I,
)

# Fairness rhetoric (control)
FAIR = re.compile(
    r"\b(unfair|not fair|unjust|injustice|biased|bias|unfairly|procedur\w* justice|due process|rights?|legitimacy)\b",
    re.I,
)
posts["fairness"] = posts["text"].apply(
    lambda t: int(bool(t and FAIR.search(t) and GOV.search(t)))
)

# Credibility/outcome undermining components
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


def cred_integrity(t: str) -> int:
    if not t:
        return 0
    if INTEGRITY_TERMS.search(t) and GOV.search(t):
        return 1
    if MANIP_VOTE.search(t):
        return 1
    return 0


def cred_risk(t: str) -> int:
    if not t:
        return 0
    return int(
        bool(
            RISK_STRUCT.search(t)
            and re.search(r"\b(vote|voting|voter|voters)\b", t, flags=re.I)
        )
    )


def futility(t: str) -> int:
    if not t:
        return 0
    return int(bool(FUTILITY.search(t) and GOV.search(t)))


posts["cred_integrity"] = posts["text"].apply(cred_integrity)
posts["cred_risk"] = posts["text"].apply(cred_risk)
posts["futility"] = posts["text"].apply(futility)

posts["cred_undermine"] = posts[["cred_integrity", "cred_risk", "futility"]].max(axis=1)

# -----------------------------
# 4) Descriptives
# -----------------------------
n_posts = len(posts)
print("\n== Prevalence ==")
for col in ["cred_integrity", "cred_risk", "futility", "cred_undermine", "fairness"]:
    print(f"{col:16s}: {posts[col].sum():4d}  ({posts[col].mean() * 100:5.2f}%)")

print(
    "\nSpaces with any cred_undermine:",
    posts.loc[posts["cred_undermine"] == 1, "space"].nunique(),
)
print("Spaces with any fairness:", posts.loc[posts["fairness"] == 1, "space"].nunique())

# Staff vs nonstaff check (proxy for “misaligned”)
overall_staff = posts["staff"].mean()
staff_in_cred = posts.loc[posts["cred_undermine"] == 1, "staff"].mean()
print("\n== Staff share ==")
print("overall staff share:", round(overall_staff, 3))
print("staff share in cred_undermine posts:", round(staff_in_cred, 3))

ct = pd.crosstab(posts["cred_undermine"], posts["staff"])
chi2, pval, _, _ = chi2_contingency(ct)
print("\nChi-square cred_undermine x staff: p =", pval)

# Top spaces (counts)
top_spaces = (
    posts[posts["cred_undermine"] == 1]
    .groupby("space")
    .size()
    .sort_values(ascending=False)
    .head(10)
)
print("\nTop spaces by cred_undermine posts:")
print(top_spaces)

# -----------------------------
# 5) Aggregate to topic_id then assign to proposals
# -----------------------------
topic_content = (
    posts.groupby("topic_id")
    .agg(
        n_posts_text=("post_id", "count"),
        n_cred_undermine=("cred_undermine", "sum"),
        n_fairness=("fairness", "sum"),
    )
    .reset_index()
)

topic_content["share_cred_undermine"] = np.where(
    topic_content["n_posts_text"] > 0,
    topic_content["n_cred_undermine"] / topic_content["n_posts_text"],
    0.0,
)
topic_content["share_fairness"] = np.where(
    topic_content["n_posts_text"] > 0,
    topic_content["n_fairness"] / topic_content["n_posts_text"],
    0.0,
)

# Proposal-level panel
disc = topics_map.copy()
disc["created_at"] = pd.to_datetime(disc["created_at"], utc=True, errors="coerce")
disc = disc.dropna(subset=["created_at"]).sort_values(
    ["space", "created_at", "proposal_id"]
)

disc = disc.merge(
    topic_content[["topic_id", "share_cred_undermine", "share_fairness"]],
    on="topic_id",
    how="left",
).fillna(0)

disc["cred_undermine_pp"] = 100 * disc["share_cred_undermine"]
disc["fairness_pp"] = 100 * disc["share_fairness"]

# Next outcome
disc["next_posts_count"] = disc.groupby("space")["posts_count"].shift(-1)
disc = disc.dropna(subset=["next_posts_count"]).copy()
disc["ln_next_posts"] = np.log1p(disc["next_posts_count"])
disc["ln_posts"] = np.log1p(disc["posts_count"])

# -----------------------------
# 6) Regression test: do these discourse signals predict declining participation?
# -----------------------------
formula = "ln_next_posts ~ cred_undermine_pp + fairness_pp + reply_ratio_regular + system_post_ratio + ln_posts + C(space)"
m = smf.ols(formula, data=disc).fit(
    cov_type="cluster", cov_kwds={"groups": disc["space"]}
)

print("\n== Main model ==")
print(m.summary().tables[1])

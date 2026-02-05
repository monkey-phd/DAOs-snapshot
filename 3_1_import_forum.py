import json
import math
import os
import pandas as pd
import random
import re
import requests
import time
import validators
from pathlib import Path

from bs4 import BeautifulSoup
from seleniumbase import SB

# working directory to the parent directory of the script's location
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

repo_root = Path(__file__).resolve().parent
os.chdir(repo_root)
Path("csvs").mkdir(parents=True, exist_ok=True)
Path("json").mkdir(parents=True, exist_ok=True)

# load propositions
props = pd.read_csv(
    "input/snapshot-hub-mainnet-2023-08-30-proposals_0.csv", low_memory=False
)
filename = "csvs/forum_urls.csv"


def get_urls():
    if os.path.exists(filename):
        df = pd.read_csv(filename)
    else:
        urls = []
        for url in props.loc[props["discussion"].notna()]["discussion"].tolist():
            if validators.url(url) and re.search("^http[s]?://forum.", url):
                urls.append(url)

        df = pd.DataFrame(urls, columns=["url"])
        df["exists"] = None
        df["body"] = None
        df.to_csv(filename, index=False)

    return df


def check_urls():
    urls = get_urls()
    for url in urls.itertuples():
        if math.isnan(url.exists):
            print(url.url)
            try:
                r = requests.get(url.url)
                urls.at[url.Index, "exists"] = r.status_code == 200
                if r.status_code == 200:
                    urls.at[url.Index, "body"] = r.text
            except:
                urls.at[url.Index, "exists"] = False

            urls.to_csv(filename, index=False)
            time.sleep(random.randrange(10, 15))


def scarpe_selenium():
    urls = get_urls()

    if "selenium_body" not in urls:
        urls["selenium_body"] = None

    for url in urls.itertuples():
        if url.exists and (
            not url.selenium_body
            or (type(url.selenium_body) != str and math.isnan(url.selenium_body))
        ):
            print(url.url)
            with SB(uc=True, headless=True) as driver:
                driver.uc_open_with_reconnect(url.url, 4)

                try:
                    driver.assert_element("section#main", timeout=3)
                    page_height = driver.get_window_size()["height"]

                    while True:
                        print(page_height)
                        driver.scroll_to_bottom()
                        time.sleep(2)
                        if driver.get_window_size()["height"] > page_height:
                            page_height = driver.get_window_size()["height"]
                        else:
                            break
                except:
                    pass

                page_source = driver.execute_script(
                    "return document.documentElement.outerHTML;"
                )
                urls.at[url.Index, "selenium_body"] = page_source

            urls.to_csv(filename, index=False)
            time.sleep(random.randrange(10, 15))


def get_discourse_data():
    urls = get_urls()
    urls["is_selenium"] = False
    urls["is_discourse"] = False
    urls["discourse_json"] = False
    for url in urls.itertuples():
        if url.exists and type(url.selenium_body) == str:
            urls.at[url.Index, "is_selenium"] = True
            if "<discourse-assets>" in url.selenium_body:
                soup = BeautifulSoup(url.selenium_body, "html.parser")
                data = json.loads(
                    soup.select("discourse-assets-json > div")[0]["data-preloaded"]
                )
                keys = [k for k in list(data.keys()) if k[:6] == "topic_"]
                if len(keys) > 0:
                    data = json.loads(data[keys[0]])
                    urls.at[url.Index, "is_discourse"] = True
                    urls.at[url.Index, "discourse_json"] = json.dumps(data)

    urls.to_csv(filename, index=False)


def filter_usable_data():
    urls = get_urls()
    urls = urls.loc[urls["is_discourse"] == True]
    urls = urls[["url", "selenium_body", "discourse_json"]]
    urls = urls.rename(columns={"selenium_body": "html", "discourse_json": "json"})
    urls.to_csv("csvs/discourse.csv", index=False)

    for i, url in enumerate(urls.itertuples()):
        data = json.loads(url.json)
        data["url"] = url.url
        with open(f"json/{i + 1}.json", "w", encoding="utf-8") as json_file:
            json.dump(data, json_file)


if __name__ == "__main__":
    check_urls()
    scarpe_selenium()
    get_discourse_data()
    filter_usable_data()

# builds discourse_posts_final.csv from discourse.csv


def export_discourse_posts_final(
    input_csv="csvs/discourse.csv",
    output_csv="csvs/discourse_posts_final.csv",
):
    if not os.path.exists(input_csv):
        raise FileNotFoundError(f"{input_csv} not found. Expected it to already exist.")

    df = pd.read_csv(input_csv, low_memory=False)

    if "url" not in df.columns or "json" not in df.columns:
        raise ValueError(
            f"{input_csv} must contain columns 'url' and 'json'. "
            f"Found: {list(df.columns)}"
        )

    # ---- extract posts from Discourse JSON ----
    def extract_posts(json_str):
        if pd.isna(json_str) or not str(json_str).strip():
            return []
        try:
            data = json.loads(json_str)
            return data.get("post_stream", {}).get("posts", []) or []
        except Exception:
            return []

    df["posts"] = df["json"].apply(extract_posts)

    # ---- explode to one row per post ----
    df_posts = df[["url", "posts"]].explode("posts").dropna(subset=["posts"])

    posts_expanded = df_posts["posts"].apply(pd.Series)

    df_posts = pd.concat(
        [
            df_posts.drop(columns=["posts"]).reset_index(drop=True),
            posts_expanded.reset_index(drop=True),
        ],
        axis=1,
    )

    # ---- select ONLY platform-assigned variables ----
    FINAL_COLUMNS = [
        "url",
        "id",  # post id
        "post_number",
        "reply_to_post_number",
        "username",
        "trust_level",
        "created_at",
        "updated_at",
        "reads",
        "score",
        "cooked",
    ]

    df_final = df_posts[[c for c in FINAL_COLUMNS if c in df_posts.columns]].copy()

    # rename for clarity
    if "id" in df_final.columns:
        df_final.rename(columns={"id": "post_id"}, inplace=True)

    # numeric coercion (Stata-safe)
    for col in ["post_number", "reply_to_post_number", "trust_level", "reads"]:
        if col in df_final.columns:
            df_final[col] = pd.to_numeric(df_final[col], errors="coerce")

    if "score" in df_final.columns:
        df_final["score"] = pd.to_numeric(df_final["score"], errors="coerce")

    # stable ordering
    if "post_number" in df_final.columns:
        df_final = df_final.sort_values(["url", "post_number"])

    df_final.to_csv(output_csv, index=False)

    print("--------------------------------------------------")
    print("[export_discourse_posts_final]")
    print(f"Threads read : {len(df):,}")
    print(f"Posts exported: {len(df_final):,}")
    print(f"Saved to     : {output_csv}")
    print("--------------------------------------------------")


# ---- run ONLY the export (no scraping, no selenium) ----
if __name__ == "__main__":
    export_discourse_posts_final()

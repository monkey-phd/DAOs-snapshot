import json
import math
import os
import pandas as pd
import random
import re
import requests
import time
import validators

from bs4 import BeautifulSoup
from seleniumbase import SB

# working directory to the parent directory of the script's location
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

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

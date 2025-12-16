import math
import os
import pandas as pd
import random
import re
import requests
import time
import validators


# load propositions
props = pd.read_csv("input/snapshot-hub-mainnet-2023-08-30-proposals_0.csv", low_memory=False)
filename = "csvs/form_urls.csv"

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
                urls.at[url.Index, 'exists'] = r.status_code == 200
                if r.status_code == 200:
                    urls.at[url.Index, 'body'] = r.text
            except:
                urls.at[url.Index, 'exists'] = False

            urls.to_csv(filename, index=False)
            time.sleep(random.randrange(10, 15))

if __name__ == "__main__":
    check_urls()

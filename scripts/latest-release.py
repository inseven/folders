#!/usr/bin/env python3

import argparse
import fnmatch
import re
import requests


def main():
    parser = argparse.ArgumentParser(description="Get the URL for an asset from the latest GitHub release matching a pattern.")
    parser.add_argument("owner")
    parser.add_argument("repository")
    parser.add_argument("pattern")
    options = parser.parse_args()

    response = requests.get(f"https://api.github.com/repos/{options.owner}/{options.repository}/releases/latest", headers={
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
    })

    regex = re.compile(fnmatch.translate(options.pattern))
    for asset in response.json()["assets"]:
        if not regex.match(asset["name"]):
            continue
        print(asset["browser_download_url"])
        return

    exit(f"Failed to find asset with pattern '{options.pattern}'.")


if __name__ == "__main__":
    main()

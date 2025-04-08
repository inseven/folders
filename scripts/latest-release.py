#!/usr/bin/env python3

# Copyright (c) 2023-2025 Jason Morley
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

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

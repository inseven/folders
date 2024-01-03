#!/bin/bash

# Copyright (c) 2023 Jason Barrie Morley
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

# This script serves as a runner for iOS and macOS project build jobs that ensures the 'changes' and 'build-tools'
# commands are available on the path, and that a temporary keychain has been set up for development (and will be cleaned
# up automatically on success or failure of the child script.
#
# It exports the following environment variables to the child script:
#
# - KEYCHAIN_PATH - the path of the temporary keychain
# - IOS_XCODE_PATH - the path of Xcode to use for iOS builds
# - MACOS_XCODE_PATH - the path of Xcode to use for macOS builds

set -e
set -o pipefail
set -x
set -u

SCRIPTS_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

ROOT_DIRECTORY="${SCRIPTS_DIRECTORY}/.."
TEMPORARY_DIRECTORY="${ROOT_DIRECTORY}/temp"

export PYTHONUSERBASE="${ROOT_DIRECTORY}/.local/python"
mkdir -p "$PYTHONUSERBASE"
export PATH="${PYTHONUSERBASE}/bin":$PATH

# TODO: Use mktemp -d
export KEYCHAIN_PATH="${TEMPORARY_DIRECTORY}/temporary.keychain"
ENV_PATH="${ROOT_DIRECTORY}/fastlane/.env"

# Tools paths.
CHANGES_DIRECTORY="${SCRIPTS_DIRECTORY}/changes"
BUILD_TOOLS_DIRECTORY="${SCRIPTS_DIRECTORY}/build-tools"

# Install the Python dependencies
pip3 install --user pipenv
PIPENV_PIPFILE="$CHANGES_DIRECTORY/Pipfile" pipenv install
PIPENV_PIPFILE="$BUILD_TOOLS_DIRECTORY/Pipfile" pipenv install

# Ensure the tools are on the path.
export PATH=$PATH:$CHANGES_DIRECTORY
export PATH=$PATH:$BUILD_TOOLS_DIRECTORY

# Expose the iOS and macOS Xcode paths to the command.
export MACOS_XCODE_PATH=${MACOS_XCODE_PATH:-/Applications/Xcode.app}
export IOS_XCODE_PATH=${IOS_XCODE_PATH:-/Applications/Xcode.app}

# Check that the GitHub command is available on the path.
which gh || (echo "GitHub cli (gh) not available on the path." && exit 1)

# Generate a random string to secure the local keychain.
export TEMPORARY_KEYCHAIN_PASSWORD=`openssl rand -base64 14`

# Source .env file if it exists to make local development easier.
if [ -f "$ENV_PATH" ] ; then
    echo "Sourcing .env..."
    source "$ENV_PATH"
fi

# Create the a new keychain.
if [ -d "$TEMPORARY_DIRECTORY" ] ; then
    rm -rf "$TEMPORARY_DIRECTORY"
fi
mkdir -p "$TEMPORARY_DIRECTORY"
echo "$TEMPORARY_KEYCHAIN_PASSWORD" | build-tools create-keychain "$KEYCHAIN_PATH" --password

function cleanup {

    # Cleanup the temporary files and keychain.
    cd "$ROOT_DIRECTORY"
    build-tools delete-keychain "$KEYCHAIN_PATH"
    rm -rf "$TEMPORARY_DIRECTORY"
}

trap cleanup EXIT

# Run our child command.
COMMAND=$1; shift
echo "Running command '$COMMAND' with arguments '$@'..."
"$COMMAND" "$@"

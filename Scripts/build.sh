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

set -e
set -o pipefail
set -x
set -u

SCRIPTS_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

ROOT_DIRECTORY="${SCRIPTS_DIRECTORY}/.."
BUILD_DIRECTORY="${ROOT_DIRECTORY}/build"

ARCHIVE_PATH="${BUILD_DIRECTORY}/Helper.xcarchive"

KEYCHAIN_PATH=${KEYCHAIN_PATH:-login}

# Process the command line arguments.
POSITIONAL=()
RELEASE=${RELEASE:-false}
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -r|--release)
        RELEASE=true
        shift
        ;;
        *)
        POSITIONAL+=("$1")
        shift
        ;;
    esac
done

cd "$ROOT_DIRECTORY"

# Clean up the build directory.
if [ -d "$BUILD_DIRECTORY" ] ; then
    rm -r "$BUILD_DIRECTORY"
fi
mkdir -p "$BUILD_DIRECTORY"

# Configure Xcode version
if [ -z ${MACOS_XCODE_PATH+x} ] ; then
    echo "Skipping Xcode selection..."
else
    sudo xcode-select --switch "$MACOS_XCODE_PATH"
fi

# Determine the version and build number.
VERSION_NUMBER=`changes version`
BUILD_NUMBER=`build-tools generate-build-number`

# Import the certificates into our dedicated keychain.
if [ -z ${DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD+x} ] ; then
    echo "Skipping certificate import..."
else
    echo "$DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD" | build-tools import-base64-certificate \
        --password \
        "$KEYCHAIN_PATH" \
        "$DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64"
fi

# Install the provisioning profiles.
# build-tools install-provisioning-profile "Helper/InContext_Helper_Developer_ID_Profile.provisionprofile"
# build-tools install-provisioning-profile "Helper/InContext_Helper_Mac_App_Store_Profile.provisionprofile"

# Build and archive.
xcodebuild \
    -project InContext.xcodeproj \
    -scheme "Folders" \
    -archivePath "$ARCHIVE_PATH" \
    MARKETING_VERSION=$VERSION_NUMBER \
    CURRENT_PROJECT_VERSION=$BUILD_NUMBER \
    clean archive

# # Export.
# xcodebuild \
#     -archivePath "$ARCHIVE_PATH" \
#     -exportArchive \
#     -exportPath "$BUILD_DIRECTORY" \
#     -exportOptionsPlist "InContext/ExportOptions.plist"
#
# # Compress the helper.
# # Apple recommends we use ditto to prepare zips for notarization.
# # https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow
# HELPER_ZIP_BASENAME="InContext-Helper-$VERSION_NUMBER-$BUILD_NUMBER.zip"
# HELPER_ZIP_PATH="$BUILD_DIRECTORY/$HELPER_ZIP_BASENAME"
# pushd "$BUILD_DIRECTORY"
# /usr/bin/ditto -c -k --keepParent "InContext Helper.app" "$HELPER_ZIP_BASENAME"
# rm -r "InContext Helper.app"
# popd
#
# API_KEY_PATH="${ROOT_DIRECTORY}/api.key"
#
# # Notarization.
#
# function cleanup {
#     echo "Cleaning up API key..."
#     rm -f "${API_KEY_PATH}"
# }
# trap cleanup EXIT
#
# echo "$APPLE_API_KEY_BASE64" | base64 -d > "$API_KEY_PATH"
#
# # Notarize the command.
#
# xcrun notarytool submit "$ZIP_PATH" \
#     --key "$API_KEY_PATH" \
#     --key-id "$APPLE_API_KEY_ID" \
#     --issuer "$APPLE_API_KEY_ISSUER_ID" \
#     --output-format json \
#     --wait | tee command-notarization-response.json
# NOTARIZATION_ID=`cat command-notarization-response.json | jq -r ".id"`
# NOTARIZATION_RESPONSE=`cat command-notarization-response.json | jq -r ".status"`
#
# xcrun notarytool log \
#     --key "$API_KEY_PATH" \
#     --key-id "$APPLE_API_KEY_ID" \
#     --issuer "$APPLE_API_KEY_ISSUER_ID" \
#     "$NOTARIZATION_ID" | tee "$BUILD_DIRECTORY/command-notarization-log.json"
#
# if [ "$NOTARIZATION_RESPONSE" != "Accepted" ] ; then
#     echo "Failed to notarize command."
#     exit 1
# fi
#
# # Notarize the helper.
#
# xcrun notarytool submit "$HELPER_ZIP_PATH" \
#     --key "$API_KEY_PATH" \
#     --key-id "$APPLE_API_KEY_ID" \
#     --issuer "$APPLE_API_KEY_ISSUER_ID" \
#     --output-format json \
#     --wait | tee helper-notarization-response.json
# NOTARIZATION_ID=`cat helper-notarization-response.json | jq -r ".id"`
# NOTARIZATION_RESPONSE=`cat helper-notarization-response.json | jq -r ".status"`
#
# xcrun notarytool log \
#     --key "$API_KEY_PATH" \
#     --key-id "$APPLE_API_KEY_ID" \
#     --issuer "$APPLE_API_KEY_ISSUER_ID" \
#     "$NOTARIZATION_ID" | tee "$BUILD_DIRECTORY/helper-notarization-log.json"
#
# if [ "$NOTARIZATION_RESPONSE" != "Accepted" ] ; then
#     echo "Failed to notarize helper."
#     exit 1
# fi
#
# # Create a GitHub release.
#
# if $RELEASE ; then
#
#     changes \
#         release \
#         --skip-if-empty \
#         --push \
#         --exec "Scripts/gh-release.sh" \
#         "$ZIP_PATH" \
#         "$HELPER_ZIP_PATH"
#
# fi

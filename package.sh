#!/bin/bash

# Configuration
ADDON_ID="skin.nimbus"
OUTPUT_ZIP="skin.nimbus.zip"

# Get the version from addon.xml
VERSION=$(grep -m 1 'version="' addon.xml | sed -e 's/.*version="\([^"]*\)".*/\1/')

if [ -z "$VERSION" ]; then
    echo "Error: Could not find version in addon.xml"
    exit 1
fi

echo "Packaging $ADDON_ID version $VERSION..."

# Create a temporary directory for the correct Kodi structure
TMP_DIR="tmp_package"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR/$ADDON_ID"

# Copy all files except git and script itself
rsync -av --progress ./ "$TMP_DIR/$ADDON_ID/" \
    --exclude ".git" \
    --exclude ".gitignore" \
    --exclude ".DS_Store" \
    --exclude "._*" \
    --exclude "package.sh" \
    --exclude "tmp_package" \
    --exclude "*.zip" \
    --exclude "xml_backups"

# Create the ZIP from inside the temp directory
cd "$TMP_DIR"
zip -r "../../$OUTPUT_ZIP" "$ADDON_ID"
cd ../..

# Cleanup
rm -rf "$TMP_DIR"

echo "--------------------------------------------------"
echo "Success! Package created: $OUTPUT_ZIP"
echo "Structure verified: $ADDON_ID/ folder is at the ZIP root."
echo "Version: $VERSION"
echo "--------------------------------------------------"

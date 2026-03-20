#!/bin/bash

# Configuration
ADDON_ID=$(sed -n 's/.*<addon id="\([^"]*\)".*/\1/p' addon.xml | head -1)
VERSION=$(sed -n 's/.*version="\([^"]*\)".*/\1/p' addon.xml | head -2 | tail -1)
REPO_DIR="repo"
SKIN_DIR="$REPO_DIR/$ADDON_ID"

if [ -z "$ADDON_ID" ] || [ -z "$VERSION" ]; then
    echo "Error: Could not find addon ID or version in addon.xml"
    exit 1
fi

ZIP_NAME="${ADDON_ID}-${VERSION}.zip"
ZIP_PATH="${SKIN_DIR}/${ZIP_NAME}"

echo "Releasing $ADDON_ID version $VERSION..."

# Ensure directories exist
mkdir -p "$SKIN_DIR"

# Step 1: Package the addon
echo "Packaging $ZIP_NAME..."
# Using python for reliable cross-platform zipping with correct root folder
python3 -c "
import os, zipfile, re
addon_id = '$ADDON_ID'
with zipfile.ZipFile('$ZIP_PATH', 'w', zipfile.ZIP_DEFLATED) as zipf:
    for root, dirs, files in os.walk('.'):
        if any(x in root for x in ['.git', '$REPO_DIR', 'tmp_package']): continue
        for file in files:
            if file in ['.gitignore', '.DS_Store', 'package.sh', 'update_repo.py', 'release.sh', 'skin.nimbus.zip']: continue
            abs_path = os.path.join(root, file)
            arc_name = os.path.join(addon_id, os.path.relpath(abs_path, '.'))
            zipf.write(abs_path, arc_name)
"

# Step 2: Generate MD5
echo "Generating MD5..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    md5 -q "$ZIP_PATH" > "${ZIP_PATH}.md5"
else
    md5sum "$ZIP_PATH" | awk '{ print $1 }' > "${ZIP_PATH}.md5"
fi

# Step 3: Generate addons.xml
echo "Generating addons.xml..."
echo '<?xml version="1.0" encoding="UTF-8"?>' > "$REPO_DIR/addons.xml"
echo '<addons>' >> "$REPO_DIR/addons.xml"
# Filter out the XML declaration from addon.xml and append
sed 's/<?xml.*?>//g' addon.xml >> "$REPO_DIR/addons.xml"
echo '</addons>' >> "$REPO_DIR/addons.xml"

# Step 4: Generate addons.xml.md5
if [[ "$OSTYPE" == "darwin"* ]]; then
    md5 -q "$REPO_DIR/addons.xml" > "$REPO_DIR/addons.xml.md5"
else
    md5sum "$REPO_DIR/addons.xml" | awk '{ print $1 }' > "$REPO_DIR/addons.xml.md5"
fi

echo "--------------------------------------------------"
echo "Success! Release files created in the '$REPO_DIR/' directory."
echo "Now commit and push the '$REPO_DIR/' folder to GitHub."
echo "--------------------------------------------------"

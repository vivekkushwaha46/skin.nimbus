#!/bin/bash

# Configuration
REPO_DIR="repo"
PACKAGES_DIR="packages"

echo "Building Kodi Repository Distribution..."

# Ensure repo directory exists
mkdir -p "$REPO_DIR"

# Initialize addons.xml
echo '<?xml version="1.0" encoding="UTF-8"?>' > "$REPO_DIR/addons.xml"
echo '<addons>' >> "$REPO_DIR/addons.xml"

# Function to generate MD5 in a portable way
gen_md5() {
    local file=$1
    if [[ "$OSTYPE" == "darwin"* ]]; then
        md5 -q "$file" > "${file}.md5"
    else
        md5sum "$file" | awk '{ print $1 }' > "${file}.md5"
    fi
}

# Iterate through all addons in the packages directory
for addon_path in "$PACKAGES_DIR"/*/; do
    [ -e "$addon_path" ] || continue
    addon_id=$(basename "$addon_path")
    addon_xml="$addon_path/addon.xml"
    
    if [ ! -f "$addon_xml" ]; then
        echo "Skipping $addon_id: No addon.xml found."
        continue
    fi
    
    version=$(sed -n 's/.*<addon.*version="\([^"]*\)".*/\1/p' "$addon_xml" | head -1)
    echo "Processing $addon_id version $version..."
    
    # Create addon-specific folder in repo
    out_dir="$REPO_DIR/$addon_id"
    mkdir -p "$out_dir"
    
    zip_name="${addon_id}-${version}.zip"
    zip_path="${out_dir}/${zip_name}"
    
    # Step 1: Package the addon
    echo "  - Packaging $zip_name..."
    # Ensure ZIP contains the correct root folder
    (cd "$PACKAGES_DIR" && zip -r "../$zip_path" "$addon_id" -x "*.git*" -x "*.DS_Store" -x "tmp_package/*" -x "repo/*") > /dev/null
    
    # Step 2: Generate MD5 for ZIP
    gen_md5 "$zip_path"
    
    # Step 3: Append metadata to addons.xml (removing declarations)
    sed 's/<?xml.*?>//g' "$addon_xml" >> "$REPO_DIR/addons.xml"
    echo "" >> "$REPO_DIR/addons.xml"
done

# Finalize addons.xml
echo '</addons>' >> "$REPO_DIR/addons.xml"
gen_md5 "$REPO_DIR/addons.xml"

echo "--------------------------------------------------"
echo "Success! All addons packaged in the '$REPO_DIR/' directory."
echo "Now commit and push the '$REPO_DIR/' and '$PACKAGES_DIR/' folders to GitHub."
echo "--------------------------------------------------"

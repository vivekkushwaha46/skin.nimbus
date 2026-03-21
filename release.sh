#!/bin/bash

# Configuration
REPO_DIR="/Users/imvivek/work/kodi-repo"
PACKAGES_DIR="packages"
TEXTURE_PACKER="./TexturePacker"

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
    
    # Create addon-specific folder in repo and CLEAN OLD VERSIONS
    out_dir="$REPO_DIR/$addon_id"
    mkdir -p "$out_dir"
    echo "  - Cleaning old versions in $out_dir..."
    rm -f "$out_dir"/*.zip "$out_dir"/*.zip.md5
    
    # TexturePacker optimization for skin.nimbus
    if [ "$addon_id" == "skin.nimbus" ]; then
        echo "  - Optimizing textures for skin.nimbus..."
        MEDIA_DIR="$addon_path/media"
        TEMP_MEDIA_DIR="media_temp"
        
        if [ -d "$MEDIA_DIR" ]; then
            # Clean up previous attempts
            rm -rf "$TEMP_MEDIA_DIR"
            mkdir -p "$TEMP_MEDIA_DIR"
            
            # Move all media files to temp to pack them
            # Use cp then rm to avoid move issues across docker mounts if needed, 
            # but here it's all local.
            cp -r "$MEDIA_DIR"/* "$TEMP_MEDIA_DIR/" 2>/dev/null
            rm -f "$MEDIA_DIR"/* 2>/dev/null
            
            # Pack textures into Textures.xbt using Docker (for ARM64 compatibility)
            echo "    - Packing textures into Textures.xbt using Docker..."
            docker run --rm -v "$(pwd):/work" -w /work debian:sid sh -c "apt-get update && apt-get install -y kodi-tools-texturepacker > /dev/null && kodi-TexturePacker -input /work/$TEMP_MEDIA_DIR/ -output /work/$MEDIA_DIR/Textures.xbt -dupecheck" > /dev/null 2>&1
            
            if [ -f "$MEDIA_DIR/Textures.xbt" ]; then
                echo "    - Successfully created Textures.xbt"
            else
                echo "    - ERROR: Failed to create Textures.xbt"
                # Restore files if failed
                cp -r "$TEMP_MEDIA_DIR"/* "$MEDIA_DIR/" 2>/dev/null
            fi
        fi
    fi
    
    zip_name="${addon_id}-${version}.zip"
    # Get absolute path for ZIP to avoid issues with cd in subshell
    zip_path="$(mkdir -p "$out_dir" && cd "$out_dir" && pwd)/$zip_name"
    
    # Step 1: Package the addon
    echo "  - Packaging $zip_name..."
    # If it's the skin, exclude the individual media files from the ZIP
    if [ "$addon_id" == "skin.nimbus" ]; then
        # Use -0 (store only) for faster installation on the TV
        (cd "$PACKAGES_DIR" && zip -0r "$zip_path" "$addon_id" -x "*.git*" -x "*.DS_Store" -x "tmp_package/*" -x "repo/*" -x "$addon_id/media/*" -x "$addon_id/media_temp/*")
        # Add the Textures.xbt manually to ensure it's included
        (cd "$PACKAGES_DIR" && zip -0g "$zip_path" "$addon_id/media/Textures.xbt")
        
        # Restore media files back to the original folder
        mv "$TEMP_MEDIA_DIR"/* "$MEDIA_DIR/" 2>/dev/null
        rm -rf "$TEMP_MEDIA_DIR"
    else
        (cd "$PACKAGES_DIR" && zip -0r "$zip_path" "$addon_id" -x "*.git*" -x "*.DS_Store" -x "tmp_package/*" -x "repo/*")
    fi
    
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

#!/bin/bash

# Configuration
REPO_DIR="repo"
PACKAGES_DIR="packages"

echo "============================================="
echo "Building Kodi Repository Distribution..."
echo "============================================="

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

# Pre-clean junk files from packages directory
echo "Cleaning junk files from packages..."
find "$PACKAGES_DIR" -name ".DS_Store" -delete 2>/dev/null
find "$PACKAGES_DIR" -name "*.pyc" -delete 2>/dev/null
find "$PACKAGES_DIR" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null
find "$PACKAGES_DIR" -name "Thumbs.db" -delete 2>/dev/null
find "$PACKAGES_DIR" -name "._.DS_Store" -delete 2>/dev/null
find "$PACKAGES_DIR" -name "._*" -delete 2>/dev/null

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
    echo ""
    echo "Processing $addon_id version $version..."

    # Create addon-specific folder in repo and CLEAN OLD VERSIONS
    out_dir="$REPO_DIR/$addon_id"
    mkdir -p "$out_dir"
    echo "  - Cleaning old versions in $out_dir..."
    rm -f "$out_dir"/*.zip "$out_dir"/*.zip.md5

    zip_name="${addon_id}-${version}.zip"
    zip_path="$(mkdir -p "$out_dir" && cd "$out_dir" && pwd)/$zip_name"

    # Standard junk-file exclusion list
    EXCLUDES=(-x "*.git*" -x "*.DS_Store" -x "._*" -x "Thumbs.db" -x "*.pyc" -x "*/__pycache__/*" -x "tmp_package/*" -x "repo/*" -x "media_temp/*")

    echo "  - Packaging $zip_name..."

    if [ "$addon_id" == "skin.nimbus" ]; then
        # -------------------------------------------------
        # SKIN PACKAGING: Use normal compression (-9 max)
        # The -0 flag creates huge uncompressed zips that cause
        # Kodi to make hundreds of HTTP range-requests on remote
        # install, leading to hangs/crashes on GitHub Pages.
        # -------------------------------------------------
        SKIN_EXCLUDES=("${EXCLUDES[@]}" -x "$addon_id/media_temp/*")

        # Try TexturePacker if Docker is available
        MEDIA_DIR="$addon_path/media"
        TEMP_MEDIA_DIR="media_temp"
        TEXTURES_PACKED=false

        if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
            if [ -d "$MEDIA_DIR" ] && [ "$(ls -A "$MEDIA_DIR" 2>/dev/null | grep -v Textures.xbt)" ]; then
                echo "  - Optimizing textures via Docker TexturePacker..."
                rm -rf "$TEMP_MEDIA_DIR"
                mkdir -p "$TEMP_MEDIA_DIR"
                cp -r "$MEDIA_DIR"/* "$TEMP_MEDIA_DIR/" 2>/dev/null
                rm -f "$MEDIA_DIR"/* 2>/dev/null

                docker run --rm -v "$(pwd):/work" -w /work debian:sid sh -c \
                    "apt-get update && apt-get install -y kodi-tools-texturepacker > /dev/null && kodi-TexturePacker -input /work/$TEMP_MEDIA_DIR/ -output /work/$MEDIA_DIR/Textures.xbt -dupecheck" > /dev/null 2>&1

                if [ -f "$MEDIA_DIR/Textures.xbt" ]; then
                    echo "    - Successfully created Textures.xbt"
                    TEXTURES_PACKED=true
                else
                    echo "    - TexturePacker failed, packaging raw media files instead"
                    cp -r "$TEMP_MEDIA_DIR"/* "$MEDIA_DIR/" 2>/dev/null
                fi
            fi
        else
            echo "  - Docker not available, packaging raw media files (no TexturePacker)"
        fi

        if [ "$TEXTURES_PACKED" = true ]; then
            # Exclude raw media, include only Textures.xbt
            (cd "$PACKAGES_DIR" && zip -9r "$zip_path" "$addon_id" "${SKIN_EXCLUDES[@]}" -x "$addon_id/media/*")
            (cd "$PACKAGES_DIR" && zip -9g "$zip_path" "$addon_id/media/Textures.xbt")
            # Restore raw media
            mv "$TEMP_MEDIA_DIR"/* "$MEDIA_DIR/" 2>/dev/null
            rm -rf "$TEMP_MEDIA_DIR"
        else
            # Package with raw media, using -9 for max compression (critical for HTTP installs)
            (cd "$PACKAGES_DIR" && zip -9r "$zip_path" "$addon_id" "${SKIN_EXCLUDES[@]}")
        fi
    else
        # Non-skin addons: use -9 for max compression (critical for HTTP installs)
        (cd "$PACKAGES_DIR" && zip -9r "$zip_path" "$addon_id" "${EXCLUDES[@]}")
    fi

    # Verify zip was created
    if [ -f "$zip_path" ]; then
        zip_size=$(du -h "$zip_path" | cut -f1)
        echo "  - Created: $zip_name ($zip_size)"
    else
        echo "  - ERROR: Failed to create $zip_name"
        continue
    fi

    # Generate MD5 for ZIP
    gen_md5 "$zip_path"

    # Append metadata to addons.xml (removing declarations)
    sed 's/<?xml.*?>//g' "$addon_xml" >> "$REPO_DIR/addons.xml"
    echo "" >> "$REPO_DIR/addons.xml"
done

# Finalize addons.xml
echo '</addons>' >> "$REPO_DIR/addons.xml"
gen_md5 "$REPO_DIR/addons.xml"

echo ""
echo "============================================="
echo "Build Complete!"
echo "Addons packaged in '$REPO_DIR/':"
ls -lh "$REPO_DIR"/*/*.zip 2>/dev/null
echo "============================================="

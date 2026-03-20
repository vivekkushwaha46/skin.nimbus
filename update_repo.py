import os
import hashlib
import zipfile
import re
from datetime import datetime

# Configuration
ADDON_ID = "skin.nimbus"
REPO_DIR = "repo"
SKIN_DIR = os.path.join(REPO_DIR, ADDON_ID)

def get_version():
    with open("addon.xml", "r") as f:
        content = f.read()
        # Look specifically for the addon version, skipping the XML declaration
        match = re.search(r'<addon[^>]+version="([^"]+)"', content)
        return match.group(1) if match else "1.0.0"

def get_md5(fname):
    hash_md5 = hashlib.md5()
    with open(fname, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()

def create_directory_listing(path, title, files):
    html_template = """<!DOCTYPE html>
<html>
<head>
    <title>Directory listing for {title}</title>
    <style>
        body {{ font-family: sans-serif; padding: 20px; }}
        h1 {{ border-bottom: 1px solid #ccc; }}
        ul {{ list-style: none; padding: 0; }}
        li {{ margin: 10px 0; }}
        a {{ text-decoration: none; color: #0000ee; }}
        a:hover {{ text-decoration: underline; }}
    </style>
</head>
<body>
    <h1>Directory listing for {title}</h1>
    <hr>
    <ul>
        <li><a href="..">..</a></li>
        {links}
    </ul>
</body>
</html>
"""
    links = ""
    for f in files:
        links += f'        <li><a href="{f}">{f}</a></li>\n'
    
    with open(os.path.join(path, "index.html"), "w") as f:
        f.write(html_template.format(title=title, links=links))

def main():
    version = get_version()
    zip_name = f"{ADDON_ID}-{version}.zip"
    zip_path = os.path.join(SKIN_DIR, zip_name)
    
    print(f"Creating repository for {ADDON_ID} version {version}...")
    
    # Ensure directories exist
    os.makedirs(SKIN_DIR, exist_ok=True)
    
    # Package the skin
    print(f"Packaging {zip_name}...")
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk("."):
            # Exclude folders
            if any(x in root for x in [".git", REPO_DIR, "tmp_package"]):
                continue
            for file in files:
                if file in [".gitignore", ".DS_Store", "package.sh", "update_repo.py", "skin.nimbus.zip"]:
                    continue
                abs_path = os.path.join(root, file)
                # Map to internal folder skin.nimbus/
                arc_name = os.path.join(ADDON_ID, os.path.relpath(abs_path, "."))
                zipf.write(abs_path, arc_name)
    
    # Create MD5
    print("Generating MD5...")
    md5_val = get_md5(zip_path)
    with open(f"{zip_path}.md5", "w") as f:
        f.write(md5_val)
        
    # Copy addon.xml to use for repository index (Kodi requirement)
    # Note: A real repo needs an addons.xml containing ALL addons.
    # For a single-addon repo, we can just use the addon description.
    with open(os.path.join(REPO_DIR, "addons.xml"), "w") as f:
        with open("addon.xml", "r") as src:
            f.write('<?xml version="1.0" encoding="UTF-8"?>\n<addons>\n')
            f.write(src.read())
            f.write('\n</addons>')
            
    with open(os.path.join(REPO_DIR, "addons.xml.md5"), "w") as f:
        f.write(get_md5(os.path.join(REPO_DIR, "addons.xml")))

    # Create HTML listings
    create_directory_listing(REPO_DIR, "repository.nimbus", [f"{ADDON_ID}/", "addons.xml", "addons.xml.md5"])
    create_directory_listing(SKIN_DIR, ADDON_ID, [zip_name, f"{zip_name}.md5"])
    
    print("-" * 50)
    print("Success! Repository generated in the 'repo/' directory.")
    print(f"URL path: /{ADDON_ID}/{zip_name}")
    print("-" * 50)

if __name__ == "__main__":
    main()

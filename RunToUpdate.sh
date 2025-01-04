#!/bin/bash

# Exit on any error
set -e

REPO_URL="https://github.com/VilktorK/DummySimpleVenvManager"
TEMP_DIR=$(mktemp -d)

echo "Starting update process..."

# Cleanup function to remove temporary directory
cleanup() {
    echo "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
}

# Register cleanup function to run on script exit
trap cleanup EXIT

# Get the directory where the script is located
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

echo "Cloning repository to temporary directory..."
git clone "$REPO_URL" "$TEMP_DIR"

echo "Updating files..."
# Copy all files from temp directory to script directory
cd "$TEMP_DIR"
for file in *; do
    if [ -f "$file" ]; then
        echo "Updating $file..."
        cp -f "$file" "$SCRIPT_DIR/$file"
    fi
done

echo "Making scripts executable..."
chmod +x "$SCRIPT_DIR"/*.sh

echo "Update complete!"
echo "You may need to restart any running instances of the manager for changes to take effect."

exit 0

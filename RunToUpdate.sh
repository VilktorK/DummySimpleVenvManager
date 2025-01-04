#!/bin/bash
# Exit on any error
set -e

REPO_URL="https://github.com/VilktorK/DummySimpleVenvManager"
TEMP_DIR=$(mktemp -d)
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LAST_COMMIT_FILE="$SCRIPT_DIR/.last_commit"

echo "Starting update process..."

# Cleanup function to remove temporary directory
cleanup() {
    echo "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    echo ""
    echo "Press Enter to exit..."
    read -r
}

# Function to handle script exit
exit_script() {
    local exit_code=$1
    cleanup
    exit "$exit_code"
}

# Register cleanup function to run on script exit
trap cleanup EXIT

# Function to get the latest commit hash from remote repository
get_remote_commit() {
    git ls-remote "$REPO_URL" HEAD | cut -f1
}

# Get the current remote commit hash
REMOTE_COMMIT=$(get_remote_commit)

# Check if we have a stored last commit hash
if [ -f "$LAST_COMMIT_FILE" ]; then
    LAST_COMMIT=$(cat "$LAST_COMMIT_FILE")
    
    if [ "$REMOTE_COMMIT" = "$LAST_COMMIT" ]; then
        echo "No new commits detected. Already up to date!"
        exit_script 0
    fi
fi

echo "New updates detected. Proceeding with update..."

# Clone repository to temporary directory
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

# Store the new commit hash
echo "$REMOTE_COMMIT" > "$LAST_COMMIT_FILE"

echo "Making scripts executable..."
chmod +x "$SCRIPT_DIR"/*.sh

echo "Update complete!"
echo "You may need to restart any running instances of the manager for changes to take effect."
exit_script 0

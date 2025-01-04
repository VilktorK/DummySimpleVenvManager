#!/bin/bash
# Exit on any error
set -e

REPO_URL="https://github.com/VilktorK/DummySimpleVenvManager"
TEMP_DIR=$(mktemp -d)
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LAST_COMMIT_FILE="$SCRIPT_DIR/.last_commit"

# Color codes
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "Starting update process..."

# Cleanup function to remove temporary directory
cleanup() {
    echo "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
}

# Function to wait for user input before exit
wait_for_exit() {
    echo ""
    echo "Press Enter to exit..."
    read -r
    exit 0
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
        echo -e "${RED}No new commits detected. Already up to date!${NC}"
        wait_for_exit
    fi
fi

echo -e "${BLUE}New updates detected. Proceeding with update...${NC}"

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
echo "You will need to relaunch any running instances of the manager for changes to take effect."
wait_for_exit

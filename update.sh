#!/bin/bash
# Exit on any error
set -e

REPO_URL="https://github.com/VilktorK/DummySimpleVenvManager"  # Change as needed
TEMP_DIR=$(mktemp -d)
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LAST_COMMIT_FILE="$SCRIPT_DIR/.last_commit"

# Color codes
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Cleanup function to remove temporary directory
cleanup() {
    echo "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
}

# Function to wait for user input before exit
wait_for_exit() {
    if [ "$CHECK_ONLY" != "true" ]; then
        echo ""
        echo "Press Enter to exit..."
        read -r
    fi
    exit $1
}

# Register cleanup function to run on script exit
trap cleanup EXIT

# Function to get the latest commit hash from remote repository
get_remote_commit() {
    git ls-remote "$REPO_URL" HEAD | cut -f1
}

# Parse arguments
CHECK_ONLY="false"
for arg in "$@"; do
    case $arg in
        --check-only)
            CHECK_ONLY="true"
            shift
            ;;
    esac
done

# Get the current remote commit hash
REMOTE_COMMIT=$(get_remote_commit 2>/dev/null) || {
    [ "$CHECK_ONLY" = "true" ] && exit 2
    echo -e "${RED}Failed to check for updates. No internet connection?${NC}"
    wait_for_exit 1
}

# Check if we have a stored last commit hash
if [ -f "$LAST_COMMIT_FILE" ]; then
    LAST_COMMIT=$(cat "$LAST_COMMIT_FILE")
    
    if [ "$REMOTE_COMMIT" = "$LAST_COMMIT" ]; then
        [ "$CHECK_ONLY" = "true" ] && exit 1
        echo -e "${RED}No new commits detected. Already up to date!${NC}"
        wait_for_exit 0
    fi
fi

# If only checking, exit now since we found an update
[ "$CHECK_ONLY" = "true" ] && exit 0

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
wait_for_exit 0

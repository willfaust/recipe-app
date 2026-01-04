#!/bin/bash
# Recipe App - SwiftUI macOS application
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/RecipeApp"

# Build with xcodebuild (required for MLX Metal libraries)
echo "Building RecipeApp..."
xcodebuild -scheme RecipeApp -destination "platform=macOS" -configuration Release build 2>&1 | grep -E "(BUILD|error:)" || true

# Find the built app in DerivedData
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "RecipeApp" -path "*/Release/*" -type f -perm +111 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find built RecipeApp"
    exit 1
fi

APP_DIR=$(dirname "$APP_PATH")

# Set project root for data file paths
export RECIPE_PROJECT_ROOT="$SCRIPT_DIR"

# Run from the build directory (required for framework paths)
echo "Launching RecipeApp..."
cd "$APP_DIR"
./RecipeApp &
disown

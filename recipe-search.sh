#!/bin/bash
# Recipe Search - Swift MLX Semantic Search CLI
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/RecipeSearch"

# Build if needed
if [ ! -f ".build/release/RecipeSearch" ] || [ "$1" == "--rebuild" ]; then
    echo "Building RecipeSearch..."
    swift build -c release
fi

# Run with paths relative to project root
./.build/release/RecipeSearch \
  --recipes "$SCRIPT_DIR/allrecipes-archive/allrecipes.com_database_12042020000000.json" \
  --embeddings "$SCRIPT_DIR/recipe_embeddings.bin"

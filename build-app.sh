#!/bin/bash
# Build standalone RecipeApp.app bundle with all resources embedded
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="RecipeApp"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "=== Building RecipeApp Bundle ==="
echo ""

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Step 1: Build the application with xcodebuild
echo "[1/6] Building application..."
cd "$SCRIPT_DIR/RecipeApp"
xcodebuild -scheme RecipeApp \
    -destination "platform=macOS,arch=arm64" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    build 2>&1 | grep -E "(BUILD|error:|warning:.*error)" || true

# Find the built executable
BUILT_EXEC=$(find "$BUILD_DIR/DerivedData" -name "RecipeApp" -type f -perm +111 ! -name "*.dSYM" 2>/dev/null | head -1)
if [ -z "$BUILT_EXEC" ]; then
    echo "Error: Could not find built RecipeApp executable"
    exit 1
fi

echo "  Found executable: $BUILT_EXEC"

# Step 2: Create app bundle structure
echo "[2/6] Creating app bundle structure..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources/Data"
mkdir -p "$APP_BUNDLE/Contents/Resources/Images/250x250"
mkdir -p "$APP_BUNDLE/Contents/Resources/Model"

# Copy executable
cp "$BUILT_EXEC" "$APP_BUNDLE/Contents/MacOS/RecipeApp"

# Copy Info.plist
cp "$SCRIPT_DIR/RecipeApp/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Copy MLX Metal library bundle (required for GPU compute)
MLX_BUNDLE=$(find "$BUILD_DIR/DerivedData" -name "mlx-swift_Cmlx.bundle" -type d 2>/dev/null | head -1)
if [ -n "$MLX_BUNDLE" ]; then
    echo "  - Copying MLX Metal library..."
    cp -R "$MLX_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
else
    echo "  Warning: MLX bundle not found"
fi

# Step 3: Copy data files
echo "[3/6] Copying data files..."
echo "  - Copying recipes JSON (~115MB)..."
cp "$SCRIPT_DIR/allrecipes-archive/allrecipes.com_database_12042020000000.json" \
   "$APP_BUNDLE/Contents/Resources/Data/recipes.json"

echo "  - Copying embeddings binary (~197MB)..."
cp "$SCRIPT_DIR/recipe_embeddings.bin" \
   "$APP_BUNDLE/Contents/Resources/Data/embeddings.bin"

# Step 4: Copy images
echo "[4/6] Copying images (~50k files, this may take a few minutes)..."
cp -R "$SCRIPT_DIR/allrecipes-archive/images/250x250/." \
    "$APP_BUNDLE/Contents/Resources/Images/250x250/"

# Step 5: Copy MLX model files
echo "[5/6] Copying MLX model (~335MB)..."
MODEL_CACHE="$HOME/.cache/huggingface/hub/models--mlx-community--Qwen3-Embedding-0.6B-4bit-DWQ"

if [ ! -d "$MODEL_CACHE" ]; then
    echo "Error: MLX model not found in cache at $MODEL_CACHE"
    echo "Please run the app once to download the model, or run:"
    echo "  python -c \"from huggingface_hub import snapshot_download; snapshot_download('mlx-community/Qwen3-Embedding-0.6B-4bit-DWQ')\""
    exit 1
fi

MODEL_SNAPSHOT=$(find "$MODEL_CACHE/snapshots" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)

if [ -z "$MODEL_SNAPSHOT" ]; then
    echo "Error: Could not find model snapshot in $MODEL_CACHE/snapshots"
    exit 1
fi

echo "  Found model snapshot: $MODEL_SNAPSHOT"

# Copy all model files (following symlinks)
for file in "$MODEL_SNAPSHOT"/*; do
    if [ -f "$file" ] || [ -L "$file" ]; then
        filename=$(basename "$file")
        echo "  - Copying $filename..."
        cp -L "$file" "$APP_BUNDLE/Contents/Resources/Model/"
    fi
done

# Step 6: Code sign (ad-hoc for local use)
echo "[6/6] Code signing..."
codesign --deep --force --sign - "$APP_BUNDLE" 2>/dev/null || echo "  Warning: Code signing failed (app may still work locally)"

# Calculate final size
BUNDLE_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)

echo ""
echo "=== Build Complete ==="
echo "App bundle: $APP_BUNDLE"
echo "Bundle size: $BUNDLE_SIZE"
echo ""
echo "To run:"
echo "  open \"$APP_BUNDLE\""
echo ""
echo "To create a distributable zip:"
echo "  cd \"$BUILD_DIR\" && zip -r RecipeApp.zip RecipeApp.app"

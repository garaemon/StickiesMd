#!/bin/bash
# This script generates the golden image for the Golden Tests.
# It builds the app in Debug configuration (with Sandbox disabled) and runs it
# with the --screenshot argument to render `StickiesMdUITests/ReferenceImages/sample.md`
# to `StickiesMdUITests/ReferenceImages/sample.png`.

set -e

# Ensure we are in the project root
cd "$(dirname "$0")/.."

# Build the app for testing (Debug configuration)
echo "Building StickiesMd..."
xcodebuild build -scheme StickiesMd -configuration Debug -destination 'platform=macOS' > /dev/null

# Get the build settings
BUILD_SETTINGS=$(xcodebuild -showBuildSettings -scheme StickiesMd -configuration Debug)
BUILT_PRODUCTS_DIR=$(echo "$BUILD_SETTINGS" | grep " BUILT_PRODUCTS_DIR =" | cut -d "=" -f 2 | xargs)
FULL_PRODUCT_NAME=$(echo "$BUILD_SETTINGS" | grep " FULL_PRODUCT_NAME =" | cut -d "=" -f 2 | xargs)
APP_PATH="$BUILT_PRODUCTS_DIR/$FULL_PRODUCT_NAME"
BINARY_PATH="$APP_PATH/Contents/MacOS/StickiesMd"

echo "App built at: $APP_PATH"

# Paths
REFERENCE_IMAGES_DIR="$(pwd)/StickiesMdUITests/ReferenceImages"
SAMPLE_MD="$REFERENCE_IMAGES_DIR/sample.md"
OUTPUT_PNG="$REFERENCE_IMAGES_DIR/sample.png"

# Generate Golden Image
echo "Generating Golden Image..."
"$BINARY_PATH" --screenshot \
  --output "$OUTPUT_PNG" \
  --width 800 \
  --height 600 \
  "$SAMPLE_MD"

echo "Golden Image updated at: $OUTPUT_PNG"

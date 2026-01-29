#!/bin/bash
# Verify Open Graph / Link Preview setup
# Run after building Flutter web to ensure OG tags are present

set -e

BUILD_DIR="${1:-app/build/web}"

echo "=== Link Preview Verification ==="
echo "Checking build directory: $BUILD_DIR"
echo ""

# Check if build directory exists
if [ ! -d "$BUILD_DIR" ]; then
    echo "ERROR: Build directory not found: $BUILD_DIR"
    echo "Run 'flutter build web' first."
    exit 1
fi

# Check for og-image.png
if [ -f "$BUILD_DIR/og-image.png" ]; then
    echo "✓ og-image.png exists"
    SIZE=$(stat -f%z "$BUILD_DIR/og-image.png" 2>/dev/null || stat -c%s "$BUILD_DIR/og-image.png" 2>/dev/null || echo "unknown")
    echo "  Size: $SIZE bytes"
else
    echo "✗ og-image.png NOT FOUND"
    exit 1
fi

# Check index.html for OG tags
INDEX="$BUILD_DIR/index.html"
if [ ! -f "$INDEX" ]; then
    echo "✗ index.html not found"
    exit 1
fi

echo ""
echo "Checking Open Graph tags in index.html..."

check_tag() {
    if grep -q "$1" "$INDEX"; then
        echo "✓ Found: $1"
    else
        echo "✗ Missing: $1"
        return 1
    fi
}

ERRORS=0
check_tag 'og:title' || ERRORS=$((ERRORS+1))
check_tag 'og:description' || ERRORS=$((ERRORS+1))
check_tag 'og:image' || ERRORS=$((ERRORS+1))
check_tag 'og:image:width' || ERRORS=$((ERRORS+1))
check_tag 'og:image:height' || ERRORS=$((ERRORS+1))
check_tag 'twitter:card' || ERRORS=$((ERRORS+1))
check_tag 'twitter:image' || ERRORS=$((ERRORS+1))

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "=== All checks passed! ==="
    echo ""
    echo "Test your link previews:"
    echo "  - Facebook: https://developers.facebook.com/tools/debug/"
    echo "  - Twitter:  https://cards-dev.twitter.com/validator"
    echo "  - LinkedIn: https://www.linkedin.com/post-inspector/"
    echo ""
    echo "Note: iMessage caches previews. Add ?v=2 to URL to force refresh."
else
    echo "=== $ERRORS checks failed ==="
    exit 1
fi

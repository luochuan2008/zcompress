#!/bin/bash
# Release script — builds, tags, and publishes zcompress.
# Usage: ./scripts/release.sh 0.1.0

set -e

VERSION="${1:?Usage: $0 <version>}"
echo "🚀 Releasing zcompress v${VERSION}"

# 1. Run tests
echo "📋 Running tests..."
zig build test --summary all

# 2. Build release
echo "🔧 Building ReleaseFast..."
zig build -Doptimize=ReleaseFast

# 3. Copy binary
BIN_DIR="release-binaries"
rm -rf "$BIN_DIR"
mkdir -p "$BIN_DIR"

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
  arm64) ARCH="arm64" ;;
  aarch64) ARCH="arm64" ;;
  x86_64) ARCH="x64" ;;
esac

BIN_NAME="zcompress-${OS}-${ARCH}"
cp zig-out/bin/zcompress "$BIN_DIR/$BIN_NAME"
echo "✅ Binary: $BIN_DIR/$BIN_NAME"

# 4. Commit & tag
git add -A
git commit -m "Release v${VERSION}" || true
git tag -d "v${VERSION}" 2>/dev/null || true
git tag "v${VERSION}"
git push origin main --tags

# 5. Publish to npm
echo "📦 Publishing to npm..."
cd plugins/vite
npm publish --access public || echo "⚠ npm publish skipped (run manually if needed)"
cd ../..

echo ""
echo "✅ v${VERSION} released!"
echo "   npm: https://www.npmjs.com/package/zcompress-vite-plugin"

#!/usr/bin/env bash
# Helper script to build happy-coder package and get correct hashes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_FILE="$SCRIPT_DIR/default.nix"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Happy Coder - Nix Package Build Helper"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if nix is available
if ! command -v nix &> /dev/null; then
    echo "❌ Error: nix command not found"
    exit 1
fi

# Extract current version from default.nix
CURRENT_VERSION=$(grep 'version = ' "$PACKAGE_FILE" | head -1 | sed 's/.*"\(.*\)".*/\1/')
echo "📦 Current version in default.nix: $CURRENT_VERSION"
echo ""

echo "Choose an option:"
echo ""
echo "  1. Get hashes for current version ($CURRENT_VERSION)"
echo "  2. Update to new version and get hashes"
echo "  3. Build package with current hashes (test build)"
echo "  4. Test built package"
echo "  5. Exit"
echo ""
read -p "Enter choice [1-5]: " choice

case $choice in
  1)
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Getting hashes for version $CURRENT_VERSION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    echo "Step 1: Getting source hash..."
    echo ""

    if command -v nix-prefetch-github &> /dev/null; then
      echo "Using nix-prefetch-github..."
      nix-prefetch-github slopus happy-cli --rev "v$CURRENT_VERSION" 2>&1 | tee /tmp/happy-prefetch.json
      SRC_HASH=$(jq -r .hash /tmp/happy-prefetch.json)
      echo ""
      echo "✅ Source hash: $SRC_HASH"
      echo ""
    else
      echo "⚠️  nix-prefetch-github not found, will use build error method"
      echo "   Install with: nix-env -iA nixpkgs.nix-prefetch-github"
      echo ""
    fi

    echo "Step 2: Getting npm dependencies hash..."
    echo "This will attempt to build and capture the expected hash from the error."
    echo ""
    read -p "Continue? [y/N]: " continue

    if [[ ! $continue =~ ^[Yy]$ ]]; then
      echo "Aborted."
      exit 0
    fi

    # Try to build, capture output
    cd "$SCRIPT_DIR/../.."

    echo ""
    echo "Building to get hashes..."
    nix build .#happy-coder 2>&1 | tee /tmp/happy-build.log || true

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Extracting hashes from build output"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Try to extract hashes
    if grep -q "got:" /tmp/happy-build.log; then
      echo "Found hash mismatches. Extracting expected hashes..."
      echo ""

      # Extract all "got:" hashes
      grep "got:" /tmp/happy-build.log | while read line; do
        echo "  $line"
      done

      echo ""
      echo "Copy these hashes to default.nix:"
      echo "  - First hash  → src.hash"
      echo "  - Second hash → npmDepsHash"
    else
      echo "⚠️  Could not extract hashes automatically."
      echo "   Check /tmp/happy-build.log for details."
    fi

    echo ""
    echo "Build log saved to: /tmp/happy-build.log"
    ;;

  2)
    echo ""
    read -p "Enter new version (e.g., 0.14.0): " NEW_VERSION

    if [ -z "$NEW_VERSION" ]; then
      echo "❌ Error: Version cannot be empty"
      exit 1
    fi

    echo ""
    echo "Updating version from $CURRENT_VERSION to $NEW_VERSION"

    # Update version in default.nix
    sed -i "s/version = \"$CURRENT_VERSION\"/version = \"$NEW_VERSION\"/" "$PACKAGE_FILE"

    # Reset hashes to fake values
    sed -i 's/hash = "sha256-[^"]*"/hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="/' "$PACKAGE_FILE"
    sed -i 's/npmDepsHash = "sha256-[^"]*"/npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="/' "$PACKAGE_FILE"

    echo "✅ Updated default.nix"
    echo ""
    echo "Now run option 1 to get the new hashes."
    ;;

  3)
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Building package"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    cd "$SCRIPT_DIR/../.."
    nix build .#happy-coder

    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "Package built to: ./result"
    echo "Test with: ./result/bin/happy --help"
    ;;

  4)
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Testing built package"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    cd "$SCRIPT_DIR/../.."

    if [ ! -L "result" ]; then
      echo "❌ Error: No build found. Run option 3 first."
      exit 1
    fi

    echo "Testing happy binary..."
    echo ""

    ./result/bin/happy --help

    echo ""
    echo "Checking binaries..."
    ls -lh ./result/bin/

    echo ""
    echo "Checking package structure..."
    tree -L 3 ./result/lib/node_modules/ || ls -R ./result/lib/node_modules/ | head -50
    ;;

  5)
    echo "Exiting."
    exit 0
    ;;

  *)
    echo "Invalid choice."
    exit 1
    ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Done!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

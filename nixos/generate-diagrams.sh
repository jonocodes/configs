#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "Building topology diagrams..."
nix build .#topology.x86_64-linux.config.output

mkdir -p diagrams

echo "Copying diagrams..."
cp -f result/*.svg diagrams/

echo "Done. Diagrams saved to diagrams/"
ls -la diagrams/

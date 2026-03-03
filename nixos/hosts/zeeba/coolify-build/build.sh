#!/usr/bin/env bash

# Build Coolify from source (jonocodes/coolify-nix fork)
#
# This clones the repo and builds using its own Dockerfile.

set -euo pipefail

REPO_URL="https://github.com/jonocodes/coolify.git"
BRANCH="jono/nix-with-compose"
# COMMIT="b29cf0cc6647ee126f2a186328a6263f3c5b9ffe"
COMMIT="41150cbc8727c4469988c21e4b3e074eb527fc0c"
BUILD_DIR="/tmp/coolify-build"
IMAGE_NAME="coolify-nixos:jono"

echo "==> Cleaning up previous build directory..."
rm -rf "$BUILD_DIR"

echo "==> Cloning $REPO_URL (branch: $BRANCH)..."
# git clone --depth 1 -b "$BRANCH" "$REPO_URL" "$BUILD_DIR"
git clone --no-checkout --depth 1 "$REPO_URL" "$BUILD_DIR"

echo "==> Building Docker image: $IMAGE_NAME..."
cd "$BUILD_DIR"

echo "==> Fetching specific commit $COMMIT..."
git fetch --depth 1 origin "$COMMIT"

echo "==> Checking out commit..."
git checkout "$COMMIT"

# Build using the production Dockerfile
# Note: On NixOS, `docker build` may fail due to a plugin invocation bug.
# We find and call the buildx binary directly as a workaround.
BUILDX_BIN=$(docker info --format '{{range .ClientInfo.Plugins}}{{if eq .Name "buildx"}}{{.Path}}{{end}}{{end}}' 2>/dev/null || true)

# Override POSTGRES_VERSION since Alpine 3.23 dropped PostgreSQL 15
BUILD_ARGS="--build-arg POSTGRES_VERSION=16"

if [[ -n "$BUILDX_BIN" && -x "$BUILDX_BIN" ]]; then
    echo "    Using buildx at: $BUILDX_BIN"
    "$BUILDX_BIN" build -t "$IMAGE_NAME" -f docker/production/Dockerfile $BUILD_ARGS --load .
else
    echo "    Using docker build"
    docker build -t "$IMAGE_NAME" -f docker/production/Dockerfile $BUILD_ARGS .
fi

echo "==> Done! Image built: $IMAGE_NAME"
echo ""
echo "To start Coolify:"
echo "  cd /data/coolify/source"
echo "  docker compose --env-file .env \\"
echo "    -f docker-compose.yml \\"
echo "    -f docker-compose.prod.yml \\"
echo "    -f docker-compose.override.yml \\"
echo "    up -d --remove-orphans --force-recreate"
echo " or "
echo "   docker-compose --env-file .env -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.override.yml up -d --remove-orphans --force-recreate"

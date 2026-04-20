#!/usr/bin/env bash
# Display last update dates for Nix flakes by host

cd "$(dirname "$0")/.." || exit 1

echo "NixOS Flakes:"
echo "============="
for lock in nixos/flake.lock nixos/hosts/*/flake.lock; do
    if [ -f "$lock" ]; then
        dir=$(dirname "$lock")
        host="${dir#nixos/hosts/}"
        [ "$host" = "nixos" ] && host="root"
        date=$(stat -c '%y' "$lock" | cut -d' ' -f1)
        echo "  $host: $date"
    fi
done

echo ""
echo "Home Manager Flakes:"
echo "===================="
for lock in home-manager/flake.lock home-manager/hosts/*/flake.lock; do
    if [ -f "$lock" ]; then
        dir=$(dirname "$lock")
        host="${dir#home-manager/hosts/}"
        [ "$host" = "home-manager" ] && host="root"
        date=$(stat -c '%y' "$lock" | cut -d' ' -f1)
        echo "  $host: $date"
    fi
done

echo ""
echo "Standalone Flakes:"
echo "=================="
for lock in flakes/*/flake.lock; do
    if [ -f "$lock" ]; then
        host=$(basename "$(dirname "$lock")")
        date=$(stat -c '%y' "$lock" | cut -d' ' -f1)
        echo "  $host: $date"
    fi
done

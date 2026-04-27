#!/usr/bin/env bash
# Remove Flutter build outputs (build/, .dart_tool build caches, etc.).
# Run from anywhere; paths are resolved from this script’s location.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
echo "==> flutter clean ($ROOT)"
flutter clean

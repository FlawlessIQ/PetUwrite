#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Runs Flutter web using the HTML renderer (no CanvasKit CDN fetches).
# Best option for offline development.
flutter run -d chrome --web-renderer html

#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Runs Flutter web without fetching CanvasKit/fonts from Google CDN.
# Useful on corporate networks, offline dev, or DNS-restricted environments.
flutter run -d chrome --no-web-resources-cdn

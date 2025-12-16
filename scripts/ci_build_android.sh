#!/usr/bin/env bash
set -euo pipefail

# Script to ensure Android platform files and build APK (for CI or local use)
# Usage: ./scripts/ci_build_android.sh

echo "Ensuring Android platform files..."
flutter create --platforms=android .

echo "Getting dependencies..."
flutter pub get

echo "Attempting to accept licenses (if sdkmanager available)..."
if command -v sdkmanager >/dev/null 2>&1; then
  yes | sdkmanager --licenses || true
fi

echo "Building release APK..."
flutter build apk --release --no-shrink

echo "APK build complete. Output: build/app/outputs/flutter-apk/"
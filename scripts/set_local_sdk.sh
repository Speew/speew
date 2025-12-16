#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/set_local_sdk.sh /path/to/Android/Sdk
# Or set ANDROID_SDK_ROOT and run: ./scripts/set_local_sdk.sh

SDK_PATH=${1:-${ANDROID_SDK_ROOT:-}}
if [[ -z "$SDK_PATH" ]]; then
  echo "ERROR: Provide SDK path as arg or set ANDROID_SDK_ROOT"
  exit 1
fi

LOCAL_PROPS_FILE="android/local.properties"
if [[ ! -f "$LOCAL_PROPS_FILE" ]]; then
  echo "flutter.sdk=$(pwd)/flutter" > "$LOCAL_PROPS_FILE"
fi

# Normalize path for local.properties (Windows uses backslashes but this is for linux/mac)
echo "sdk.dir=$SDK_PATH" >> "$LOCAL_PROPS_FILE"
echo "Wrote sdk.dir=$SDK_PATH to $LOCAL_PROPS_FILE"

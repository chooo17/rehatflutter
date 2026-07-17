#!/usr/bin/env bash
# Build APK PELANGGAN (ramping, tanpa izin Bluetooth, tanpa UI admin).
# APK per-ABI (split) → tiap file ~1/3 ukuran universal.
# Output: build/app/outputs/flutter-apk/app-customer-<abi>-release.apk
set -euo pipefail

FLUTTER="${FLUTTER_BIN:-C:/Users/thezu/flutter/bin/flutter.bat}"
API_BASE_URL="https://rehat-backend-production.up.railway.app/v1"

"$FLUTTER" build apk --release \
  --flavor customer \
  --split-per-abi \
  --dart-define=ADMIN_BUILD=false \
  --dart-define=API_BASE_URL="$API_BASE_URL"

echo "✅ APK pelanggan → build/app/outputs/flutter-apk/app-customer-*-release.apk"

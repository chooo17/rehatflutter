#!/usr/bin/env bash
# Build APK ADMIN/KASIR (dengan printer thermal Bluetooth + UI admin).
# APK per-ABI (split). Output: app-admin-<abi>-release.apk
set -euo pipefail

FLUTTER="${FLUTTER_BIN:-C:/Users/thezu/flutter/bin/flutter.bat}"
API_BASE_URL="https://rehat-backend-production.up.railway.app/v1"

"$FLUTTER" build apk --release \
  --flavor admin \
  --split-per-abi \
  --dart-define=ADMIN_BUILD=true \
  --dart-define=API_BASE_URL="$API_BASE_URL"

echo "✅ APK admin → build/app/outputs/flutter-apk/app-admin-*-release.apk"

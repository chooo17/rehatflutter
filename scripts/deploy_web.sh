#!/usr/bin/env bash
# Deploy Flutter web ke Vercel dengan andal (mengatasi bug manifest aset yang
# kadang hilang). Jalankan dari root project:  bash scripts/deploy_web.sh
set -euo pipefail

FLUTTER="${FLUTTER_BIN:-C:/Users/thezu/flutter/bin/flutter.bat}"
API_BASE_URL="https://rehat-backend-production.up.railway.app/v1"
VERCEL_PROJECT='{"projectId":"prj_3bWLBPG6MaSX1EYA2IrxGkKldpCf","orgId":"team_XihjgOUyxny5SGvvVYp7diI4","projectName":"rehatflutter"}'

build() {
  "$FLUTTER" build web --release --pwa-strategy=none \
    --dart-define=API_BASE_URL="$API_BASE_URL"
}

echo "▶ flutter clean"
"$FLUTTER" clean >/dev/null

echo "▶ build web (percobaan 1)"
build

# Bug tooling: kadang manifest aset tak tergenerate → clean + rebuild sekali lagi.
if [ ! -f build/web/assets/AssetManifest.bin.json ]; then
  echo "⚠ manifest hilang → clean + rebuild (percobaan 2)"
  "$FLUTTER" clean >/dev/null
  build
fi

if [ ! -f build/web/assets/AssetManifest.bin.json ]; then
  echo "❌ manifest tetap hilang setelah 2x. Batal deploy."
  exit 1
fi
echo "✅ build lengkap ($(wc -c < build/web/assets/AssetManifest.bin.json) B)"

# SPA rewrite + link project Vercel.
cp web/vercel.json build/web/vercel.json
mkdir -p build/web/.vercel
printf '%s' "$VERCEL_PROJECT" > build/web/.vercel/project.json

echo "▶ deploy ke Vercel (production)"
( cd build/web && npx vercel --prod --yes )

echo "▶ verifikasi aset terserve sebagai JSON"
curl -sS -m 15 -o /dev/null -w "AssetManifest → %{content_type}\n" \
  https://rehatflutter.vercel.app/assets/AssetManifest.bin.json
echo "🎉 selesai → https://rehatflutter.vercel.app"

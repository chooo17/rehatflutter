# Deploy & CI/CD — Rehat App

## Ringkas
| Target | Otomatis (CI) | Manual (lokal) |
|---|---|---|
| **Web** (Vercel) | push ke `main` → `.github/workflows/deploy-web.yml` | `bash scripts/deploy_web.sh` |
| **APK** | tag `v*` atau "Run workflow" → `build-apk.yml` (artifact) | `flutter build apk --release --dart-define=API_BASE_URL=…` |
| **Backend** (Railway) | belum (repo backend tak punya remote GitHub) | `railway up --service rehat-backend` dari `D:\REHAT\rehat-backend\rehat-backend` |

## Setup CI (sekali)
GitHub → repo `chooo17/rehatflutter` → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Nilai |
|---|---|
| `VERCEL_TOKEN` | buat di https://vercel.com/account/tokens |
| `VERCEL_ORG_ID` | `team_XihjgOUyxny5SGvvVYp7diI4` |
| `VERCEL_PROJECT_ID` | `prj_3bWLBPG6MaSX1EYA2IrxGkKldpCf` |

Setelah itu, setiap push ke `main` yang menyentuh `lib/`, `web/`, atau `pubspec.yaml` akan otomatis build + deploy web ke production.

## Bug build web (manifest aset hilang)
`flutter build web` kadang menghasilkan `build/web` tanpa `assets/AssetManifest.bin.json` (cache build inkremental rusak) → di produksi aset diserve sebagai `index.html` → app **stuck di loading**. 

**Solusi (sudah diterapkan):** selalu `flutter clean` sebelum build web. CI dan `scripts/deploy_web.sh` melakukan ini + verifikasi manifest ada sebelum deploy (script mengulang sekali bila perlu, lalu gagal jelas bila tetap kosong).

**Jangan** build web & APK bersamaan — keduanya memakai folder `build/` dan saling menimpa.

## Catatan APK
APK saat ini **debug-signed** (belum untuk Play Store). Untuk rilis resmi: buat keystore + `android/key.properties`, ubah `signingConfig` ke release, lalu build **AAB** (`flutter build appbundle`).

# Deploy Web — Rehat (embed di rehat-coffeehouse.my.id)

App Flutter ini di-host sebagai web statis di subdomain, lalu di-embed lewat
`<iframe>` pada halaman `/preorder` situs Next.js (var `NEXT_PUBLIC_ORDER_APP_URL`).

## 1. Build

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://rehat-backend-production.up.railway.app/v1
```

- Hasil: folder `build/web` (statis, siap upload).
- API URL dibaku saat build. Jika URL backend berbeda → build ulang dengan
  nilai `API_BASE_URL` yang benar.
- Subdomain (base-href `/`) → tidak perlu flag tambahan. Jika di **subpath**
  (mis. `.../pesan/`), tambahkan `--base-href /pesan/`.
- Routing berbasis hash (`/#/...`) → aman di iframe & subpath, tanpa rewrite
  server. `web/_redirects` disertakan sebagai fallback SPA (Netlify/Cloudflare).

## 2. Host `build/web` (pilih salah satu)

**Cloudflare Pages** (CLI)
```bash
npx wrangler pages deploy build/web --project-name rehat-order
```

**Netlify** (CLI) — honor `_redirects`
```bash
npx netlify deploy --prod --dir=build/web
```

**Vercel** (CLI) — deploy folder statis
```bash
npx vercel deploy build/web --prod
```

Arahkan domain kustom **`order.rehat-coffeehouse.my.id`** ke deployment tsb.

## 3. Sambungkan ke situs

Di project `D:\rehat-coffeehouse`, set env lalu deploy ulang situs:

```
NEXT_PUBLIC_ORDER_APP_URL=https://order.rehat-coffeehouse.my.id
```

Halaman `/preorder` akan menampilkan app pemesanan (lihat
`app/(site)/preorder/page.tsx`).

## Prasyarat
- Backend Node harus online di `API_BASE_URL` (lihat titik A rencana deploy).
- CORS backend: `FRONTEND_URL=https://rehat-coffeehouse.my.id` (atau `*`).

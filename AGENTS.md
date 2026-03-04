# AGENTS.md — PVC (Proxy VPN Cloud)

## Project Identity
- **App name:** PVC (Proxy VPN Cloud) | **Package:** `id.web.idm.pvc` | **Version:** 3.9.0+55
- **Repo:** https://github.com/aiksatria/pvc | **Stack:** Flutter/Dart + Android Kotlin + V2Ray core

## Essential Commands
```bash
flutter pub get          # wajib setelah clone / ubah pubspec.yaml
flutter analyze          # harus "No issues found!" sebelum commit
flutter build apk --release                  # universal APK (build manual, bukan CI)
flutter build apk --split-per-abi --release  # split per arsitektur
```
> **Keystore tidak disimpan di repo.** Build release dilakukan lokal saja. File `android/app/keystore.jks` dan `android/key.properties` sudah di-`.gitignore`.

## Architecture
```
lib/providers/   → ChangeNotifier state (V2RayProvider, LanguageProvider)
lib/services/    → Business logic (ServerService, V2RayService, PingService)
lib/screens/     → UI screens
lib/widgets/     → Reusable widgets
assets/config_vpn/ → VPN config files + Python scraper
local_packages/flutter_v2ray_client/ → Local V2Ray plugin — JANGAN dimodifikasi
```

## Config Loading — Hybrid Strategy
File **`lib/services/server_service.dart`** mengelola dua sumber:

| Prioritas | Sumber | Kondisi |
|-----------|--------|---------|
| 1 | GitHub raw URL (`_kRawBase`) | Online — fetch 4 file sekaligus, deduplicate |
| 2 | Bundled asset (`assets/config_vpn/`) | Offline / network gagal |

Urutan file (paling fresh dulu): `configs4.txt` → `configs.txt` → `configs2.txt` → `configs3.txt`

`V2RayProvider._initialize()` → jika storage kosong: load bundled dulu, lalu `_refreshDefaultServersInBackground()`.

## Config Auto-Update (GitHub Actions)
`assets/config_vpn/main.py` scrape Telegram publik → output 4 file config.
`.github/workflows/update_configs.yml` jalankan ini **setiap jam**, auto-commit:
- `configs.txt`, `configs2.txt`, `configs3.txt`, `configs4.txt`
- `data.temp` (database config), `pointer.txt` (posisi rotasi) — **harus ikut di-commit**

## MethodChannel — Dart ↔ Kotlin (nama harus identik)
| Channel | Kotlin File |
|---------|-------------|
| `id.web.idm.pvc/vpn_control` | `MainActivity.kt` |
| `id.web.idm.pvc/app_list` | `AppListMethodChannel.kt` |
| `id.web.idm.pvc/ping` | `PingMethodChannel.kt` |
| `id.web.idm.pvc/settings` | `SettingsMethodChannel.kt` |
| `id.web.idm.pvc/download` | `DownloadMethodChannel.kt` |

## Konvensi Wajib
```dart
// 1. Async context safety — selalu setelah setiap await sebelum pakai context
await someAsyncCall();
if (!mounted) return;
ScaffoldMessenger.of(context)...

// 2. Warna dengan opacity
color.withValues(alpha: 0.5)   // ✅ bukan .withOpacity()

// 3. Switch vs Checkbox
Switch(activeThumbColor: ...)   // ✅ Switch pakai activeThumbColor
Checkbox(activeColor: ...)      // ✅ Checkbox tetap pakai activeColor

// 4. Logging
debugPrint('msg');  // ✅  —  bukan print()

// 5. Widget constructor
const MyWidget({super.key});    // ✅ Dart 3.x — bukan Key? key / super(key: key)
```

## Lokalisasi
Tambah key baru di **semua 8 file**: `assets/languages/{ar,en,es,fa,fr,ru,tr,zh}.json`
Daftarkan konstanta di `lib/utils/app_localizations.dart`, akses via `context.tr('key')`.


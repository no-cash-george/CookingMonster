# Cooking Monster

An offline-first, zero-telemetry recipe manager and peer-to-peer sharing utility built with Flutter and Dart. Cooking Monster stores your recipes, cook counts, and live kitchen progress locally—with adaptive native interfaces for Apple and Android platforms.

---

## Key Features

- **Local-First Architecture:** Powered by an embedded Sembast database and `SharedPreferences`. No cloud accounts, servers, or network connection required.
- **Dual Native Adaptive UI:**
  - **iOS & macOS:** Translucent Liquid Glass surfaces, Cupertino navigation, and native system styling.
  - **Android:** Material You (Material 3) dynamic surfaces and components.
  - **Appearance Customization:** System, Light, and Dark modes paired with an 8-swatch macOS-inspired accent color picker (Blue, Purple, Pink, Red, Orange, Yellow, Green, and Graphite).
- **Interactive Kitchen Mode:**
  - Live checkboxes for ingredients and execution steps that automatically persist across app restarts.
  - Automatic cook counter (`timesMade`) that increments upon recipe completion, alongside manual `-`/`+` adjustments.
- **Metric-Enforced Recipe Editor:** Two-step creation and editing workflow enforcing strict metric weights (`g`) or item counts (`pc`/`pcs`), portion yields, and preparation notes.
- **Import from AI:** Generates a schema-enforced prompt for any external LLM and validates/sanitizes pasted JSON responses directly into your local recipe library.
- **Serverless QR & Payload Sharing (`cm1:`):** Compresses recipes using ZLib + Base64URL into compact `cm1:` payloads for offline QR code generation and camera scanning—automatically stripping personal cook counts and active checklist progress prior to sharing.
- **Full Backup & Restore:** Exports and imports complete JSON backups (chef profile, theme/accent preferences, recipes, cook counts, and checklist states) from either the initial startup screen or **Settings → Data & Backup** (supporting both **Merge** and **Replace** restore modes).

---

## Tech Stack

| Layer | Technology |
| :--- | :--- |
| **Framework & Language** | Flutter (Dart SDK `^3.14.0`) |
| **Local Persistence** | `sembast`, `sembast_web`, `shared_preferences` |
| **QR & Compression** | `archive` (ZLib), `qr_flutter`, `mobile_scanner` |
| **File I/O & Assets** | `file_picker`, `path_provider`, `flutter_launcher_icons` |

---

## Project Structure

```text
lib/
├── main.dart                          # App entry point & adaptive ThemeData builder
├── models/
│   └── recipe.dart                    # Recipe & Ingredient models + cm1: serialization
├── services/
│   ├── ai_recipe_service.dart         # LLM prompt generator & strict JSON sanitizer
│   ├── backup_export_io.dart          # Native mobile/desktop backup writer
│   ├── backup_export_service.dart     # Full-app JSON backup serializer
│   ├── backup_export_stub.dart        # Conditional import fallback
│   ├── backup_export_web.dart         # Browser download backup exporter
│   ├── backup_import_service.dart     # Backup parser & validation engine
│   ├── database_service.dart          # Sembast database initialization & CRUD
│   └── share_codec.dart               # ZLib + Base64URL cm1: encoder/decoder
├── state/
│   └── app_state.dart                 # Reactive state management & persistence layer
└── ui/
    ├── screens/
    │   ├── ai_import_screen.dart      # Two-step AI prompt & JSON import flow
    │   ├── main_shell.dart            # Adaptive bottom navigation & floating actions
    │   ├── onboarding_screen.dart     # First-run profile setup & backup restore
    │   ├── receive_screen.dart        # QR camera scanner & cm1: payload importer
    │   ├── recipe_complete_screen.dart# Completion celebration & cook counter summary
    │   ├── recipe_detail_screen.dart  # Persistent ingredient/step checklist view
    │   ├── recipe_editor_screen.dart  # Two-step metric recipe creator/editor
    │   ├── recipes_screen.dart        # Pinned header & recipe collection list
    │   └── settings_screen.dart       # Profile, theme/accent picker & backup tools
    └── widgets/
        ├── import_backup_sheet.dart   # File picker & JSON paste restore modal
        ├── platform_primitives.dart   # Liquid Glass container & avatar primitives
        └── share_recipe_sheet.dart    # QR code & clipboard payload share modal
```

---

## Getting Started

### Prerequisites

- **Flutter SDK** (`3.50+` / Dart `^3.14.0`)
- **For Android:** JDK 21 and Android SDK (Command-line Tools / Android Studio)
- **For iOS:** macOS with Xcode, Xcode Command Line Tools, and CocoaPods (`brew install cocoapods`)

### Installation & Asset Setup

1. Clone the repository and fetch Dart packages:
   ```bash
   git clone [https://github.com/no-cash-george/cooking_monster.git](https://github.com/no-cash-george/cooking_monster.git)
   cd cooking_monster
   flutter pub get
   ```

2. *(Optional)* Regenerate native iOS and Android launcher icons from `assets/app_icon/icon.png`:
   ```bash
   dart run flutter_launcher_icons
   ```

---

## Building for Android

### Release APK (Direct Sideloading)

```bash
flutter build apk --release
```
The compiled binary is written to:
```text
build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (Google Play)

```bash
flutter build appbundle --release
```
The bundle is written to:
```text
build/app/outputs/bundle/release/app-release.aab
```

---

## Building for iOS

### Option A: Direct Device Install via Xcode / CLI (Signed)

1. Open the CocoaPods workspace in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. Select the **Runner** project → **Runner** target → **Signing & Capabilities**.
3. Enable **Automatically manage signing**, select your **Team** (Apple ID), and set a unique **Bundle Identifier** if prompted.
4. Connect your iPhone (with **Developer Mode** enabled under **Settings → Privacy & Security**) and deploy in release mode:
   ```bash
   flutter devices
   flutter run --release -d <your-iphone-device-id>
   ```
5. On first launch with a free Personal Team certificate, trust your developer profile on the iPhone via **Settings → General → VPN & Device Management**.

### Option B: Unsigned `.ipa` Package (AltStore / SideStore / Sideloadly)

To produce a standalone `.ipa` without an Apple Developer Program distribution certificate:

```bash
flutter build ios --release --no-codesign
mkdir -p build/ios/ipa/Payload
cp -r build/ios/iphoneos/Runner.app build/ios/ipa/Payload/
cd build/ios/ipa && zip -qry CookingMonster.ipa Payload
```

Install `build/ios/ipa/CookingMonster.ipa` onto your iOS device using **AltStore**, **SideStore**, or **Sideloadly**, which will handle provisioning and signing during installation.

---

## Automated Builds (GitHub Actions)

Every push or pull request to `main` (as well as manual triggers via **Actions → Run workflow**) runs `.github/workflows/build.yml` to produce downloadable release artifacts:

- **`CookingMonster.apk`:** Built on `ubuntu-latest` with JDK 21 and Flutter stable.
- **`CookingMonster.ipa`:** Built on `macos-latest` (`--no-codesign`) and packaged into a sideload-ready IPA archive.

*(Note: Production release builds compiled with `--release` automatically disable and hide the Settings UI-engine developer switcher via `kReleaseMode`.)*

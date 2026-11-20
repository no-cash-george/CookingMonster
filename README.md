# Cooking Monster

An offline-first, zero-backend personal recipe database and peer-to-peer recipe sharing application built with Flutter.

Designed around kitchen practicality and zero cloud dependencies, **Cooking Monster** stores every recipe locally on your device and transfers dishes directly between phones using compressed, self-contained QR codes and clipboard payloads—no accounts, servers, or internet connection required.

---

## Core Features

### Dual Platform-Native UI Engines
Powered directly by Flutter's **Impeller** rendering engine, the interface adapts to the host operating system's native visual language:
* **iOS & macOS — Apple Liquid Glass:** Real-time Gaussian `BackdropFilter` blurs, translucent luminance gradients, `1px` specular rim borders, Cupertino controls, and a floating capsule navigation bar.
* **Android — Material You (Material 3):** Dynamic tonal `ColorScheme` palettes, pill-indicator `NavigationBar`, filled cards, and an extended Material 3 `FloatingActionButton`.
* **Runtime Engine & Theme Controls:** Switch between **Auto**, **iOS Glass**, and **Material You** live inside **Settings** (ideal for cross-platform UI testing in Chrome), alongside a 3-way Dark Mode toggle (**System**, **Always Off**, **Always On**).

### Kitchen-First Recipe Management
* **Personalized Onboarding:** First-launch setup collects your name, validated `@username` (`1–64` characters: letters, numbers, `_`, and `-`), and avatar selection (`Male`, `Female`, `Other`) mapped to custom home screen icons.
* **Two-Step Recipe Wizard:**
  1. **Step 1 — Metadata & Ingredients:** Set the recipe title, portion yield counter, and dynamic ingredient rows supporting both **grams (`g`)** and **piece counts (`pc` / `pcs`)** with optional preparation notes.
  2. **Step 2 — Execution Steps:** Ordered, step-by-step cooking instructions.
* **Interactive Cooking Checklist:** Open any recipe to check off *mise en place* ingredients while weighing and tap execution steps as you cook. Completing 100% of ingredients and steps triggers an animated **Congratulations** screen.
* **Author Attribution:** Automatically stamps `created by @username` onto newly created recipes and preserves original attribution across shares and imports.

### Serverless Peer-to-Peer Sharing (`cm1:` Codec)
* **Share via QR or Clipboard:** Compresses recipes into a compact binary-backed payload (`cm1:<base64url(zlib(json))>`) and renders a high-contrast QR code alongside a one-tap **Copy Recipe Code** action.
* **Receive via Camera or Paste:** Scan another device's QR code using the live camera viewfinder or paste a shared `cm1:` string from your clipboard, preview the dish summary, and save it straight to your local database.

---

## Wire Format & Compression

To keep QR codes low-density and fast for mobile cameras to focus on, recipes are serialized with single-character JSON keys, compressed with Zlib via the pure-Dart `archive` package (ensuring identical behavior across iOS, Android, and Web), and Base64URL-encoded:

```text
cm1:<Base64URL(Zlib(UTF-8 Compact JSON))>
```

| JSON Key | Field | Notes |
| :--- | :--- | :--- |
| `t` | Title | Recipe name (`String`) |
| `c` | Created By | Sanitized `@username`, omitted if empty (`String`) |
| `p` | Portions | Yield count, defaults to `1` (`int`) |
| `i` | Ingredients | Array of compact ingredient objects |
| `s` | Steps | Ordered array of instruction strings |
| `i[].n` | Ingredient Name | `String` |
| `i[].g` | Amount | Numeric quantity (`int` when whole, `double` otherwise) |
| `i[].u` | Unit | `'c'` for piece count; omitted when stored in grams (`'g'`) |
| `i[].m` | Note | Optional prep note (e.g., `"browned"`, `"diced"`), omitted if empty |

---

## Project Structure

```text
cooking_monster/
├── assets/
│   └── icons/
│       ├── male.png              # Custom home avatar (Male)
│       ├── female.png            # Custom home avatar (Female)
│       └── other.png             # Custom home avatar (Other)
└── lib/
    ├── main.dart                 # App entrypoint, theme configuration & routing
    ├── models/
    │   └── recipe.dart           # Recipe & Ingredient entities + compact JSON codec
    ├── services/
    │   ├── database_service.dart # Transactional Sembast CRUD layer
    │   ├── db_factory_io.dart    # Native file-backed Sembast factory (iOS/Android)
    │   ├── db_factory_web.dart   # IndexedDB-backed Sembast factory (Web testing)
    │   ├── db_factory_stub.dart  # Conditional import stub
    │   └── share_codec.dart      # Zlib + Base64URL encoder/decoder (cm1: protocol)
    ├── state/
    │   └── app_state.dart        # ChangeNotifier state, profile validation & persistence
    └── ui/
        ├── screens/
        │   ├── main_shell.dart             # Platform navigation bar & floating Add button
        │   ├── onboarding_screen.dart      # First-run profile setup
        │   ├── recipes_screen.dart         # Home recipe list & personalized empty state
        │   ├── recipe_detail_screen.dart   # Interactive cooking checklist view
        │   ├── recipe_editor_screen.dart   # 2-step recipe creation & editing wizard
        │   ├── recipe_complete_screen.dart # Completion celebration screen
        │   ├── receive_screen.dart         # Live QR scanner & clipboard importer
        │   └── settings_screen.dart        # Profile editor, Dark Mode & UI engine toggle
        └── widgets/
            ├── platform_primitives.dart    # LiquidGlassContainer & UserGenderAvatar
            └── share_recipe_sheet.dart     # Modal QR generator & clipboard share sheet
```

---

## Getting Started

### Prerequisites
* **Flutter SDK** (`>= 3.24` / Dart `>= 3.5` recommended)
* **Chrome** (for rapid UI and logic testing) or **Xcode / Android Studio** toolchains for native mobile builds

### Installation

1. **Clone the repository and install dependencies:**
   ```bash
   git clone [https://github.com/no-cash-george/cooking_monster.git](https://github.com/no-cash-george/cooking_monster.git)
   cd cooking_monster
   flutter pub get
   ```

2. **Add custom profile icons (optional):**
   Place your PNG icons at:
   * `assets/icons/male.png`
   * `assets/icons/female.png`
   * `assets/icons/other.png`
   *(If omitted, the avatar widget gracefully falls back to platform-native person icons.)*

3. **Run the application:**
   * **Quick UI & workflow testing in Chrome:**
     ```bash
     flutter run -d chrome
     ```
   * **iOS or Android device / simulator:**
     ```bash
     flutter run
     ```

---

## Dependencies

| Package | Purpose |
| :--- | :--- |
| `sembast` & `sembast_web` | Cross-platform local NoSQL database (file-backed on mobile, IndexedDB on Web) |
| `path_provider` & `path` | Resolving native application documents directories for local database storage |
| `shared_preferences` | Persisting onboarding state, user profile, and theme preferences |
| `archive` | Pure-Dart Zlib compression/decompression across mobile and Web |
| `qr_flutter` | Generating crisp QR codes for offline recipe sharing |
| `mobile_scanner` | Hardware-accelerated camera QR code scanning |
| `cupertino_icons` | Native iOS iconography |

---

## License

This project is open-source and available under the [MIT License](LICENSE).

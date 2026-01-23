# Development Setup — The Skinning Shed

## Prerequisites

- **Flutter SDK**: 3.38.x or later (stable channel)
- **Dart SDK**: 3.10.x or later (bundled with Flutter)
- **Git**: For version control
- **Android Studio** or **VS Code** with Flutter extensions (recommended)

### Platform-Specific

- **Web**: Chrome browser
- **Android**: Android Studio with Android SDK, Emulator or physical device
- **iOS**: macOS with Xcode (iOS development requires a Mac)

## Initial Setup

### 1. Clone the Repository

```bash
git clone https://github.com/adammcguffee/the-skinning-shed.git
cd the-skinning-shed
```

### 2. Install Flutter Dependencies

```bash
cd app
flutter pub get
```

### 3. Environment Variables

The app requires Supabase credentials. **Never commit these to git.**

Create environment variables or use `--dart-define`:

| Variable | Description |
|----------|-------------|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_ANON_KEY` | Public/anonymous API key |

**IMPORTANT:** Never use `SERVICE_ROLE` key in client code. It's for server-side only.

---

## Running the App

### Web (Development)

```bash
cd app
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Or for quick testing without Supabase:

```bash
flutter run -d chrome
```

### Android Emulator

1. Start an Android emulator from Android Studio
2. Run:

```bash
cd app
flutter run -d emulator-5554 \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Or list available devices:

```bash
flutter devices
```

### iOS (Requires Mac)

1. Open iOS Simulator or connect a physical device
2. Run:

```bash
cd app
flutter run -d iphone \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Note: First build on iOS will take longer as CocoaPods installs.

---

## Build Commands

### Web Build (Production)

```bash
cd app
flutter build web \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Output: `app/build/web/`

### Android APK

```bash
cd app
flutter build apk \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Output: `app/build/app/outputs/flutter-apk/app-release.apk`

### iOS (Requires Mac)

```bash
cd app
flutter build ios \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

---

## Code Generation

The project uses `freezed` and `json_serializable` for model generation.

After modifying model classes:

```bash
cd app
flutter pub run build_runner build --delete-conflicting-outputs
```

Or watch mode for development:

```bash
flutter pub run build_runner watch --delete-conflicting-outputs
```

---

## Project Structure

```
the_skinning_shed/
├── app/                      # Flutter application
│   ├── lib/
│   │   ├── main.dart        # Entry point
│   │   ├── app/             # App-level config
│   │   │   ├── app.dart     # Root widget
│   │   │   ├── router.dart  # Navigation
│   │   │   └── theme/       # Design system
│   │   ├── features/        # Feature modules
│   │   ├── shared/          # Shared widgets & utils
│   │   ├── services/        # API clients
│   │   └── models/          # Data models
│   ├── assets/              # Images, fonts
│   └── pubspec.yaml         # Dependencies
├── docs/                    # Documentation
├── supabase/                # Backend
│   ├── sql/                 # Migrations
│   ├── functions/           # Edge functions
│   └── storage_policies/    # Storage config
└── tools/                   # Dev scripts
```

---

## Troubleshooting

### Flutter Doctor

Run to diagnose issues:

```bash
flutter doctor -v
```

### Clean Build

If you encounter build issues:

```bash
cd app
flutter clean
flutter pub get
```

### Android Build Issues

If Gradle fails:

```bash
cd app/android
./gradlew clean
```

### iOS Build Issues

If CocoaPods fails:

```bash
cd app/ios
pod deintegrate
pod install
```

---

## IDE Setup

### VS Code

Recommended extensions:
- Flutter
- Dart
- Error Lens
- GitLens

### Android Studio

Install Flutter and Dart plugins via Preferences > Plugins.

---

## Security Reminders

1. ✅ Use `SUPABASE_ANON_KEY` in client
2. ❌ Never use `SERVICE_ROLE` key in client
3. ✅ Pass keys via `--dart-define` (not hardcoded)
4. ❌ Never commit `.env` files
5. ✅ Always check `.gitignore` is working

---

*Last updated: 2026-01-22*

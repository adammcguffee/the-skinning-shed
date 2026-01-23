# The Skinning Shed - Project State

> Last updated: January 23, 2026

## Overview

Premium hunting & fishing community app built with Flutter. Dark, cinematic forest-green theme matching the reference design.

---

## Tech Stack

- **Framework**: Flutter/Dart (SDK ^3.10.7)
- **State Management**: Riverpod
- **Routing**: GoRouter
- **Backend**: Supabase (Auth, Database, Storage)
- **Typography**: Google Fonts (Inter)

---

## Branding Assets

### Location
All finalized brand assets are in:
```
app/assets/branding/banner_v2/
├── hero_banner.png   # Auth screen hero (wide, transparent)
├── wordmark.png      # Text-only logo
└── crest.png         # Icon mark for nav rail (48px)
```

### Single Source of Truth
```dart
// app/lib/shared/branding/brand_assets.dart
abstract final class BrandAssets {
  static const String heroBanner = 'assets/branding/banner_v2/hero_banner.png';
  static const String wordmark = 'assets/branding/banner_v2/wordmark.png';
  static const String crest = 'assets/branding/banner_v2/crest.png';
}
```

### Usage Rules
- **NEVER** crop or resize images in code
- **ALWAYS** use `BoxFit.contain`
- **ALWAYS** use explicit height constraints
- **NO** white backgrounds behind logos
- Render PNG transparency as-is

---

## Banner Header System

### Widget: `BannerHeader`
Location: `app/lib/shared/widgets/banner_header.dart`

Three variants:
| Variant | Asset | Use Case | Heights (large/medium/small) |
|---------|-------|----------|------------------------------|
| `authHero()` | heroBanner | Auth screen | 260 / 230 / 200 |
| `appTop()` | heroBanner | In-app pages | 170 / 150 / 130 |

Breakpoints:
- Large: ≥1024px
- Medium: 600–1023px
- Small: <600px

### Current Usage
- **Auth**: `BannerHeader.authHero()` - overflow-safe layout using LayoutBuilder → SingleChildScrollView → ConstrainedBox → IntrinsicHeight → Column pattern
- **AppScaffold**: `BannerHeader.appTop()` is rendered ONCE centrally for all in-app pages (feed, explore, trophy_wall, weather, land, settings)
- **Swap Shop**: Uses `BannerHeader.appTop()` directly (standalone route outside AppScaffold)
- **Nav Rail**: `BrandAssets.crest` at 52px with BoxFit.contain

---

## Color System

Defined in `app/lib/app/theme/app_colors.dart`:

| Token | Value | Use |
|-------|-------|-----|
| `primary` | `#1B3D36` | Deep forest green |
| `primaryDark` | `#0C1614` | Darker green |
| `accent` | `#CD8232` | Burnt copper/brass |
| `background` | `#121C1A` | Deep background |
| `backgroundAlt` | `#1A2420` | Slightly lighter |
| `surface` | `#24302C` | Cards, containers |
| `textPrimary` | `#F8F6F3` | Off-white/ivory |
| `textSecondary` | `#9AA8A3` | Muted gray-green |
| `textTertiary` | `#6B7A75` | Subtle tone |

---

## Key Screens

| Screen | File | Notes |
|--------|------|-------|
| Auth | `features/auth/auth_screen.dart` | Full viewport, hero banner, "Keep me signed in" toggle |
| Feed | `features/feed/feed_screen.dart` | Image-first grid, category tabs |
| Explore | `features/explore/explore_screen.dart` | Species tiles, quick links |
| Trophy Wall | `features/trophy_wall/trophy_wall_screen.dart` | Profile + trophy grid |
| Weather | `features/weather/weather_screen.dart` | Hourly forecast w/ wind direction, clickable detail sheet |
| Land | `features/land/land_screen.dart` | Lease/Sale tabs |
| Settings | `features/settings/settings_screen.dart` | Account, preferences |
| Swap Shop | `features/swap_shop/swap_shop_screen.dart` | Marketplace |

---

## Weather Screen Features

- **Hourly Cards**: time, temp, precip %, wind speed, wind direction (arrow + N/NE/E/etc)
- **Clickable Detail Sheet**: feels like, wind/gusts/direction, humidity, pressure, visibility, precip, condition
- **Wind Section**: Compass visualization with speed/direction/gusts
- **Hunting Tools**: Sunrise, sunset, moon phase, activity indicators

---

## Auth Persistence ("Keep Me Signed In")

### Files
- `app/lib/services/auth_preferences.dart` - SharedPreferences wrapper
- `app/lib/services/supabase_service.dart` - Checks preference on startup

### Behavior
- **ON (default)**: Normal persistent session
- **OFF**: Calls `signOut()` on app start if session exists

---

## Pending Work

1. **Commit needed**: UI regression fixes applied:
   - Crest icon restored in NavigationRail at 52px
   - Hero banner header centralized in AppScaffold for all main pages
   - Auth screen overflow-safe layout implemented
   - All individual screen banner duplicates removed (except swap_shop standalone)

2. **Checkerboard issue**: If hero_banner.png still shows checkerboard in-app, the PNG itself has baked pixels (not code issue). Verify asset transparency.

---

## File Structure

```
app/
├── lib/
│   ├── app/
│   │   ├── app.dart
│   │   ├── router.dart
│   │   └── theme/
│   │       ├── app_colors.dart
│   │       ├── app_spacing.dart
│   │       └── app_theme.dart
│   ├── features/
│   │   ├── auth/
│   │   ├── explore/
│   │   ├── feed/
│   │   ├── land/
│   │   ├── settings/
│   │   ├── swap_shop/
│   │   ├── trophy_wall/
│   │   └── weather/
│   ├── services/
│   │   ├── auth_preferences.dart
│   │   ├── auth_service.dart
│   │   ├── supabase_service.dart
│   │   └── ...
│   ├── shared/
│   │   ├── branding/
│   │   │   └── brand_assets.dart
│   │   └── widgets/
│   │       ├── banner_header.dart
│   │       ├── app_nav_rail.dart
│   │       ├── app_scaffold.dart
│   │       └── widgets.dart
│   └── main.dart
└── assets/
    └── branding/
        └── banner_v2/
```

---

## Git Status (as of last check)

```
## main...origin/main [ahead 1]
 M app/lib/features/auth/auth_screen.dart
 M app/lib/features/explore/explore_screen.dart
 M app/lib/features/feed/feed_screen.dart
 M app/lib/features/land/land_screen.dart
 M app/lib/features/settings/settings_screen.dart
 M app/lib/features/swap_shop/swap_shop_screen.dart
 M app/lib/features/trophy_wall/trophy_wall_screen.dart
 M app/lib/features/weather/weather_screen.dart
 M app/lib/services/supabase_service.dart
 M app/lib/shared/branding/brand_assets.dart
 M app/lib/shared/widgets/banner_header.dart
 M app/pubspec.yaml
?? app/lib/services/auth_preferences.dart
```

### Suggested Commit
```bash
git add -A
git commit -m "fix: use hero banner for in-app header + add keep signed in toggle"
git push origin main
```

---

## Commands

```bash
# Run web
flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# Run Windows
flutter run -d windows --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# Analyze
flutter analyze --no-fatal-infos

# Build web
flutter build web --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

---

## Notes for Next Session

1. **Commit the pending changes** (see Git Status section)
2. **Verify banner appearance** - if checkerboard still shows, the hero_banner.png asset needs to be re-exported with true transparency
3. **Test "Keep me signed in"** - toggle OFF, close app, reopen → should require sign in
4. **Nav rail crest** is set to 48px with `BrandAssets.crest`
5. All screens now use `BannerHeader.appTop()` for consistent page headers

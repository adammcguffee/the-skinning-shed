# The Skinning Shed - Project State

> Last updated: January 24, 2026

## Overview

Premium hunting & fishing community app built with Flutter. Dark, cinematic forest-green theme with full Supabase backend integration. Features include trophy posting with weather auto-fill, social interactions, direct messaging, land listings, swap shop marketplace, regulations lookup, and research analytics.

---

## Tech Stack

- **Framework**: Flutter/Dart (SDK ^3.10.7)
- **State Management**: Riverpod
- **Routing**: GoRouter
- **Backend**: Supabase (Auth, Database, Storage, Edge Functions, Realtime)
- **Typography**: Google Fonts (Inter)
- **APIs**: Open-Meteo (weather/historical), USNO (moon phases)

---

## Navigation Structure

### Main Navigation (AppScaffold)
| Index | Route | Screen | Description |
|-------|-------|--------|-------------|
| 0 | `/` | FeedScreen | Trophy feed with category tabs |
| 1 | `/explore` | ExploreScreen | Species tiles, quick links |
| 2 | `/trophy-wall` | TrophyWallScreen | User profile + trophy grid |
| 3 | `/land` | LandScreen | Land lease/sale listings |
| 4 | `/messages` | MessagesInboxScreen | DM inbox with unread badge |
| 5 | `/weather` | WeatherScreen | Forecast + hunting tools |
| 6 | `/research` | ResearchScreen | Pattern analytics |
| 7 | `/regulations` | RegulationsScreen | Seasons & limits |
| 8 | `/settings` | SettingsScreen | Account & preferences |

### Detail Routes (Outside Shell)
| Route | Screen | Description |
|-------|--------|-------------|
| `/auth` | AuthScreen | Login/signup |
| `/post` | PostScreen | Create trophy post |
| `/trophy/:id` | TrophyDetailScreen | Trophy detail with social |
| `/user/:id` | TrophyWallScreen | Other user's profile |
| `/messages/:conversationId` | ConversationScreen | Chat thread |
| `/swap-shop` | SwapShopScreen | Marketplace list |
| `/swap-shop/create` | SwapShopCreateScreen | Create listing |
| `/swap-shop/detail/:id` | SwapShopDetailScreen | Listing detail |
| `/land/create` | LandCreateScreen | Post land listing |
| `/land/:id` | LandDetailScreen | Land detail |
| `/regulations/:stateCode` | StateRegulationsScreen | State-specific regs |
| `/admin/regulations` | RegulationsAdminScreen | Admin: run regs sync |

---

## Features Status

### Core Features (Implemented)
- [x] **Auth**: Email sign in/up, "Keep me signed in" toggle
- [x] **Trophy Posts**: Full CRUD, species picker, weather auto-fill
- [x] **Weather Auto-Fill**: 3-tier API (forecast → historical → archive)
- [x] **Moon Phase**: USNO API integration with auto-fill
- [x] **Feed**: Category tabs, infinite scroll, trophy cards
- [x] **Trophy Detail**: Full stats display, social interactions
- [x] **Trophy Wall**: Profile view, trophy grid, filters
- [x] **Social**: Likes (respect/well-earned), comments, follows
- [x] **DM Messenger**: 1:1 direct messaging with realtime
- [x] **Weather Screen**: Location picker, hourly forecast, hunting tools
- [x] **Weather Favorites**: Sync across devices, star toggle
- [x] **Land Listings**: Create/view lease and sale listings
- [x] **Swap Shop**: Marketplace with categories, contact seller
- [x] **Regulations**: State selector, season dates, limits
- [x] **Research**: Pattern analytics with privacy threshold
- [x] **Ads System**: Header slots, page targeting, scheduling

### Pending / In Progress
- [ ] Push notifications
- [ ] Avatar upload in settings
- [ ] Full profile editing
- [ ] Admin moderation dashboard
- [ ] Offline mode / caching

---

## Services Layer

| Service | File | Purpose |
|---------|------|---------|
| `SupabaseService` | `supabase_service.dart` | Core Supabase client, auth |
| `AuthService` | `auth_service.dart` | Authentication flows |
| `TrophyService` | `trophy_service.dart` | Trophy CRUD operations |
| `WeatherService` | `weather_service.dart` | Weather API integration |
| `WeatherFavoritesService` | `weather_favorites_service.dart` | Favorite locations sync |
| `SolunarService` | `solunar_service.dart` | Moon phases from USNO |
| `LocationService` | `location_service.dart` | Geolocation + county lookup |
| `LocationPrefetchService` | `location_prefetch_service.dart` | Background location prefetch |
| `SpeciesService` | `species_service.dart` | Species master data |
| `LandListingService` | `land_listing_service.dart` | Land CRUD |
| `SwapShopService` | `swap_shop_service.dart` | Swap shop CRUD |
| `SocialService` | `social_service.dart` | Likes, comments |
| `FollowService` | `follow_service.dart` | User follows |
| `MessagingService` | `messaging_service.dart` | DM conversations |
| `RegulationsService` | `regulations_service.dart` | Regs data + Edge Function |
| `AdService` | `ad_service.dart` | Ad slot management |

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
| `success` | `#4CAF50` | Positive actions |
| `warning` | `#FF9800` | Caution states |
| `error` | `#F44336` | Errors |
| `info` | `#2196F3` | Informational |

---

## Branding Assets

### Location
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

---

## Key Screens Detail

### Feed (`/`)
- Image-first trophy cards
- Category tabs: All, Deer, Turkey, Bass, Other Game, Other Fishing
- Pull-to-refresh
- Tap card → Trophy detail

### Trophy Detail (`/trophy/:id`)
- Full-size cover photo
- Species, location, harvest date/time
- Weather conditions at harvest
- Moon phase
- Stats display (weight, points, etc.)
- Social: Like (respect/well-earned), comment
- Share button

### Trophy Wall (`/trophy-wall`, `/user/:id`)
- Profile header with avatar, username, bio
- Stats: trophy count, followers, following
- Follow/Message buttons (for other users)
- Trophy grid with category filters
- Edit profile (own profile only)

### Messages (`/messages`, `/messages/:conversationId`)
- Inbox list with unread badges
- Context pills (Swap/Land/Trophy)
- Relative timestamps
- Pull-to-refresh + 30s polling
- Conversation: realtime messages, pagination, keyboard shortcuts

### Weather (`/weather`)
- Location picker with favorites
- Hourly forecast cards (24h)
- Current conditions
- Hunting tools: sunrise/sunset, moon phase
- Clickable detail sheet per hour

### Land (`/land`, `/land/:id`, `/land/create`)
- Lease/Sale tabs
- Listing cards with photos
- Detail view with contact options
- Create listing form

### Swap Shop (`/swap-shop`, `/swap-shop/detail/:id`, `/swap-shop/create`)
- Category filter tabs
- Listing cards
- Detail with contact seller
- Message seller button → DM

### Regulations (`/regulations`, `/regulations/:stateCode`)
- State selector grid
- State detail: seasons, bag limits, special rules
- Admin: manual sync trigger

### Research (`/research`)
- Pattern analytics from trophy data
- Filters: species, date range, region
- Privacy threshold (≥10 samples)
- Moon phase, pressure, temperature, time-of-day charts

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
│   ├── data/
│   │   ├── county_centroids.dart
│   │   └── us_states.dart
│   ├── features/
│   │   ├── auth/
│   │   ├── explore/
│   │   ├── feed/
│   │   ├── land/
│   │   ├── messages/
│   │   ├── post/
│   │   ├── regulations/
│   │   ├── research/
│   │   ├── settings/
│   │   ├── swap_shop/
│   │   ├── trophy_wall/
│   │   └── weather/
│   ├── services/
│   │   ├── ad_service.dart
│   │   ├── auth_preferences.dart
│   │   ├── auth_service.dart
│   │   ├── follow_service.dart
│   │   ├── land_listing_service.dart
│   │   ├── location_prefetch_service.dart
│   │   ├── location_service.dart
│   │   ├── messaging_service.dart
│   │   ├── regulations_service.dart
│   │   ├── social_service.dart
│   │   ├── solunar_service.dart
│   │   ├── species_service.dart
│   │   ├── supabase_service.dart
│   │   ├── swap_shop_service.dart
│   │   ├── trophy_service.dart
│   │   ├── weather_favorites_service.dart
│   │   └── weather_service.dart
│   ├── shared/
│   │   ├── branding/
│   │   │   └── brand_assets.dart
│   │   └── widgets/
│   │       ├── ad_slot.dart
│   │       ├── app_nav_rail.dart
│   │       ├── app_scaffold.dart
│   │       ├── banner_header.dart
│   │       ├── modals/
│   │       │   └── create_menu_sheet.dart
│   │       └── widgets.dart
│   └── main.dart
├── assets/
│   └── branding/
│       └── banner_v2/
└── pubspec.yaml
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

## Recent Commits (Latest First)

```
2959f10 feat(chat): verification polish + inbox context + pagination + realtime optimization
4a2f3dd fix(ads): correct page ID mapping after Messages nav addition
df12ffc feat(chat-wire): wire Swap/Land/Profile message buttons
4555219 feat(chat-ui): inbox + conversation screen + unread badges + mark read
b944e86 feat(chat-db): tables + RLS + RPC + triggers
02c5620 feat(research): top insights readability + compare mode
e97fc93 feat(regs): sources seed + regulations-check edge function + admin run-now
4994491 feat(social): post detail + likes + comments + share + report
660a7c0 fix(core): polish pass - regulations empty state + search + admin provider
```

---

## Notes for Next Session

1. **Manual QA recommended** - Test DM flows, social interactions, regulations sync
2. **Edge Function deployment** - Verify `regulations-check` function is deployed
3. **Ad slots** - Add test creatives to verify ad rendering
4. **Performance audit** - Profile app startup time, image loading
5. **Accessibility pass** - Add semantic labels, verify contrast ratios

---

*Generated: January 24, 2026*

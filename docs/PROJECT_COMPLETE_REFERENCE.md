# The Skinning Shed — Complete Project Reference

**Version:** 1.0.0  
**Last Updated:** 2026-01-28  
**Domain:** https://theskinningshed.com

---

## TABLE OF CONTENTS

1. [Project Overview](#1-project-overview)
2. [Tech Stack](#2-tech-stack)
3. [Project Structure](#3-project-structure)
4. [Architecture](#4-architecture)
5. [Database Schema](#5-database-schema)
6. [API & Services](#6-api--services)
7. [Features & Screens](#7-features--screens)
8. [Routing](#8-routing)
9. [Authentication](#9-authentication)
10. [State Management](#10-state-management)
11. [Design System](#11-design-system)
12. [Storage & File Uploads](#12-storage--file-uploads)
13. [Backend Workers](#13-backend-workers)
14. [Development Guide](#14-development-guide)
15. [Build & Deployment](#15-build--deployment)
16. [Environment Configuration](#16-environment-configuration)
17. [Security](#17-security)

---

## 1. PROJECT OVERVIEW

### What is The Skinning Shed?

The Skinning Shed is a **premium hunting and fishing community platform** that allows users to:

- **Share trophy harvests** with photos, weather data, and location info
- **Buy/sell gear** through the Swap Shop marketplace
- **Find hunting land** (leases and sales)
- **Check weather** with solunar data for hunting/fishing conditions
- **Access official links** to state wildlife agency portals
- **Research patterns** to analyze harvest conditions
- **Connect with other hunters** via messaging and follows

### Target Platforms

| Platform | Status |
|----------|--------|
| Web | ✅ Production Ready |
| iOS | ✅ Configured (requires Mac for build) |
| Android | ✅ Configured |
| Windows | ✅ Supported |
| macOS | ✅ Supported |

### Key Identifiers

| Item | Value |
|------|-------|
| Package Name (Flutter) | `shed` |
| iOS Bundle ID | `com.theskinning.shed` |
| Android Application ID | `com.theskinning.shed` |
| Production Domain | `theskinningshed.com` |
| Supabase Project | `ssrlhrydcetpspmdphfo` |

---

## 2. TECH STACK

### Frontend (Flutter)

| Technology | Version | Purpose |
|------------|---------|---------|
| Flutter | 3.38.x | Cross-platform UI framework |
| Dart | 3.10.x | Programming language |
| flutter_riverpod | 2.6.1 | State management |
| go_router | 15.0.0 | Navigation/routing |
| supabase_flutter | 2.9.0 | Backend client |
| cached_network_image | 3.4.1 | Image caching |
| image_picker | 1.2.1 | Photo selection |
| geolocator | 13.0.2 | Location services |
| google_fonts | 6.2.1 | Typography |
| dio | 5.8.0 | HTTP client |
| share_plus | 12.0.1 | Share functionality |

### Backend (Supabase)

| Component | Purpose |
|-----------|---------|
| PostgreSQL | Primary database |
| Supabase Auth | Authentication (email/password) |
| Supabase Storage | File/image storage |
| Row Level Security (RLS) | Data access control |
| Edge Functions | Serverless functions |
| Realtime | Subscriptions (future) |

### Infrastructure

| Service | Purpose |
|---------|---------|
| Vercel | Web hosting |
| Namecheap | Domain registrar |
| Open-Meteo API | Weather data |

### Backend Worker (Node.js)

| Technology | Purpose |
|------------|---------|
| Node.js | Runtime |
| TypeScript | Language |
| OpenAI API | GPT for regulations extraction |

---

## 3. PROJECT STRUCTURE

```
the_skinning_shed/
├── app/                          # Flutter application
│   ├── lib/
│   │   ├── main.dart            # Entry point
│   │   ├── app/                 # App configuration
│   │   │   ├── app.dart         # Root widget (SkinningApp)
│   │   │   ├── bootstrap_screen.dart  # Startup/loading screen
│   │   │   ├── router.dart      # GoRouter configuration
│   │   │   └── theme/           # Design system
│   │   │       ├── app_colors.dart    # Color palette
│   │   │       ├── app_spacing.dart   # Spacing constants
│   │   │       ├── app_theme.dart     # ThemeData
│   │   │       └── background_theme.dart
│   │   ├── features/            # Feature modules (screens)
│   │   │   ├── auth/            # Login/signup
│   │   │   ├── explore/         # Discovery
│   │   │   ├── feed/            # Home feed
│   │   │   ├── land/            # Land listings
│   │   │   ├── messages/        # DM system
│   │   │   ├── post/            # Create trophy post
│   │   │   ├── regulations/     # Official links
│   │   │   ├── research/        # Pattern analysis
│   │   │   ├── settings/        # Settings & legal
│   │   │   ├── swap_shop/       # Marketplace
│   │   │   ├── trophy_wall/     # Profile & trophies
│   │   │   └── weather/         # Weather & solunar
│   │   ├── services/            # Business logic & API clients
│   │   ├── shared/              # Shared widgets & utilities
│   │   │   ├── branding/        # Brand assets
│   │   │   └── widgets/         # Reusable UI components
│   │   ├── data/                # Static data (states, counties)
│   │   ├── ads/                 # Ad system
│   │   └── utils/               # Utilities
│   ├── assets/                  # Images, fonts, data files
│   ├── android/                 # Android native config
│   ├── ios/                     # iOS native config
│   ├── web/                     # Web-specific files
│   │   ├── index.html           # HTML template
│   │   ├── manifest.json        # PWA manifest
│   │   ├── robots.txt           # SEO
│   │   ├── sitemap.xml          # SEO
│   │   └── .well-known/         # App links
│   ├── vercel.json              # Vercel hosting config
│   └── pubspec.yaml             # Dependencies
├── supabase/
│   ├── functions/               # Edge Functions
│   │   └── regulations-check-v*/
│   ├── migrations/              # Database migrations (78 total)
│   ├── sql/                     # SQL reference scripts
│   └── storage_policies/        # Storage policy docs
├── worker/
│   └── regs_worker/             # Node.js background worker
│       ├── src/
│       │   ├── index.ts         # Entry point
│       │   ├── crawler.ts       # Web crawler
│       │   ├── discover.ts      # URL discovery
│       │   ├── extract.ts       # Regulations extraction
│       │   ├── openai.ts        # GPT integration
│       │   └── supabase.ts      # DB client
│       └── package.json
├── tools/                       # Development scripts
│   ├── seed_ads.py              # Seed ad data
│   └── build_county_centroids.py
└── docs/                        # Documentation
    ├── PRODUCTION_DEPLOYMENT.md
    ├── SECURITY_AUDIT.md
    ├── LEGAL_AND_PRIVACY_CHECKLIST.md
    └── ... (many more)
```

---

## 4. ARCHITECTURE

### App Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         UI Layer                             │
│   (Screens in features/, Widgets in shared/widgets/)         │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    State Management                          │
│              (Riverpod Providers in services/)               │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                     Service Layer                            │
│        (API clients, business logic in services/)            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   Supabase Backend                           │
│      (PostgreSQL + Auth + Storage + Edge Functions)          │
└─────────────────────────────────────────────────────────────┘
```

### Navigation Architecture

Uses `go_router` with a `ShellRoute` for the main app scaffold:

```
AppScaffold (Shell)
├── Feed (/)
├── Explore (/explore)
├── Trophy Wall (/trophy-wall)
├── Land (/land)
├── Messages (/messages)
├── Swap Shop (/swap-shop)
├── Weather (/weather)
├── Research (/research)
├── Official Links (/official-links)
└── Settings (/settings)

Full-screen routes (outside shell):
├── /auth
├── /post
├── /trophy/:id
├── /swap-shop/detail/:id
├── /land/:id
├── /messages/:conversationId
└── /admin/official-links
```

---

## 5. DATABASE SCHEMA

### Core Tables (49 total)

#### User & Profiles

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `profiles` | User profiles | id (FK auth.users), username, display_name, avatar_path, bio, default_state, default_county, is_admin, favorite_species |

#### Trophy System

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `trophy_posts` | Harvest posts | user_id, category (deer/turkey/bass/other_game/other_fishing), species_id, state, county, harvest_date, visibility, story, private_notes, cover_photo_path, likes_count, comments_count |
| `trophy_photos` | Post photos | post_id, storage_path, sort_order |
| `weather_snapshots` | Weather at harvest | post_id, temp_f, wind_speed, pressure_hpa, humidity_pct, condition_text |
| `moon_snapshots` | Moon phase at harvest | post_id, phase_name, illumination_pct |
| `analytics_buckets` | Pre-computed analytics | post_id, state, county, category, tod_bucket, temp_bucket, moon_phase_bucket |

#### Marketplace

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `swap_shop_listings` | Gear listings | user_id, category, title, description, price, condition, contact_method, contact_value, status |
| `swap_shop_photos` | Listing photos | listing_id, storage_path |
| `land_listings` | Land for sale/lease | user_id, type (lease/sale), state, county, acreage, price_total, title, description |
| `land_photos` | Land photos | listing_id, storage_path |

#### Social

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `follows` | User follows | follower_id, following_id |
| `post_likes` | Trophy likes | post_id, user_id |
| `post_comments` | Trophy comments | post_id, user_id, body |
| `reactions` | Reactions | post_id, user_id, type |

#### Messaging

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `conversations` | DM threads | id, created_at |
| `conversation_members` | Thread participants | conversation_id, user_id, last_read_at |
| `messages` | Messages | conversation_id, sender_id, body, subject_type, subject_id |

#### Regulations System

| Table | Purpose |
|-------|---------|
| `state_portal_links` | Official wildlife agency URLs per state |
| `state_official_roots` | Verified agency domains |
| `state_regulations_sources` | Source URLs for extraction |
| `state_regulations_extracted` | Extracted regulation data |
| `state_record_highlights` | State record buck/bass data |

#### Reference Data

| Table | Purpose |
|-------|---------|
| `species_master` | Species list (deer, turkey, bass, etc.) |
| `ad_slots` | Advertisement placements |

#### Weather

| Table | Purpose |
|-------|---------|
| `weather_favorite_locations` | User's saved weather locations |

#### Moderation

| Table | Purpose |
|-------|---------|
| `content_reports` | User reports |
| `moderation_reports` | Moderation queue |
| `feedback_reports` | User feedback |

### Key Enums

```sql
-- Trophy categories
CREATE TYPE trophy_category AS ENUM ('deer', 'turkey', 'bass', 'other_game', 'other_fishing');

-- Post visibility
CREATE TYPE visibility_type AS ENUM ('public', 'private', 'followers_only');

-- Listing status
CREATE TYPE listing_status AS ENUM ('active', 'inactive', 'expired', 'removed');

-- Land type
CREATE TYPE land_type AS ENUM ('lease', 'sale');

-- Contact method
CREATE TYPE contact_method AS ENUM ('email', 'phone', 'external_link');

-- Time buckets
CREATE TYPE time_bucket AS ENUM ('morning', 'midday', 'evening', 'night');
```

### Row Level Security (RLS)

All 49 tables have RLS enabled. Key policies:

| Pattern | Example |
|---------|---------|
| Own data only | `auth.uid() = user_id` |
| Public read | `visibility = 'public'` |
| Active listings | `status = 'active'` |
| Admin access | `profiles.is_admin = true` |
| Conversation members | `EXISTS (SELECT 1 FROM conversation_members WHERE user_id = auth.uid())` |

---

## 6. API & SERVICES

### Service Files (`app/lib/services/`)

| Service | File | Purpose |
|---------|------|---------|
| **SupabaseService** | `supabase_service.dart` | Supabase client initialization, auth state |
| **AuthService** | `auth_service.dart` | Sign in, sign up, sign out |
| **ProfileService** | `profile_service.dart` | Profile CRUD, avatar upload |
| **TrophyService** | `trophy_service.dart` | Trophy posts CRUD, feed queries |
| **SwapShopService** | `swap_shop_service.dart` | Listings CRUD, search |
| **LandListingService** | `land_listing_service.dart` | Land listings CRUD |
| **MessagingService** | `messaging_service.dart` | Conversations, messages |
| **FollowService** | `follow_service.dart` | Follow/unfollow, counts |
| **SocialService** | `social_service.dart` | Likes, comments |
| **WeatherService** | `weather_service.dart` | Open-Meteo API calls |
| **WeatherFavoritesService** | `weather_favorites_service.dart` | Saved locations |
| **SolunarService** | `solunar_service.dart` | Moon phase calculations |
| **SpeciesService** | `species_service.dart` | Species list |
| **RegulationsService** | `regulations_service.dart` | Portal links |
| **LocationService** | `location_service.dart` | GPS, county lookup |
| **AdService** | `ad_service.dart` | Ad slot loading |

### External APIs

| API | Purpose | Authentication |
|-----|---------|----------------|
| Supabase | All backend | Anon key + JWT |
| Open-Meteo | Weather forecasts | None (free) |
| OpenAI | Regulations extraction (worker only) | API key |

### Key Providers (Riverpod)

```dart
// Auth
final supabaseServiceProvider = Provider<SupabaseService>(...);
final supabaseClientProvider = Provider<SupabaseClient?>(...);
final currentUserProvider = Provider<User?>(...);
final isAuthenticatedProvider = Provider<bool>(...);
final isAdminProvider = FutureProvider<bool>(...);

// Services
final profileServiceProvider = Provider<ProfileService>(...);
final trophyServiceProvider = Provider<TrophyService>(...);
final swapShopServiceProvider = Provider<SwapShopService>(...);
final messagingServiceProvider = Provider<MessagingService>(...);
final weatherServiceProvider = Provider<WeatherService>(...);
```

---

## 7. FEATURES & SCREENS

### Feed (`/`)

**File:** `features/feed/feed_screen.dart`

The home feed showing public trophy posts. Features:
- Category tabs (All, Deer, Turkey, Bass, Other)
- Filter panel (State, County, Username)
- Infinite scroll
- Like/comment/share actions

### Trophy Wall (`/trophy-wall`)

**File:** `features/trophy_wall/trophy_wall_screen.dart`

User's profile and trophy collection:
- Profile header with avatar, bio, stats
- Trophy grid
- Follower/following counts
- Edit profile button (own profile)
- Follow button (other profiles)

### Swap Shop (`/swap-shop`)

**File:** `features/swap_shop/swap_shop_screen.dart`

Gear marketplace:
- Category tabs (Firearms, Bows, Optics, etc.)
- Search and filters
- Listing cards with price
- Create listing flow

### Land (`/land`)

**File:** `features/land/land_screen.dart`

Hunting land listings:
- Lease vs Sale tabs
- State/County filters
- Listing details with photos
- Contact seller

### Weather (`/weather`)

**File:** `features/weather/weather_screen.dart`

Weather and solunar data:
- Current conditions
- 7-day forecast
- Moon phase
- Solunar best times
- Favorite locations

### Messages (`/messages`)

**File:** `features/messages/messages_inbox_screen.dart`

Direct messaging:
- Conversation list
- Unread indicators
- New message (user search)
- Threaded conversations

### Official Links (`/official-links`)

**File:** `features/regulations/regulations_screen.dart`

State wildlife agency portals:
- State selector
- Hunting seasons, regulations, licensing links
- Verification status badges

### Research (`/research`)

**File:** `features/research/research_screen.dart`

Harvest pattern analysis:
- Time of day distribution
- Temperature trends
- Moon phase correlations
- Pressure analysis

### Settings (`/settings`)

**File:** `features/settings/settings_screen.dart`

User settings and legal:
- Profile settings
- Notifications (future)
- Legal pages (Terms, Privacy, Disclaimer)
- Admin section (if admin)
- Sign out

---

## 8. ROUTING

### Route Table

| Path | Screen | Auth Required | Notes |
|------|--------|---------------|-------|
| `/` | FeedScreen | Yes | Supports `?category=` |
| `/auth` | AuthScreen | No | |
| `/explore` | ExploreScreen | Yes | |
| `/trophy-wall` | TrophyWallScreen | Yes | |
| `/weather` | WeatherScreen | Yes | |
| `/land` | LandScreen | Yes | |
| `/swap-shop` | SwapShopScreen | Yes | |
| `/messages` | MessagesInboxScreen | Yes | |
| `/research` | ResearchScreen | Yes | |
| `/official-links` | RegulationsScreen | Yes | |
| `/settings` | SettingsScreen | Yes | |
| `/post` | PostScreen | Yes | Create trophy |
| `/trophy/:id` | TrophyDetailScreen | Yes | |
| `/user/:id` | TrophyWallScreen | Yes | Other user's profile |
| `/profile/edit` | ProfileEditScreen | Yes | |
| `/swap-shop/create` | SwapShopCreateScreen | Yes | |
| `/swap-shop/detail/:id` | SwapShopDetailScreen | Yes | |
| `/land/create` | LandCreateScreen | Yes | Supports `?mode=` |
| `/land/:id` | LandDetailScreen | Yes | |
| `/messages/:conversationId` | ConversationScreen | Yes | |
| `/admin/official-links` | RegulationsAdminScreen | Admin | Protected |
| `/settings/terms` | TermsOfServicePage | Yes | |
| `/settings/privacy` | PrivacyPolicyPage | Yes | |
| `/settings/disclaimer` | ContentDisclaimerPage | Yes | |
| `/settings/help` | HelpCenterPage | Yes | |
| `/settings/about` | AboutPage | Yes | |
| `/settings/feedback` | FeedbackPage | Yes | |

### Navigation Implementation

```dart
// Navigate to route
context.go('/trophy-wall');

// Push route (with back)
context.push('/trophy/abc123');

// Navigate with parameters
context.go('/?category=deer');
context.push('/land/create?mode=lease');

// Navigate with path parameters
context.push('/trophy/$trophyId');
```

---

## 9. AUTHENTICATION

### Auth Flow

1. App starts → `BootstrapScreen` initializes Supabase
2. `AuthNotifier` checks session state
3. If no session → redirect to `/auth`
4. If session exists → redirect to `/`

### Auth Methods

| Method | Implementation |
|--------|----------------|
| Email/Password | `supabase_flutter` built-in |
| Magic Link | Supported (PKCE flow) |
| OAuth | Configurable (not enabled) |

### Session Persistence

```dart
// AuthPreferences manages "Keep me signed in"
final keepSignedIn = await AuthPreferences.getKeepSignedIn();
if (!keepSignedIn) {
  await client.auth.signOut();
}
```

### Route Protection

```dart
// GoRouter redirect
redirect: (context, state) {
  final isAuthenticated = authNotifier.isAuthenticated;
  if (!isAuthenticated && !isAuthRoute) {
    return '/auth';
  }
  return null;
}
```

---

## 10. STATE MANAGEMENT

### Riverpod Architecture

```dart
// Simple provider
final profileServiceProvider = Provider<ProfileService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ProfileService(client);
});

// Future provider (async data)
final isAdminProvider = FutureProvider<bool>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  // ... fetch is_admin from profiles
});

// State notifier (mutable state)
final unreadCountProvider = StateNotifierProvider<UnreadCountNotifier, int>(...);

// Change notifier (for GoRouter)
final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>(...);
```

### Widget Usage

```dart
class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final isAdmin = ref.watch(isAdminProvider);
    
    return isAdmin.when(
      data: (admin) => admin ? AdminWidget() : UserWidget(),
      loading: () => CircularProgressIndicator(),
      error: (e, _) => ErrorWidget(e),
    );
  }
}
```

---

## 11. DESIGN SYSTEM

### Color Palette (Dark Theme)

```dart
// Core colors
primary: Color(0xFF1E4D40)     // Deep forest green
accent: Color(0xFFCD8232)      // Warm copper/brass
background: Color(0xFF0C1614)  // Near-black forest
surface: Color(0xFF162420)     // Dark charcoal-green

// Text
textPrimary: Color(0xFFF5F2EC)   // Warm ivory
textSecondary: Color(0xFFA3B5AC) // Muted gray-green
textTertiary: Color(0xFF728579)  // Subtle

// Semantic
success: Color(0xFF4CAF50)
warning: Color(0xFFF9A825)
error: Color(0xFFE53935)
info: Color(0xFF42A5F5)
```

### Spacing Scale

```dart
static const double xxs = 2.0;
static const double xs = 4.0;
static const double sm = 8.0;
static const double md = 12.0;
static const double lg = 16.0;
static const double xl = 24.0;
static const double xxl = 32.0;
static const double xxxl = 48.0;

static const double screenPadding = 16.0;
static const double cardPadding = 16.0;
```

### Border Radius

```dart
static const double radiusXs = 4.0;
static const double radiusSm = 6.0;
static const double radiusMd = 8.0;
static const double radiusLg = 12.0;
static const double radiusXl = 16.0;
static const double radiusFull = 999.0;
```

### Shared Widgets (`shared/widgets/`)

| Widget | Purpose |
|--------|---------|
| `AppScaffold` | Main app shell with nav rail |
| `AppTopBar` | Custom app bar |
| `AppCard` | Styled card container |
| `AppButtonPrimary` | Primary action button |
| `AppButtonSecondary` | Secondary action button |
| `AppEmptyState` | Empty state placeholder |
| `AppSkeleton` | Loading skeleton |
| `PageHeader` | Page title header |
| `LocationPicker` | State/County selector |
| `AdSlot` | Advertisement placement |

---

## 12. STORAGE & FILE UPLOADS

### Storage Buckets

| Bucket | Purpose | Max Size | Types |
|--------|---------|----------|-------|
| `avatars` | Profile photos | 5MB | jpeg, png, webp, gif |
| `trophy_photos` | Trophy posts | 10MB | jpeg, png, webp, heic |
| `land_photos` | Land listings | 10MB | jpeg, png, webp |
| `swap_shop_photos` | Swap listings | 10MB | jpeg, png, webp |
| `ad_share` | Advertisements | 2MB | png, jpeg, webp, gif |
| `record_photos` | State records | 10MB | jpeg, png, webp, gif |

### Upload Pattern

```dart
// 1. Pick image
final picker = ImagePicker();
final result = await picker.pickImage(source: ImageSource.gallery);

// 2. Upload to storage
final path = '${userId}/${postId}/${filename}';
await supabase.storage.from('trophy_photos').upload(path, file);

// 3. Get public URL
final url = supabase.storage.from('trophy_photos').getPublicUrl(path);

// 4. Save path to database
await supabase.from('trophy_photos').insert({
  'post_id': postId,
  'storage_path': path,
});
```

---

## 13. BACKEND WORKERS

### Regulations Worker (`worker/regs_worker/`)

A Node.js background service that:

1. **Discovers** official wildlife agency URLs
2. **Verifies** link validity
3. **Extracts** regulation data using GPT
4. **Repairs** broken links

#### Job Types

| Job | Description |
|-----|-------------|
| `discover_state` | Find hunting/fishing regulation URLs |
| `extract_state_species` | Extract deer/turkey season data |

#### Running the Worker

```bash
cd worker/regs_worker
npm install
cp env.example.txt .env
# Edit .env with Supabase and OpenAI keys
npm run dev
```

### Edge Functions (`supabase/functions/`)

| Function | Purpose |
|----------|---------|
| `regulations-check-v6` | Validate portal links |

---

## 14. DEVELOPMENT GUIDE

### Prerequisites

- Flutter SDK 3.38.x+
- Dart SDK 3.10.x+
- Git
- Android Studio / VS Code
- Supabase account

### Initial Setup

```bash
# Clone repository
git clone <repo-url>
cd the_skinning_shed

# Install Flutter dependencies
cd app
flutter pub get

# Generate code (freezed, etc.)
flutter pub run build_runner build --delete-conflicting-outputs
```

### Running Locally

```bash
cd app

# Web
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://ssrlhrydcetpspmdphfo.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-key>

# Android
flutter run -d <device-id> \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

### Code Generation

After modifying models with `@freezed` or `@JsonSerializable`:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Linting

```bash
flutter analyze
```

---

## 15. BUILD & DEPLOYMENT

### Web Build

```bash
cd app

flutter build web --release \
  --dart-define=SUPABASE_URL=https://ssrlhrydcetpspmdphfo.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<key>

# Deploy to Vercel
cd build/web
npx vercel --prod
```

### Android Build

```bash
cd app

# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...

# Play Store Bundle
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

### iOS Build (requires Mac)

```bash
cd app

flutter build ios --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...

# Then archive in Xcode
```

---

## 16. ENVIRONMENT CONFIGURATION

### Required Environment Variables

| Variable | Description |
|----------|-------------|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase anonymous/public key |

### Configuration Method

Flutter uses `--dart-define` at build time:

```bash
flutter run --dart-define=SUPABASE_URL=https://... --dart-define=SUPABASE_ANON_KEY=...
```

In code:

```dart
const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
```

### Supabase Configuration

| Setting | Value |
|---------|-------|
| Project URL | `https://ssrlhrydcetpspmdphfo.supabase.co` |
| Site URL (Auth) | `https://theskinningshed.com` |
| Redirect URLs | `https://theskinningshed.com/**`, `com.theskinning.shed://callback` |

---

## 17. SECURITY

### RLS (Row Level Security)

All tables have RLS enabled. Key patterns:

```sql
-- Users can only modify their own data
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Public data is readable
CREATE POLICY "Public posts are viewable"
ON trophy_posts FOR SELECT
USING (visibility = 'public');

-- Admin-only access
CREATE POLICY "Admins can manage"
ON admin_table FOR ALL
USING (EXISTS (
  SELECT 1 FROM profiles
  WHERE profiles.id = auth.uid()
  AND profiles.is_admin = true
));
```

### Admin Access

Three-layer protection:

1. **UI**: Admin section hidden unless `isAdminProvider` returns true
2. **Router**: `/admin/*` routes check `profiles.is_admin`
3. **Database**: RLS policies require `is_admin = true`

### Client Security

- ✅ No SERVICE_ROLE key in client
- ✅ Credentials via `--dart-define` only
- ✅ No hardcoded URLs
- ✅ No sensitive data logging

### Storage Security

- Public read (intentional for sharing)
- Authenticated upload only
- File size limits enforced
- MIME type restrictions

---

## APPENDIX

### Useful Commands

```bash
# Flutter
flutter doctor              # Check setup
flutter devices             # List devices
flutter clean               # Clean build
flutter pub outdated        # Check dependencies

# Git
git status                  # Check changes
git log --oneline -10       # Recent commits

# Supabase (via MCP or CLI)
supabase db push            # Apply migrations
supabase functions deploy   # Deploy edge functions
```

### Key Files Quick Reference

| Need to... | Look at... |
|------------|------------|
| Add a new route | `app/lib/app/router.dart` |
| Add a new service | `app/lib/services/` |
| Modify theme colors | `app/lib/app/theme/app_colors.dart` |
| Add a shared widget | `app/lib/shared/widgets/` |
| Add database migration | `supabase/migrations/` |
| Configure hosting | `app/vercel.json` |
| Update app metadata | `app/pubspec.yaml` |
| Update iOS config | `app/ios/Runner/Info.plist` |
| Update Android config | `app/android/app/src/main/AndroidManifest.xml` |

### Contact

- Support Email: support@theskinningshed.com
- Production URL: https://theskinningshed.com

---

*Document generated: 2026-01-28*

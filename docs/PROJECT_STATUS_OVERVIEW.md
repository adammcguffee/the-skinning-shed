# Project Status Overview

> Last updated: 2026-01-23

## Repository Information

| Item | Value |
|------|-------|
| **GitHub Repo** | `adammcguffee/the-skinning-shed` |
| **Local Path** | `C:\src\skinning_shed\the_skinning_shed` |
| **App Root** | `C:\src\skinning_shed\the_skinning_shed\app` |
| **Framework** | Flutter (Dart) |
| **Backend** | Supabase (Auth, Database, Storage) |

## Branding Assets

**Canonical location**: `app/assets/branding/banner_v2/`

| Asset | Path |
|-------|------|
| Hero Banner | `banner_v2/hero_banner.png` |
| Crest | `banner_v2/crest.png` |
| Wordmark | `banner_v2/wordmark.png` |

**pubspec.yaml assets** (only these are bundled):
- `assets/images/`
- `assets/branding/banner_v2/`
- `assets/data/` (county centroids JSON)

Do NOT reference other branding folders—they are deprecated.

## Supabase Configuration

The app requires Supabase credentials passed via `--dart-define` flags.

**Required defines**:
- `SUPABASE_URL` — Project API URL (e.g., `https://xxxxx.supabase.co`)
- `SUPABASE_ANON_KEY` — Publishable anon key (starts with `eyJ...`)

**Optional defines**:
- `ADS_BUCKET_PUBLIC` — Default `true`. Set `false` if ad_share bucket is private.

**Example run command**:
```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL="https://your-project.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="eyJ..." \
  --dart-define=ADS_BUCKET_PUBLIC=true
```

**IMPORTANT**: Never commit Supabase keys to the repository.

## Major Features Implemented

### 1. Trophy Post with Weather Auto-Fill
- User selects county + date + time
- App fetches historical weather from Open-Meteo
- Weather conditions are editable before submission
- Stores `weather_snapshots` and `moon_snapshots` linked to trophy

### 2. WeatherService 3-Tier Selection
| Tier | API | Date Range | Source Tag |
|------|-----|------------|------------|
| 1 | Forecast API (`past_days=14`) | Now to now-14d | `auto_forecast_recent` |
| 2 | Historical Forecast API | 2022-01-01 to now-14d | `auto_historical_forecast` |
| 3 | Archive API | Before 2022-01-01 | `auto_archive` |

- Fallback chain: if one tier returns no data, tries next
- All snapshots tagged with `source` field for analytics

### 3. Research/Patterns Screen
- Aggregates trophy success by: moon phase, pressure, temperature, wind, time-of-day
- **Privacy gate**: Only shows aggregations when `count >= 10`
- Supports filtering by species/category
- Designed for pattern discovery without exposing individual data

### 4. Ad Slots System
- **Storage bucket**: `ad_share` (public, 2MB limit)
- **Metadata table**: `ad_slots` (page, position, storage_path, click_url, scheduling)
- **Responsive behavior**:
  - Mobile (<768px): Ads hidden
  - Tablet (768-1024px): Right ad only
  - Desktop (>1024px): Both left and right
- **URL resolution**: `kAdsBucketPublic` flag controls public vs signed URLs
- See `docs/ADS.md` for full documentation

### 5. County Centroid Lookup
- Full US county coverage via Census Gazetteer import
- JSON asset: `app/assets/data/county_centroids.json` (~3,222 counties)
- Keyed by 5-digit FIPS (GEOID)
- Privacy-preserving: uses county center, not user GPS

### 6. Bootstrap/Error UI
- `BootstrapScreen` gates app startup until Supabase initializes
- Loading and error views wrapped in `Directionality` widget
- Required because these render before `MaterialApp` mounts

## Current Known Issues / Risks

### Resolved Recently
- ✅ `weather_snapshots` column mismatch (pressure_inhg, wind_dir_text) — migrated
- ✅ `uploadBinary` Uint8List type error — fixed
- ✅ Swap shop record access (`listing['title']` → `listing.$1`) — fixed
- ✅ Bootstrap screen `No Directionality widget found` — fixed

### Potentially Still Present
- Photo upload flow may need end-to-end verification on all platforms
- Some bottom sheets may overflow on very small screens
- Certain buttons may still show "Coming soon" placeholder behavior

### Technical Debt
- No automated tests yet
- Error handling could be more robust in services
- Some hardcoded mock data in placeholder screens

## Current Priorities (Ranked)

1. **Verify trophy post + uploads end-to-end**
   - Photo upload, DB insert, feed render, photo display

2. **Responsive UI audit**
   - Ensure all sheets/dialogs/modals don't overflow
   - Test on mobile, tablet, desktop breakpoints

3. **Research patterns polish**
   - Lift vs baseline calculations
   - Species/category filters working
   - Chart improvements

4. **Ads smoke test**
   - Upload test creative to `ad_share/feed/left.png`
   - Verify ad renders on Feed page (desktop)

5. **Profile and settings completion**
   - Avatar upload
   - User preferences
   - Privacy settings

## Key Guardrails / Lessons Learned

| Issue | Lesson |
|-------|--------|
| Scaffold outside MaterialApp | Always wrap standalone Scaffold in `Directionality` if shown before MaterialApp |
| Record vs Map access | Dart records use `$1`, `$2`, `$3` not `['key']` |
| uploadBinary type | Convert `List<int>` to `Uint8List` via `Uint8List.fromList(bytes)` |
| Column name mismatches | Always verify DB schema matches app insert keys exactly |
| Weather API gaps | Use tiered fallback (forecast → historical forecast → archive) |
| Branding asset drift | Only reference `banner_v2/` assets; remove old folders from pubspec |
| Supabase keys | Never commit; always use `--dart-define` |

## File Structure (Key Directories)

```
the_skinning_shed/
├── app/
│   ├── lib/
│   │   ├── app/           # App shell, theme, routing
│   │   ├── features/      # Feature screens (feed, weather, post, etc.)
│   │   ├── services/      # Supabase, weather, trophy services
│   │   └── shared/        # Shared widgets, utilities
│   ├── assets/
│   │   ├── branding/banner_v2/  # Canonical branding
│   │   ├── data/                # county_centroids.json
│   │   └── images/              # App images
│   └── pubspec.yaml
├── docs/                  # Documentation
├── supabase/
│   ├── functions/         # Edge functions (if any)
│   └── sql/               # SQL migrations
└── tools/                 # Build scripts (e.g., county centroid generator)
```

## Related Documentation

- `docs/ADS.md` — Ad slot system details
- `docs/RUNBOOK.md` — Commands to run/build/deploy
- `docs/ARCHITECTURE_NOTES.md` — Technical architecture
- `docs/TODO_NEXT.md` — Prioritized task list
- `docs/WIRING_CHECKLIST.md` — UI wiring status

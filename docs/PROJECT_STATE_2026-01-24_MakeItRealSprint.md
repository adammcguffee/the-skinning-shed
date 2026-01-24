# PROJECT STATE — Premium "Make It Real" Sprint
**Date:** January 24, 2026  
**Commits:** 758a79b → b31184f (4 commits)

---

## Sprint Summary

This sprint elevated The Skinning Shed to a professional, functional level with:

1. **Improved Create UX** - Extended "Create" button with label on desktop
2. **Species-Aware Seasons** - Proper hunting vs fishing season bucketing
3. **Regulations Feature** - Complete state regulations browser with admin review
4. **Research Enhancements** - RPC aggregations + "How it works" transparency

---

## Commits

### 1. feat(create): extended Create button + land lease/sale context routing
`758a79b`

- Nav rail "Create" button now shows label (Extended FAB style)
- `showCreateMenu` accepts `landMode` parameter for context-aware land listings
- CreateMenuSheet reorders options based on context (Land first on Land page)
- Router accepts `?mode=lease|sale` query param for `/land/create`
- LandCreateScreen accepts `initialMode` to pre-select listing type
- LandScreen empty state passes current tab mode to create flow

### 2. feat(seasons): species-aware season bucketing + trophy wall filtering
`fb66f3f`

**New File:** `app/lib/utils/season_utils.dart`

- `SeasonType` enum: `huntingSeason` vs `calendarYear`
- Hunting seasons (deer/turkey/game): Aug Y to Jul Y+1, labeled "Y-Y+1"
- Fishing seasons: calendar years, labeled "YYYY"
- `SeasonUtils` class with computation methods

**Trophy Wall Updates:**
- Added `SpeciesCategory` filter (All/Game/Fish)
- Season chips adapt based on selected species category
- `_CategoryAndSeasonFilters` widget for combined filtering
- Empty state messages show correct season format

### 3. feat(regs): regulations page + schema + admin UI
`49fc9a1`

**Database Migrations:**
- `add_is_admin_to_profiles` - Added `is_admin` boolean column
- `create_regulations_tables_v2`:
  - `state_regulations_approved` - Public read, admin write
  - `state_regulations_pending` - Admin-only pending updates
  - Proper RLS policies for admin access control
  - Update triggers for `updated_at` timestamps

**New Files:**
- `app/lib/services/regulations_service.dart`
  - `RegulationsService` class with fetch/approve/reject methods
  - `StateRegulation` and `PendingRegulation` models
  - `RegulationSummary` with seasons/bagLimits/weapons/notes
- `app/lib/features/regulations/regulations_screen.dart`
  - State grid with clickable cards
  - Shows which states have data vs "Coming Soon"
- `app/lib/features/regulations/state_regulations_screen.dart`
  - Deer/Turkey/Fishing tabs
  - Season dates, bag limits, legal methods, notes
  - Source URL links to official sources
- `app/lib/features/regulations/regulations_admin_screen.dart`
  - Admin-only review interface
  - Approve/reject pending updates with notes

**Navigation:**
- Added Regulations and Research to mobile More sheet
- Routes: `/regulations`, `/regulations/:stateCode`, `/admin/regulations`
- Admin section in Settings (visible only to `is_admin` users)

### 4. feat(research): patterns dashboard + RPC functions + how it works
`b31184f`

**Database Functions (RPC):**
- `get_counts_by_tod` - Time of day aggregation
- `get_counts_by_temp` - Temperature bucket aggregation
- `get_counts_by_pressure` - Pressure bucket aggregation
- `get_counts_by_wind_dir` - Wind direction aggregation
- `get_counts_by_moon_phase` - Moon phase aggregation
- `get_top_condition_clusters` - Multi-variable pattern detection
- `get_research_total_count` - Total count with filters
- All RPCs enforce privacy threshold (count >= 10)

**Research Screen Updates:**
- Added "How it works" button and bottom sheet explaining:
  - Data comes from user uploads (not official records)
  - Weather snapshots captured at harvest time
  - Privacy threshold protects individual hunts
  - Patterns show correlation, not causation
- Prominent data source disclaimer banner
- Consistent with trust and transparency requirements

---

## Database Schema Changes

### New Tables

```sql
-- Approved regulations (public read)
CREATE TABLE state_regulations_approved (
  id UUID PRIMARY KEY,
  state_code CHAR(2),
  category TEXT CHECK (category IN ('deer', 'turkey', 'fishing')),
  season_year_label TEXT,
  year_start INT,
  year_end INT,
  summary JSONB,
  source_url TEXT,
  source_hash TEXT,
  last_checked_at TIMESTAMPTZ,
  approved_at TIMESTAMPTZ,
  approved_by UUID,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);

-- Pending regulations (admin only)
CREATE TABLE state_regulations_pending (
  id UUID PRIMARY KEY,
  state_code CHAR(2),
  category TEXT,
  season_year_label TEXT,
  year_start INT,
  year_end INT,
  proposed_summary JSONB,
  diff_summary TEXT,
  source_url TEXT,
  source_hash TEXT,
  status TEXT CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID,
  notes TEXT,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);
```

### New Column

```sql
ALTER TABLE profiles ADD COLUMN is_admin BOOLEAN DEFAULT false;
```

### New RPC Functions

6 aggregation functions for research analytics with privacy threshold enforcement.

---

## Files Changed/Created

### Created
- `app/lib/utils/season_utils.dart`
- `app/lib/services/regulations_service.dart`
- `app/lib/features/regulations/regulations_screen.dart`
- `app/lib/features/regulations/state_regulations_screen.dart`
- `app/lib/features/regulations/regulations_admin_screen.dart`

### Modified
- `app/lib/shared/widgets/app_nav_rail.dart` - Extended Create button
- `app/lib/shared/widgets/modals/create_menu_sheet.dart` - Land mode context
- `app/lib/app/router.dart` - New routes for regulations + admin
- `app/lib/features/land/land_create_screen.dart` - Accept initial mode
- `app/lib/features/land/land_screen.dart` - Pass mode to empty state CTA
- `app/lib/features/trophy_wall/trophy_wall_screen.dart` - Species-aware seasons
- `app/lib/features/settings/settings_screen.dart` - Admin section
- `app/lib/shared/widgets/app_scaffold.dart` - More sheet items
- `app/lib/features/research/research_screen.dart` - How it works modal

---

## What Works Now

- **Create Menu**: Clear "Create" label on desktop, context-aware options
- **Land Create**: Respects Lease/Sale tab selection without extra prompt
- **Trophy Wall**: Species-aware season filtering (Game: "2025-26", Fish: "2026")
- **Regulations**: Browse by state, view deer/turkey/fishing regs
- **Admin**: Review pending regulation updates (for is_admin users)
- **Research**: Clear data source attribution and "How it works" explanation

---

## What's Still Needed

1. **Regulations Data**: Need to populate `state_regulations_approved` with actual regulation data
2. **Weekly Checker**: Edge Function for automated source checking (schema supports it, not implemented)
3. **Avatar Upload**: Profile edit with avatar storage handling
4. **Post Detail**: Comments and reactions UI
5. **Following Feed**: Filter feed by users you follow

---

## Testing Checklist

- [ ] Open app, verify extended "Create" button shows label on desktop
- [ ] Click Create on Land page with "For Lease" tab selected → should go to create with lease pre-selected
- [ ] Trophy Wall: Select "Game" filter → seasons show "2025-26" format
- [ ] Trophy Wall: Select "Fish" filter → seasons show "2026" format
- [ ] Navigate to /regulations → see state grid
- [ ] Click any state → verify tabbed regulations view loads
- [ ] Research page: click "How it works" → verify modal explains data source
- [ ] If admin: Settings shows "Regulations Admin" option

---

## Git History

```
b31184f feat(research): patterns dashboard + RPC functions + how it works
49fc9a1 feat(regs): regulations page + schema + admin UI
fb66f3f feat(seasons): species-aware season bucketing + trophy wall filtering
758a79b feat(create): extended Create button + land lease/sale context routing
```

**Pushed to:** `origin/main`

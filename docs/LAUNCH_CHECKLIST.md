# Professional Launch Pass - Checklist

## Last Updated: 2026-01-26

---

## Phase 0: Quick Audit
- [x] Storage buckets verified: avatars, trophy_photos, land_photos, swap_shop_photos, ad_share, record_photos
- [x] All screens identified and audited

## Phase 1: Navigation Safety
- [x] AppPageHeader widget exists (PageHeader in widgets.dart) 
- [x] Swap Shop Create has proper header with back/home
- [x] Trophy Post Create has proper header
- [x] Land Create has proper header
- [x] Profile Edit has proper header
- [x] All sidebar icons route correctly

## Phase 2: Storage & Uploads  
- [x] All buckets exist with correct MIME types
- [x] Upload flows work for trophy photos
- [x] Upload flows work for swap shop photos
- [x] Upload flows work for land photos
- [x] Avatar upload works

## Phase 3: Official Links (formerly Regulations)
- [x] State grid with direct external links
- [x] No intermediate state page
- [x] Search by state name/abbreviation
- [x] Trust microcopy added
- [x] No negative badges/text shown to users

## Phase 4: Swap Shop Fixes
- [x] **FIXED**: Keyword search - searches title, description, category, state, county (ilike)
- [x] **FIXED**: Tile overflow - adjusted padding, font sizes, aspect ratio (0.75 → 0.72)

## Phase 5: Visual Polish
- [x] Empty states present (AppEmptyState widget)
- [x] Loading skeletons present
- [x] Hover animations on cards

## Phase 6: Trophy Wall & Profile
- [x] Edit Profile fully wired (display name, bio, state/county, species)
- [x] Avatar upload/change/remove works
- [x] Profile photo clickable to edit
- [x] Trophy grid with species chips

## Weather Page Fixes
- [x] **FIXED**: Dropdown text contrast - dark surface bg with high-contrast white text
- [x] **FIXED**: Remove FIPS display from county picker list

## Naming Consistency (Regulations → Official Links)
- [x] Sidebar label updated to "Official Links"
- [x] AdPages.regulations → AdPages.officialLinks
- [x] Ad slot registry updated
- [x] Page title/subtitle updated
- [x] Trust microcopy: "We link directly to state wildlife agencies — no summaries, no guesswork."

---

## Build Verification

| Platform | Status | Notes |
|----------|--------|-------|
| Web (Chrome) | ✅ Pass | `flutter build web --release` succeeded |
| Windows | ⬜ Pending | Ready for test |

---

## Fixes Applied (2026-01-26)

### 1. Weather Dropdown Text Contrast
**File**: `app/lib/shared/widgets/location_picker.dart`
**Change**: Changed _LocationField background from `Colors.white` to `AppColors.surfaceElevated` with `Colors.white` text for selected values.

### 2. County FIPS Display  
**File**: `app/lib/shared/widgets/location_picker.dart`
**Change**: Removed `subtitle: Text('FIPS: ${county.fips}')` from CountyPickerSheet ListTile.

### 3. Swap Shop Tile Overflow
**File**: `app/lib/features/swap_shop/swap_shop_screen.dart`
**Changes**:
- Reduced content padding from `AppSpacing.md` to `AppSpacing.sm/xs`
- Changed title from 2 lines to 1 line with ellipsis
- Reduced font sizes (title 13px, location 10px)
- Adjusted grid childAspectRatio from 0.75 to 0.72

### 4. Swap Shop Keyword Search
**File**: `app/lib/services/swap_shop_service.dart`
**Change**: Expanded ilike OR query to include category, state, and county fields.

### 5. Official Links Naming Consistency
**Files**: 
- `app/lib/services/ad_service.dart` - `AdPages.regulations` → `AdPages.officialLinks`
- `app/lib/shared/widgets/app_scaffold.dart` - Updated page ID mapping
- `app/lib/ads/ad_slot_registry.dart` - Updated slot names
- `app/lib/features/regulations/regulations_screen.dart` - Updated tooltips and trust copy

### 6. Official Links UX Polish
**File**: `app/lib/features/regulations/regulations_screen.dart`
**Changes**:
- Removed "Link unavailable" tooltip - all states show positive "Open {state} wildlife portal"
- Changed snackbar for missing links to friendly "coming soon" message
- Updated info card copy to trust-focused messaging

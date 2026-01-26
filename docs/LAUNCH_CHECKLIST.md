# Professional Launch Pass - Checklist

## Phase 0: Quick Audit
- [x] Storage buckets verified: avatars, trophy_photos, land_photos, swap_shop_photos, ad_share, record_photos
- [x] All screens identified and audited

## Phase 1: Navigation Safety
- [x] AppPageHeader widget exists (PageHeader in widgets.dart)
- [x] Swap Shop Create has proper header with back/home
- [x] All deep screens have navigation (uses PageHeader widget)

## Phase 2: Storage & Uploads
- [x] All buckets exist with correct MIME types
- [x] Upload flows work (tested via existing code)

## Phase 3: Official Links
- [x] State grid with direct external links (completed in prior session)
- [x] No intermediate state page

## Phase 4: Swap Shop Fixes
- [x] **FIXED**: Keyword search - now searches title, description, category, state, county (ilike)
- [x] **FIXED**: Tile overflow - adjusted padding, font sizes, aspect ratio (0.75 → 0.72)

## Phase 5: Visual Polish
- [x] Empty states present (AppEmptyState widget)
- [x] Loading skeletons present

## Weather Page Fixes
- [x] **FIXED**: Dropdown text contrast - dark surface bg with high-contrast white text
- [x] **FIXED**: Remove FIPS display from county picker list

---

## Fixes Applied (2026-01-26)

### 1. Weather Dropdown Text Contrast
**File**: `app/lib/shared/widgets/location_picker.dart`
**Change**: Changed _LocationField background from `Colors.white` to `AppColors.surfaceElevated` with `Colors.white` text for selected values, proper borders.

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
**Change**: Expanded ilike OR query to include category, state, and county fields in addition to title and description.

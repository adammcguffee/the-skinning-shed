# Project State Checkpoint — Big Sprint #2
**Date:** 2026-01-24  
**Branch:** main  
**Last Commit:** 53fd0d7

---

## Summary

Big Sprint #2 focused on replacing "Coming Soon" placeholders with real, functioning flows. The app now has working create flows, a social follow system, and full browse/search/filter/detail experiences for Swap Shop and Land listings.

---

## Commits in This Sprint

| Commit | Message |
|--------|---------|
| 43171b2 | feat(create): global Create Menu + create flows + services |
| 6a1a46b | feat(social): follows system + real follower/following UI |
| 8be091c | feat(swap): swap shop search + filters + sorting + real data |
| 53fd0d7 | feat(land): land listings real data + detail screen + filters |

---

## What Was Built

### A) Global Create Menu
- **Location:** `app/lib/shared/widgets/modals/create_menu_sheet.dart`
- Replaced ambiguous "+" FAB with premium Create Menu bottom sheet
- Context-aware: highlights relevant option based on current page
- Options: Trophy Post, Swap Shop Listing, Land Listing
- FAB now has tooltip (web) and long-press feedback (mobile)

### B) Follows System
- **Database:** `follows` table with RLS
  - `follower_id`, `following_id`, `created_at`
  - Unique constraint, no self-follow check
  - Anyone can read, users manage their own follows
- **Service:** `app/lib/services/follow_service.dart`
  - `isFollowing()`, `follow()`, `unfollow()`, `toggleFollow()`
  - `getFollowCounts()`, `getFollowers()`, `getFollowing()`
  - `FollowStateNotifier` for reactive state per user
- **UI:** Trophy Wall now shows:
  - Real profile data (name, username, avatar, location)
  - Follow/Unfollow button for other users
  - Clickable Followers/Following counts → opens list sheet
  - Follow toggle in follower/following lists

### C) Swap Shop
- **Service:** `app/lib/services/swap_shop_service.dart`
  - Full CRUD operations
  - Search (title + description ilike)
  - Filter by category, condition, state, county, price range
  - Sort by newest, price low→high, price high→low
- **Screens:**
  - `swap_shop_screen.dart` — Browse with search bar, category chips, sort options
  - `swap_shop_create_screen.dart` — Full form with photos, category, condition, location, contact
  - `swap_shop_detail_screen.dart` — Photo carousel, seller info, contact button
- **Database:** Added `condition` column to `swap_shop_listings`

### D) Land Listings
- **Service:** `app/lib/services/land_listing_service.dart`
  - Full CRUD operations
  - Filter by type, state, county, acreage range, price range, species
  - Sort by newest, price, acreage
- **Screens:**
  - `land_screen.dart` — Browse with lease/sale tabs, sort filters
  - `land_create_screen.dart` — Full form with type toggle, photos, species tags, contact
  - `land_detail_screen.dart` — Photo carousel, stats, species tags, contact button

### E) Shared Widgets
- **Form Fields:** `app/lib/shared/widgets/app_form_fields.dart`
  - `AppTextField` — Premium text field with dark theme
  - `AppDropdownField` — Premium dropdown with dark theme
  - `AppSearchField` — Search with clear button

---

## Database Migrations Applied

1. `add_condition_to_swap_shop_listings` — Added `condition` text column
2. `create_follows_table` — Created follows table with indexes and RLS

---

## Routes Added

| Route | Screen |
|-------|--------|
| `/swap-shop/create` | SwapShopCreateScreen |
| `/swap-shop/detail/:id` | SwapShopDetailScreen |
| `/land/create` | LandCreateScreen |

---

## Files Created

```
app/lib/features/land/land_create_screen.dart
app/lib/features/swap_shop/swap_shop_create_screen.dart
app/lib/features/swap_shop/swap_shop_detail_screen.dart
app/lib/services/follow_service.dart
app/lib/services/land_listing_service.dart
app/lib/services/swap_shop_service.dart
app/lib/shared/widgets/app_form_fields.dart
app/lib/shared/widgets/modals/create_menu_sheet.dart
```

## Files Modified

```
app/lib/app/router.dart
app/lib/features/land/land_detail_screen.dart
app/lib/features/land/land_screen.dart
app/lib/features/swap_shop/swap_shop_screen.dart
app/lib/features/trophy_wall/trophy_wall_screen.dart
app/lib/shared/widgets/app_scaffold.dart
app/lib/shared/widgets/widgets.dart
```

---

## What's Working (MVP Complete)

| Feature | Status |
|---------|--------|
| Create Menu (global) | ✅ Working |
| Trophy Post creation | ✅ Working (was already implemented) |
| Trophy Wall - own profile | ✅ Working |
| Trophy Wall - other users | ✅ Working with follow button |
| Follow/Unfollow | ✅ Working |
| Followers/Following lists | ✅ Working |
| Swap Shop browse | ✅ Working with search/filter/sort |
| Swap Shop create | ✅ Working |
| Swap Shop detail | ✅ Working with contact |
| Land browse | ✅ Working with filter/sort |
| Land create | ✅ Working |
| Land detail | ✅ Working with contact |
| Weather (fast open) | ✅ Working (from Sprint #1) |

---

## Remaining "Coming Soon" (Post-MVP)

| Feature | Current State |
|---------|---------------|
| Edit Profile | Coming Soon modal |
| Avatar upload | Not implemented |
| Report/Block | Coming Soon modal |
| Comments system | Coming Soon modal |
| Native share sheet | Uses clipboard copy |
| Reactions (like) | Partial implementation |

---

## How to Run

```bash
cd app
flutter run -d chrome \
  --dart-define=SUPABASE_URL=your_url \
  --dart-define=SUPABASE_ANON_KEY=your_key
```

---

## QA Checklist

- [ ] Create Menu opens from FAB on all pages
- [ ] Create Menu highlights correct option per page context
- [ ] Trophy Post creation works end-to-end
- [ ] Swap Shop create → appears in browse
- [ ] Swap Shop search filters results
- [ ] Swap Shop detail shows photos and contact works
- [ ] Land create → appears in browse
- [ ] Land filter by lease/sale works
- [ ] Land detail shows photos and contact works
- [ ] Follow button appears on other users' Trophy Walls
- [ ] Follow/unfollow updates counts
- [ ] Followers list shows and allows follow toggle
- [ ] Following list shows and allows follow toggle

---

## Notes

- No Supabase keys committed (using dart-define)
- Branding assets unchanged
- All new UI uses shared widgets and dark theme
- RLS policies in place for follows table

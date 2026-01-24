# Supabase Schema — The Skinning Shed

> MVP database schema with RLS enabled on all tables.

## Tables Overview

| Table | Purpose | RLS | Rows |
|-------|---------|-----|------|
| `profiles` | User identity / Trophy Wall | ✅ | 0 |
| `species_master` | Controlled species taxonomy | ✅ | 42 |
| `trophy_posts` | Core harvest records | ✅ | 0 |
| `trophy_photos` | Multiple photos per trophy | ✅ | 0 |
| `weather_snapshots` | Historical weather at harvest | ✅ | 0 |
| `moon_snapshots` | Moon phase at harvest | ✅ | 0 |
| `weather_favorite_locations` | User's favorite weather locations | ✅ | 0 |
| `analytics_buckets` | Denormalized research data | ✅ | 0 |
| `land_listings` | Land for lease/sale | ✅ | 0 |
| `land_photos` | Land listing photos | ✅ | 0 |
| `swap_shop_listings` | BST classifieds | ✅ | 0 |
| `swap_shop_photos` | Swap shop photos | ✅ | 0 |
| `comments` | Trophy comments | ✅ | 0 |
| `reactions` | Respect / Well-earned reactions | ✅ | 0 |
| `moderation_reports` | User reports | ✅ | 0 |

## Storage Buckets

| Bucket | Purpose | Public | Size Limit |
|--------|---------|--------|------------|
| `avatars` | User profile photos | ✅ | 5MB |
| `trophy_photos` | Trophy images | ✅ | 10MB |
| `land_photos` | Land listing images | ✅ | 10MB |
| `swap_shop_photos` | Swap shop images | ✅ | 10MB |

### Storage Path Conventions

```
avatars/{user_id}/avatar.{ext}
trophy_photos/{user_id}/{trophy_id}/{filename}
land_photos/{user_id}/{listing_id}/{filename}
swap_shop_photos/{user_id}/{listing_id}/{filename}
```

## Enums

| Type | Values |
|------|--------|
| `visibility_type` | public, private, followers_only |
| `trophy_category` | deer, turkey, bass, other_game, other_fishing |
| `time_bucket` | morning, midday, evening, night |
| `species_category` | game, fish |
| `land_type` | lease, sale |
| `contact_method` | email, phone, external_link |
| `listing_status` | active, inactive, expired, removed |
| `reaction_type` | respect, well_earned |
| `report_target` | post, listing, comment, user |
| `report_status` | open, reviewed, closed |
| `wind_direction` | N, NE, E, SE, S, SW, W, NW, VAR |

---

## Key Tables

### profiles

User identity linked to Supabase Auth.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | = auth.users.id |
| `username` | TEXT (unique) | Display username |
| `display_name` | TEXT | Friendly name |
| `avatar_path` | TEXT | Storage path |
| `bio` | TEXT | User bio |
| `default_state` | TEXT | Preferred state |
| `default_county` | TEXT | Preferred county |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |

### trophy_posts

Core harvest records.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | |
| `user_id` | UUID (FK) | → profiles.id |
| `visibility` | visibility_type | public/private |
| `category` | trophy_category | deer/turkey/bass/other |
| `species_id` | UUID (FK) | → species_master.id |
| `custom_species_name` | TEXT | For "Other (specify)" |
| `state` | TEXT | State code |
| `county` | TEXT | County name |
| `harvest_date` | DATE | **User-entered** |
| `harvest_time` | TIME | Exact time (optional) |
| `harvest_time_bucket` | time_bucket | Morning/Midday/Evening |
| `posted_at` | TIMESTAMPTZ | **System timestamp** |
| `story` | TEXT | User's story |
| `private_notes` | TEXT | Owner-only notes |
| `stats_json` | JSONB | Species-specific stats |
| `cover_photo_path` | TEXT | Primary photo |
| `reaction_count` | INT | Denormalized count |
| `comment_count` | INT | Denormalized count |

### species_master

Controlled species list (42 species seeded).

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | |
| `category` | species_category | game/fish |
| `subcategory` | trophy_category | deer/turkey/bass/other |
| `common_name` | TEXT | Display name |
| `scientific_name` | TEXT | Latin name (optional) |
| `regions` | TEXT[] | State codes |
| `is_active` | BOOLEAN | Enabled for selection |
| `sort_order` | INT | Display order |

### land_listings

Property for lease or sale.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | |
| `user_id` | UUID (FK) | → profiles.id |
| `type` | land_type | lease/sale |
| `state` | TEXT | |
| `county` | TEXT | |
| `acreage` | NUMERIC | |
| `price_total` | NUMERIC | |
| `title` | TEXT | |
| `description` | TEXT | |
| `species_tags` | TEXT[] | ['deer', 'turkey'] |
| `contact_method` | contact_method | |
| `contact_value` | TEXT | |
| `status` | listing_status | |
| `expires_at` | TIMESTAMPTZ | Auto-expiration |

### swap_shop_listings

Buy/Sell/Trade classifieds.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | |
| `user_id` | UUID (FK) | → profiles.id |
| `category` | TEXT | Equipment category |
| `state` | TEXT | |
| `county` | TEXT | (optional) |
| `title` | TEXT | |
| `description` | TEXT | |
| `price` | NUMERIC | (optional) |
| `contact_method` | contact_method | |
| `contact_value` | TEXT | |
| `status` | listing_status | |
| `expires_at` | TIMESTAMPTZ | Auto-expiration |

### weather_favorite_locations

User's saved weather location favorites. Syncs across web/mobile.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | |
| `user_id` | UUID (FK) | → auth.users.id |
| `state_code` | TEXT | 2-letter state code |
| `county_name` | TEXT | Full county name |
| `county_fips` | TEXT | 5-digit FIPS code (optional) |
| `label` | TEXT | Display label e.g. "Jefferson Co, AL" |
| `sort_order` | INT | User ordering |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |

---

## RLS Policies Summary

### profiles
- ✅ Public read for all profiles
- ✅ Users can update/insert their own profile

### trophy_posts
- ✅ Public posts readable by everyone
- ✅ Private posts readable only by owner
- ✅ Users can CRUD their own posts

### trophy_photos, weather_snapshots, moon_snapshots
- ✅ Readable if parent post is public OR user is owner
- ✅ Writable only by post owner

### land_listings, swap_shop_listings
- ✅ Active listings readable by everyone
- ✅ All listings readable by owner
- ✅ CRUD by owner only

### comments, reactions
- ✅ Readable on public posts
- ✅ Insertable by authenticated users on public posts
- ✅ Deletable by owner

### moderation_reports
- ✅ Users can create reports
- ✅ Users can view their own reports

### weather_favorite_locations
- ✅ Users can CRUD their own favorites
- ✅ User-scoped via RLS (auth.uid() = user_id)

### Storage (all buckets)
- ✅ Public read
- ✅ Write only to user's own folder (`{user_id}/...`)

---

## Migrations Applied

| Version | Name |
|---------|------|
| 20260123033813 | create_enums_and_types |
| 20260123033823 | create_profiles_table |
| 20260123033841 | create_species_master_table |
| 20260123033908 | create_trophy_posts_table |
| 20260123033919 | create_trophy_photos_table |
| 20260123033938 | create_weather_moon_snapshots |
| 20260123033953 | create_land_listings |
| 20260123034007 | create_swap_shop |
| 20260123034025 | create_social_and_moderation |
| 20260123034047 | create_storage_buckets |

---

## Auto-Generated Triggers

1. **profiles_updated_at** — Updates `updated_at` on profile changes
2. **trophy_posts_updated_at** — Updates `updated_at` on post changes
3. **land_listings_updated_at** — Updates `updated_at` on listing changes
4. **swap_shop_updated_at** — Updates `updated_at` on listing changes
5. **on_auth_user_created** — Auto-creates profile on signup
6. **update_reaction_count** — Maintains reaction count on trophy_posts
7. **update_comment_count** — Maintains comment count on trophy_posts

---

*Generated: 2026-01-23*

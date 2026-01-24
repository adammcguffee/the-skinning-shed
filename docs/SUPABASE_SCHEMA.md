# Supabase Schema — The Skinning Shed

> Last updated: January 24, 2026
> MVP database schema with RLS enabled on all tables.

## Tables Overview

| Table | Purpose | RLS | Rows |
|-------|---------|-----|------|
| `profiles` | User identity / Trophy Wall | ✅ | 1 |
| `species_master` | Controlled species taxonomy | ✅ | 42 |
| `trophy_posts` | Core harvest records | ✅ | 3 |
| `trophy_photos` | Multiple photos per trophy | ✅ | 0 |
| `weather_snapshots` | Historical weather at harvest | ✅ | 0 |
| `moon_snapshots` | Moon phase at harvest | ✅ | 0 |
| `analytics_buckets` | Denormalized research data | ✅ | 0 |
| `weather_favorite_locations` | User's favorite weather locations | ✅ | 0 |
| `land_listings` | Land for lease/sale | ✅ | 0 |
| `land_photos` | Land listing photos | ✅ | 0 |
| `swap_shop_listings` | BST classifieds | ✅ | 0 |
| `swap_shop_photos` | Swap shop photos | ✅ | 0 |
| `comments` | Trophy comments (legacy) | ✅ | 0 |
| `post_comments` | Trophy comments (new) | ✅ | 0 |
| `reactions` | Respect / Well-earned reactions | ✅ | 0 |
| `post_likes` | Simple like system | ✅ | 0 |
| `follows` | User follow relationships | ✅ | 0 |
| `content_reports` | Content moderation reports | ✅ | 0 |
| `moderation_reports` | User reports (legacy) | ✅ | 0 |
| `conversations` | DM conversation containers | ✅ | 0 |
| `conversation_members` | DM participants + read state | ✅ | 0 |
| `messages` | DM message content | ✅ | 0 |
| `state_regulations_sources` | Regulation source URLs | ✅ | 18 |
| `state_regulations_approved` | Verified regulation data | ✅ | 0 |
| `state_regulations_pending` | Pending regulation updates | ✅ | 0 |
| `ad_slots` | Advertising slot configuration | ✅ | 1 |

---

## Storage Buckets

| Bucket | Purpose | Public | Size Limit |
|--------|---------|--------|------------|
| `avatars` | User profile photos | ✅ | 5MB |
| `trophy_photos` | Trophy images | ✅ | 10MB |
| `land_photos` | Land listing images | ✅ | 10MB |
| `swap_shop_photos` | Swap shop images | ✅ | 10MB |
| `ad_share` | Advertising creatives | ✅ | 5MB |

### Storage Path Conventions

```
avatars/{user_id}/avatar.{ext}
trophy_photos/{user_id}/{trophy_id}/{filename}
land_photos/{user_id}/{listing_id}/{filename}
swap_shop_photos/{user_id}/{listing_id}/{filename}
ad_share/{page}/{position}.png
```

---

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
| `is_admin` | BOOLEAN | Admin flag |
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
| `state` | TEXT | State name |
| `state_code` | TEXT | 2-letter code |
| `county` | TEXT | County name |
| `county_fips` | TEXT | 5-digit FIPS |
| `harvest_date` | DATE | **User-entered** |
| `harvest_time` | TIME | Exact time (optional) |
| `harvest_time_bucket` | time_bucket | Morning/Midday/Evening |
| `posted_at` | TIMESTAMPTZ | **System timestamp** |
| `story` | TEXT | User's story |
| `private_notes` | TEXT | Owner-only notes |
| `stats_json` | JSONB | Species-specific stats |
| `cover_photo_path` | TEXT | Primary photo |
| `weather_source` | TEXT | auto/user/mixed |
| `weather_edited` | BOOLEAN | User modified weather |
| `likes_count` | INT | Denormalized count |
| `comments_count` | INT | Denormalized count |

### weather_snapshots

Historical weather at harvest time.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | |
| `post_id` | UUID (FK, unique) | → trophy_posts.id |
| `source` | TEXT | API source |
| `is_hourly` | BOOLEAN | Hourly vs daily data |
| `snapshot_time` | TIMESTAMPTZ | Weather timestamp |
| `temp_f` | NUMERIC | Temperature °F |
| `temp_c` | NUMERIC | Temperature °C |
| `feels_like_f` | NUMERIC | Feels like °F |
| `wind_speed` | NUMERIC | Wind speed mph |
| `wind_gust` | NUMERIC | Wind gust mph |
| `wind_dir_deg` | INT | Wind direction degrees |
| `wind_dir_text` | TEXT | N/NE/E/SE/S/SW/W/NW |
| `pressure_hpa` | NUMERIC | Pressure hPa |
| `pressure_inhg` | NUMERIC | Pressure inHg |
| `humidity_pct` | NUMERIC | Humidity % |
| `precip_mm` | NUMERIC | Precipitation mm |
| `cloud_pct` | NUMERIC | Cloud cover % |
| `condition_text` | TEXT | Weather description |
| `condition_code` | TEXT | WMO code |
| `raw_json` | JSONB | Full API response |

### moon_snapshots

Moon phase at harvest time.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | |
| `post_id` | UUID (FK, unique) | → trophy_posts.id |
| `phase_name` | TEXT | Full Moon, New Moon, etc. |
| `phase_number` | INT | 0-7 (0=new, 4=full) |
| `illumination_pct` | NUMERIC | Illumination % |
| `is_waxing` | BOOLEAN | Waxing vs waning |
| `raw_json` | JSONB | Full API response |

### conversations (DM System)

Direct message conversation containers.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | Updated on new message |

### conversation_members

DM participants and read state.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | |
| `conversation_id` | UUID (FK) | → conversations.id |
| `user_id` | UUID (FK) | → auth.users.id |
| `joined_at` | TIMESTAMPTZ | |
| `last_read_at` | TIMESTAMPTZ | For unread calculation |

UNIQUE(conversation_id, user_id)

### messages

DM message content.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | |
| `conversation_id` | UUID (FK) | → conversations.id |
| `sender_id` | UUID (FK) | → auth.users.id |
| `body` | TEXT | Message text (1-5000 chars) |
| `subject_type` | TEXT | swap/land/trophy (optional) |
| `subject_id` | UUID | Reference ID (optional) |
| `subject_title` | TEXT | Cached title (optional) |
| `created_at` | TIMESTAMPTZ | |

### follows

User follow relationships.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | |
| `follower_id` | UUID (FK) | → profiles.id |
| `following_id` | UUID (FK) | → profiles.id |
| `created_at` | TIMESTAMPTZ | |

UNIQUE(follower_id, following_id)

### post_likes

Simple like system.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | |
| `post_id` | UUID (FK) | → trophy_posts.id |
| `user_id` | UUID (FK) | → auth.users.id |
| `created_at` | TIMESTAMPTZ | |

UNIQUE(post_id, user_id)

### post_comments

Trophy post comments.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | |
| `post_id` | UUID (FK) | → trophy_posts.id |
| `user_id` | UUID (FK) | → auth.users.id |
| `body` | TEXT | Comment text (1-2000 chars) |
| `created_at` | TIMESTAMPTZ | |

### state_regulations_sources

Official regulation source URLs.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | |
| `state_code` | TEXT | 2-letter state |
| `category` | TEXT | deer/turkey/fishing |
| `source_url` | TEXT | Official URL |
| `source_name` | TEXT | Agency name |
| `last_checked_at` | TIMESTAMPTZ | Last sync |
| `content_hash` | TEXT | For change detection |

### state_regulations_approved

Verified regulation data.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | |
| `state_code` | CHAR(2) | |
| `category` | TEXT | deer/turkey/fishing |
| `season_year_label` | TEXT | "2025-2026" |
| `year_start` | INT | |
| `year_end` | INT | |
| `summary` | JSONB | Structured reg data |
| `source_url` | TEXT | |
| `approved_at` | TIMESTAMPTZ | |
| `approved_by` | UUID (FK) | → profiles.id |

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

### post_comments, post_likes
- ✅ Readable on public posts
- ✅ Insertable by authenticated users
- ✅ Deletable by owner

### follows
- ✅ Public read (for counts)
- ✅ Users can follow/unfollow (insert/delete own rows)

### conversations
- ✅ SELECT: only members can view

### conversation_members
- ✅ SELECT: only members can view
- ✅ UPDATE: only own membership (last_read_at)

### messages
- ✅ SELECT: only members can view
- ✅ INSERT: must be sender AND member

### moderation_reports, content_reports
- ✅ Users can create reports
- ✅ Users can view their own reports

### weather_favorite_locations
- ✅ Users can CRUD their own favorites

### Storage (all buckets)
- ✅ Public read
- ✅ Write only to user's own folder

---

## RPC Functions

### Messaging (SECURITY DEFINER, authenticated only)

| Function | Returns | Description |
|----------|---------|-------------|
| `get_or_create_dm(other_user_id, subject_type?, subject_id?, subject_title?, initial_message?)` | JSONB | Find/create 1:1 DM, optionally send first message |
| `get_inbox()` | TABLE | All conversations with last message, unread count |
| `get_unread_count()` | INT | Total unread messages |
| `mark_conversation_read(conversation_id)` | BOOLEAN | Update last_read_at |

### Research Analytics

| Function | Returns | Description |
|----------|---------|-------------|
| `get_pattern_data(...)` | TABLE | Aggregated pattern analytics |
| `get_top_insights(...)` | TABLE | Top performing conditions |

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
| 20260123034148 | fix_function_search_paths |
| 20260123215319 | add_weather_enrichment_columns |
| 20260123220619 | add_county_fips_columns |
| 20260123225057 | add_weather_snapshot_columns |
| 20260123225115 | add_moon_snapshot_columns |
| 20260123231530 | create_ad_slots_table |
| 20260124003945 | create_weather_favorite_locations |
| 20260124040052 | add_condition_to_swap_shop_listings |
| 20260124040124 | create_follows_table |
| 20260124043248 | add_is_admin_to_profiles |
| 20260124043300 | create_regulations_tables_v2 |
| 20260124043742 | create_research_rpc_functions |
| 20260124142239 | create_social_tables |
| 20260124142602 | seed_regulation_sources |
| 20260124143204 | create_dm_messaging_system |
| 20260124144908 | secure_messaging_rpcs |
| 20260124144921 | secure_messaging_rpcs_v2 |

---

## Database Triggers

1. **profiles_updated_at** — Updates `updated_at` on profile changes
2. **trophy_posts_updated_at** — Updates `updated_at` on post changes
3. **land_listings_updated_at** — Updates `updated_at` on listing changes
4. **swap_shop_updated_at** — Updates `updated_at` on listing changes
5. **on_auth_user_created** — Auto-creates profile on signup
6. **update_reaction_count** — Maintains reaction count on trophy_posts
7. **update_comment_count** — Maintains comment count on trophy_posts
8. **update_conversation_timestamp** — Updates conversation.updated_at on new message
9. **increment_likes_count** / **decrement_likes_count** — Maintains likes_count
10. **increment_comments_count** / **decrement_comments_count** — Maintains comments_count

---

## Edge Functions

| Function | Purpose |
|----------|---------|
| `regulations-check` | Fetch and parse state regulation PDFs, populate pending table |

---

*Generated: January 24, 2026*

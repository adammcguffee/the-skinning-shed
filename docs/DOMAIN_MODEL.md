# Domain Model — The Skinning Shed

> Entity definitions and relationships for MVP.

## Entity Relationship Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              THE SKINNING SHED                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────┐        ┌──────────────┐        ┌────────────────┐             │
│  │ profiles │◄───────│ trophy_posts │───────►│ trophy_photos  │             │
│  └────┬─────┘        └──────┬───────┘        └────────────────┘             │
│       │                     │                                                │
│       │              ┌──────┴───────┐                                       │
│       │              │              │                                       │
│       │    ┌─────────▼────┐  ┌──────▼────────┐                              │
│       │    │ weather_     │  │ moon_         │                              │
│       │    │ snapshots    │  │ snapshots     │                              │
│       │    └──────────────┘  └───────────────┘                              │
│       │                                                                      │
│       │              ┌───────────────┐                                      │
│       │              │ analytics_    │                                      │
│       │              │ buckets       │                                      │
│       │              └───────────────┘                                      │
│       │                                                                      │
│       │        ┌───────────────┐        ┌──────────────────┐                │
│       ├───────►│ land_listings │───────►│ land_photos      │                │
│       │        └───────────────┘        └──────────────────┘                │
│       │                                                                      │
│       │        ┌───────────────────┐    ┌──────────────────┐                │
│       ├───────►│ swap_shop_listings│───►│ swap_shop_photos │                │
│       │        └───────────────────┘    └──────────────────┘                │
│       │                                                                      │
│       │        ┌──────────┐      ┌────────────┐                             │
│       ├───────►│ comments │      │ reactions  │◄─────────────┐              │
│       │        └──────────┘      └────────────┘              │              │
│       │                                                       │              │
│       │        ┌────────────────────┐                        │              │
│       └───────►│ moderation_reports │                        │              │
│                └────────────────────┘                        │              │
│                                                               │              │
│  ┌────────────────┐                                          │              │
│  │ species_master │◄─────────────────────────────────────────┘              │
│  └────────────────┘                                                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Core Entities

### profiles
The user identity and Trophy Wall configuration.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid (PK) | = auth.users.id |
| `username` | text (unique, nullable) | Display username |
| `display_name` | text | Friendly display name |
| `avatar_path` | text | Storage path to avatar |
| `bio` | text | Optional bio text |
| `created_at` | timestamptz | Account creation |
| `updated_at` | timestamptz | Last profile update |

### trophy_posts
Core trophy/harvest records.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid (PK) | Unique trophy ID |
| `user_id` | uuid (FK → profiles) | Owner |
| `visibility` | enum | public, private, followers_only (future) |
| `category` | enum | deer, turkey, bass, other_game, other_fishing |
| `species_id` | uuid (FK → species_master) | Species reference |
| `custom_species_name` | text (nullable) | When "Other (specify)" |
| `state` | text | US state code/name |
| `county` | text | County name |
| `harvest_date` | date | **User-entered** harvest date |
| `harvest_time` | time (nullable) | Exact time if known |
| `harvest_time_bucket` | enum (nullable) | morning, midday, evening, night |
| `posted_at` | timestamptz | **System** timestamp |
| `story` | text | User's story/description |
| `private_notes` | text | Private journal notes (owner-only) |
| `stats_json` | jsonb | Species-specific structured stats |
| `cover_photo_path` | text | Primary photo storage path |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |

**Note:** `harvest_date`/`harvest_time` is user-entered. `posted_at` is system-generated. Never conflate these.

### trophy_photos
Multiple photos per trophy.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid (PK) | |
| `post_id` | uuid (FK → trophy_posts) | Parent trophy |
| `storage_path` | text | Path in storage bucket |
| `sort_order` | int | Display order |
| `created_at` | timestamptz | |

### species_master
Controlled species taxonomy.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid (PK) | |
| `category` | enum | game, fish |
| `subcategory` | text | deer, turkey, bass, other_game, other_fishing |
| `common_name` | text | Display name |
| `scientific_name` | text (nullable) | Latin name |
| `regions` | text[] (nullable) | State codes where found |
| `is_active` | boolean | Enabled for selection |
| `sort_order` | int | Display order |
| `created_at` | timestamptz | |

---

## Weather & Research Entities

### weather_snapshots
Historical weather at harvest time (privacy-safe).

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid (PK) | |
| `post_id` | uuid (FK → trophy_posts, unique) | One per trophy |
| `source` | text | Weather provider name |
| `is_hourly` | boolean | Hourly vs daily data |
| `snapshot_time` | timestamptz | Aligned to harvest |
| `temp_f` | numeric | Temperature (Fahrenheit) |
| `temp_c` | numeric | Temperature (Celsius) |
| `wind_speed` | numeric | Wind speed (mph) |
| `wind_gust` | numeric (nullable) | Gust speed |
| `wind_dir_deg` | int | Direction in degrees |
| `pressure_hpa` | numeric (nullable) | Barometric pressure |
| `humidity_pct` | numeric (nullable) | Humidity percentage |
| `precip_mm` | numeric (nullable) | Precipitation |
| `cloud_pct` | numeric (nullable) | Cloud cover |
| `raw_json` | jsonb | Full API response |
| `created_at` | timestamptz | |

### moon_snapshots
Moon phase at harvest.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid (PK) | |
| `post_id` | uuid (FK → trophy_posts, unique) | One per trophy |
| `phase_name` | text | new, waxing_crescent, first_quarter, etc. |
| `illumination_pct` | numeric | 0-100 |
| `raw_json` | jsonb | Full API response |
| `created_at` | timestamptz | |

### analytics_buckets
Denormalized for fast research queries.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid (PK) | |
| `post_id` | uuid (FK → trophy_posts, unique) | |
| `state` | text | |
| `county` | text | |
| `category` | enum | deer, turkey, bass, other |
| `season_year` | int | Hunting/fishing season year |
| `dow` | int | Day of week (0-6) |
| `tod_bucket` | enum | morning, midday, evening, night, unknown |
| `temp_bucket` | text | e.g., "60-70" |
| `pressure_bucket` | text | e.g., "rising", "falling", "steady" |
| `moon_phase_bucket` | text | e.g., "new", "full", "quarter" |
| `wind_dir_bucket` | text | N, NE, E, SE, S, SW, W, NW, VAR |
| `created_at` | timestamptz | |

---

## Land Module Entities

### land_listings
Property for lease or sale.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid (PK) | |
| `user_id` | uuid (FK → profiles) | Owner |
| `type` | enum | lease, sale |
| `state` | text | |
| `county` | text | |
| `acreage` | numeric | Property size |
| `price_total` | numeric (nullable) | Total price |
| `price_per_acre` | numeric (nullable) | Price per acre |
| `description` | text | Listing description |
| `species_tags` | text[] | Game present (deer, turkey, etc.) |
| `contact_method` | enum | email, phone, external_link |
| `contact_value` | text | Email/phone/URL |
| `status` | enum | active, inactive, expired, removed |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |
| `expires_at` | timestamptz | Auto-expiration |

### land_photos
Photos for land listings.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid (PK) | |
| `listing_id` | uuid (FK → land_listings) | |
| `storage_path` | text | |
| `sort_order` | int | |
| `created_at` | timestamptz | |

---

## Swap Shop Entities

### swap_shop_listings
Buy/Sell/Trade classifieds.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid (PK) | |
| `user_id` | uuid (FK → profiles) | |
| `category` | text | Equipment category |
| `state` | text | |
| `county` | text (nullable) | |
| `price` | numeric (nullable) | Asking price |
| `title` | text | Listing title |
| `description` | text | |
| `contact_method` | enum | email, phone |
| `contact_value` | text | |
| `status` | enum | active, expired, removed |
| `expires_at` | timestamptz | Auto-expiration |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |

### swap_shop_photos
Photos for swap shop listings.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid (PK) | |
| `listing_id` | uuid (FK → swap_shop_listings) | |
| `storage_path` | text | |
| `sort_order` | int | |
| `created_at` | timestamptz | |

---

## Social Entities

### comments
Comments on trophies (optional MVP).

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid (PK) | |
| `post_id` | uuid (FK → trophy_posts) | |
| `user_id` | uuid (FK → profiles) | |
| `body` | text | Comment text |
| `created_at` | timestamptz | |

### reactions
Respect / Well-earned reactions.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid (PK) | |
| `post_id` | uuid (FK → trophy_posts) | |
| `user_id` | uuid (FK → profiles) | |
| `type` | enum | respect, well_earned |
| `created_at` | timestamptz | |

**Constraint:** Unique on (post_id, user_id, type)

---

## Moderation Entities

### moderation_reports
User-submitted reports.

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid (PK) | |
| `reporter_user_id` | uuid (FK → profiles) | |
| `target_type` | enum | post, listing, comment, user |
| `target_id` | uuid | ID of reported item |
| `reason` | text | Report reason |
| `details` | text | Additional details |
| `status` | enum | open, reviewed, closed |
| `created_at` | timestamptz | |
| `resolved_at` | timestamptz (nullable) | |
| `resolved_by` | uuid (nullable) | Admin who resolved |

---

## Enums Summary

| Enum | Values |
|------|--------|
| visibility | public, private, followers_only |
| category | deer, turkey, bass, other_game, other_fishing |
| species_category | game, fish |
| time_bucket | morning, midday, evening, night |
| land_type | lease, sale |
| contact_method | email, phone, external_link |
| listing_status | active, inactive, expired, removed |
| reaction_type | respect, well_earned |
| report_target | post, listing, comment, user |
| report_status | open, reviewed, closed |
| wind_direction | N, NE, E, SE, S, SW, W, NW, VAR |

---

*Derived from: docs/blueprint/The_Skinning_Shed_Blueprint_Pack_v1.zip*

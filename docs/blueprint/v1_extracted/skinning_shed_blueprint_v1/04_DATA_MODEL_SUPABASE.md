# 04 — Data Model (Supabase/Postgres) — MVP Schema Blueprint

> This is a blueprint; Cursor can implement via SQL migrations.

## Core Entities

### profiles
- id (uuid, PK) = auth.users.id
- username (unique, nullable)
- display_name
- avatar_path (storage)
- created_at

### trophy_posts
- id (uuid, PK)
- user_id (uuid, FK -> profiles.id)
- visibility (enum: public, private, followers_only?)  [followers optional later]
- category (enum: deer, turkey, bass, other_game, other_fishing)
- species_id (FK -> species_master)  [required for other_*; for deer/turkey/bass can be implied]
- custom_species_name (text nullable) [when “Other (specify)”]
- state (text or US state code)
- county (text)
- harvest_date (date, required)
- harvest_time (time nullable)
- harvest_time_bucket (enum nullable: morning, midday, evening) [used when time unknown]
- posted_at (timestamptz default now())
- story (text)
- private_notes (text, private only; not exposed publicly)
- stats_json (jsonb)  [species-specific structured stats]
- cover_photo_path (text)
- created_at, updated_at

### trophy_photos
- id
- post_id FK trophy_posts
- storage_path
- sort_order
- created_at

### weather_snapshots
- id
- post_id FK trophy_posts (unique)
- source (text)  [provider]
- is_hourly (bool)
- snapshot_time (timestamptz)  [aligned to harvest time or approximated]
- temp_c / temp_f
- wind_speed
- wind_gust
- wind_dir_deg
- pressure_hpa (nullable)
- precip_mm (nullable)
- cloud_pct (nullable)
- raw_json (jsonb)
- created_at

### moon_snapshots
- id
- post_id FK trophy_posts (unique)
- phase_name (text)
- illumination_pct (numeric)
- raw_json
- created_at

### analytics_buckets (denormalized for fast research queries)
- id
- post_id FK trophy_posts (unique)
- state
- county
- category (deer/turkey/bass/other)
- season_year (int)
- dow (0-6)
- tod_bucket (morning/midday/evening/night/unknown)
- temp_bucket (text)
- pressure_bucket (text)
- moon_phase_bucket (text)
- wind_dir_bucket (N/NE/E/SE/S/SW/W/NW/VAR)
- created_at

### land_listings
- id
- user_id
- type (enum: lease, sale)
- state
- county
- acreage
- price_total (numeric) OR price_per_acre (numeric)
- description
- species_tags (text[])
- photos (separate table like listing_photos)
- contact_method (enum: email, phone, external_link)
- contact_value (text)
- status (active, inactive, expired)
- created_at, updated_at, expires_at

### swap_shop_listings
- id
- user_id
- category (enum/text)
- state
- county
- price (numeric nullable)
- title
- description
- contact_method + contact_value
- status (active/expired/removed)
- expires_at (auto)
- created_at, updated_at

### moderation_reports
- id
- reporter_user_id
- target_type (post, listing, comment, user)
- target_id
- reason
- details
- status (open/closed)
- created_at

### comments (optional MVP; can be phased)
- id
- post_id
- user_id
- body
- created_at

### reactions (Respect / Well-earned)
- id
- post_id
- user_id
- type (enum: respect, well_earned)
- created_at

## Species Master List (Controlled)
### species_master
- id
- category (game/fish)
- common_name
- scientific_name (nullable)
- regions (text[] nullable)  [state codes]
- is_active
- created_at

**Rule:** Always include “Other (specify)” fallback in UI; store custom_species_name for rare cases.

## RLS & Storage (High-level)
- Users can CRUD their own posts/photos/listings.
- Public can read public posts and photos.
- Private posts readable only by owner.
- Research dashboard reads from aggregated/bucketed tables with threshold logic enforced server-side (RPC/edge function) where needed.

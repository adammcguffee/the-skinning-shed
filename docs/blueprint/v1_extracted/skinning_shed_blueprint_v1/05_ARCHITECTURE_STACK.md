# 05 — Architecture & Tech Stack (Recommended)

## Recommended Stack (fits Web+iOS+Android + Supabase)
- **Flutter** (single codebase for iOS/Android/Web)
- **Supabase** (Auth + Postgres + Storage + Edge Functions)
- Optional: Supabase Realtime for live feed updates (later)

## Core Architecture
- Client app (Flutter):
  - Feature modules: trophies, trophy_wall, explore, tools(weather/activity/research), land, swap_shop, auth, moderation
  - Offline-friendly caching for lists & filters
  - Image upload pipeline with compression and retry
- Backend (Supabase):
  - Postgres schema + RLS policies
  - Storage buckets:
    - trophy_photos
    - land_photos
    - swap_shop_photos
    - avatars
  - Edge functions / cron jobs:
    - attach_weather_snapshot(post_id)
    - attach_moon_snapshot(post_id)
    - build_analytics_buckets(post_id)
    - expire_listings (swap shop / land)
    - research aggregation RPCs (threshold + rollup)

## Key Implementation Notes
- Weather & moon data:
  - Use a provider that supports **historical** queries.
  - Never store or show exact coordinates publicly.
  - Use county centroid/nearest city behind the scenes for snapshots.
- Research dashboard performance:
  - Precompute buckets into analytics_buckets for fast grouping.
  - Use thresholds (N-min posts) for county views.

## Performance Requirements
- CDN-backed image delivery (Supabase storage + caching headers)
- Feed pagination and thumbnailing
- Skeleton loaders and smooth scroll
- Avoid heavy client-side joins; use views/RPC for complex queries

## Security Requirements
- Strict RLS on all user-owned tables
- Signed URLs where appropriate
- Moderation endpoints restricted to admin role

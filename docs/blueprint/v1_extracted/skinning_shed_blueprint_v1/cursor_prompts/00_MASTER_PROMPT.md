# Cursor Master Prompt — The Skinning Shed (Paste into Cursor)

You are Cursor working inside a Git repo. Build **The Skinning Shed** as a production-ready MVP (no throwaway v1). The app must support **Web + iOS + Android** from day one using a **shared codebase** (Flutter recommended) and Supabase backend. You have MCP access to Supabase.

## Non-Negotiables (Do Not Drift)
- Premium modern UI/UX, fast and simple navigation.
- Outdoors “modern lodge” vibe; muted palette; **no neon/futuristic colors**.
- NOT business/SaaS/fintech look.
- Privacy-first: **no GPS pins**, no public exact coordinates.
- Mapping/waypoints are explicitly **out of MVP**.
- Canonical terms:
  - User page is called **Trophy Wall**
  - BST is **The Swap Shop** (discovery-only; no payments)
- Modern searchable dropdowns for state/county/species/filters everywhere.
- Separate “Harvested at” (user-entered) from “Posted at” (system). Never infer harvest time from upload time.

## Modules (Frozen MVP)
1) Trophy platform:
   - Deer, Turkey, Bass (first-class)
   - Other Game + Other Fishing (species dropdown required, master list + Other specify)
   - Trophy Wall (season grouping)
   - Feed + Explore
2) Weather tab:
   - current + forecast + wind direction
   - attach historical weather snapshot to trophy posts based on harvest time/date & county (privacy safe)
3) Activity/Feeding Times:
   - calendar-style windows, guidance not guarantees
4) Research/Patterns:
   - State required; optional County drill-down (All counties vs one county)
   - charts of counts by pressure/temp/moon/wind/day/time/season
   - thresholds + rollups for privacy
5) Land:
   - Lease + Sale, filters, photos, contact, disclaimers
6) Swap Shop:
   - classifieds with filters, photos, contact, auto-expire, disclaimers
7) Moderation:
   - report content, admin remove/ban (basic)

## Backend (Supabase)
- Design and apply Postgres schema + RLS.
- Create Storage buckets and policies for photos.
- Implement edge functions/cron jobs:
  - attach_weather_snapshot(post_id)
  - attach_moon_snapshot(post_id)
  - build_analytics_buckets(post_id)
  - expire_listings
  - research queries with threshold logic (RPC)

## Execution Rules
- Work in vertical slices and keep the app always buildable.
- After each major step:
  - run builds/tests
  - `git status`
  - commit with message
  - push to origin/main
  - write/update docs/CHECKPOINTS.md with what changed and how to verify

## Deliverables
- A working app with premium UI and the modules above.
- A `docs/` folder containing:
  - ARCH.md (architecture)
  - DATA_MODEL.md
  - RLS_POLICIES.md
  - BUILD_AND_RUN.md
  - CHECKPOINTS.md
  - PRODUCT_RULES.md (the non-negotiables)
- A seed dataset for species_master and some demo content.
- Smoke test script or checklist.

## Start Now
1) Initialize Flutter project and connect Supabase.
2) Build the app shell + theme + navigation.
3) Implement Auth + profiles.
4) Implement Trophy posting + photo uploads + Feed + Trophy Wall.
Proceed through all modules in the frozen list.

Before you begin coding, print a concise plan of the first 10 steps and the repo structure you will create.

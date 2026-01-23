# 06 — Build Plan (No-Rework Execution Order)

> Goal: get a production-grade MVP without rework. Build vertical slices; keep quality high.

## Phase 0 — Repo + Rules + CI
- Initialize repo (Flutter)
- Add Cursor project rules
- Add formatting/linting
- Add GitHub Actions build checks (web + iOS + android) if desired

## Phase 1 — Auth + Identity + Base UI Shell
- Supabase Auth
- profiles table + RLS
- App shell: navigation, theme, component library

## Phase 2 — Trophy Posting + Trophy Wall (Core loop)
- Post creation wizard (Trophy vs Land vs Swap Shop)
- Trophy post create/edit/delete
- Photo upload
- Trophy Wall view (by season, by species)
- Feed list

## Phase 3 — Explore + Filters (premium UX)
- State/county dropdowns (modern searchable)
- Explore hubs for deer/turkey/bass/other
- County pages (optional MVP)

## Phase 4 — Weather + Historical Snapshots
- Weather tab
- On trophy post: attach historical snapshot from harvest time/date
- Display “Harvested vs Posted” clearly; show “approx conditions” labels

## Phase 5 — Activity / Feeding Times
- Calendar views for deer/turkey/fishing times
- Inputs: sunrise/sunset, moon phase, weather snapshot (basic)
- Disclaimers

## Phase 6 — Research / Patterns
- State → optional County drill-down
- Charts/panels from analytics_buckets
- Threshold logic + rollups

## Phase 7 — Land Listings
- Lease + Sale listing flows
- Filters: state/county/price/acreage/species tags
- Photos + contact

## Phase 8 — Swap Shop
- Listing flows + categories
- Filters + expire listings + disclaimers
- Moderation/report

## Phase 9 — Polish & Launch Readiness
- Empty/loading/error states
- Moderation tools
- Performance tuning
- App store metadata + privacy policy + terms

# 02 — Features & Modules (Frozen MVP Scope)

## A) Trophy Platform (Core)

### First-class species sections (custom stats, leaderboards, research support)
- **Deer**
- **Turkey**
- **Largemouth Bass**

### Flexible sections (generic but structured; future promotion-ready)
- **Other Game** (species dropdown required)
- **Other Fishing** (species dropdown required)

### Trophy Post fields
**Required**
- Species (first-class or other)
- State
- County
- Harvest date

**Optional / encouraged**
- Harvest time (or time bucket: Morning/Midday/Evening)
- Photos (1–10+)
- Story/summary
- Stats by species (examples):
  - Deer: score, weapon, distance, season, etc.
  - Turkey: beard/spurs/weight, call used, distance
  - Bass: weight/length, bait/lure, water body name, depth, water temp (optional)
- Visibility: Public / Followers-only (optional later) / Private (journal)

**Always store separately**
- Harvested_at (user-entered)
- Posted_at (system)

## B) Trophy Wall (User Page)
- Canonical term: **Trophy Wall**
- Seasons grouping (e.g., “2025 Deer Season”)
- Private “notes to self” per trophy (private by default)
- Clean stats summary (optional)

## C) Feed & Explore
- Feed: latest trophies, fast filters, clean cards, big images.
- Explore: species hubs, state/county browsing, leaderboards, discovery shortcuts.

## D) Weather Tab (Privacy-safe)
- Current conditions + forecast
- Wind speed + **wind direction**
- Optional later: pressure trends, severe alerts (not MVP)

### Historical conditions attachment (automatic)
Attach weather snapshot based on:
- Harvest date/time (preferred) OR date-only (daily summary) OR time bucket
- Coarse location derived from county (centroid/nearest major city)

## E) Activity / Feeding Times
Calendar-style “Good/Better/Best” windows for:
- Deer
- Turkey
- Fishing “best times”
Inputs: time-of-day, season, weather, wind, pressure, moon phase, sunrise/sunset.
**Disclaimer:** guidance/patterns, not guarantees.

## F) Research / Patterns Dashboard (State → County)
- State required; County optional (All counties vs specific county)
- Panels: counts by pressure buckets, temp ranges, wind direction, moon phase, day-of-week, time-of-day, season/week-of-season.
- Minimum thresholds + rollups to protect privacy and avoid misleading tiny samples.

## G) Land Module (First-class)
- Land for Lease
- Land for Sale
Filters: state, county, price range, acreage, species present.
Discovery only: no payments/contracts handled by the platform.

## H) The Swap Shop (BST classifieds)
- Canonical name: **The Swap Shop**
- Discovery-only listings: category, state/county, price optional, photos, description, contact method.
- No payments or transaction handling; clear disclaimers; listings auto-expire.
- Basic moderation: report, remove, block.

## I) Moderation & Safety
- Report content/listing
- Hide user
- Admin tools (remove posts/listings, ban users)
- Clear community guidelines shown in-app.

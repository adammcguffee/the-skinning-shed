# MVP Scope — The Skinning Shed

> Derived from Blueprint Pack v1. This document defines what is IN and OUT of MVP.

## MVP Philosophy

- **No v1 / no rework:** First public release must be production-quality
- **High-tech operation:** Fast, smooth, engineered
- **Premium design:** Outdoors "modern lodge" vibe; no neon/flashy colors
- **Privacy-first:** No GPS pins; no public exact coordinates

---

## ✅ IN SCOPE (MVP)

### A) Trophy Platform (Core)

#### First-Class Species (Rich Stats + Leaderboards)
- **Deer** — score, weapon, distance, season, etc.
- **Turkey** — beard/spurs/weight, call used, distance
- **Largemouth Bass** — weight/length, bait/lure, water body name, depth, water temp

#### Flexible Species
- **Other Game** — species dropdown required, controlled list + "Other (specify)"
- **Other Fishing** — species dropdown required, controlled list + "Other (specify)"

#### Trophy Post Fields
| Required | Optional/Encouraged |
|----------|---------------------|
| Species | Harvest time (or bucket: Morning/Midday/Evening) |
| State | Photos (1-10+) |
| County | Story/summary |
| Harvest date | Species-specific stats |
| | Visibility: Public/Private |

#### Always Store Separately
- `harvested_at` (user-entered)
- `posted_at` (system timestamp)

### B) Trophy Wall (User Page)
- ✅ Canonical term: **Trophy Wall**
- ✅ Seasons grouping (e.g., "2025 Deer Season")
- ✅ Private "notes to self" per trophy
- ✅ Clean stats summary

### C) Feed & Explore
- ✅ Feed: Latest trophies, fast filters, clean cards, big images
- ✅ Explore: Species hubs, state/county browsing, leaderboards, discovery

### D) Weather Tab (Privacy-Safe)
- ✅ Current conditions + forecast
- ✅ Wind speed + **wind direction**
- ✅ Historical weather attachment to trophies (based on harvest date/time, coarse location)
- ❌ Severe alerts (future)

### E) Activity / Feeding Times
- ✅ Calendar-style "Good/Better/Best" windows
- ✅ For: Deer, Turkey, Fishing
- ✅ Inputs: time-of-day, season, weather, wind, pressure, moon phase, sunrise/sunset
- ✅ **Disclaimer:** guidance/patterns, not guarantees

### F) Research / Patterns Dashboard
- ✅ State required; County optional (All counties vs specific)
- ✅ Panels: counts by pressure, temp, wind direction, moon phase, day-of-week, time-of-day, season
- ✅ Minimum thresholds + rollups for privacy

### G) Land Module (First-Class)
- ✅ Land for Lease
- ✅ Land for Sale
- ✅ Filters: state, county, price range, acreage, species present
- ✅ Discovery only (no payments/contracts)

### H) The Swap Shop (BST Classifieds)
- ✅ Canonical name: **The Swap Shop**
- ✅ Category, state/county, price (optional), photos, description, contact
- ✅ No payments or transaction handling
- ✅ Clear disclaimers; auto-expire listings
- ✅ Basic moderation: report, remove, block

### I) Moderation & Safety
- ✅ Report content/listing
- ✅ Hide user
- ✅ Admin tools (remove posts/listings, ban users)
- ✅ Community guidelines shown in-app

---

## ❌ OUT OF SCOPE (MVP)

| Feature | Status | Notes |
|---------|--------|-------|
| GPS mapping / waypoints | **DEFERRED** | onX/HuntStand-like features come later after traction |
| Payments / escrow | **DEFERRED** | No transaction handling |
| DMs / messaging | **DEFERRED** | Optional future feature |
| Property boundary layers | **DEFERRED** | Requires licensed data |
| Severe weather alerts | **DEFERRED** | Future enhancement |
| Followers-only visibility | **DEFERRED** | Public and Private first |

---

## Platforms (Locked)

- ✅ **Web** — from day one
- ✅ **iOS** — from day one
- ✅ **Android** — from day one
- ✅ Shared codebase (Flutter)

---

## Key Terms (Canonical)

| Term | Definition |
|------|------------|
| Trophy Wall | User's personal page showing their trophies |
| The Swap Shop | Buy/Sell/Trade classifieds section |
| Harvested | User-entered date/time of harvest |
| Posted | System timestamp when trophy was uploaded |

---

*Derived from: docs/blueprint/The_Skinning_Shed_Blueprint_Pack_v1.zip*

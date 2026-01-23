# UI/UX Standards — The Skinning Shed

> "Apple-level polish" but outdoors-themed.

## Design Philosophy

### What We Are
- ✅ Premium, modern, high-tech function
- ✅ Calm, timeless, professional
- ✅ Outdoors "modern lodge" vibe
- ✅ Fast, thumb-friendly, minimal taps
- ✅ Photos are the hero; UI is the frame

### What We Are NOT
- ❌ Neon/futuristic accents
- ❌ Business/SaaS/fintech look
- ❌ Cheesy camo backgrounds
- ❌ Antler borders
- ❌ Distressed body fonts
- ❌ Cluttered interfaces

---

## Color Palette (Modern Lodge)

### Primary Colors
| Name | Use |
|------|-----|
| Forest | Primary backgrounds, headers |
| Charcoal | Text, icons |
| Bone/Cream | Light backgrounds, cards |
| Muted Earth | Accents (olive, tan, rust) |

### Avoid
- Bright neon colors
- Pure black backgrounds
- Overly saturated colors
- Blue/purple tech colors

---

## Navigation Structure

### Main Navigation (≤5 items)
| Tab | Content |
|-----|---------|
| Feed | Latest trophies, main timeline |
| Explore | Species hubs, state/county browsing, discovery |
| Post | Center primary action (+ button) |
| Tools | Weather, Activity/Feeding Times, Research |
| Trophy Wall | User's personal page |

### Secondary Access
- **Land** (Lease/Sale) — In Explore or Tools
- **Swap Shop** — In Explore or Tools
- **Settings** — From Trophy Wall or header

### Responsive Layout
| Device | Navigation |
|--------|------------|
| Phone (portrait) | Bottom navigation bar |
| Tablet/Wide Web | Navigation rail or sidebar |

---

## Component System

### Cards (Photo-First)
```
┌─────────────────────────────────┐
│                                 │
│          [HERO PHOTO]           │
│                                 │
├─────────────────────────────────┤
│ 🦌 Buck • Texas • Travis County │
│ 72°F | Wind: SW 8mph | 01/15/26 │
│ Score: 142" • Rifle             │
└─────────────────────────────────┘
```

- Photo dominates (60%+ of card)
- Compact "stats strip" below
- Species icon/tag visible
- Location: State + County
- Quick stats: temp, wind, date, score/weight

### Dropdowns (Hard Requirement)
All state/county/species/season/price filters must be:
- ✅ Modern design
- ✅ Searchable (type to filter)
- ✅ Big tap targets (thumb-friendly)
- ✅ Fast (cached data)
- ✅ "All" default with optional drill-down

### States
| State | Visual |
|-------|--------|
| Loading | Skeleton loaders (shimmer effect) |
| Empty | Intentional empty state with helpful message |
| Error | Clear error message with retry option |
| Success | Content displays normally |

---

## Typography

### Font Selection
- Clean, readable sans-serif
- Professional weight hierarchy
- Support for scalable text (accessibility)

### Hierarchy
| Level | Use |
|-------|-----|
| H1 | Screen titles |
| H2 | Section headers |
| H3 | Card titles |
| Body | Regular text |
| Caption | Metadata, timestamps |

---

## Accessibility

### Requirements
- ✅ Minimum contrast ratios (WCAG AA)
- ✅ Scalable text support
- ✅ Large touch targets (44px minimum)
- ✅ Screen reader support
- ✅ Focus indicators

---

## Performance Targets

### Smooth Experience
- ✅ Smooth scroll feeds (60fps)
- ✅ Fast filter application (<200ms)
- ✅ Aggressive image optimization
- ✅ CDN-backed image delivery
- ✅ Feed pagination
- ✅ Thumbnail generation

### Offline Tolerance
- ✅ Graceful degradation when offline
- ✅ Queue actions for sync (optional enhancement)
- ✅ Cache list data locally

---

## Canonical Terminology

### Always Use
| Correct Term | Never Use |
|--------------|-----------|
| Trophy Wall | Profile, User Page |
| The Swap Shop | Marketplace, BST, Classifieds |
| Harvested | Caught, Shot, Killed |
| Posted | Uploaded, Created |

### Time Display
- Always show "Harvested" time separately from "Posted" time
- Never assume harvest time from upload time
- Use time buckets (Morning/Midday/Evening) when exact time unknown

---

## Form Patterns

### Trophy Post Flow
1. Select category (Deer/Turkey/Bass/Other)
2. If Other: Select species from dropdown or "Other (specify)"
3. Select State → County (cascading dropdowns)
4. Enter harvest date (required), time (optional)
5. Upload photos (1-10+)
6. Enter species-specific stats
7. Add story (optional)
8. Set visibility (Public/Private)
9. Review → Post

### Filter Pattern
```
┌─────────────────────────────────┐
│ State: [All States      ▼]     │
│ County: [All Counties   ▼]     │
│ Species: [All Species   ▼]     │
│ Date Range: [Last 30 days ▼]   │
│                                 │
│ [Apply Filters]                 │
└─────────────────────────────────┘
```

---

## Reactions (Respect-First)

### Use
- ✅ "Respect" (primary)
- ✅ "Well-earned" (secondary)

### Avoid
- ❌ Hearts
- ❌ Likes
- ❌ Influencer-style reactions

---

## Image Guidelines

### Photo Display
- Hero photos should be high quality
- Support multiple photos per trophy (1-10+)
- Lazy loading for feed performance
- Thumbnail generation for lists
- Full-size view on tap

### Upload
- Compression before upload
- Retry on failure
- Progress indication
- Maximum file size limits

---

*Derived from: docs/blueprint/The_Skinning_Shed_Blueprint_Pack_v1.zip*

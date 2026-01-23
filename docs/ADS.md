# Ad Slot System

> Privacy-safe, production-grade ad system for The Skinning Shed

## Overview

The ad slot system displays banner ads in the app header area, positioned on either side of the main banner. Ads are:

- **Privacy-safe**: No GPS data, no tracking beyond basic click URLs
- **Server-controlled**: Creatives and metadata stored in Supabase (no app redeploy needed)
- **Responsive**: Hidden on mobile, shown on tablet/desktop
- **Graceful**: Empty slots take zero space (no blank boxes)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     HEADER AREA                              │
│  ┌──────────┐    ┌─────────────────────┐    ┌──────────┐   │
│  │ Ad Left  │    │   Hero Banner       │    │ Ad Right │   │
│  │ (200x100)│    │   (centered)        │    │ (200x100)│   │
│  └──────────┘    └─────────────────────┘    └──────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Supabase Setup

### Storage Bucket

**Bucket Name**: `ad_share`

Create this bucket manually in Supabase Dashboard:
1. Go to Storage → Create bucket
2. Name: `ad_share`
3. Public: Yes (recommended for simplicity) or No (use signed URLs)
4. File size limit: 2MB
5. Allowed MIME types: `image/png`, `image/jpeg`, `image/webp`, `image/gif`

### Database Table

Table `ad_slots` is created via migration. Key columns:

| Column | Type | Description |
|--------|------|-------------|
| `page` | text | Target page: `feed`, `explore`, `trophy_wall`, `weather`, `land`, `swap_shop`, `settings`, `research` |
| `position` | text | `left` or `right` |
| `storage_path` | text | Path in `ad_share` bucket, e.g., `feed/left.png` |
| `click_url` | text | Destination URL (opens in browser) |
| `enabled` | bool | Whether ad is active |
| `starts_at` | timestamp | Start date (null = immediately) |
| `ends_at` | timestamp | End date (null = never expires) |
| `priority` | int | Lower = higher priority (for future multi-ad support) |
| `label` | text | Internal name for reference |

## How to Add an Ad

### Step 1: Upload Creative

1. Go to Supabase Dashboard → Storage → `ad_share` bucket
2. Create folder structure: `{page}/` (e.g., `feed/`)
3. Upload image file (e.g., `left.png`)
4. Note the path: `feed/left.png`

### Step 2: Insert Metadata

Run SQL in Supabase SQL Editor:

```sql
INSERT INTO public.ad_slots (page, position, storage_path, click_url, enabled, label)
VALUES (
  'feed',           -- page
  'left',           -- position
  'feed/left.png',  -- storage_path (matches uploaded file)
  'https://example.com/campaign',  -- click_url
  true,             -- enabled
  'Example Sponsor' -- label
);
```

### Step 3: Verify

- Reload app on desktop/tablet
- Ad should appear next to banner
- Click should open URL in browser

## How to Schedule an Ad

Use `starts_at` and `ends_at` for scheduling:

```sql
-- Ad runs from Jan 1 to Jan 31, 2026
INSERT INTO public.ad_slots (page, position, storage_path, click_url, enabled, starts_at, ends_at, label)
VALUES (
  'weather',
  'right',
  'weather/winter_promo.png',
  'https://sponsor.com/winter-sale',
  true,
  '2026-01-01 00:00:00+00',
  '2026-01-31 23:59:59+00',
  'Winter Sale Promo'
);
```

## How to Disable an Ad

Option 1: Set `enabled = false`:
```sql
UPDATE public.ad_slots SET enabled = false WHERE page = 'feed' AND position = 'left';
```

Option 2: Delete the row:
```sql
DELETE FROM public.ad_slots WHERE page = 'feed' AND position = 'left';
```

## How to Update a Creative

```sql
UPDATE public.ad_slots 
SET storage_path = 'feed/new_left.png', 
    click_url = 'https://new-url.com'
WHERE page = 'feed' AND position = 'left';
```

Then upload the new image to Storage.

## Supported Pages and Positions

| Page ID | Description | Left | Right |
|---------|-------------|------|-------|
| `feed` | Main feed | ✅ | ✅ |
| `explore` | Explore/discover | ✅ | ✅ |
| `trophy_wall` | User trophy wall | ✅ | ✅ |
| `weather` | Weather & tools | ✅ | ✅ |
| `land` | Land listings | ✅ | ✅ |
| `swap_shop` | Swap shop | ✅ | ✅ |
| `settings` | Settings | ✅ | ✅ |
| `research` | Research/patterns | ✅ | ✅ |

## Recommended Image Sizes

| Size | Use Case |
|------|----------|
| **200 x 100 px** | Standard desktop |
| **160 x 80 px** | Compact/tablet |
| **400 x 200 px** | @2x for retina |

**Format**: PNG or WebP (with transparency if needed)
**Max file size**: 500KB (smaller = faster load)

## Responsive Behavior

| Screen Width | Left Ad | Right Ad |
|--------------|---------|----------|
| < 768px (mobile) | Hidden | Hidden |
| 768-1024px (tablet) | Hidden | Shown |
| > 1024px (desktop) | Shown | Shown |

## Caching

- Ad metadata is cached in-memory for 10 minutes
- Images are cached by the browser/Flutter image cache
- To force refresh: user restarts app, or call `adService.clearCache()`

## Privacy Notes

- **No GPS**: Ads are targeted by page only, not by location
- **No user tracking**: No user ID sent to ad servers
- **No third-party SDKs**: Images served from Supabase Storage
- **Click tracking**: Optional `tracking_tag` field for UTM parameters

## Troubleshooting

### Ad not showing

1. Check `enabled = true` in database
2. Check dates: `starts_at <= now() <= ends_at`
3. Check storage path matches uploaded file exactly
4. Check bucket is public or signed URLs work
5. Check screen width is >= 768px

### Ad shows but image broken

1. Verify file exists in Storage at exact path
2. Check file permissions (bucket should be public)
3. Check image format is supported

### Layout issues

1. Ads only show on tablet/desktop
2. Banner should remain centered
3. If no ads exist, no empty space should appear

## SQL Queries for Management

```sql
-- List all ads
SELECT * FROM public.ad_slots ORDER BY page, position;

-- List active ads
SELECT * FROM public.ad_slots 
WHERE enabled = true 
  AND (starts_at IS NULL OR starts_at <= now())
  AND (ends_at IS NULL OR ends_at >= now());

-- Count ads by page
SELECT page, COUNT(*) FROM public.ad_slots GROUP BY page;
```

## Future Enhancements

- [ ] Admin UI for ad management
- [ ] Click analytics (count clicks in database)
- [ ] A/B testing (multiple creatives per slot)
- [ ] Geo-targeting by state (without GPS)
- [ ] Impression tracking

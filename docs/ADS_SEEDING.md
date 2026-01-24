# Ad Seeding Guide

This document explains how to seed sample ads into the ad system for development and testing.

## Overview

The ad system consists of:
- **Storage bucket**: `ad_share` (Supabase Storage)
- **Metadata table**: `ad_slots` (Supabase Database)
- **Widget**: `AdSlot` and `AdAwareBannerHeader` (Flutter)

## Ad Slot Registry

All ad slots are defined in `app/lib/ads/ad_slot_registry.dart`.

Each page has two positions:
- `left` - Left side of header (desktop only)
- `right` - Right side of header (tablet and desktop)

### Pages with Ad Slots

| Page | Left Slot | Right Slot |
|------|-----------|------------|
| feed | feed:left | feed:right |
| explore | explore:left | explore:right |
| trophy_wall | trophy_wall:left | trophy_wall:right |
| land | land:left | land:right |
| messages | messages:left | messages:right |
| weather | weather:left | weather:right |
| research | research:left | research:right |
| regulations | regulations:left | regulations:right |
| settings | settings:left | settings:right |
| swap_shop | swap_shop:left | swap_shop:right |

## Seeding Sample Ads

### Prerequisites

1. Python 3.8+ with pip
2. Service role key (NOT anon key)

### Install Dependencies

```bash
pip install supabase pillow
```

### Set Environment Variables

```bash
# Linux/macOS
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="eyJ..."

# Windows PowerShell
$env:SUPABASE_URL = "https://your-project.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY = "eyJ..."
```

> **WARNING**: Never commit service role keys. Use environment variables or secrets management.

### Run the Seeding Script

```bash
python tools/seed_ads.py
```

The script will:
1. Create 4 sample ad images (placeholder PNGs)
2. Upload them to `ad_share/sample/` in Supabase Storage
3. Insert `ad_slots` rows for all 20 slots (10 pages × 2 positions)

### Verify in App

1. Run the Flutter app
2. Go to **Settings**
3. In debug builds, find **Developer** section
4. Enable **Show Ad Slot Overlay**
5. Navigate to different screens to see ad slot boundaries

## Ad Slot Schema

```sql
CREATE TABLE ad_slots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  page text NOT NULL,           -- 'feed', 'weather', etc.
  position text NOT NULL,       -- 'left' or 'right'
  storage_path text NOT NULL,   -- Path in ad_share bucket
  click_url text,               -- Optional click-through URL
  enabled boolean DEFAULT true,
  starts_at timestamptz,        -- Optional schedule start
  ends_at timestamptz,          -- Optional schedule end
  priority integer DEFAULT 100, -- Lower = higher priority
  label text,                   -- Internal label
  tracking_tag text,            -- Analytics tag
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
```

## Storage Structure

```
ad_share/
├── sample/
│   ├── sample_01.png   # "Sample Ad - The Skinning Shed"
│   ├── sample_02.png   # "Gear Sale (Sample)"
│   ├── sample_03.png   # "Land Lease (Sample)"
│   └── sample_04.png   # "Swap Shop Promo (Sample)"
└── production/
    └── (your actual ad creatives)
```

## Bucket Configuration

The `ad_share` bucket can be public or private:

- **Public bucket**: Images served directly via public URL
- **Private bucket**: Images served via signed URL (1-hour expiry)

Set via `--dart-define=ADS_BUCKET_PUBLIC=false` to use signed URLs.

## Debug Overlay

In debug builds, enable the overlay in Settings > Developer > Show Ad Slot Overlay.

The overlay shows:
- **Green border**: Ad loaded successfully
- **Orange border**: No ad available for this slot
- **Slot key label**: `page:position` identifier

## Clearing Sample Ads

To remove all sample ads:

```sql
-- Remove sample ad slots
DELETE FROM ad_slots WHERE storage_path LIKE 'sample/%';
```

Then manually delete files from `ad_share/sample/` in the Storage dashboard.

## Production Ads

For production, upload real ad creatives to `ad_share/production/` and insert corresponding `ad_slots` rows without the 'sample' prefix in storage_path.

## Troubleshooting

### Ads not appearing

1. Check `ad_slots` table has enabled rows for the page/position
2. Verify `storage_path` matches actual file in `ad_share` bucket
3. Check `enabled = true` and current time is within `starts_at`/`ends_at` range
4. Clear ad cache in Settings > Developer > Clear Ad Cache

### Signed URL errors

If using private bucket, ensure service role or authenticated user has proper RLS policies.

### Storage permission errors

Ensure storage policies allow reads from the `ad_share` bucket for the appropriate role (anon for public, authenticated for private).

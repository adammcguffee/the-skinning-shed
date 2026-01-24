# Regulations Admin Guide

> Last updated: January 2026

This document explains how to manage hunting and fishing regulations in The Skinning Shed.

## Overview

Regulations are organized by:
- **State** (50 US states)
- **Category** (deer, turkey, fishing)
- **Region/Zone** (STATEWIDE by default, or specific zones for states with multiple hunting areas)
- **Season Year** (e.g., 2025-2026)

## Database Tables

| Table | Purpose |
|-------|---------|
| `state_regulations_sources` | Official URLs to check for updates |
| `state_regulations_pending` | Changes detected, awaiting admin approval |
| `state_regulations_approved` | Verified regulations shown to users |

## Region/Zone Support

Many states have different season dates and bag limits by zone. The system supports:

- **STATEWIDE** (default): Applies to entire state
- **ZONE_X**: Named zones (e.g., ZONE_A, ZONE_B)
- **UNIT_X**: Management units
- **County groups**: Collections of counties

### Region Fields

```json
{
  "region_key": "ZONE_A",
  "region_label": "Zone A (North Texas)",
  "region_scope": "zone",
  "region_geo": {
    "type": "zone",
    "zones": ["A"]
  }
}
```

## Admin Workflows

### 1. Seed Sources (First Time Setup)

1. Go to **Regulations Admin** → **Tools** tab
2. Click **Seed Sources**
3. This populates official URLs for all 50 states × 3 categories

### 2. Run Checker

The checker runs automatically weekly (Sunday 6 AM UTC). To run manually:

1. Go to **Regulations Admin** → **Tools** tab
2. Click **Run Now** on the Regulations Checker card
3. Review results: sources checked, changes detected

### 3. Review Pending Updates

When the checker detects a change:

1. Go to **Regulations Admin** → **Pending** tab
2. Review each pending item:
   - Click source URL to view official page
   - Compare diff summary
3. Either:
   - **Approve**: Moves to approved table (visible to users)
   - **Reject**: Marks as rejected with notes

### 4. Bulk Import

To import regulations from JSON:

1. Go to **Regulations Admin** → **Tools** tab
2. Click **Import JSON**
3. Paste JSON array in format:

```json
[
  {
    "state_code": "TX",
    "category": "deer",
    "season_year_label": "2025-2026",
    "year_start": 2025,
    "year_end": 2026,
    "region_key": "STATEWIDE",
    "region_label": "Statewide",
    "summary": {
      "seasons": [
        {
          "name": "General Season",
          "start_date": "Nov 2, 2025",
          "end_date": "Jan 5, 2026"
        }
      ],
      "bag_limits": [
        {
          "species": "White-tailed Deer",
          "daily": "1",
          "season": "5"
        }
      ],
      "weapons": [
        {
          "name": "Rifle",
          "allowed": true
        }
      ],
      "notes": [
        "Antler restrictions may apply in certain counties"
      ]
    },
    "source_url": "https://tpwd.texas.gov/regulations/..."
  }
]
```

4. Click **Import** - items go to pending for review
5. Approve items individually or in batch

### 5. Export Regulations

To backup or transfer data:

1. Go to **Regulations Admin** → **Tools** tab
2. Click **Export** on the Export Approved card
3. JSON is copied to clipboard

### 6. Coverage Dashboard

View status at a glance:

1. Go to **Regulations Admin** → **Coverage** tab
2. Grid shows all states × categories
3. Status icons:
   - ✅ Green check: Approved data exists
   - ⏳ Yellow pending: Pending review
   - ❌ Red X: Missing
4. Toggle "Missing only" to filter

## Adding Zone-Specific Regulations

For states with multiple zones:

1. Add zone-specific sources to `state_regulations_sources`:
   ```sql
   INSERT INTO state_regulations_sources 
   (state_code, category, region_key, region_label, source_url, source_name)
   VALUES 
   ('TX', 'deer', 'SOUTH_ZONE', 'South Zone', 'https://...', 'Texas Parks & Wildlife');
   ```

2. Or use Bulk Import with region fields populated

3. Each zone will have its own pending/approved records

## Weekly Check Schedule

The `regulations-check` Edge Function runs via pg_cron:

- **Schedule**: Every Sunday at 6:00 AM UTC
- **Action**: Fetches all source URLs, computes hash, creates pending if changed
- **Never auto-approves**: All changes require admin review

## Troubleshooting

### Checker returns errors

- Check source URLs are accessible
- Some sites block automated requests - may need manual updates

### Missing regions

- Ensure `region_key` is unique per state/category
- STATEWIDE should exist for every state/category

### Duplicate constraint errors

- Unique constraint: `(state_code, category, season_year_label, region_key)`
- Use upsert to update existing records

## Security Notes

- Never commit `SUPABASE_SERVICE_ROLE_KEY`
- Edge Function uses service role for write access
- Admin actions require `is_admin = true` on user profile

---

*For questions, contact the development team.*

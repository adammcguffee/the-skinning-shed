# Privacy & Safety — The Skinning Shed

> Privacy-first design is a non-negotiable core principle.

## Location Privacy

### What We DO
- ✅ Store and display **State + County** only
- ✅ Use county centroid/nearest major city for weather lookups (behind the scenes)
- ✅ Allow users to choose "Private" visibility for journal entries

### What We DO NOT Do (MVP)
- ❌ **No GPS pins** — Never display exact coordinates publicly
- ❌ **No map markers** — No onX-style mapping in MVP
- ❌ **No property boundaries** — No licensed boundary data
- ❌ **No precise location storage** — We don't store or transmit exact GPS coordinates

### Location Resolution
```
User Input → State + County → Weather lookup uses county centroid
                            → Public display shows State + County only
```

## Research Dashboard Privacy

### Aggregation Thresholds
To prevent small-sample leakage that could identify individuals or locations:

- **Minimum N posts** required before showing county-level data
- When threshold not met → roll up to state level
- Panels show counts, not individual records
- Never expose individual harvest locations through analytics

### What Research Shows
- Counts by pressure buckets
- Counts by temperature ranges
- Counts by wind direction
- Counts by moon phase
- Counts by day-of-week
- Counts by time-of-day bucket
- Counts by season/week-of-season

### What Research Does NOT Show
- Individual trophy locations
- Exact coordinates
- Individual user patterns
- Low-N county breakdowns (rolled up)

## User Data Privacy

### Profile Data
- Users can read public profile fields
- Users can update only their own profile
- Private notes are visible only to the owner

### Trophy Posts
- **Public posts:** Visible to all authenticated users
- **Private posts:** Visible only to the owner (journal mode)
- Followers-only mode: Deferred to post-MVP

### Photos
- Photos are tied to trophies via storage policies
- Users can only upload to paths they own
- Public photos can be viewed; private trophy photos restricted

## Storage Security

### Bucket Structure
| Bucket | Access |
|--------|--------|
| `avatars` | Public read; write only to own uid path |
| `trophy_photos` | Read with trophy access; write only by owner |
| `land_photos` | Read with listing access; write only by owner |
| `swap_shop_photos` | Read with listing access; write only by owner |

### Path Conventions
```
avatars/{user_id}/avatar.{ext}
trophy_photos/{user_id}/{trophy_id}/{filename}
land_photos/{user_id}/{listing_id}/{filename}
swap_shop_photos/{user_id}/{listing_id}/{filename}
```

## Moderation & Safety

### Community Standards
- Respect-first reactions: "Respect" / "Well-earned" (not influencer hearts)
- No politics, no arguing legality, no doxxing
- Clear community guidelines shown in-app

### Moderation Tools
- **Report content:** Users can flag posts/listings
- **Hide user:** Block content from specific users
- **Admin remove:** Moderators can remove content
- **Admin ban:** Moderators can ban users

### Content Moderation Flow
```
User reports content
    → Report stored in moderation_reports table
    → Admin reviews (status: open/closed)
    → Action: remove content / warn user / ban user
```

## Weather Data Privacy

### How Weather Works
1. User enters harvest date/time (or time bucket)
2. System derives coarse location from county
3. Weather API queried using county centroid (not user GPS)
4. Weather snapshot stored with trophy
5. **User's actual location never transmitted or stored**

### Historical Weather
- Based on harvest date + county only
- Uses county centroid for API lookup
- Displays "approximate conditions" label
- No GPS required from user

## Data We Never Collect (MVP)

| Data Type | Status |
|-----------|--------|
| Precise GPS coordinates | ❌ Never collected |
| Background location | ❌ Never collected |
| Property boundaries | ❌ Not in MVP |
| User movement patterns | ❌ Never tracked |
| Cross-app tracking | ❌ Never implemented |

---

## Security Requirements

### RLS (Row Level Security)
- ✅ Enabled on all user-facing tables
- ✅ Users can only CRUD their own data
- ✅ Public data readable per visibility rules
- ✅ Private data restricted to owner

### Client Security
- ✅ Only use `SUPABASE_ANON_KEY` in client
- ✅ Never include `SERVICE_ROLE` key in client app
- ✅ No secrets in source code or commits
- ✅ Environment variables via dart-define (not bundled)

### API Security
- ✅ Signed URLs for private content where appropriate
- ✅ Moderation endpoints restricted to admin role
- ✅ Service role key used only server-side/edge functions

---

*Derived from: docs/blueprint/The_Skinning_Shed_Blueprint_Pack_v1.zip*

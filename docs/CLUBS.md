# Hunting Clubs Feature

Private hunting clubs with news, stand sign-in board, and member management.

## Overview

Clubs allow hunting groups to:
- Share news and updates with members only
- Track who is hunting which stand (sign-in board)
- Manage members with roles (owner, admin, member)
- Optionally be discoverable for others to request to join

## Privacy Model

Clubs are **private by default**. Non-members cannot see:
- Club posts/news
- Stand sign-in board
- Member list
- Any club content

### Discoverable Clubs

Clubs can be marked as "discoverable" which allows:
- Club name and description visible in the Discover list
- Users can request to join (pending admin approval)
- No other content is visible until membership is approved

### RLS Enforcement

All privacy is enforced at the database level via Row Level Security (RLS):
- `is_club_member(club_id)` - SECURITY DEFINER function checks membership
- `is_club_admin(club_id)` - Checks admin/owner role
- Non-members cannot read club_posts, club_stands, stand_signins, club_members

## Data Model

### Tables

| Table | Description |
|-------|-------------|
| `clubs` | Club metadata (name, slug, settings, discoverable flag) |
| `club_members` | Membership records with roles |
| `club_invites` | Invite links and direct invites |
| `club_join_requests` | Requests to join discoverable clubs |
| `club_posts` | News feed posts |
| `club_stands` | Stand definitions |
| `stand_signins` | Sign-in records |

### Member Roles

| Role | Permissions |
|------|-------------|
| `owner` | Full control, can delete club |
| `admin` | Manage members, stands, posts, settings |
| `member` | Post news, sign in to stands, view content |

### Member Status

| Status | Description |
|--------|-------------|
| `active` | Full member access |
| `invited` | Pending invite acceptance |
| `requested` | Pending join request approval |
| `banned` | Removed from club |

## Stand Sign-In Board

The stand sign-in board tracks who is hunting which stand.

### How It Works

1. Admin creates stands (e.g., "Stand 1", "North Tower")
2. Members sign in to a stand before hunting
3. Sign-ins expire automatically based on club settings (default 6 hours)
4. Only one person can sign in to a stand at a time (enforced by DB)
5. Members can sign out early or let it expire

### TTL (Time-To-Live)

Sign-ins automatically expire after a configurable duration:
- Default: 6 hours
- Options: 2, 4, 6, 8, 12, 24 hours
- Configured per-club in Settings

### "Forgot to Sign Out" Handling

If a hunter forgets to sign out:
- The sign-in expires automatically at `expires_at`
- UI shows "Expired" and stand becomes available
- No action needed from the hunter

### Concurrency Handling

If two hunters try to sign in to the same stand simultaneously:
- Database has a unique partial index: `uniq_active_signin_per_stand`
- Only one INSERT succeeds; the other gets a unique constraint error
- UI shows "Stand was just taken by someone else!" and refreshes

### Polling

The Stands tab polls every 15 seconds while visible to show near-real-time updates. Manual pull-to-refresh is also available.

## Invite Links

### Format

```
https://www.theskinningshed.com/clubs/join/<TOKEN>
```

Where `<TOKEN>` is a 32-character base64 string.

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| `expires_at` | 7 days | Link expiration |
| `max_uses` | 5 | Maximum number of uses |
| `uses` | 0 | Current use count |

### Flow

1. Admin clicks "Create Invite Link"
2. System generates token and inserts into `club_invites`
3. Admin shares link via copy/share sheet
4. Recipient opens link → ClubJoinScreen
5. Screen validates token (not expired, not fully used)
6. User clicks "Join Club" → `accept_club_invite()` RPC
7. User becomes a member → redirected to club detail

## Database Functions

### `is_club_member(club_id uuid) → boolean`
Check if current user is an active member. Used in RLS policies.

### `is_club_admin(club_id uuid) → boolean`
Check if current user is admin or owner. Used in RLS policies.

### `create_club(...) → uuid`
Creates club and adds caller as owner atomically.

### `accept_club_invite(token text) → jsonb`
Validates invite and adds user as member.

### `approve_join_request(request_id uuid) → boolean`
Approves pending request and adds user as member.

### `get_invite_info(token text) → jsonb`
Returns limited club info for join page (validates token first).

## UI Screens

| Screen | Path | Description |
|--------|------|-------------|
| ClubsHomeScreen | `/clubs` | My Clubs + Discover |
| CreateClubScreen | `/clubs/create` | Create new club wizard |
| ClubDetailScreen | `/clubs/:id` | Tabbed detail (News, Stands, Members, Settings) |
| ClubJoinScreen | `/clubs/join/:token` | Accept invite link |

## Settings (per club)

| Setting | Default | Description |
|---------|---------|-------------|
| `is_discoverable` | false | Show in Discover list |
| `require_approval` | true | Require admin approval for join requests |
| `sign_in_ttl_hours` | 6 | Stand sign-in expiration |
| `allow_multi_signin_per_stand` | false | Allow multiple sign-ins per stand (not implemented) |
| `allow_members_create_stands` | false | Let members create stands (not implemented) |

## Future Enhancements

- [ ] Real-time updates via Supabase Realtime (instead of polling)
- [ ] Club logo/banner image uploads
- [ ] Direct member invites by username
- [ ] Stand map view with GPS coordinates (privacy considerations)
- [ ] Sign-in history and analytics
- [ ] Push notifications for sign-in changes

---

*Last updated: January 2026*

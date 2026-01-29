# Hunting Clubs Feature

> Last updated: January 29, 2026

Private hunting clubs with news, stand sign-in board, trail cam photos, and member management.

## Overview

Clubs allow hunting groups to:
- Share news and updates with members only
- Track who is hunting which stand (sign-in board)
- Log hunt details (parked at, entry route, etc.)
- Record stand activity/observations after each sit
- Manage members with roles (owner, admin, member)
- Invite members by username or shareable link
- Optionally be discoverable for others to request to join

---

## Database Schema

### Tables

| Table | Description |
|-------|-------------|
| `clubs` | Club metadata (name, slug, settings, discoverable flag) |
| `club_members` | Membership records with roles and status |
| `club_invites` | Invite links and direct invites |
| `club_join_requests` | Requests to join discoverable clubs |
| `club_posts` | News feed posts |
| `club_stands` | Stand definitions (supports soft delete) |
| `stand_signins` | Sign-in records with hunt details |
| `stand_activity` | Observations/activity logs per stand |
| `club_photos` | Trail cam and club photo uploads |
| `club_buck_profiles` | Buck tracking profiles |

### clubs

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | |
| `owner_id` | UUID (FK) | → profiles.id |
| `name` | TEXT | Club name |
| `slug` | TEXT (unique) | URL-friendly name |
| `description` | TEXT | Club description |
| `state` | TEXT | State name |
| `state_code` | CHAR(2) | 2-letter state code |
| `county` | TEXT | County name |
| `is_discoverable` | BOOLEAN | Show in discover list |
| `settings` | JSONB | Club settings object |
| `created_at` | TIMESTAMPTZ | |

### club_members

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | |
| `club_id` | UUID (FK) | → clubs.id |
| `user_id` | UUID (FK) | → profiles.id |
| `role` | TEXT | owner / admin / member |
| `status` | TEXT | active / invited / requested / banned |
| `invited_by` | UUID (FK) | → profiles.id (nullable) |
| `joined_at` | TIMESTAMPTZ | |

### club_stands

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | |
| `club_id` | UUID (FK) | → clubs.id |
| `name` | TEXT | Stand name (e.g., "North Tower") |
| `description` | TEXT | Optional description |
| `sort_order` | INT | Display order |
| `is_deleted` | BOOLEAN | Soft delete flag (default false) |
| `created_at` | TIMESTAMPTZ | |

### stand_signins

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | |
| `club_id` | UUID (FK) | → clubs.id |
| `stand_id` | UUID (FK) | → club_stands.id |
| `user_id` | UUID (FK) | → profiles.id |
| `status` | TEXT | active / signed_out / expired |
| `signed_in_at` | TIMESTAMPTZ | |
| `signed_out_at` | TIMESTAMPTZ | |
| `expires_at` | TIMESTAMPTZ | Auto-expire time |
| `ended_reason` | TEXT | manual / auto_expired / stand_deleted / new_signin |
| `note` | TEXT | Quick note on sign-in |
| `details` | JSONB | Hunt details (parked_at, entry_route, etc.) |
| `activity_prompt_dismissed` | BOOLEAN | User dismissed activity prompt |

**Hunt Details JSONB Schema:**
```json
{
  "parked_at": "North gate pull-off",
  "entry_route": "Came in from south firebreak",
  "wind": "NW",
  "weapon": "Bow",
  "extra": "Additional notes"
}
```

### stand_activity

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | |
| `club_id` | UUID (FK) | → clubs.id |
| `stand_id` | UUID (FK) | → club_stands.id |
| `user_id` | UUID (FK) | → profiles.id |
| `signin_id` | UUID (FK) | → stand_signins.id (nullable) |
| `body` | TEXT | Activity/observation text |
| `created_at` | TIMESTAMPTZ | |
| `updated_at` | TIMESTAMPTZ | |

### club_invites

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID (PK) | |
| `club_id` | UUID (FK) | → clubs.id |
| `invite_type` | TEXT | link / direct |
| `token` | TEXT (unique) | Invite token (for links) |
| `target_user_id` | UUID (FK) | → profiles.id (for direct) |
| `created_by` | UUID (FK) | → profiles.id |
| `expires_at` | TIMESTAMPTZ | |
| `max_uses` | INT | Max uses (for links) |
| `uses` | INT | Current use count |
| `created_at` | TIMESTAMPTZ | |

---

## Permission Model

### Member Roles

| Role | Description |
|------|-------------|
| `owner` | Creator of the club, full control |
| `admin` | Promoted by owner, can manage club |
| `member` | Regular member |

### Role Permissions

| Action | Owner | Admin | Member |
|--------|-------|-------|--------|
| View club content | ✅ | ✅ | ✅ |
| Post news | ✅ | ✅ | ✅ |
| Sign in/out of stands | ✅ | ✅ | ✅ |
| Add stands | ✅ | ✅ | ✅ |
| Edit stands | ✅ | ✅ | ❌ |
| Delete stands (soft) | ✅ | ✅ | ❌ |
| Invite members | ✅ | ✅ | ❌ |
| Approve join requests | ✅ | ✅ | ❌ |
| Manage members | ✅ | ✅ | ❌ |
| Club settings | ✅ | ✅ | ❌ |
| Promote to admin | ✅ | ❌ | ❌ |
| Delete club | ✅ | ❌ | ❌ |

### Member Status

| Status | Description |
|--------|-------------|
| `active` | Full member access |
| `invited` | Pending invite acceptance |
| `requested` | Pending join request approval |
| `banned` | Removed from club |

---

## Stand Sign-In Board

### How It Works

1. Any member can add stands to the club
2. Members sign in to a stand before hunting
3. Sign-ins expire automatically based on club settings (default 6 hours)
4. Only one person can sign in to a stand at a time (enforced by DB)
5. Members can sign out early or let it expire
6. After sign-out, users are prompted to log their activity

### Hunt Details

When signing in, members can optionally provide:
- **Parked at**: Where they parked (e.g., "North gate pull-off")
- **Entry route**: How they entered (e.g., "South firebreak")
- **Note**: Quick note about the hunt

### Stand Activity / "Log Your Sit"

After signing out (manual or auto-expired), members are prompted to log what they saw:
- Quick chips: "Saw buck", "Saw doe", "Saw turkey", "Heard movement", "Nothing seen"
- Freeform text for details (e.g., "8pt buck at 80 yards at 7:10am")

Activity entries are visible to all club members in the Stand Details sheet.

### TTL (Time-To-Live)

Sign-ins automatically expire after a configurable duration:
- Options: 1, 2, 4, 6, 8, 10, 12 hours
- Default: 6 hours
- Configured per-club in Settings

### Occupied Stand Styling

Occupied stands show premium visual styling:
- Light orange/warm background tint
- Orange border accent
- Occupant avatar/initials displayed
- Time remaining shown

### Polling

The Stands tab polls every 12 seconds while visible for near-real-time updates.

---

## Invite System

### Invite Methods

1. **By Username**: Send direct invite to @username
2. **Share Link**: Generate shareable invite link

### Invite Link Format

```
https://www.theskinningshed.com/#/clubs/join/<TOKEN>
```

Where `<TOKEN>` is a 32-character base64 string.

### Invite Link Properties

| Property | Default | Description |
|----------|---------|-------------|
| `expires_at` | 7 days | Link expiration |
| `max_uses` | 25 | Maximum number of uses |
| `uses` | 0 | Current use count |

### Share Options (Mobile)

- **Copy Link**: Copy to clipboard
- **Share**: Opens native share sheet (share_plus)
- **Text**: Opens SMS with prefilled message

---

## Mobile UI

### Entry Points for Actions

| Action | Access Method |
|--------|---------------|
| Add Stand | FAB on Stands tab + Header menu (⋮) |
| Edit/Delete Stand | Stand Details sheet (tap stand) |
| Invite Members | FAB on Members tab + Header menu (⋮) |
| Club Settings | Header menu (⋮) |

### Header Overflow Menu (⋮)

Available to all members:
- Add Stand

Available to admin/owner only:
- Invite Members
- Club Settings

### Responsive Design

- FABs visible at bottom-right on mobile
- Bottom sheets use `isScrollControlled` + keyboard inset handling
- No horizontal overflow
- SafeArea respected

---

## Database Functions (RPC)

| Function | Description |
|----------|-------------|
| `is_club_member(club_id)` | Check if current user is active member |
| `is_club_admin(club_id)` | Check if current user is admin/owner |
| `create_club(...)` | Create club and add caller as owner |
| `accept_club_invite(token)` | Accept invite link |
| `accept_club_direct_invite(club_id)` | Accept direct invite |
| `decline_club_direct_invite(club_id)` | Decline direct invite |
| `invite_user_to_club(club_id, username)` | Send direct invite by username |
| `get_my_club_invites()` | Get pending invites for current user |
| `get_club_pending_invites(club_id)` | Get pending invites for a club (admin) |
| `cancel_club_invite(club_id, user_id)` | Cancel pending invite (admin) |
| `approve_join_request(request_id)` | Approve join request |
| `get_invite_info(token)` | Get limited club info for join page |
| `soft_delete_stand(stand_id)` | Soft delete stand (admin) |
| `update_stand(stand_id, name, description)` | Update stand (admin) |
| `get_stand_activity(stand_id, limit)` | Get recent activity for stand |
| `get_pending_activity_prompts(club_id)` | Get pending activity prompts |
| `dismiss_activity_prompt(signin_id)` | Dismiss activity prompt |

---

## RLS Policies

| Table | SELECT | INSERT | UPDATE | DELETE |
|-------|--------|--------|--------|--------|
| `clubs` | Members can view their clubs | Authenticated | Owner/Admin | Owner |
| `club_members` | Members can view list | Via RPC | Admin | Admin |
| `club_stands` | Members | Members | Admin | Admin |
| `stand_signins` | Members | Members | Owner of signin OR Admin | - |
| `stand_activity` | Members | Members (own) | Author OR Admin | Author OR Admin |
| `club_invites` | Admin | Admin | Admin | Admin |
| `club_posts` | Members | Members | Author | Author |

---

## UI Screens

| Screen | Path | Description |
|--------|------|-------------|
| ClubsHomeScreen | `/clubs` | My Clubs + Discover + Pending Invites |
| CreateClubScreen | `/clubs/create` | Create new club wizard |
| ClubDetailScreen | `/clubs/:id` | Tabbed detail (News, Stands, Trail Cam, Members) |
| ClubPreviewScreen | `/clubs/preview/:id` | Preview for non-members |
| ClubSettingsScreen | `/clubs/:id/settings` | Club settings (admin) |
| ClubJoinScreen | `/clubs/join/:token` | Accept invite link |

---

## Club Settings

| Setting | Field | Default | Description |
|---------|-------|---------|-------------|
| Discoverable | `is_discoverable` | false | Show in Discover list |
| Require Approval | `settings.require_approval` | true | Require admin approval |
| Sign-in TTL | `settings.sign_in_ttl_hours` | 6 | Stand sign-in expiration |

---

## Flutter Services

### ClubsService (`clubs_service.dart`)

| Method | Description |
|--------|-------------|
| `getMyClubs()` | Get clubs user is a member of |
| `getClub(id)` | Get single club |
| `createClub(...)` | Create new club |
| `updateClub(...)` | Update club details |
| `deleteClub(id)` | Delete club (owner only) |
| `updateClubSettings(...)` | Update club settings |
| `joinClub(id)` | Request to join discoverable club |
| `leaveClub(id)` | Leave club |
| `inviteUserByUsername(clubId, username)` | Send direct invite |
| `createInviteLink(clubId)` | Generate invite link |
| `getMyPendingInvites()` | Get pending invites for user |
| `acceptDirectInvite(clubId)` | Accept direct invite |
| `declineDirectInvite(clubId)` | Decline direct invite |
| `getClubMembers(clubId)` | Get member list |
| `updateMemberRole(...)` | Change member role |
| `removeMember(...)` | Remove member from club |

### StandsService (`stands_service.dart`)

| Method | Description |
|--------|-------------|
| `getStandsWithSignins(clubId)` | Get stands + active signins |
| `createStand(clubId, name, description)` | Create new stand |
| `updateStand(standId, name, description)` | Update stand (direct) |
| `updateStandViaRpc(standId, name, description)` | Update stand (RPC) |
| `deleteStand(standId)` | Soft delete stand |
| `signIn(clubId, standId, ttlHours, note, details)` | Sign in to stand |
| `signOut(signinId)` | Sign out from stand |
| `signOutWithPrompt(signinId)` | Sign out and return signin for prompt |
| `getMyActiveSignin(clubId)` | Get user's active signin |
| `updateSigninDetails(signinId, note, details)` | Update signin details |
| `getStandActivity(standId, limit)` | Get recent activity |
| `addStandActivity(clubId, standId, body, signinId)` | Add activity entry |
| `editStandActivity(id, body)` | Edit activity entry |
| `deleteStandActivity(id)` | Delete activity entry |
| `getPendingActivityPrompt(clubId)` | Get pending prompt |
| `dismissActivityPrompt(signinId)` | Dismiss prompt |

### Riverpod Providers

| Provider | Type | Description |
|----------|------|-------------|
| `myClubsProvider` | `FutureProvider<List<Club>>` | User's clubs |
| `clubProvider(id)` | `FutureProvider.family<Club?, String>` | Single club |
| `clubMembersProvider(id)` | `FutureProvider.family<List<ClubMember>, String>` | Club members |
| `myClubMembershipProvider(id)` | `FutureProvider.family<ClubMember?, String>` | User's membership |
| `clubStandsProvider(id)` | `FutureProvider.family<List<ClubStand>, String>` | Club stands |
| `myActiveSigninProvider(id)` | `FutureProvider.family<StandSignin?, String>` | User's active signin |
| `standActivityProvider(id)` | `FutureProvider.family<List<StandActivity>, String>` | Stand activity |
| `pendingActivityPromptProvider(id)` | `FutureProvider.family<PendingActivityPrompt?, String>` | Pending prompt |
| `myClubInvitesProvider` | `FutureProvider<List<ClubInviteInfo>>` | User's pending invites |
| `pendingClubInvitesProvider(id)` | `FutureProvider.family<List<PendingClubInvite>, String>` | Club's pending invites |

---

## Data Models

### Club

```dart
class Club {
  final String id;
  final String ownerId;
  final String name;
  final String slug;
  final String? description;
  final String? state;
  final String? stateCode;
  final String? county;
  final bool isDiscoverable;
  final ClubSettings settings;
  final DateTime createdAt;
}
```

### ClubMember

```dart
class ClubMember {
  final String id;
  final String clubId;
  final String odUserId;
  final String role;      // owner, admin, member
  final String status;    // active, invited, requested, banned
  final String? username;
  final String? displayName;
  final String? avatarPath;
  
  bool get isAdmin => role == 'owner' || role == 'admin';
  bool get isOwner => role == 'owner';
}
```

### ClubStand

```dart
class ClubStand {
  final String id;
  final String clubId;
  final String name;
  final String? description;
  final int sortOrder;
  final StandSignin? activeSignin;
  
  bool get isOccupied => activeSignin != null && activeSignin!.isActive;
}
```

### StandSignin

```dart
class StandSignin {
  final String id;
  final String clubId;
  final String standId;
  final String userId;
  final String status;
  final DateTime signedInAt;
  final DateTime? signedOutAt;
  final DateTime expiresAt;
  final String? note;
  final HuntDetails? details;
  final String? username;
  final String? displayName;
  
  bool get isActive => status == 'active' && expiresAt.isAfter(DateTime.now());
  bool get isExpired => expiresAt.isBefore(DateTime.now());
}
```

### HuntDetails

```dart
class HuntDetails {
  final String? parkedAt;
  final String? entryRoute;
  final String? wind;
  final String? weapon;
  final String? extra;
}
```

### StandActivity

```dart
class StandActivity {
  final String id;
  final String clubId;
  final String standId;
  final String userId;
  final String? signinId;
  final String body;
  final DateTime createdAt;
  final String? username;
  final String? displayName;
}
```

---

## Future Enhancements

- [ ] Real-time updates via Supabase Realtime (instead of polling)
- [ ] Club logo/banner image uploads
- [ ] Stand map view with GPS coordinates
- [ ] Sign-in history and analytics dashboard
- [ ] Push notifications for sign-in changes
- [ ] Weather conditions auto-fill on sign-in
- [ ] Multi-club sign-in conflict detection

---

*Last updated: January 29, 2026*

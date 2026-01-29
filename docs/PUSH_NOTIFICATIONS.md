# Push Notifications

Production-grade push notifications for iOS and Android via Firebase Cloud Messaging (FCM).

## Overview

The notification system consists of:
1. **Device token storage** - Store FCM tokens in Supabase
2. **User preferences** - Per-user notification toggles
3. **In-app notifications** - Notification center with read/unread tracking
4. **Edge Functions** - Server-side push delivery via FCM HTTP v1

## Database Schema

### Tables

| Table | Description |
|-------|-------------|
| `device_push_tokens` | FCM tokens per device per user |
| `notifications` | In-app notification center entries |
| `user_notification_prefs` | Per-user notification preferences |

### User Preferences

| Preference | Default | Description |
|-----------|---------|-------------|
| `push_enabled` | true | Master push toggle |
| `club_post_push` | true | Club news posts |
| `stand_push` | true | Stand sign-in alerts |
| `message_push` | true | Direct messages |

## Edge Functions

### send-push
Core push delivery function. Called by other edge functions.

**Input:**
```json
{
  "userIds": ["uuid1", "uuid2"],
  "notification": {
    "type": "club_post",
    "title": "New post in Big Buck Club",
    "body": "@hunter123: Great morning hunt!",
    "data": {
      "route": "/clubs/abc123"
    }
  }
}
```

**Behavior:**
1. Checks user preferences (respects toggles)
2. Fetches FCM tokens from `device_push_tokens`
3. Sends via FCM HTTP v1 API
4. Creates `notifications` row for in-app center
5. Removes invalid tokens automatically

### notify-club-event
Triggered when club events occur (posts, stand sign-ins).

**Events:**
- `club_post` - New news post
- `stand_signin` - Someone signed in to a stand
- `stand_signout` - Someone signed out (optional)

### notify-message
Triggered when a new message is sent.

## Firebase Configuration

### Required Secrets (Supabase)

Set these in your Supabase project settings:

```
FCM_PROJECT_ID=your-firebase-project-id
FCM_CLIENT_EMAIL=firebase-adminsdk-xxx@your-project.iam.gserviceaccount.com
FCM_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n
```

Get these from Firebase Console → Project Settings → Service Accounts → Generate new private key.

### Flutter Setup

1. **Create Firebase project** at console.firebase.google.com

2. **Add Android app:**
   - Package name: `com.theskinningshed.app` (or your actual package)
   - Download `google-services.json`
   - Place in `android/app/google-services.json`

3. **Add iOS app:**
   - Bundle ID: `com.theskinningshed.app` (or your actual bundle ID)
   - Download `GoogleService-Info.plist`
   - Place in `ios/Runner/GoogleService-Info.plist`

4. **Android gradle config:**
   
   In `android/build.gradle`:
   ```gradle
   buildscript {
     dependencies {
       classpath 'com.google.gms:google-services:4.4.0'
     }
   }
   ```
   
   In `android/app/build.gradle`:
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

5. **iOS capabilities:**
   - Enable Push Notifications in Xcode
   - Enable Background Modes → Remote notifications
   - Upload APNs key to Firebase Console

## Flutter Integration

### Initialize on startup

```dart
// In main.dart after Firebase.initializeApp()
await PushNotificationService.instance.initialize(router: goRouter);
```

### Register token on login

```dart
// After successful authentication
await PushNotificationService.instance.requestPermission();
await PushNotificationService.instance.registerToken();
```

### Unregister on logout

```dart
// Before signing out
await PushNotificationService.instance.unregisterToken();
```

### Set router for deep links

```dart
// After router is ready
PushNotificationService.instance.setRouter(router);
```

## Notification Types

| Type | When | Data |
|------|------|------|
| `club_post` | New club news post | `{route, clubId, postId}` |
| `stand_signin` | Stand occupied | `{route, clubId, standId}` |
| `message` | New DM | `{route, conversationId}` |

## Deep Linking

Notifications include a `route` in the data payload that maps to GoRouter paths:

- Club posts: `/clubs/<clubId>`
- Stand sign-ins: `/clubs/<clubId>?tab=stands`
- Messages: `/messages/<conversationId>`

## In-App Notification Center

### UI Location
- Bell icon in app bar (shows unread badge)
- Tapping opens `/notifications` screen

### Features
- List of all notifications (newest first)
- Unread indicator (blue dot)
- Swipe to dismiss
- Mark all as read
- Tap to navigate + mark read

### Providers

```dart
// Get notifications list
final notifications = ref.watch(notificationsProvider);

// Get unread count
final unreadCount = ref.watch(unreadNotificationCountProvider);

// Get/update preferences
final prefs = ref.watch(notificationPrefsProvider);
```

## Testing

### Send test push (via curl)

```bash
curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/send-push' \
  -H 'Authorization: Bearer YOUR_SERVICE_ROLE_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "userIds": ["USER_UUID"],
    "notification": {
      "type": "club_post",
      "title": "Test Notification",
      "body": "This is a test push notification",
      "data": {"route": "/clubs"}
    }
  }'
```

### Check FCM delivery

1. Open app on device
2. Go to Settings → Notifications (ensure push enabled)
3. Send test push
4. Should receive notification

### Debug token registration

Check `device_push_tokens` table for registered tokens:
```sql
SELECT * FROM device_push_tokens WHERE user_id = 'YOUR_USER_ID';
```

## Troubleshooting

### Notification not received

1. Check `device_push_tokens` has entry for user
2. Check `user_notification_prefs` has push enabled
3. Check `notifications` table for entry (error column)
4. Verify FCM secrets are set correctly

### Token registration fails

1. Ensure Firebase config files are in place
2. Check Firebase project setup
3. For iOS: verify APNs key uploaded

### Deep link not working

1. Check `data.route` is present in notification
2. Verify GoRouter has route defined
3. Check PushNotificationService has router set

## Security Notes

- FCM credentials stored as Supabase secrets (not in repo)
- Tokens never logged in full (only first 10 chars)
- RLS prevents users from seeing others' tokens/notifications
- Notifications sent via service role (edge functions only)

---

*Last updated: January 2026*

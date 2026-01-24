# Chat System (DM Messenger)

The Skinning Shed includes a 1:1 direct messaging system for users to communicate about swaps, land listings, trophies, or general topics.

## Schema Overview

### Tables

```
conversations
├── id (uuid, PK)
├── created_at (timestamptz)
└── updated_at (timestamptz)  -- auto-updated on new message via trigger

conversation_members
├── id (uuid, PK)
├── conversation_id (uuid, FK → conversations)
├── user_id (uuid, FK → auth.users)
├── joined_at (timestamptz)
└── last_read_at (timestamptz)  -- used for unread count calculation
    UNIQUE(conversation_id, user_id)

messages
├── id (uuid, PK)
├── conversation_id (uuid, FK → conversations)
├── sender_id (uuid, FK → auth.users)
├── body (text)
├── subject_type (text, nullable)  -- 'swap', 'land', 'trophy'
├── subject_id (uuid, nullable)
├── subject_title (text, nullable)  -- cached title for display
└── created_at (timestamptz)
```

### Design Decisions

- **Single thread per user pair**: Regardless of subject context, two users share one conversation thread. Subject metadata is stored on individual messages for context display.
- **Unread tracking**: Uses `last_read_at` timestamp comparison against message `created_at` to calculate unread counts efficiently.
- **Trigger for updated_at**: A database trigger automatically updates `conversations.updated_at` when a new message is inserted, enabling efficient inbox ordering.

## RLS (Row-Level Security) Overview

All three tables have RLS enabled with the following policies:

### conversations
- **SELECT**: Only members can view (checks `conversation_members` for `auth.uid()`)

### conversation_members
- **SELECT**: Only members can view other members
- **UPDATE**: Users can only update their own membership (`user_id = auth.uid()`) - used for `last_read_at`

### messages
- **SELECT**: Only members can read messages in their conversations
- **INSERT**: Must be sender (`sender_id = auth.uid()`) AND a member of the conversation

## RPC Functions

All RPCs are `SECURITY DEFINER` with `search_path = public` and restricted to `authenticated` role only (anon cannot execute).

### `get_or_create_dm(other_user_id, p_subject_type?, p_subject_id?, p_subject_title?, initial_message?)`
- **Returns**: `jsonb { conversation_id, message_id?, created }`
- **Behavior**: 
  - Validates caller is authenticated
  - Prevents self-DM
  - Finds existing 2-member conversation between the two users OR creates new one
  - Optionally sends initial message with subject context
- **Atomic**: Uses transaction to prevent race conditions

### `get_inbox()`
- **Returns**: Table of conversations with:
  - `conversation_id`, `other_user_id`, `other_user_name`, `other_user_avatar`
  - `last_message_body`, `last_message_at`, `last_message_sender_id`
  - `subject_type`, `subject_title` (from latest message)
  - `unread_count`
- **Ordering**: By `last_message_at DESC`

### `get_unread_count()`
- **Returns**: `integer` total unread messages across all conversations
- **Logic**: Counts messages where `created_at > last_read_at` and `sender_id != auth.uid()`

### `mark_conversation_read(p_conversation_id)`
- **Returns**: `boolean` (true if update succeeded, false if not a member)
- **Behavior**: Updates `last_read_at = now()` for the calling user in that conversation

## Flutter Integration

### Service Layer (`messaging_service.dart`)

```dart
class MessagingService {
  Future<String> getOrCreateDM({...}) // Returns conversation_id
  Future<List<Conversation>> getInbox()
  Future<MessagesPage> getMessages(conversationId, {limit, beforeId})
  Future<Message> sendMessage({conversationId, body, ...})
  Future<void> markConversationRead(conversationId)
  Future<int> getUnreadCount()
  RealtimeChannel subscribeToConversation(conversationId, onMessage)
  RealtimeChannel subscribeToConversationUpdates(onUpdate)
}
```

### Providers

- `messagingServiceProvider` - Service instance
- `inboxProvider` - FutureProvider for inbox data
- `unreadCountProvider` - StateNotifierProvider for nav badge

### UI Screens

- `/messages` - `MessagesInboxScreen` (inbox list)
- `/messages/:conversationId` - `ConversationScreen` (chat thread)

### Entry Points

Message buttons are wired in:
- Swap Shop detail → "Message seller"
- Land detail → "Message owner"
- Trophy Wall / Profile → "Message" (when viewing another user)

## Performance Considerations

1. **Pagination**: Messages load 50 at a time with cursor-based pagination (`beforeId`)
2. **Inbox polling**: Uses 30-second polling interval instead of heavy realtime subscriptions
3. **Conversation realtime**: Single subscription per open conversation for new message inserts
4. **Unread badge**: Refreshed on inbox load, conversation open, and message send

## Testing with Two Accounts

### Setup
1. Create two test accounts (User A and User B)
2. Log in as User A in one browser/device
3. Log in as User B in incognito/another device

### Test Cases

#### Basic DM Flow
1. User A: Go to Swap Shop, view a listing owned by User B
2. User A: Click "Message" button
3. User A: Send a message → Should create conversation
4. User B: Check inbox → Should see conversation with unread badge
5. User B: Open conversation → Unread badge should clear
6. User B: Send reply → User A should see it via realtime

#### Same Thread Verification
1. User A: Message User B from Swap listing
2. User A: Message User B from Land listing
3. Verify: Both use the same conversation thread (subject context on messages differs)

#### RLS Verification (Database)
```sql
-- As User A, try to read User B's other conversations
-- Should return empty (RLS blocks)
SELECT * FROM messages WHERE conversation_id = '<user_b_other_convo>';

-- As User A, try to insert into a conversation they're not a member of
-- Should fail with RLS violation
INSERT INTO messages (conversation_id, sender_id, body)
VALUES ('<other_convo>', auth.uid(), 'test');
```

#### RPC Security Verification
```sql
-- Verify anon cannot call messaging RPCs
-- (Should fail with permission denied)
SET ROLE anon;
SELECT get_inbox();
```

### Mobile Testing
1. Test keyboard safe behavior - input should remain visible when keyboard opens
2. Test pull-to-refresh on inbox
3. Test pagination - scroll to top in long conversation to load older messages

## Troubleshooting

### "Not authenticated" error
- Ensure user is logged in before accessing messages
- Check that JWT is valid and not expired

### Messages not appearing in realtime
- Verify Realtime is enabled for the project
- Check that the subscription is for the correct conversation_id
- Inspect browser console for WebSocket errors

### Unread count not updating
- Call `ref.read(unreadCountProvider.notifier).refresh()` after marking read
- Verify `last_read_at` is being updated in the database

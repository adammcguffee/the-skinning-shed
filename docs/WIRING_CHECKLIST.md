# UI Wiring Checklist

> Dev-only checklist for ensuring all buttons, FABs, and primary actions are functional.
> Last updated: January 24, 2026

## Screens & Actions

### Auth Screen (`/auth`)
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Email Sign In | Authenticate via Supabase Auth | ✅ Wired |
| Email Sign Up | Create account via Supabase Auth | ✅ Wired |
| Keep Me Signed In toggle | Persist/clear session on app restart | ✅ Wired |

### Feed Screen (`/`)
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Category tabs (All/Deer/Turkey/etc) | Filter feed by category | ✅ Wired |
| Tap trophy card | Navigate to trophy detail | ✅ Wired |
| Pull to refresh | Reload feed | ✅ Wired |
| Like button | Toggle like on post | ✅ Wired |
| Comment button | Open trophy detail at comments | ✅ Wired |
| Share button | Native share sheet | ✅ Wired |

### Explore Screen (`/explore`)
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Species tiles | Navigate to feed filtered by species | ✅ Wired |
| Quick links | Navigate to destination | ✅ Wired |
| Trending items | Navigate to feed | ✅ Wired |

### Trophy Wall Screen (`/trophy-wall`, `/user/:id`)
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Edit profile button | Edit profile flow | ⚠️ Coming Soon |
| Trophy grid items | Navigate to trophy detail | ✅ Wired |
| Filter tabs | Filter by category | ✅ Wired |
| Follow button | Follow/unfollow user | ✅ Wired |
| Message button | Open DM with user | ✅ Wired |
| Followers count | Show followers list | ⚠️ Coming Soon |
| Following count | Show following list | ⚠️ Coming Soon |

### Trophy Detail Screen (`/trophy/:id`)
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Like button | Toggle like | ✅ Wired |
| Comment button | Focus comment input | ✅ Wired |
| Share button | Native share sheet | ✅ Wired |
| Report button | Open report modal | ✅ Wired |
| User avatar tap | Navigate to user profile | ✅ Wired |
| Submit comment | Post comment to trophy | ✅ Wired |
| Delete comment | Remove own comment | ✅ Wired |

### Post Trophy Screen (`/post`)
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Add photos | Pick from gallery | ✅ Wired |
| Remove photo | Remove from selection | ✅ Wired |
| Select species | Show species picker | ✅ Wired |
| Select state/county | Show location picker | ✅ Wired |
| Pick date | Show date picker | ✅ Wired |
| Pick time | Show time picker | ✅ Wired |
| Auto-fill weather | Fetch historical weather | ✅ Wired |
| Edit conditions | Update weather fields | ✅ Wired |
| Submit trophy | Create trophy + upload photos | ✅ Wired |

### Messages Screen (`/messages`)
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Pull to refresh | Reload inbox | ✅ Wired |
| Tap conversation | Open conversation thread | ✅ Wired |
| Unread badge | Show unread count | ✅ Wired |

### Conversation Screen (`/messages/:conversationId`)
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Send message | Post message to thread | ✅ Wired |
| Scroll to top | Load older messages | ✅ Wired |
| Real-time updates | Receive new messages | ✅ Wired |
| Mark read | Update last_read_at | ✅ Wired |
| Back button | Return to inbox | ✅ Wired |
| Keyboard shortcuts | Enter sends, Shift+Enter newline (web) | ✅ Wired |

### Weather Screen (`/weather`)
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Select location | Choose state/county | ✅ Wired |
| Tap hourly card | Show detail bottom sheet | ✅ Wired |
| Scroll hourly | Horizontal scroll | ✅ Wired |
| Star favorite | Toggle favorite location | ✅ Wired |
| Location chips | Quick switch location | ✅ Wired |

### Land Screen (`/land`)
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Lease/Sale tabs | Filter by type | ✅ Wired |
| Listing cards | Navigate to detail | ✅ Wired |
| Post listing FAB | Navigate to create | ✅ Wired |

### Land Detail Screen (`/land/:id`)
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Contact owner | Show contact info | ✅ Wired |
| Message owner | Open DM with owner | ✅ Wired |
| Back button | Return to listings | ✅ Wired |

### Land Create Screen (`/land/create`)
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Type toggle | Lease/Sale selection | ✅ Wired |
| Add photos | Pick from gallery | ✅ Wired |
| Location picker | Select state/county | ✅ Wired |
| Submit listing | Create land listing | ✅ Wired |

### Swap Shop Screen (`/swap-shop`)
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Category filter | Filter listings | ✅ Wired |
| Listing cards | Navigate to detail | ✅ Wired |
| Post listing FAB | Navigate to create | ✅ Wired |

### Swap Shop Detail Screen (`/swap-shop/detail/:id`)
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Contact seller | Show contact info | ✅ Wired |
| Message seller | Open DM with seller | ✅ Wired |
| Back button | Return to listings | ✅ Wired |

### Swap Shop Create Screen (`/swap-shop/create`)
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Category picker | Select category | ✅ Wired |
| Add photos | Pick from gallery | ✅ Wired |
| Condition picker | Select item condition | ✅ Wired |
| Submit listing | Create swap shop listing | ✅ Wired |

### Regulations Screen (`/regulations`)
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| State grid | Select state | ✅ Wired |
| Category tabs | Filter by deer/turkey/fishing | ✅ Wired |
| Search | Filter states | ✅ Wired |

### State Regulations Screen (`/regulations/:stateCode`)
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Category tabs | Switch deer/turkey/fishing | ✅ Wired |
| Back button | Return to state grid | ✅ Wired |
| Source link | Open official source | ✅ Wired |

### Research Screen (`/research`)
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Filter dropdowns | Update aggregation query | ✅ Wired |
| Pattern cards | Display counts (privacy gate ≥10) | ✅ Wired |
| Compare mode | Toggle comparison view | ✅ Wired |
| Insights panel | Show top performing conditions | ✅ Wired |

### Settings Screen (`/settings`)
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Account settings | Navigate to account | ⚠️ Coming Soon |
| Notification settings | Show notification prefs | ⚠️ Coming Soon |
| Privacy settings | Show privacy options | ⚠️ Coming Soon |
| Sign out | Sign out and return to auth | ✅ Wired |

### Admin Screens
| Screen | Action | Status |
|--------|--------|--------|
| `/admin/regulations` | Run regulations sync | ✅ Wired |

---

## Navigation

| Element | Expected Behavior | Status |
|---------|-------------------|--------|
| Bottom nav / Rail icons | Navigate to correct screen | ✅ Wired |
| Messages badge | Show unread count | ✅ Wired |
| Back buttons | Return to previous screen | ✅ Wired |
| Post FAB (global) | Navigate to post screen | ✅ Wired |
| Deep links | Handle routing | ⚠️ Needs Testing |

---

## Uploads

| Feature | Bucket | Path Convention | Status |
|---------|--------|-----------------|--------|
| Trophy photos | `trophy_photos` | `{userId}/{trophyId}/{filename}` | ✅ Wired |
| Avatar | `avatars` | `{userId}/avatar.{ext}` | ⚠️ Needs Impl |
| Land photos | `land_photos` | `{userId}/{listingId}/{filename}` | ✅ Wired |
| Swap Shop photos | `swap_shop_photos` | `{userId}/{listingId}/{filename}` | ✅ Wired |

---

## Legend

- ✅ **Wired** - Implemented and functional
- ⚠️ **Coming Soon** - Placeholder or needs implementation
- ❌ **Broken** - Known issue requiring fix

---

## Notes

- Prefer minimal functional implementation over placeholder buttons
- If a feature isn't ready, disable the button with "Coming soon" label
- No dead taps - every tappable element must do something
- All bottom sheets should use `isScrollControlled: true` and `useRootNavigator: true`

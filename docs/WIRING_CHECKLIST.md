# UI Wiring Checklist

> Dev-only checklist for ensuring all buttons, FABs, and primary actions are functional.
> Last updated: January 23, 2026

## Screens & Actions

### Auth Screen
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Email Sign In | Authenticate via Supabase Auth | ✅ Wired |
| Email Sign Up | Create account via Supabase Auth | ✅ Wired |
| Keep Me Signed In toggle | Persist/clear session on app restart | ✅ Wired |

### Feed Screen
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Category tabs (All/Deer/Turkey/etc) | Filter feed by category | ✅ Wired |
| Tap trophy card | Navigate to trophy detail | ✅ Wired |
| Share button | Shows "Coming soon" | ✅ Wired |
| Bookmark button | Shows "Coming soon" | ✅ Wired |

### Explore Screen
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Species tiles | Navigate to feed + snackbar | ✅ Wired |
| Quick links | Navigate to destination | ✅ Wired |
| Trending items | Navigate to feed | ✅ Wired |

### Trophy Wall Screen
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Edit profile button | Shows "Coming soon" | ✅ Wired |
| Trophy grid items | Navigate to trophy detail | ✅ Wired |
| Filter tabs | Filter by category | ✅ Wired |

### Post Trophy Screen
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

### Weather Screen
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Select location | Choose state/county | ✅ Wired |
| Tap hourly card | Show detail bottom sheet | ✅ Wired |
| Scroll hourly | Horizontal scroll | ✅ Wired |

### Land Screen
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Lease/Sale tabs | Filter by type | ✅ Wired |
| Listing cards | View listing info | 🚧 Placeholder data |
| Contact button | Shows "Coming soon" | ⚠️ Needs impl |
| Post listing FAB | Shows "Coming soon" | ⚠️ Needs impl |

### Swap Shop Screen
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Category filter | Filter listings | ✅ Wired |
| Listing cards | Shows listing info + contact snackbar | ✅ Wired |
| Post listing FAB | Shows "Coming soon" | ⚠️ Needs impl |

### Settings Screen
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| All settings items | Shows "Coming soon" | ✅ Wired |
| Sign out | Sign out and return to auth | ✅ Wired |

### Research Screen
| Action | Expected Behavior | Status |
|--------|-------------------|--------|
| Filter dropdowns | Update aggregation query | ✅ Wired |
| Pattern cards | Display counts (privacy gate ≥10) | ✅ Wired |

---

## Navigation

| Element | Expected Behavior | Status |
|---------|-------------------|--------|
| Bottom nav / Rail icons | Navigate to correct screen | ✅ Wired |
| Back buttons | Return to previous screen | ⚠️ Check |
| Post FAB (global) | Navigate to post screen | ✅ Wired |
| Deep links | Handle routing | ⚠️ Check |

---

## Uploads

| Feature | Bucket | Path Convention | Status |
|---------|--------|-----------------|--------|
| Trophy photos | `trophy_photos` | `{userId}/{trophyId}/{filename}` | ✅ Wired |
| Avatar | `avatars` | `{userId}/avatar.{ext}` | ⚠️ Check |
| Land photos | `land_photos` | `{userId}/{listingId}/{filename}` | ⚠️ Check |
| Swap Shop photos | `swap_shop_photos` | `{userId}/{listingId}/{filename}` | ⚠️ Check |

---

## Legend

- ✅ **Wired** - Implemented and functional
- ⚠️ **Check** - Needs verification or implementation
- ❌ **Broken** - Known issue
- 🚧 **Coming Soon** - Placeholder, intentionally disabled

---

## Notes

- Prefer minimal functional implementation over placeholder buttons
- If a feature isn't ready, disable the button with "Coming soon" label
- No dead taps - every tappable element must do something

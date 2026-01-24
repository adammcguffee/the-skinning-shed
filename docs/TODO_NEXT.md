# TODO Next

> Prioritized task list for The Skinning Shed
> Last updated: January 24, 2026

## Completed Features

- [x] **Auth System**: Email sign in/up, "Keep me signed in" toggle
- [x] **Supabase Bootstrap**: Initialization gate, client providers
- [x] **Trophy Posts**: Full CRUD, photo upload, weather auto-fill
- [x] **Weather Auto-Fill**: 3-tier API (forecast → historical → archive)
- [x] **Moon Phase**: USNO API integration with auto-fill
- [x] **County Coverage**: Full US county centroids (Census Gazetteer)
- [x] **Feed Screen**: Category tabs, trophy cards, infinite scroll
- [x] **Trophy Detail**: Full stats, weather, moon phase display
- [x] **Trophy Wall / Profile**: User profile + trophy grid
- [x] **Social System**: Likes, comments, follows
- [x] **DM Messenger**: 1:1 conversations, realtime, inbox + threads
- [x] **Land Listings**: Create/view lease and sale listings
- [x] **Swap Shop**: Marketplace with categories, contact seller
- [x] **Regulations**: State selector, season/limit display
- [x] **Regulations Edge Function**: Auto-fetch and parse state PDFs
- [x] **Research / Analytics**: Pattern data with privacy threshold
- [x] **Weather Screen**: Location picker, favorites sync, hourly forecast
- [x] **Weather Favorites**: Cross-device sync via Supabase
- [x] **Ads System**: Header slots, page targeting, scheduling
- [x] **Navigation**: 9-item nav with Messages unread badge

---

## Priority 1: QA & Polish

- [ ] **End-to-End QA**
  - [ ] Trophy post flow: create → feed display → detail view
  - [ ] DM flow: message from listing → inbox → thread
  - [ ] Social flow: like → comment → follow → view profile
  - [ ] Land/Swap: create listing → view → contact
  - [ ] Test on web, iOS simulator, Android emulator

- [ ] **Bug Fixes**
  - [ ] Verify all bottom sheets use `isScrollControlled: true`
  - [ ] Check all modals use `useRootNavigator: true`
  - [ ] Fix any overflow issues on small screens

---

## Priority 2: Profile & Settings

- [ ] **Profile Editing**
  - [ ] Avatar upload
  - [ ] Display name editing
  - [ ] Bio editing
  - [ ] Default location setting

- [ ] **Settings Screen**
  - [ ] Notification preferences (placeholder)
  - [ ] Privacy settings (placeholder)
  - [ ] Account management
  - [ ] Sign out working (✅ done)

---

## Priority 3: Ads & Monetization

- [ ] **Ad Smoke Test**
  - [ ] Upload test PNG to `ad_share/feed/left.png`
  - [ ] Verify ad_slots row exists (feed, left, enabled)
  - [ ] Verify ad renders on Feed (desktop)
  - [ ] Verify click opens URL
  - [ ] Verify mobile hides ads

- [ ] **Additional Ad Slots**
  - [ ] Weather page ads
  - [ ] Trophy wall ads
  - [ ] Test scheduling (starts_at, ends_at)

---

## Priority 4: Regulations Enhancement

- [ ] **Regulations Sync**
  - [ ] Deploy regulations-check Edge Function
  - [ ] Run initial sync for all 50 states
  - [ ] Admin UI: approve/reject pending updates
  - [ ] Display approved regulations in UI

- [ ] **Source Management**
  - [ ] Add more state sources to seed data
  - [ ] Set up scheduled function runs

---

## Priority 5: Performance & Polish

- [ ] **Performance Audit**
  - [ ] Profile app startup time
  - [ ] Image loading optimization
  - [ ] Lazy loading for lists
  - [ ] Caching review

- [ ] **UI Polish**
  - [ ] Skeleton loaders for feed items
  - [ ] Loading indicators on all buttons during async
  - [ ] Pull-to-refresh everywhere appropriate
  - [ ] Error states with retry buttons

- [ ] **Accessibility**
  - [ ] Semantic labels on all interactive elements
  - [ ] Verify contrast ratios
  - [ ] Screen reader testing

---

## Backlog (Lower Priority)

- [ ] Push notifications
- [ ] Offline mode / local caching
- [ ] Social sharing (native share sheet)
- [ ] Admin moderation dashboard
- [ ] Click analytics for ads
- [ ] Dark/light theme toggle
- [ ] Localization support
- [ ] Group DMs (expand messaging)
- [ ] Search functionality
- [ ] Trending/popular feed algorithm

---

## Known Issues

1. **Pre-existing linter warnings** - Various unused imports/variables in non-critical files
2. **Regulations data** - Edge Function needs deployment and initial run
3. **Ad creatives** - No test ads uploaded yet

---

*Update this list as tasks are completed or priorities change.*

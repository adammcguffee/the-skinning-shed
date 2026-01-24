# TODO Next

> Prioritized task list for The Skinning Shed

## Priority 1: Core Functionality

- [ ] **Verify trophy post end-to-end**
  - [ ] Photo selection works on web/mobile
  - [ ] Photos upload to `trophy_photos` bucket
  - [ ] `trophy_posts` row created with all fields
  - [ ] `weather_snapshots` row created with correct columns
  - [ ] `moon_snapshots` row created
  - [ ] `analytics_buckets` row created
  - [ ] Feed displays new trophy with photo

- [ ] **Photo display in feed**
  - [ ] Cover photo renders correctly
  - [ ] Fallback for missing photos
  - [ ] Image loading states

## Priority 2: UI Polish

- [ ] **Responsive audit**
  - [ ] All bottom sheets use `isScrollControlled: true`
  - [ ] All dialogs fit on small screens
  - [ ] No overflow errors on any breakpoint
  - [ ] Test: mobile (360px), tablet (768px), desktop (1280px)

- [ ] **Loading states**
  - [ ] Skeleton loaders for feed items
  - [ ] Loading indicators on buttons during async
  - [ ] Pull-to-refresh where appropriate

- [ ] **Error states**
  - [ ] User-friendly error messages
  - [ ] Retry buttons on failures
  - [ ] Offline detection

## Priority 3: Research & Analytics

- [ ] **Research patterns screen**
  - [ ] Moon phase aggregation working
  - [ ] Pressure aggregation working
  - [ ] Temperature aggregation working
  - [ ] Time-of-day aggregation working
  - [ ] Privacy threshold (count >= 10) enforced

- [ ] **Lift vs baseline**
  - [ ] Calculate baseline success rate
  - [ ] Show lift percentage per bin
  - [ ] Visual indicators (green/red)

- [ ] **Filters**
  - [ ] Species/category filter
  - [ ] Date range filter
  - [ ] State/region filter

## Priority 4: Ads System

- [ ] **Smoke test**
  - [ ] Upload test PNG to `ad_share/feed/left.png`
  - [ ] Verify ad_slots row exists (feed, left, enabled)
  - [ ] Verify ad renders on Feed (desktop)
  - [ ] Verify click opens URL
  - [ ] Verify mobile hides ads

- [ ] **Additional slots**
  - [ ] Add test ads for other pages (weather, trophy_wall)
  - [ ] Test scheduling (starts_at, ends_at)

## Priority 5: Profile & Settings

- [ ] **Profile screen**
  - [ ] Avatar upload
  - [ ] Display name editing
  - [ ] Bio/description

- [ ] **Settings screen**
  - [ ] Notification preferences
  - [ ] Privacy settings
  - [ ] Account management
  - [ ] Sign out working

- [ ] **Trophy wall**
  - [ ] User's own trophies displayed
  - [ ] Edit/delete functionality
  - [ ] Sorting options

## Priority 6: Remaining Screens

- [ ] **Land listings**
  - [ ] List view with filters
  - [ ] Detail view
  - [ ] Contact seller

- [ ] **Swap shop**
  - [ ] List view
  - [ ] Post item flow
  - [ ] Messaging/contact

- [ ] **Explore**
  - [ ] Discovery feed
  - [ ] Search functionality
  - [ ] Trending/popular

## Priority 7: Polish & QA

- [ ] **Performance**
  - [ ] Image optimization
  - [ ] Lazy loading
  - [ ] Caching review

- [ ] **Accessibility**
  - [ ] Semantic labels
  - [ ] Contrast ratios
  - [ ] Screen reader testing

- [ ] **Testing**
  - [ ] Unit tests for services
  - [ ] Widget tests for key screens
  - [ ] Integration tests for flows

## Backlog (Lower Priority)

- [ ] Backfill weather/moon for existing trophies
- [ ] Admin UI for ad management
- [ ] Click analytics for ads
- [ ] Push notifications
- [ ] Social sharing
- [ ] Dark/light theme toggle
- [ ] Localization support

## Completed

- [x] Supabase initialization gate (BootstrapScreen)
- [x] Weather auto-fill 3-tier API selection
- [x] County centroid full US coverage (Census Gazetteer)
- [x] Ad slots system (table + bucket + widget)
- [x] Bootstrap Directionality fix
- [x] uploadBinary Uint8List fix
- [x] Swap shop record access fix
- [x] Ad bucket public mode configuration

---

*Update this list as tasks are completed or priorities change.*

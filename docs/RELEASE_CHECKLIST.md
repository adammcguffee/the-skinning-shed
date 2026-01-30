# Release Checklist — The Skinning Shed

**Purpose:** QA checklist before iOS/Android/Web releases  
**Last Updated:** 2026-01-29

---

## Pre-Release Checklist

### 1. Legal & Compliance

- [ ] **Terms of Service** renders correctly at `/settings/terms` and `/terms`
- [ ] **Privacy Policy** renders correctly at `/settings/privacy` and `/privacy`
- [ ] **Copyright page** renders correctly at `/settings/copyright` and `/copyright`
- [ ] Footer legal links work in "More" menu (mobile)
- [ ] Settings > Legal section shows all 4 items
- [ ] Copyright year is current (dynamic)

### 2. Authentication

- [ ] Sign up with email works
- [ ] Sign in with existing account works
- [ ] Password reset email is sent
- [ ] Sign out clears session and redirects to auth
- [ ] Username selection flow works for new users
- [ ] Deep links redirect to intended route after login

### 3. User Data Privacy

- [ ] User A **cannot** view User B's private posts
- [ ] User A **cannot** edit User B's profile
- [ ] User A **cannot** delete User B's listings
- [ ] Email addresses are **never** shown publicly
- [ ] User can delete their own account
- [ ] Profile edit saves correctly

### 4. Club Privacy (Critical)

- [ ] Non-member **cannot** see club posts
- [ ] Non-member **cannot** see club photos
- [ ] Non-member **cannot** see stand locations
- [ ] Non-member **cannot** see stand activity
- [ ] Non-member **cannot** see member list details
- [ ] Non-member **can** see public club info (name, description)
- [ ] Member **can** see all club content
- [ ] Member **can** post and comment
- [ ] Admin **can** manage stands and members
- [ ] Admin **can** invite new members
- [ ] Owner **can** edit club settings
- [ ] Owner **can** delete/archive club

### 5. Messaging Privacy

- [ ] User A **cannot** view User B's conversations
- [ ] Cannot send messages to threads you're not in
- [ ] Notifications only show for your messages
- [ ] Unread count updates correctly
- [ ] Message notifications appear in bell

### 6. Admin Access Control

- [ ] Non-admin **cannot** access `/admin/*` routes (redirects to /)
- [ ] Non-admin **cannot** see Admin section in Settings
- [ ] Admin **can** access Reports page
- [ ] Admin **can** access Official Links Admin
- [ ] Admin **can** see debug tools (in debug mode)

### 7. Notifications

- [ ] Notification bell appears on all screens
- [ ] Unread count badge shows correctly
- [ ] Tapping notification navigates to correct route
- [ ] Mark as read works
- [ ] Mark all as read works
- [ ] Delete notification works
- [ ] Club invite notifications appear
- [ ] Like notifications appear
- [ ] Comment notifications appear
- [ ] Message notifications appear

### 8. Invite Links

- [ ] Invite link generation works (Share Link tab)
- [ ] Copy invite link works
- [ ] SMS share opens messaging app with link
- [ ] Clicking invite link when **signed in** → ClubJoinScreen
- [ ] Clicking invite link when **signed out** → Auth → ClubJoinScreen after login
- [ ] Join Club button works
- [ ] Invalid/expired token shows error

### 9. Content Features

- [ ] Trophy post creation works
- [ ] Photo upload works (trophy, listing, profile)
- [ ] Swap Shop listing creation works
- [ ] Land listing creation works
- [ ] Club creation works
- [ ] Opening creation works
- [ ] Edit flows work for owned content
- [ ] Delete flows work for owned content

### 10. Storage & Photos

- [ ] Profile avatar upload works
- [ ] Trophy photo upload works
- [ ] Club photo upload works
- [ ] Photos display correctly
- [ ] File size limits enforced (shows error for oversized files)
- [ ] Only image types accepted

### 11. Mobile Layouts

- [ ] Feed renders correctly on mobile
- [ ] Bottom nav works
- [ ] More menu opens and shows all items
- [ ] Legal links appear in More menu footer
- [ ] FAB (create button) works
- [ ] Trophy Wall renders correctly
- [ ] Club detail renders correctly
- [ ] Settings renders correctly
- [ ] All modals/sheets fit screen

### 12. Desktop/Tablet Layouts

- [ ] Nav rail appears on wide screens
- [ ] Content area respects max-width
- [ ] Header renders correctly
- [ ] Ad slots appear (if enabled)
- [ ] All features accessible

### 13. Routing & Navigation

- [ ] All main nav items work (Feed, Explore, Discover, etc.)
- [ ] Back navigation works
- [ ] Deep links work (`/trophy/:id`, `/clubs/:id`, etc.)
- [ ] Hash routing works (`/#/clubs/join/:token`)
- [ ] 404s handled gracefully

### 14. Error Handling

- [ ] Network errors show user-friendly message
- [ ] Form validation errors display
- [ ] Auth errors display correctly
- [ ] Permission denied handled gracefully

### 15. Performance

- [ ] Initial load time < 5 seconds
- [ ] Navigation transitions smooth
- [ ] Lists scroll smoothly
- [ ] Images load progressively
- [ ] No obvious memory leaks

---

## Platform-Specific Checks

### iOS

- [ ] App installs from TestFlight
- [ ] Push notifications work (if enabled)
- [ ] Safe area insets respected
- [ ] Keyboard doesn't cover inputs
- [ ] Gestures work (swipe back, pull to refresh)

### Android

- [ ] App installs from Play Store / APK
- [ ] Push notifications work (if enabled)
- [ ] Back button works correctly
- [ ] Keyboard doesn't cover inputs
- [ ] Material Design elements render

### Web

- [ ] Deploys to Vercel successfully
- [ ] SPA routing works (no 404 on refresh)
- [ ] Hash routing works
- [ ] OG meta tags render (check with social debugger)
- [ ] Favicon shows
- [ ] PWA manifest loads

---

## Security Verification

### Before Each Release

Run through [SECURITY_AUDIT.md](./SECURITY_AUDIT.md) manual test checklist:

- [ ] User data isolation tests pass
- [ ] Club isolation tests pass
- [ ] Admin access tests pass
- [ ] No secrets in client code
- [ ] No sensitive data logging

### Environment Check

- [ ] Production Supabase URL configured
- [ ] Production anon key configured
- [ ] No debug flags enabled in release
- [ ] Source maps not included

---

## Deployment Steps

### Web (Vercel)

1. Push to `main` branch
2. Vercel auto-deploys
3. Verify at https://www.theskinningshed.com
4. Check OG preview: https://www.theskinningshed.com/og-image.png
5. Test invite link: https://www.theskinningshed.com/?v=test

### iOS (App Store)

1. Run `flutter build ios --release`
2. Archive in Xcode
3. Upload to App Store Connect
4. Submit for review
5. Monitor TestFlight feedback

### Android (Play Store)

1. Run `flutter build appbundle --release`
2. Upload to Play Console
3. Submit for review
4. Monitor internal testing feedback

---

## Post-Release Monitoring

- [ ] Check error reporting dashboard
- [ ] Monitor user feedback
- [ ] Check analytics for anomalies
- [ ] Review support emails
- [ ] Monitor server performance

---

## Rollback Plan

If critical issues found:

### Web
- Revert to previous Vercel deployment via dashboard

### iOS
- Submit expedited review with fix
- Or: halt rollout in App Store Connect

### Android
- Halt rollout in Play Console
- Push hotfix or revert

---

## Sign-off

| Role | Name | Date | Approved |
|------|------|------|----------|
| Developer | | | [ ] |
| QA | | | [ ] |
| Product | | | [ ] |

---

*Checklist version: 1.0*

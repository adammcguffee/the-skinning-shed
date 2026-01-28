# Legal & Privacy Checklist — The Skinning Shed

**Review Date:** 2026-01-28  
**Status:** ✅ COMPLETE

---

## 1. LEGAL PAGES

### Terms of Service

| Item | Status | Location |
|------|--------|----------|
| Page exists | ✅ | `/settings/terms` |
| Accessible from Settings | ✅ | Settings → Legal → Terms of Service |
| Deep link works | ✅ | https://theskinningshed.com/settings/terms |
| Last updated date | ✅ | January 2026 |
| No placeholders | ✅ | Full original content |

**Content Covers:**
- ✅ Agreement acceptance
- ✅ User accounts (age requirement, security)
- ✅ User-generated content ownership
- ✅ Prohibited content list
- ✅ Swap Shop marketplace disclaimer
- ✅ Land listings disclaimer
- ✅ Account termination policy
- ✅ Limitation of liability
- ✅ Changes to terms notice
- ✅ Contact information

### Privacy Policy

| Item | Status | Location |
|------|--------|----------|
| Page exists | ✅ | `/settings/privacy` |
| Accessible from Settings | ✅ | Settings → Legal → Privacy Policy |
| Deep link works | ✅ | https://theskinningshed.com/settings/privacy |
| Last updated date | ✅ | January 2026 |
| No placeholders | ✅ | Full original content |

**Content Covers:**
- ✅ Information collected (account, content, location, usage)
- ✅ How information is used
- ✅ What we don't do (sell data, track GPS, share email)
- ✅ Public vs private content explanation
- ✅ Data storage & security
- ✅ User rights (edit, delete, data export)
- ✅ Third-party services disclosure
- ✅ Contact information

### Content Disclaimer

| Item | Status | Location |
|------|--------|----------|
| Page exists | ✅ | `/settings/disclaimer` |
| Accessible from Settings | ✅ | Settings → Legal → Disclaimer |
| Deep link works | ✅ | https://theskinningshed.com/settings/disclaimer |
| No placeholders | ✅ | Full original content |

**Required Disclaimers:**
- ✅ "Not affiliated with state wildlife agencies"
- ✅ "No legal or regulatory advice"
- ✅ "User-generated content responsibility"
- ✅ Marketplace transaction disclaimer
- ✅ Land listings disclaimer
- ✅ Weather data disclaimer
- ✅ No professional advice disclaimer

---

## 2. SUPPORT & CONTACT

| Item | Status | Details |
|------|--------|---------|
| Support email | ✅ | support@theskinningshed.com |
| Feedback page | ✅ | `/settings/feedback` |
| Help center | ✅ | `/settings/help` |
| About page | ✅ | `/settings/about` |

---

## 3. DOMAIN & URLs

| URL | Purpose | Status |
|-----|---------|--------|
| https://theskinningshed.com | Production domain | ✅ Configured |
| https://theskinningshed.com/settings/terms | Terms of Service | ✅ Works |
| https://theskinningshed.com/settings/privacy | Privacy Policy | ✅ Works |
| https://theskinningshed.com/settings/disclaimer | Disclaimer | ✅ Works |

---

## 4. NAVIGATION PATHS

### From Settings Screen

```
Settings
└── Legal
    ├── Terms of Service → /settings/terms
    ├── Privacy Policy → /settings/privacy
    └── Disclaimer → /settings/disclaimer
```

### Route Definitions (router.dart)

```dart
GoRoute(path: '/settings/privacy', ...),
GoRoute(path: '/settings/terms', ...),
GoRoute(path: '/settings/disclaimer', ...),
```

---

## 5. THIRD-PARTY ATTRIBUTIONS

| Service | Purpose | Disclosed |
|---------|---------|-----------|
| Supabase | Authentication & Database | ✅ Privacy Policy |
| Open-Meteo | Weather API | ✅ Privacy Policy |
| State Wildlife Agencies | Official Links | ✅ Disclaimer |

---

## 6. DATA HANDLING DISCLOSURES

### Collected Data

| Data Type | Disclosed | Location |
|-----------|-----------|----------|
| Email address | ✅ | Privacy Policy |
| Display name | ✅ | Privacy Policy |
| Profile bio | ✅ | Privacy Policy |
| State/county | ✅ | Privacy Policy |
| Trophy photos | ✅ | Privacy Policy |
| Listing photos | ✅ | Privacy Policy |
| Messages | ✅ | Privacy Policy |

### Not Collected

| Data Type | Disclosed |
|-----------|-----------|
| GPS coordinates | ✅ "We do not track precise location" |
| Payment info | ✅ Not collected (no in-app purchases) |
| Device identifiers | ✅ Only basic analytics |

---

## 7. COMPLIANCE NOTES

### Age Requirement
- ✅ Minimum age 13 stated in Terms of Service

### Content Moderation
- ✅ Prohibited content list in Terms
- ✅ Report functionality available
- ✅ Account termination policy

### Firearms Disclaimer
- ✅ "Firearms transactions must comply with federal, state, and local laws"

### Not a Broker
- ✅ "We are not a licensed real estate broker" in Terms and Disclaimer

---

## 8. CHECKLIST SUMMARY

| Category | Status |
|----------|--------|
| Terms of Service | ✅ Complete |
| Privacy Policy | ✅ Complete |
| Content Disclaimer | ✅ Complete |
| Support Contact | ✅ Available |
| Deep Links | ✅ Working |
| No Placeholders | ✅ Verified |
| Attributions | ✅ Included |

---

**Legal Status: ✅ PRODUCTION READY**

All required legal pages are present, accessible, and contain original, appropriate content for a hunting/fishing community app.

---

*Last reviewed: 2026-01-28*

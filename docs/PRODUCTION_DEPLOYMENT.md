# Production Deployment — theskinningshed.com

## Overview

This guide covers deploying The Skinning Shed to production at `https://theskinningshed.com`.

**Domain Registrar:** Namecheap  
**Recommended Hosting:** Vercel (free tier supports custom domains, automatic HTTPS)  
**Backend:** Supabase (already configured)

---

## Step 1: Deploy to Vercel

### Option A: Deploy via Vercel CLI

```bash
# Install Vercel CLI
npm i -g vercel

# Navigate to app directory
cd app

# Build Flutter web with production credentials
flutter build web --release \
  --dart-define=SUPABASE_URL=https://ssrlhrydcetpspmdphfo.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNzcmxocnlkY2V0cHNwbWRwaGZvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkxMjYzMTUsImV4cCI6MjA4NDcwMjMxNX0.NI9dxnyHfOj9Ck5VVKnnCE7TxUwrImZ5TI3BjlYT1kQ

# Deploy to Vercel
cd build/web
vercel --prod
```

### Option B: Deploy via Vercel Dashboard

1. Go to https://vercel.com/new
2. Import from GitHub (or upload build/web folder)
3. Set Framework Preset to "Other"
4. Output Directory: `app/build/web`
5. Deploy

After deployment, Vercel will provide a URL like:
- `the-skinning-shed.vercel.app` (or similar)

### Add Custom Domain in Vercel

1. Go to Project Settings → Domains
2. Add `theskinningshed.com`
3. Add `www.theskinningshed.com`
4. Note the CNAME/A records Vercel shows you

---

## Step 2: Namecheap DNS Configuration

### DNS Records to Add

Go to Namecheap → Domain List → Manage → Advanced DNS

**Delete any existing A, AAAA, or CNAME records for @ and www first.**

Then add these records:

| Type | Host | Value | TTL |
|------|------|-------|-----|
| A | @ | `76.76.21.21` | Automatic |
| CNAME | www | `cname.vercel-dns.com` | Automatic |

> **Note:** The A record IP `76.76.21.21` is Vercel's anycast IP. Vercel will provide this when you add your domain.

### Alternative: If Vercel provides different records

Vercel may provide:
- Different IP for A record
- A specific CNAME target

**Always use the exact values Vercel shows in their dashboard.**

### Redirect Configuration

**Recommended:** Root domain (`theskinningshed.com`) as primary

In Vercel Dashboard → Project → Settings → Domains:
- Set `theskinningshed.com` as primary
- Enable "Redirect www to non-www"

This ensures:
- `www.theskinningshed.com` → redirects to `theskinningshed.com`
- All traffic uses the clean root domain
- SEO benefits from single canonical URL

---

## Step 3: Supabase Configuration

### Auth Settings (Dashboard → Authentication → URL Configuration)

Update these settings in the Supabase Dashboard:

| Setting | Value |
|---------|-------|
| Site URL | `https://theskinningshed.com` |
| Redirect URLs | See list below |

**Redirect URLs (one per line):**
```
https://theskinningshed.com
https://theskinningshed.com/**
https://www.theskinningshed.com
https://www.theskinningshed.com/**
http://localhost:3000
http://localhost:3000/**
```

> Keep localhost entries for development!

### Email Templates (if using email auth)

Update any hardcoded URLs in email templates:
- Dashboard → Authentication → Email Templates
- Replace any `localhost` or old URLs with `https://theskinningshed.com`

### Storage CORS (Already Public)

All storage buckets are already public. No CORS changes needed for:
- avatars
- trophy_photos
- land_photos
- swap_shop_photos
- ad_share
- record_photos

---

## Step 4: Environment Variables

### For CI/CD or Vercel Environment Variables

If deploying via Vercel's git integration, set these env vars in Vercel Dashboard:

| Variable | Value |
|----------|-------|
| `SUPABASE_URL` | `https://ssrlhrydcetpspmdphfo.supabase.co` |
| `SUPABASE_ANON_KEY` | `eyJhbGciOiJI...` (full key) |

### Build Command (if using Vercel git integration)

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

---

## Step 5: Verification Checklist

After DNS propagates (usually 5-30 minutes, up to 48 hours):

### URLs to Test

- [ ] `https://theskinningshed.com` — loads app
- [ ] `https://www.theskinningshed.com` — redirects to root
- [ ] `https://theskinningshed.com/trophy-wall` — deep link works
- [ ] `https://theskinningshed.com/swap-shop` — deep link works
- [ ] `https://theskinningshed.com/settings` — deep link works

### Functionality Tests

- [ ] Sign up / Sign in works
- [ ] Profile photo upload works
- [ ] Trophy photo upload works
- [ ] Share links copy correct URL
- [ ] No mixed-content warnings in console
- [ ] Browser tab shows "The Skinning Shed"
- [ ] Favicon displays correctly

### SEO Tests

- [ ] View page source shows meta tags
- [ ] Open Graph preview works (use https://www.opengraph.xyz/)
- [ ] Twitter card preview works (use https://cards-dev.twitter.com/validator)

---

## Troubleshooting

### DNS Not Propagating

- Use https://dnschecker.org to check propagation
- Try flushing local DNS: `ipconfig /flushdns` (Windows) or `sudo dscacheutil -flushcache` (Mac)

### 404 on Refresh

If you see 404 when refreshing on a deep link:
- Ensure `vercel.json` rewrites are correct
- For Netlify: ensure `_redirects` file is in build output

### Auth Redirect Issues

If OAuth or magic links fail:
- Check Supabase Dashboard → Auth → URL Configuration
- Ensure redirect URLs include `/**` wildcards
- Check browser console for redirect URL mismatch errors

### Mixed Content Warnings

If you see mixed content (http vs https):
- Check for hardcoded `http://` URLs in code
- All Supabase storage URLs are already HTTPS

---

## Quick Reference

| Service | URL |
|---------|-----|
| Production App | https://theskinningshed.com |
| Supabase Dashboard | https://supabase.com/dashboard/project/ssrlhrydcetpspmdphfo |
| Vercel Dashboard | https://vercel.com/dashboard |
| Namecheap DNS | https://ap.www.namecheap.com |

---

*Last updated: 2026-01-28*

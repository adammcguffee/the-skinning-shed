# Production Deployment — theskinningshed.com

## Overview

This guide covers deploying The Skinning Shed to production for **Web, iOS, and Android**.

| Platform | Domain/Identifier |
|----------|-------------------|
| **Web** | https://theskinningshed.com |
| **iOS** | Bundle ID: `com.theskinning.shed` |
| **Android** | Application ID: `com.theskinning.shed` |

**Domain Registrar:** Namecheap  
**Web Hosting:** Vercel (static deploy from `vercel-dist` branch)  
**CI/CD:** GitHub Actions  
**Backend:** Supabase

---

# PART 1: WEB DEPLOYMENT (GitHub Actions → Vercel)

## Architecture

```
┌─────────────────┐      ┌──────────────────┐      ┌─────────────────┐
│  Push to main   │ ───▶ │  GitHub Actions  │ ───▶ │  vercel-dist    │
│  (source code)  │      │  (Flutter build) │      │  (static files) │
└─────────────────┘      └──────────────────┘      └────────┬────────┘
                                                            │
                                                            ▼
                                                   ┌─────────────────┐
                                                   │     Vercel      │
                                                   │ (auto-deploys)  │
                                                   └─────────────────┘
```

**How it works:**
1. You push code to `main` branch
2. GitHub Actions automatically builds Flutter web
3. Built files are pushed to `vercel-dist` branch
4. Vercel auto-deploys from `vercel-dist` (no Flutter needed on Vercel!)

---

## Step 1: Set Up GitHub Secrets

Go to **GitHub → Repository → Settings → Secrets and variables → Actions → New repository secret**

Add these secrets:

| Secret Name | Value |
|-------------|-------|
| `SUPABASE_URL` | `https://ssrlhrydcetpspmdphfo.supabase.co` |
| `SUPABASE_ANON_KEY` | Your Supabase anon key (starts with `eyJ...`) |

> ⚠️ **Never commit these values to git!** The workflow reads them from GitHub Secrets.

---

## Step 2: Connect Vercel to `vercel-dist` Branch

### Option A: New Project (Recommended)

1. Go to https://vercel.com/new
2. Import your GitHub repository
3. **IMPORTANT:** In "Configure Project":
   - **Branch:** Select `vercel-dist` (not `main`)
   - **Framework Preset:** `Other`
   - **Build Command:** Leave empty (no build needed)
   - **Output Directory:** `.` (root of branch)
   - **Install Command:** Leave empty
4. Click Deploy

### Option B: Existing Project

1. Go to Vercel Dashboard → Your Project → Settings → Git
2. Change **Production Branch** to `vercel-dist`
3. Set **Build & Output Settings:**
   - Build Command: (leave empty)
   - Output Directory: `.`
   - Install Command: (leave empty)
4. Trigger a redeployment

---

## Step 3: Add Custom Domain in Vercel

1. Go to Project Settings → Domains
2. Add `theskinningshed.com`
3. Add `www.theskinningshed.com`
4. Note the CNAME/A records Vercel shows

---

## Step 4: Trigger First Build

Push any commit to `main`, or manually trigger the workflow:

```bash
# Option 1: Push to main
git commit --allow-empty -m "trigger build"
git push origin main

# Option 2: Manual trigger
# Go to GitHub → Actions → "Build Flutter Web" → Run workflow
```

The workflow will:
1. Build Flutter web with your Supabase credentials
2. Push built files to `vercel-dist` branch
3. Vercel auto-deploys within ~30 seconds

---

## How Updates Flow

```
1. Developer pushes to main
           ↓
2. GitHub Actions detects push
           ↓
3. Workflow runs (~2-3 minutes):
   - Checkout code
   - Setup Flutter
   - flutter pub get
   - flutter build web --release --dart-define=...
   - Push build/web/* to vercel-dist branch
           ↓
4. Vercel detects vercel-dist update
           ↓
5. Vercel deploys static files (~30 seconds)
           ↓
6. Site is live at theskinningshed.com
```

---

## Manual Build (Alternative)

If you need to deploy manually without GitHub Actions:

```bash
cd app

# Build Flutter web
flutter build web --release \
  --dart-define=SUPABASE_URL=https://ssrlhrydcetpspmdphfo.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-key>

# Deploy directly to Vercel
cd build/web
npx vercel --prod
```

---

## Step 2: Namecheap DNS Configuration

### DNS Records to Add

Go to **Namecheap → Domain List → Manage → Advanced DNS**

**Delete any existing A, AAAA, or CNAME records for @ and www first.**

| Type | Host | Value | TTL |
|------|------|-------|-----|
| **A** | `@` | `76.76.21.21` | Automatic |
| **CNAME** | `www` | `cname.vercel-dns.com` | Automatic |

> The A record IP `76.76.21.21` is Vercel's anycast IP. Use exact values from Vercel dashboard if different.

### Redirect Strategy

**Root domain as primary** (recommended):
- In Vercel Dashboard → Domains → Set `theskinningshed.com` as primary
- Enable "Redirect www to non-www"

---

## Step 3: Supabase Configuration

### Auth Settings (Dashboard → Authentication → URL Configuration)

| Setting | Value |
|---------|-------|
| Site URL | `https://theskinningshed.com` |

**Redirect URLs (one per line):**
```
https://theskinningshed.com
https://theskinningshed.com/**
https://www.theskinningshed.com
https://www.theskinningshed.com/**
com.theskinning.shed://callback
http://localhost:3000
http://localhost:3000/**
```

> Keep localhost for dev, `com.theskinning.shed://callback` for mobile OAuth.

---

# PART 2: iOS DEPLOYMENT

## iOS Configuration Summary

| Setting | Value |
|---------|-------|
| Bundle ID | `com.theskinning.shed` |
| Display Name | `The Skinning Shed` |
| Version | `1.0.0` (from pubspec.yaml) |
| Build Number | `1` (increment for each release) |
| Min iOS Version | `13.0` |

## iOS Permissions (Info.plist)

Already configured:
- ✅ `NSPhotoLibraryUsageDescription` — Photo library access for uploads
- ✅ `NSPhotoLibraryAddUsageDescription` — Save photos to library
- ✅ `NSCameraUsageDescription` — Camera for trophy photos
- ✅ `NSLocationWhenInUseUsageDescription` — Location for weather

## iOS Build Commands

```bash
cd app

# Debug build (simulator)
flutter build ios --debug

# Release build (requires Mac + Xcode + Apple Developer account)
flutter build ios --release \
  --dart-define=SUPABASE_URL=https://ssrlhrydcetpspmdphfo.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-key>

# Archive for App Store (run in Xcode after flutter build)
# Xcode → Product → Archive
```

## iOS Deep Links (Optional)

To enable Universal Links (opening theskinningshed.com URLs in the app):

1. Add Associated Domains capability in Xcode:
   - Target → Signing & Capabilities → + Capability → Associated Domains
   - Add: `applinks:theskinningshed.com`

2. Host `apple-app-site-association` file at:
   `https://theskinningshed.com/.well-known/apple-app-site-association`

   ```json
   {
     "applinks": {
       "apps": [],
       "details": [
         {
           "appID": "TEAMID.com.theskinning.shed",
           "paths": ["*"]
         }
       ]
     }
   }
   ```

   Replace `TEAMID` with your Apple Developer Team ID.

---

# PART 3: ANDROID DEPLOYMENT

## Android Configuration Summary

| Setting | Value |
|---------|-------|
| Application ID | `com.theskinning.shed` |
| App Name | `The Skinning Shed` |
| Version Name | `1.0.0` (from pubspec.yaml) |
| Version Code | `1` (increment for each release) |
| Min SDK | `21` (Android 5.0) |
| Target SDK | `34` (Android 14) |

## Android Permissions (AndroidManifest.xml)

Already configured:
- ✅ `INTERNET` — API calls
- ✅ `ACCESS_FINE_LOCATION` — GPS for weather
- ✅ `ACCESS_COARSE_LOCATION` — Network location

Photo/camera permissions are handled by Flutter plugins automatically.

## Android Deep Links

Already configured in AndroidManifest.xml:
- ✅ `https://theskinningshed.com/*`
- ✅ `https://www.theskinningshed.com/*`
- ✅ `com.theskinning.shed://callback` (OAuth)

## Android Build Commands

```bash
cd app

# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://ssrlhrydcetpspmdphfo.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-key>

# Release App Bundle (for Play Store)
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://ssrlhrydcetpspmdphfo.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-key>
```

## Android Signing (Production)

For Play Store release, create a signing config:

1. Generate keystore:
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Create `android/key.properties` (DO NOT commit to git):
   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=upload
   storeFile=/path/to/upload-keystore.jks
   ```

3. Update `android/app/build.gradle.kts` to use the keystore for release builds.

---

# PART 4: ENVIRONMENT CONFIGURATION

## Environment Variables

All platforms use `--dart-define` for build-time configuration:

| Variable | Description |
|----------|-------------|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase anonymous/public key |

## Build Commands by Platform

### Web
```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://ssrlhrydcetpspmdphfo.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<key>
```

### Android
```bash
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://ssrlhrydcetpspmdphfo.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<key>
```

### iOS
```bash
flutter build ios --release \
  --dart-define=SUPABASE_URL=https://ssrlhrydcetpspmdphfo.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<key>
```

## Local Development

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://ssrlhrydcetpspmdphfo.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<key>
```

---

# VERIFICATION CHECKLISTS

## Web Verification

After DNS propagates:

- [ ] https://theskinningshed.com — loads app
- [ ] https://www.theskinningshed.com — redirects to root
- [ ] https://theskinningshed.com/trophy-wall — deep link works
- [ ] https://theskinningshed.com/swap-shop — deep link works
- [ ] Sign up / Sign in works
- [ ] Photo uploads work
- [ ] No mixed-content warnings
- [ ] Browser tab shows "The Skinning Shed"
- [ ] Favicon displays

## iOS Verification

- [ ] App displays as "The Skinning Shed" on home screen
- [ ] App icon appears correctly
- [ ] Photo picker works
- [ ] Camera works
- [ ] Auth flow completes
- [ ] Share links use theskinningshed.com
- [ ] No debug banners in release build

## Android Verification

- [ ] App displays as "The Skinning Shed" in launcher
- [ ] App icon appears correctly
- [ ] Photo picker works
- [ ] Camera works
- [ ] Auth flow completes
- [ ] Share links use theskinningshed.com
- [ ] Deep links open app (if installed)
- [ ] No debug flags in release build

---

# TROUBLESHOOTING

## DNS Not Propagating
- Check https://dnschecker.org
- Flush local DNS: `ipconfig /flushdns` (Windows)

## 404 on Refresh (Web)
- Verify `vercel.json` rewrites are deployed
- Check Vercel deployment logs

## Auth Redirect Issues
- Verify Supabase redirect URLs include `/**` wildcards
- For mobile: ensure `com.theskinning.shed://callback` is in redirect URLs

## Android Deep Links Not Working
- Run: `adb shell am start -a android.intent.action.VIEW -d "https://theskinningshed.com/trophy-wall"`
- Check Android App Links verification in device settings

---

# QUICK REFERENCE

| Service | URL |
|---------|-----|
| Production Web | https://theskinningshed.com |
| Supabase Dashboard | https://supabase.com/dashboard/project/ssrlhrydcetpspmdphfo |
| Vercel Dashboard | https://vercel.com/dashboard |
| Namecheap DNS | https://ap.www.namecheap.com |
| Google Play Console | https://play.google.com/console |
| App Store Connect | https://appstoreconnect.apple.com |

---

*Last updated: 2026-01-28*

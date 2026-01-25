# Runbook

> Commands and procedures for running, building, and maintaining The Skinning Shed

## Prerequisites

- Flutter SDK (stable channel)
- Chrome browser (for web development)
- Git
- Supabase project with credentials

## Environment Variables

The app requires Supabase credentials passed via `--dart-define`:

| Variable | Required | Description |
|----------|----------|-------------|
| `SUPABASE_URL` | Yes | Supabase project URL |
| `SUPABASE_ANON_KEY` | Yes | Supabase anon/public key |
| `ADS_BUCKET_PUBLIC` | No | Default `true`. Set `false` for signed ad URLs |

**Never commit credentials to the repository.**

## Running the App

### Web (Chrome)

```powershell
cd C:\src\skinning_shed\the_skinning_shed\app

flutter run -d chrome `
  --dart-define=SUPABASE_URL="https://your-project.supabase.co" `
  --dart-define=SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

### Web (Edge)

```powershell
flutter run -d edge `
  --dart-define=SUPABASE_URL="..." `
  --dart-define=SUPABASE_ANON_KEY="..."
```

### Android Emulator

```powershell
flutter run -d emulator-5554 `
  --dart-define=SUPABASE_URL="..." `
  --dart-define=SUPABASE_ANON_KEY="..."
```

### iOS Simulator (macOS only)

```bash
flutter run -d "iPhone 15" \
  --dart-define=SUPABASE_URL="..." \
  --dart-define=SUPABASE_ANON_KEY="..."
```

## Local Helper Script (Optional)

Create a local script to avoid typing credentials repeatedly.

**File**: `app/run_web.ps1.example`

```powershell
# Copy this file to run_web.ps1 and fill in your credentials
# DO NOT COMMIT run_web.ps1

$env:SUPABASE_URL = "https://your-project.supabase.co"
$env:SUPABASE_ANON_KEY = "eyJ..."

flutter run -d chrome `
  --dart-define=SUPABASE_URL="$env:SUPABASE_URL" `
  --dart-define=SUPABASE_ANON_KEY="$env:SUPABASE_ANON_KEY" `
  --dart-define=ADS_BUCKET_PUBLIC=true
```

Add to `.gitignore`:
```
run_web.ps1
*.local.ps1
```

## Clean Rebuild

When dependencies or assets change:

```powershell
cd C:\src\skinning_shed\the_skinning_shed\app
flutter clean
flutter pub get
```

## Build for Release

### Web

```powershell
flutter build web --release `
  --dart-define=SUPABASE_URL="..." `
  --dart-define=SUPABASE_ANON_KEY="..."
```

Output: `app/build/web/`

### Android APK

```powershell
flutter build apk --release `
  --dart-define=SUPABASE_URL="..." `
  --dart-define=SUPABASE_ANON_KEY="..."
```

### iOS (macOS only)

```bash
flutter build ios --release \
  --dart-define=SUPABASE_URL="..." \
  --dart-define=SUPABASE_ANON_KEY="..."
```

## Git Checkpoint Flow

Standard checkpoint procedure:

```powershell
cd C:\src\skinning_shed\the_skinning_shed

# 1. Check status
git status

# 2. Stage all changes
git add -A

# 3. Commit with descriptive message
git commit -m "feat: description of changes"

# 4. Push to remote
git push origin main
```

### Commit Message Conventions

| Prefix | Use Case |
|--------|----------|
| `feat:` | New feature |
| `fix:` | Bug fix |
| `docs:` | Documentation only |
| `refactor:` | Code restructuring |
| `style:` | Formatting, no logic change |
| `test:` | Adding tests |
| `chore:` | Maintenance tasks |

## Supabase Operations

### Edge Function Secrets

Some Edge Functions require additional secrets. Set these via Supabase Dashboard or CLI:

| Secret | Required For | Description |
|--------|-------------|-------------|
| `OPENAI_API_KEY` | `regs-repair-gpt` | OpenAI API key for GPT-assisted portal link classification |
| `OPENAI_MODEL` | `regs-repair-gpt` | OpenAI model to use. Default is `gpt-4.1-mini` for higher accuracy. |

**Setting secrets via CLI:**
```bash
npx supabase secrets set OPENAI_API_KEY=sk-...
npx supabase secrets set OPENAI_MODEL=gpt-4.1-mini
```

**Setting via Dashboard:**
1. Go to Project Settings > Edge Functions
2. Add secret key/value pairs

### Check Logs

```powershell
# Via MCP or Supabase Dashboard
# Dashboard: https://supabase.com/dashboard/project/YOUR_PROJECT_ID/logs
```

### Run SQL Migration

```sql
-- In Supabase SQL Editor or via MCP apply_migration
ALTER TABLE public.some_table ADD COLUMN new_col text;
```

### Refresh Schema Cache

After DDL changes, PostgREST cache may need refresh:
- Wait ~60 seconds, or
- Restart the project in Supabase Dashboard

## Troubleshooting

### "Supabase not initialized"

- Ensure `--dart-define` flags are passed correctly
- Check `BootstrapScreen` is wrapping the app
- Verify network connectivity to Supabase

### "No Directionality widget found"

- Wrap standalone `Scaffold` in `Directionality(textDirection: TextDirection.ltr, child: ...)`
- This happens when rendering before `MaterialApp` mounts

### "uploadBinary expects Uint8List"

- Convert: `Uint8List.fromList(bytes)`

### Hot reload not working

- Try hot restart: press `R` in terminal
- If still broken: `flutter clean && flutter pub get && flutter run`

### Asset not found

- Verify asset is listed in `pubspec.yaml` under `flutter.assets`
- Run `flutter pub get` after adding assets
- Check path is relative to `app/` directory

## Useful Commands

```powershell
# List available devices
flutter devices

# Check Flutter installation
flutter doctor

# Update dependencies
flutter pub upgrade

# Generate code (if using build_runner)
flutter pub run build_runner build

# Analyze code
flutter analyze

# Format code
dart format lib/
```

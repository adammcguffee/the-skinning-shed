# Project State - 2026-01-23

## Rollback Summary

Rolled back repo and Supabase to commit `4c0b2f2` baseline.

### Repo Rollback
- Commit `318727a` reverts to `4c0b2f2` baseline
- Removed all post-baseline auth/regs automation code

### Supabase Edge Functions

**Deployed from baseline (all `verify_jwt: false`):**
| Function | Version | Status |
|----------|---------|--------|
| regulations-check | v3 | ACTIVE (cron target) |
| regulations-check-v3 | v4 | ACTIVE |
| regulations-check-v4 | v2 | ACTIVE |
| regulations-check-v5 | v2 | ACTIVE |
| regulations-check-v6 | v4 | ACTIVE |

**MANUAL DELETION REQUIRED - Not in baseline:**
These functions have `verify_jwt: true` and will fail if called. Delete via Supabase Dashboard > Edge Functions:

| Function | Action |
|----------|--------|
| `regs-links-verify` | DELETE |
| `regs-links-discover` | DELETE |
| `regs-discover-official` | DELETE |
| `regs-discovery-start` | DELETE |
| `regs-discovery-continue` | DELETE |
| `regs-auth-diagnostic` | DELETE |

### Cron Jobs

| Job ID | Schedule | Target | Status |
|--------|----------|--------|--------|
| 1 | `0 6 * * 0` (Sunday 6 AM) | regulations-check | OK - Keep |

No changes needed to cron.

### Database Tables

All tables retained. No schema rollback needed. Key tables:
- `state_regulations_sources` (150 rows)
- `state_regulations_pending` (53 rows) 
- `state_regulations_approved` (2 rows)
- `state_regulations_audit_log` (180 rows)
- `state_portal_links` (50 rows)
- `state_official_roots` (50 rows)
- `reg_discovery_runs` (0 rows) - empty, harmless
- `reg_discovery_run_items` (0 rows) - empty, harmless

### What Was Fixed

1. **Edge functions v3-v6** now use service role key directly (no JWT verification)
2. **No more `requireAdmin` helper** - removed from baseline
3. **No more `EdgeAdminClient`** - removed from Flutter app
4. **Router uses `ref.read`** not `ref.watch` - prevents GlobalKey crash

### Verification Steps

1. Start app fresh - should show login screen without errors
2. Log in - auth should work normally
3. Navigate to Regulations screen - should load without 401 errors
4. Admin functions (if UI exists) only callable via explicit button click

### Next Steps

1. **Delete 6 edge functions** listed above via Supabase Dashboard
2. Run app to verify no 401/JWT loops
3. If admin UI removed, no action needed - buttons won't appear

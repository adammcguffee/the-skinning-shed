# Cursor Module Prompt Template (Use for each milestone)

## Goal
Implement: <MODULE NAME>

## Constraints (must obey)
- Keep premium outdoors theme; muted colors; no neon.
- Use canonical terms (Trophy Wall, Swap Shop).
- No GPS pins; no mapping features.
- Modern dropdown filters; fast UX.

## Backend tasks (Supabase)
- SQL migrations:
  - <tables/columns/indexes>
- RLS policies:
  - <policy list>
- Storage buckets/policies:
  - <bucket + prefix policies>
- Edge functions/RPC:
  - <functions needed>

## Frontend tasks (Flutter)
- Screens:
  - <screen list>
- Components:
  - <components>
- State/data:
  - <providers/services>
- UX requirements:
  - <loading/empty/error>
- Performance:
  - caching, pagination, image optimization

## Acceptance Criteria (must pass)
- Build succeeds for web + android + ios targets (as applicable).
- Manual smoke tests:
  1) ...
  2) ...
- Data correctness checks:
  - ...
- Security checks:
  - RLS prevents cross-user access.
- Git hygiene:
  - `git status` clean
  - commit + push
  - update docs/CHECKPOINTS.md

## Output
- Show key file diffs
- Show SQL applied
- Show commands run

# 07 — Cursor Rules, Workflow & “One-Prompt” Strategy

## A) Cursor + MCP + Supabase (Assumed)
- Cursor has MCP access to Supabase (read/write schema, run SQL, deploy edge functions).
- Cursor must prefer doing everything itself unless impossible.

## B) Cost Strategy
- Prompts are expensive, so each prompt should be:
  - Big, detailed
  - Include exact acceptance criteria
  - Include commands to run and success checks
  - Include “do not drift” constraints

## C) Repo Hygiene / Catastrophe Avoidance (Hard Rules)
- Always keep repo in a buildable state.
- After each milestone:
  - Run tests/build
  - Commit with descriptive message
  - Push to GitHub
  - Tag checkpoint (git tag) or write CHECKPOINT.md
- Maintain a CHANGELOG.md and DECISIONS.md.
- Maintain a “tree snapshot” of the repo structure in docs (or auto-generated).

## D) “Sync tree” requirement
After significant changes, Cursor must:
- Output `git status`
- Output a short file tree summary
- Ensure no untracked critical files
- Commit + push

## E) Cursor must not
- Introduce bright neon/futuristic colors
- Drift into SaaS/business UI
- Add mapping/waypoints (explicitly out of MVP)
- Add payment processing
- Add exact GPS public display
- Rename canonical terms (Trophy Wall, Swap Shop)

## F) Prompt Packing: Template
Use the prompt templates in `cursor_prompts/` to:
- Build modules end-to-end
- Include DB migrations + RLS + storage policies
- Include UI with premium outdoors theme
- Include validation and smoke tests

## G) Acceptance Criteria Style
Every Cursor task must include:
- What files are touched
- What DB changes are applied
- What manual smoke test steps confirm it works
- What success looks like (screenshots optional)

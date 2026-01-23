# 08 — Ops: Checkpoints, Versioning, and “Update the Zip” Process

## A) How we keep continuity across chats
- This zip is the canonical project memory.
- At the start of a new chat:
  - Upload the zip
  - Ask the assistant to read it and continue from it

## B) When you say “save memory to start a new chat”
We will:
1) Summarize what changed since the last zip version.
2) Update:
   - DECISIONS.md (new decisions)
   - CHANGELOG.md (date + bullets)
   - Any requirements/spec docs affected
   - Add any new Cursor prompts used
3) Rebuild the zip and provide a new download link.

## C) Repo checkpoints (mandatory)
- Each milestone:
  - run build
  - commit
  - push
  - tag (optional) and update docs/CHECKPOINTS.md

## D) Suggested docs in repo
- docs/PRODUCT_RULES.md
- docs/ARCH.md
- docs/DATA_MODEL.md
- docs/RLS_POLICIES.md
- docs/BUILD_AND_RUN.md
- docs/CHECKPOINTS.md

## E) Disaster recovery
- If anything breaks:
  - revert to last checkpoint tag/commit
  - restore from docs/CHECKPOINTS.md

# Source of Truth — The Skinning Shed

## Canonical Authority

The **single source of truth** for The Skinning Shed project is:

```
docs/blueprint/The_Skinning_Shed_Blueprint_Pack_v1.zip
```

This ZIP contains the complete specification, requirements, feature scope, UI rules, architecture, data model, and build plan.

## Version Control

- The ZIP file is stored in the repository at `docs/blueprint/`
- Extracted contents are available at `docs/blueprint/v1_extracted/` for easy reference
- The original ZIP is preserved alongside extractions

## Change Management Process

### Reading Current State
1. The extracted files in `v1_extracted/` reflect the current canonical spec
2. Always refer to these files when making implementation decisions
3. If any assumption conflicts with the ZIP contents, **the ZIP wins**

### Making Changes
1. Changes to scope, requirements, or design must be documented in `DECISIONS.md`
2. When significant changes occur, update the `CHANGELOG.md`
3. At major milestones, a new version of the ZIP may be created

### Conflict Resolution
- **Blueprint > User Assumptions** — The ZIP is authoritative
- **Blueprint > Implementation Drift** — If implementation diverges, realign to blueprint
- **New Decisions** — Document in `DECISIONS.md` and consider for next ZIP version

## Files in Blueprint Pack v1

| File | Purpose |
|------|---------|
| `00_README.md` | Overview and non-negotiables |
| `01_VISION_REQUIREMENTS.md` | Product vision, MVP philosophy, platforms |
| `02_FEATURES_MODULES.md` | Frozen MVP scope and feature list |
| `03_UI_UX_DESIGN_SYSTEM.md` | Design system and UX requirements |
| `04_DATA_MODEL_SUPABASE.md` | Database schema blueprint |
| `05_ARCHITECTURE_STACK.md` | Tech stack and architecture |
| `06_BUILD_PLAN.md` | Phased build execution order |
| `07_CURSOR_RULES_WORKFLOW.md` | Development workflow rules |
| `08_OPS_CHECKPOINTS_AND_ZIP_PROCESS.md` | Operational checkpoints |
| `CHANGELOG.md` | Version history |
| `DECISIONS.md` | Decision log |
| `cursor_prompts/` | Reusable prompt templates |

## Quick Reference: Non-Negotiables

- Premium modern UI/UX (calm outdoors vibe; NOT business/SaaS look)
- High-tech function + fast performance
- Web + iOS + Android from day one (shared codebase)
- MVP-first: production-ready on first launch (no throwaway v1)
- Privacy-first: **no GPS pins** / no exact public location
- Modern dropdown filters everywhere
- **Trophy Wall** is the canonical term for user profile page
- **The Swap Shop** is the canonical term for classifieds (discovery-only; no payments)

---
*Generated: 2026-01-22*

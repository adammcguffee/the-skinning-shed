# Supabase SQL Migrations

This folder contains all database migrations and seed scripts for The Skinning Shed.

## Naming Convention

Migrations follow timestamped naming:
```
YYYYMMDD_HHMMSS_description.sql
```

Example: `20260122_210000_create_initial_schema.sql`

## Migration Types

- **Schema migrations**: Create/alter tables, indexes, RLS policies
- **Seed data**: Insert controlled data (species list, etc.)
- **Functions**: Database functions and triggers

## How to Apply

Migrations are applied via MCP tools to the Supabase project.
They can also be applied manually via the Supabase SQL editor.

## Important

- All migrations should be idempotent where possible
- RLS must be enabled on all user-facing tables
- Never include secrets or hardcoded credentials

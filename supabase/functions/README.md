# Supabase Edge Functions

This folder contains Edge Functions for The Skinning Shed backend.

## Planned Functions

- `attach_weather_snapshot` - Attach historical weather to trophy posts
- `attach_moon_snapshot` - Attach moon phase to trophy posts
- `build_analytics_buckets` - Compute analytics buckets for research dashboard
- `expire_listings` - Auto-expire old land/swap shop listings
- `research_aggregation` - RPCs for research dashboard with threshold logic

## Deployment

Edge functions are deployed via MCP tools or Supabase CLI.

## Security

- Functions that access internal data use SERVICE_ROLE
- SERVICE_ROLE key is never exposed to client
- Public-facing endpoints validate auth tokens

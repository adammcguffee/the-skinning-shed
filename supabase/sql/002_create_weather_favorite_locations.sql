-- Weather favorite locations table
-- Allows users to save favorite county locations for quick weather access
-- Privacy-safe: stores only county identifiers, not coordinates

-- 1) Table
create table if not exists public.weather_favorite_locations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- location identity / display
  state_code text not null,
  county_name text not null,
  county_fips text, -- preferred stable id if available
  label text not null, -- chip label e.g. "Jefferson Co, AL"

  -- ordering
  sort_order int not null default 0
);

-- 2) Unique constraint so user can't favorite same place twice
-- Using partial unique indexes instead of constraints for null handling
create unique index if not exists weather_fav_unique_fips
  on public.weather_favorite_locations (user_id, county_fips)
  where county_fips is not null;

create unique index if not exists weather_fav_unique_state_county
  on public.weather_favorite_locations (user_id, state_code, county_name);

-- 3) updated_at trigger
create or replace function public.set_weather_fav_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_weather_fav_updated_at on public.weather_favorite_locations;
create trigger trg_weather_fav_updated_at
before update on public.weather_favorite_locations
for each row execute function public.set_weather_fav_updated_at();

-- 4) RLS
alter table public.weather_favorite_locations enable row level security;

drop policy if exists "weather_fav_select_own" on public.weather_favorite_locations;
create policy "weather_fav_select_own"
on public.weather_favorite_locations
for select
using (auth.uid() = user_id);

drop policy if exists "weather_fav_insert_own" on public.weather_favorite_locations;
create policy "weather_fav_insert_own"
on public.weather_favorite_locations
for insert
with check (auth.uid() = user_id);

drop policy if exists "weather_fav_update_own" on public.weather_favorite_locations;
create policy "weather_fav_update_own"
on public.weather_favorite_locations
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "weather_fav_delete_own" on public.weather_favorite_locations;
create policy "weather_fav_delete_own"
on public.weather_favorite_locations
for delete
using (auth.uid() = user_id);

-- Index for faster queries by user
create index if not exists idx_weather_fav_user_id
  on public.weather_favorite_locations (user_id);

-- Index for sorting
create index if not exists idx_weather_fav_sort
  on public.weather_favorite_locations (user_id, sort_order, created_at);

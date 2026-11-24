-- HelpingHand: initial schema
-- Run once in Supabase: Dashboard → SQL Editor → New query → paste → Run.
--
-- Security model (RLS is on for every table):
--   crisis_zones, drop_off_points  → anyone can read; only the backend (secret key) can write
--   reports                        → anyone can submit; nobody can read except you (dashboard / secret key)
--   profiles                       → each signed-in user can only see and edit their own row

-- ---------------------------------------------------------------------------
-- Crisis zones (filled every 12h by the backend refresh job)
-- ---------------------------------------------------------------------------
create table public.crisis_zones (
  region_id      text primary key,
  name           text not null,
  severity_level smallint not null check (severity_level between 1 and 5),
  center_lat     double precision check (center_lat between -90 and 90),
  center_lng     double precision check (center_lng between -180 and 180),
  area           jsonb,             -- optional GeoJSON polygon for the map
  understand     jsonb not null default '{}'::jsonb,  -- { headline, bulletPoints[], sourceUrls[{name,url}] }
  act            jsonb not null default '{}'::jsonb,  -- { donationUrl, verifiedOrg, suppliesNeeded[], volunteerOpportunities[] }
  last_updated   timestamptz not null default now()
);

create index crisis_zones_severity_idx on public.crisis_zones (severity_level desc);

-- ---------------------------------------------------------------------------
-- Drop-off points for physical aid
-- ---------------------------------------------------------------------------
create table public.drop_off_points (
  id               uuid primary key default gen_random_uuid(),
  facility_name    text not null,
  verified_ngo     text,
  latitude         double precision not null check (latitude between -90 and 90),
  longitude        double precision not null check (longitude between -180 and 180),
  accepted_items   text[] not null default '{}',
  operating_hours  text,
  region_id        text references public.crisis_zones (region_id) on delete set null,
  created_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Issue reports from the app
-- ---------------------------------------------------------------------------
create table public.reports (
  id             uuid primary key default gen_random_uuid(),
  category       text not null check (category in ('crisis_info', 'dropoff_info', 'app_bug', 'other')),
  target_type    text not null default 'app' check (target_type in ('crisis', 'dropoff', 'app')),
  target_id      text check (char_length(target_id) <= 100),
  target_name    text check (char_length(target_name) <= 200),
  message        text not null check (char_length(trim(message)) between 5 and 2000),
  contact_email  text check (contact_email is null or (char_length(contact_email) <= 200 and contact_email ~ '^\S+@\S+\.\S+$')),
  app_version    text check (char_length(app_version) <= 50),
  device         text check (char_length(device) <= 100),
  user_id        uuid default auth.uid() references auth.users (id) on delete set null,
  status         text not null default 'open' check (status in ('open', 'reviewing', 'resolved')),
  created_at     timestamptz not null default now()
);

create index reports_status_created_idx on public.reports (status, created_at desc);

-- ---------------------------------------------------------------------------
-- User profiles (for when sign-in is added)
-- ---------------------------------------------------------------------------
create table public.profiles (
  id                      uuid primary key references auth.users (id) on delete cascade,
  pinned_region_ids       text[] not null default '{}',
  notification_frequency  text not null default 'daily_digest'
                          check (notification_frequency in ('immediate', 'daily_digest', 'weekly_summary')),
  digest_time             time not null default '08:00',
  quiet_hours_enabled     boolean not null default false,
  updated_at              timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.crisis_zones    enable row level security;
alter table public.drop_off_points enable row level security;
alter table public.reports         enable row level security;
alter table public.profiles        enable row level security;

create policy "Anyone can read crisis zones"
  on public.crisis_zones for select to anon, authenticated using (true);

create policy "Anyone can read drop-off points"
  on public.drop_off_points for select to anon, authenticated using (true);

-- Submitters can only create new, open reports, and can't pretend to be another user
create policy "Anyone can submit a report"
  on public.reports for insert to anon, authenticated
  with check (status = 'open' and (user_id is null or user_id = auth.uid()));

create policy "Users can read their own profile"
  on public.profiles for select to authenticated using (id = auth.uid());
create policy "Users can create their own profile"
  on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "Users can update their own profile"
  on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- ---------------------------------------------------------------------------
-- API grants (the project doesn't auto-grant new tables, so be explicit)
-- ---------------------------------------------------------------------------
grant select on public.crisis_zones, public.drop_off_points to anon, authenticated;
grant insert on public.reports to anon, authenticated;
grant select, insert, update on public.profiles to authenticated;
grant all on public.crisis_zones, public.drop_off_points, public.reports, public.profiles to service_role;

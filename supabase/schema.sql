-- ForgeFit initial Supabase schema
-- Apply through the Supabase SQL editor or migration tooling.

create extension if not exists pgcrypto;

do $$ begin
  create type public.account_role as enum ('client', 'professional', 'admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.verification_status as enum ('not_submitted', 'pending', 'verified', 'rejected');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.service_format as enum ('in_person', 'virtual', 'hybrid');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.membership_status as enum (
    'free_beta', 'trialing', 'active', 'past_due', 'canceled', 'expired'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.access_source as enum (
    'free_beta', 'complimentary', 'promotional', 'paid', 'grandfathered'
  );
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role public.account_role not null default 'client',
  display_name text not null default '',
  avatar_url text,
  city text,
  region text,
  country_code text not null default 'US',
  bio text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint display_name_length check (char_length(display_name) <= 100),
  constraint bio_length check (char_length(bio) <= 2000)
);

create table if not exists public.professional_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  category text not null,
  headline text,
  years_experience integer,
  service_format public.service_format not null default 'hybrid',
  travels_to_clients boolean not null default false,
  travel_radius_miles integer,
  verification public.verification_status not null default 'not_submitted',
  published boolean not null default false,
  accepting_clients boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint years_experience_range check (years_experience between 0 and 80),
  constraint travel_radius_range check (travel_radius_miles between 0 and 500),
  constraint headline_length check (char_length(headline) <= 160)
);

create table if not exists public.client_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  goals text[] not null default '{}',
  preferred_format public.service_format,
  preferred_categories text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.specialties (
  id bigint generated always as identity primary key,
  slug text not null unique,
  name text not null unique,
  active boolean not null default true
);

create table if not exists public.professional_specialties (
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  specialty_id bigint not null references public.specialties(id) on delete restrict,
  primary key (professional_id, specialty_id)
);

create table if not exists public.certifications (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  name text not null,
  issuing_organization text not null,
  credential_number text,
  issued_on date,
  expires_on date,
  document_path text,
  verification public.verification_status not null default 'not_submitted',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint certification_dates check (expires_on is null or issued_on is null or expires_on >= issued_on)
);

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  name text not null,
  description text,
  format public.service_format not null,
  duration_minutes integer,
  price_cents integer,
  currency text not null default 'USD',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint duration_range check (duration_minutes between 5 and 1440),
  constraint price_nonnegative check (price_cents >= 0),
  constraint currency_code check (char_length(currency) = 3)
);

create table if not exists public.early_access_signups (
  id uuid primary key default gen_random_uuid(),
  role public.account_role not null,
  name text not null,
  email text not null,
  city text,
  region text,
  preferred_format public.service_format,
  category_or_goal text,
  notes text,
  created_at timestamptz not null default now(),
  constraint early_access_email_length check (char_length(email) <= 320),
  constraint early_access_name_length check (char_length(name) <= 100),
  constraint early_access_notes_length check (char_length(notes) <= 2000)
);

create table if not exists public.membership_plans (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  role public.account_role not null,
  name text not null,
  monthly_price_cents integer,
  annual_price_cents integer,
  currency text not null default 'USD',
  stripe_product_id text unique,
  stripe_monthly_price_id text unique,
  stripe_annual_price_id text unique,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint plan_monthly_price_nonnegative check (monthly_price_cents is null or monthly_price_cents >= 0),
  constraint plan_annual_price_nonnegative check (annual_price_cents is null or annual_price_cents >= 0),
  constraint plan_currency_code check (char_length(currency) = 3)
);

create table if not exists public.membership_features (
  code text primary key,
  name text not null,
  description text,
  active boolean not null default true
);

create table if not exists public.plan_features (
  plan_id uuid not null references public.membership_plans(id) on delete cascade,
  feature_code text not null references public.membership_features(code) on delete cascade,
  primary key (plan_id, feature_code)
);

create table if not exists public.memberships (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  plan_id uuid not null references public.membership_plans(id) on delete restrict,
  status public.membership_status not null default 'free_beta',
  access_source public.access_source not null default 'free_beta',
  stripe_customer_id text unique,
  stripe_subscription_id text unique,
  current_period_start timestamptz,
  current_period_end timestamptz,
  free_access_until timestamptz,
  cancel_at_period_end boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint membership_period_order check (
    current_period_end is null or current_period_start is null or current_period_end >= current_period_start
  )
);

create index if not exists professional_profiles_discovery_idx
  on public.professional_profiles (published, accepting_clients, category, service_format);
create index if not exists profiles_location_idx on public.profiles (country_code, region, city);
create index if not exists certifications_professional_idx on public.certifications (professional_id);
create index if not exists services_professional_idx on public.services (professional_id, active);
create index if not exists memberships_status_idx on public.memberships (status, current_period_end);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
drop trigger if exists professional_profiles_set_updated_at on public.professional_profiles;
create trigger professional_profiles_set_updated_at before update on public.professional_profiles
for each row execute function public.set_updated_at();
drop trigger if exists client_profiles_set_updated_at on public.client_profiles;
create trigger client_profiles_set_updated_at before update on public.client_profiles
for each row execute function public.set_updated_at();
drop trigger if exists certifications_set_updated_at on public.certifications;
create trigger certifications_set_updated_at before update on public.certifications
for each row execute function public.set_updated_at();
drop trigger if exists services_set_updated_at on public.services;
create trigger services_set_updated_at before update on public.services
for each row execute function public.set_updated_at();
drop trigger if exists membership_plans_set_updated_at on public.membership_plans;
create trigger membership_plans_set_updated_at before update on public.membership_plans
for each row execute function public.set_updated_at();
drop trigger if exists memberships_set_updated_at on public.memberships;
create trigger memberships_set_updated_at before update on public.memberships
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_role public.account_role;
begin
  requested_role := case
    when new.raw_user_meta_data ->> 'role' = 'professional' then 'professional'::public.account_role
    else 'client'::public.account_role
  end;

  insert into public.profiles (id, role, display_name)
  values (
    new.id,
    requested_role,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''), split_part(new.email, '@', 1))
  );

  if requested_role = 'professional' then
    insert into public.professional_profiles (user_id, category)
    values (new.id, coalesce(nullif(new.raw_user_meta_data ->> 'category', ''), 'Personal Trainer'));
  else
    insert into public.client_profiles (user_id) values (new.id);
  end if;

  insert into public.memberships (user_id, plan_id, status, access_source)
  select new.id, mp.id, 'free_beta'::public.membership_status, 'free_beta'::public.access_source
  from public.membership_plans mp
  where mp.code = case when requested_role = 'professional' then 'professional_monthly' else 'client_monthly' end
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.professional_profiles enable row level security;
alter table public.client_profiles enable row level security;
alter table public.specialties enable row level security;
alter table public.professional_specialties enable row level security;
alter table public.certifications enable row level security;
alter table public.services enable row level security;
alter table public.early_access_signups enable row level security;
alter table public.membership_plans enable row level security;
alter table public.membership_features enable row level security;
alter table public.plan_features enable row level security;
alter table public.memberships enable row level security;

drop policy if exists "profiles visible to owner or for published professionals" on public.profiles;
drop policy if exists "profiles visible to owner published professionals or session parties" on public.profiles;
create policy "profiles visible to owner published professionals or session parties"
on public.profiles for select to authenticated
using (
  auth.uid() = id
  or exists (
    select 1 from public.professional_profiles pp
    where pp.user_id = profiles.id and pp.published = true
  )
  or exists (
    select 1 from public.session_requests request
    where request.client_id = profiles.id
      and request.professional_id = auth.uid()
  )
);

drop policy if exists "users update own profile" on public.profiles;
create policy "users update own profile" on public.profiles for update
using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "professional profiles visible when published or owned" on public.professional_profiles;
create policy "professional profiles visible when published or owned"
on public.professional_profiles for select
using (published = true or auth.uid() = user_id);
drop policy if exists "professionals update own professional profile" on public.professional_profiles;
create policy "professionals update own professional profile"
on public.professional_profiles for update
using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "clients manage own client profile" on public.client_profiles;
create policy "clients manage own client profile" on public.client_profiles for all
using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "active specialties are public" on public.specialties;
create policy "active specialties are public" on public.specialties for select using (active = true);

drop policy if exists "professional specialties visible for published profiles" on public.professional_specialties;
create policy "professional specialties visible for published profiles"
on public.professional_specialties for select
using (
  auth.uid() = professional_id
  or exists (
    select 1 from public.professional_profiles pp
    where pp.user_id = professional_id and pp.published = true
  )
);
drop policy if exists "professionals manage own specialties" on public.professional_specialties;
create policy "professionals manage own specialties" on public.professional_specialties for all
using (auth.uid() = professional_id) with check (auth.uid() = professional_id);

drop policy if exists "credentials visible for published profiles" on public.certifications;
create policy "credentials visible for published profiles" on public.certifications for select
using (
  auth.uid() = professional_id
  or exists (
    select 1 from public.professional_profiles pp
    where pp.user_id = professional_id and pp.published = true
  )
);
drop policy if exists "professionals manage own credentials" on public.certifications;
create policy "professionals manage own credentials" on public.certifications for all
using (auth.uid() = professional_id) with check (auth.uid() = professional_id);

drop policy if exists "active services visible for published profiles" on public.services;
create policy "active services visible for published profiles" on public.services for select
using (
  auth.uid() = professional_id
  or (
    active = true and exists (
      select 1 from public.professional_profiles pp
      where pp.user_id = professional_id and pp.published = true
    )
  )
);
drop policy if exists "professionals manage own services" on public.services;
create policy "professionals manage own services" on public.services for all
using (auth.uid() = professional_id) with check (auth.uid() = professional_id);

drop policy if exists "visitors may join early access" on public.early_access_signups;
create policy "visitors may join early access" on public.early_access_signups for insert
to anon, authenticated with check (role in ('client', 'professional'));

-- Intentionally no SELECT policy on early_access_signups. Contact data remains private.

drop policy if exists "active membership plans are public" on public.membership_plans;
create policy "active membership plans are public"
on public.membership_plans for select using (active = true);

drop policy if exists "active membership features are public" on public.membership_features;
create policy "active membership features are public"
on public.membership_features for select using (active = true);

drop policy if exists "active plan features are public" on public.plan_features;
create policy "active plan features are public"
on public.plan_features for select
using (
  exists (
    select 1 from public.membership_plans mp
    where mp.id = plan_id and mp.active = true
  )
);

drop policy if exists "users view own membership" on public.memberships;
create policy "users view own membership"
on public.memberships for select using (auth.uid() = user_id);

-- Intentionally no browser INSERT, UPDATE, or DELETE policy on memberships.
-- Only trusted server code and verified billing webhooks may change access.

insert into public.specialties (slug, name) values
  ('strength-training', 'Strength Training'),
  ('mobility', 'Mobility'),
  ('weight-management', 'Weight Management'),
  ('sports-performance', 'Sports Performance'),
  ('nutrition', 'Nutrition'),
  ('military-preparation', 'Military Preparation'),
  ('accountability', 'Accountability Coaching')
on conflict (slug) do update set name = excluded.name, active = true;

insert into public.membership_plans (
  code, role, name, monthly_price_cents, annual_price_cents, currency, active
) values
  ('professional_monthly', 'professional', 'ForgeFit Professional', 1000, null, 'USD', true),
  ('client_monthly', 'client', 'ForgeFit Client', 500, null, 'USD', true)
on conflict (code) do update set
  role = excluded.role,
  name = excluded.name,
  monthly_price_cents = excluded.monthly_price_cents,
  currency = excluded.currency,
  active = excluded.active;

insert into public.membership_features (code, name, description) values
  ('account_access', 'Account Access', 'Create an account and access role-specific experiences.'),
  ('professional_profile', 'Professional Profile', 'Create and publish a professional profile.'),
  ('professional_tools', 'Professional Tools', 'Use professional business and client-management tools.'),
  ('client_profile', 'Client Profile', 'Create a client profile and save preferences.'),
  ('professional_discovery', 'Professional Discovery', 'Search and connect with professionals.'),
  ('program_library', 'Program Library', 'Access purchased or assigned programs.')
on conflict (code) do update set
  name = excluded.name,
  description = excluded.description,
  active = true;

insert into public.plan_features (plan_id, feature_code)
select mp.id, feature.code
from public.membership_plans mp
cross join lateral (
  select unnest(
    case
      when mp.code = 'professional_monthly' then array[
        'account_access', 'professional_profile', 'professional_tools', 'professional_discovery'
      ]
      else array[
        'account_access', 'client_profile', 'professional_discovery', 'program_library'
      ]
    end
  ) as code
) feature
where mp.code in ('professional_monthly', 'client_monthly')
on conflict (plan_id, feature_code) do nothing;


-- Explicit Data API privileges. The project is configured not to expose new
-- tables automatically, so only the operations listed here are available to
-- browser clients. Row Level Security policies above further restrict rows.
grant usage on schema public to anon, authenticated;

grant select on table
  public.profiles,
  public.professional_profiles,
  public.specialties,
  public.professional_specialties,
  public.certifications,
  public.services,
  public.membership_plans,
  public.membership_features,
  public.plan_features
to anon, authenticated;

grant insert on table public.early_access_signups to anon, authenticated;

grant update on table
  public.profiles,
  public.professional_profiles,
  public.client_profiles
to authenticated;

grant select on table
  public.client_profiles,
  public.memberships
to authenticated;

grant insert, update, delete on table
  public.professional_specialties,
  public.certifications,
  public.services
to authenticated;

grant all privileges on all tables in schema public to service_role;
grant all privileges on all sequences in schema public to service_role;

revoke execute on function public.set_updated_at() from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;


-- Client competition goals and private progress tracking
-- ForgeFit client competition goals and private progress tracking
-- Apply once through the Supabase SQL editor before testing the related dashboard.

create table if not exists public.client_measurements (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.client_profiles(user_id) on delete cascade,
  measured_at date not null default current_date,
  unit_system text not null default 'imperial',
  height_cm numeric(5,2),
  weight_kg numeric(6,2),
  body_fat_percentage numeric(5,2),
  neck_cm numeric(5,2),
  chest_cm numeric(5,2),
  waist_cm numeric(5,2),
  hips_cm numeric(5,2),
  upper_arm_cm numeric(5,2),
  thigh_cm numeric(5,2),
  calf_cm numeric(5,2),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint measurement_unit_system check (unit_system in ('imperial', 'metric')),
  constraint measurement_height_range check (height_cm is null or height_cm between 50 and 275),
  constraint measurement_weight_range check (weight_kg is null or weight_kg between 20 and 500),
  constraint measurement_body_fat_range check (body_fat_percentage is null or body_fat_percentage between 1 and 75),
  constraint measurement_neck_range check (neck_cm is null or neck_cm between 10 and 100),
  constraint measurement_chest_range check (chest_cm is null or chest_cm between 30 and 250),
  constraint measurement_waist_range check (waist_cm is null or waist_cm between 25 and 250),
  constraint measurement_hips_range check (hips_cm is null or hips_cm between 25 and 250),
  constraint measurement_upper_arm_range check (upper_arm_cm is null or upper_arm_cm between 10 and 100),
  constraint measurement_thigh_range check (thigh_cm is null or thigh_cm between 15 and 150),
  constraint measurement_calf_range check (calf_cm is null or calf_cm between 10 and 100),
  constraint measurement_notes_length check (char_length(notes) <= 2000)
);

create index if not exists client_measurements_timeline_idx
  on public.client_measurements (client_id, measured_at desc, created_at desc);

drop trigger if exists client_measurements_set_updated_at on public.client_measurements;
create trigger client_measurements_set_updated_at before update on public.client_measurements
for each row execute function public.set_updated_at();

alter table public.client_measurements enable row level security;

drop policy if exists "clients privately manage own measurements" on public.client_measurements;
create policy "clients privately manage own measurements"
on public.client_measurements for all
to authenticated
using (auth.uid() = client_id)
with check (auth.uid() = client_id);

grant select, insert, update, delete on table public.client_measurements to authenticated;
grant all privileges on table public.client_measurements to service_role;

insert into public.specialties (slug, name) values
  ('ifbb-competition-prep', 'IFBB Competition Prep'),
  ('bodybuilding-competition-prep', 'Bodybuilding Competition Prep'),
  ('figure-competition-prep', 'Figure Competition Prep')
on conflict (slug) do update set name = excluded.name, active = true;


-- Progress methods, private media, and consent-based sharing
-- ForgeFit progress methods, private media, and revocable sharing
-- Apply after 20260808_client_competition_progress.sql.

alter table public.client_measurements
  add column if not exists measurement_method text not null default 'tape',
  add column if not exists calculation_profile text,
  add column if not exists age_years integer,
  add column if not exists chest_skinfold_mm numeric(5,2),
  add column if not exists midaxillary_skinfold_mm numeric(5,2),
  add column if not exists triceps_skinfold_mm numeric(5,2),
  add column if not exists subscapular_skinfold_mm numeric(5,2),
  add column if not exists abdomen_skinfold_mm numeric(5,2),
  add column if not exists suprailiac_skinfold_mm numeric(5,2),
  add column if not exists thigh_skinfold_mm numeric(5,2),
  add constraint measurement_method_allowed check (measurement_method in ('tape', 'caliper_3', 'caliper_7', 'device')),
  add constraint measurement_profile_allowed check (calculation_profile is null or calculation_profile in ('male', 'female')),
  add constraint measurement_age_range check (age_years is null or age_years between 18 and 100),
  add constraint measurement_skinfold_ranges check (
    (chest_skinfold_mm is null or chest_skinfold_mm between 1 and 100)
    and (midaxillary_skinfold_mm is null or midaxillary_skinfold_mm between 1 and 100)
    and (triceps_skinfold_mm is null or triceps_skinfold_mm between 1 and 100)
    and (subscapular_skinfold_mm is null or subscapular_skinfold_mm between 1 and 100)
    and (abdomen_skinfold_mm is null or abdomen_skinfold_mm between 1 and 100)
    and (suprailiac_skinfold_mm is null or suprailiac_skinfold_mm between 1 and 100)
    and (thigh_skinfold_mm is null or thigh_skinfold_mm between 1 and 100)
  );

create table if not exists public.progress_media (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.client_profiles(user_id) on delete cascade,
  storage_path text not null unique,
  media_type text not null,
  category text not null default 'progress',
  caption text,
  captured_at date not null default current_date,
  file_size_bytes bigint not null,
  created_at timestamptz not null default now(),
  constraint progress_media_type check (media_type in ('photo', 'video')),
  constraint progress_media_category check (category in ('progress', 'form_review', 'posing_review', 'virtual_checkin', 'competition_prep')),
  constraint progress_media_caption_length check (char_length(caption) <= 500),
  constraint progress_media_size check (file_size_bytes between 1 and 104857600)
);

create index if not exists progress_media_client_timeline_idx
  on public.progress_media (client_id, captured_at desc, created_at desc);

create table if not exists public.client_progress_shares (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.client_profiles(user_id) on delete cascade,
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  measurement_id uuid references public.client_measurements(id) on delete cascade,
  media_id uuid references public.progress_media(id) on delete cascade,
  shared_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint one_shared_progress_item check (
    (measurement_id is not null and media_id is null)
    or (measurement_id is null and media_id is not null)
  )
);

create unique index if not exists active_measurement_share_unique
  on public.client_progress_shares (client_id, professional_id, measurement_id)
  where measurement_id is not null and revoked_at is null;
create unique index if not exists active_media_share_unique
  on public.client_progress_shares (client_id, professional_id, media_id)
  where media_id is not null and revoked_at is null;

alter table public.progress_media enable row level security;
alter table public.client_progress_shares enable row level security;

drop policy if exists "clients privately manage own progress media" on public.progress_media;
create policy "clients privately manage own progress media"
on public.progress_media for all to authenticated
using (auth.uid() = client_id)
with check (auth.uid() = client_id);

drop policy if exists "professionals view explicitly shared measurements" on public.client_measurements;
create policy "professionals view explicitly shared measurements"
on public.client_measurements for select to authenticated
using (
  exists (
    select 1 from public.client_progress_shares share
    where share.measurement_id = client_measurements.id
      and share.professional_id = auth.uid()
      and share.revoked_at is null
  )
);

drop policy if exists "professionals view explicitly shared media metadata" on public.progress_media;
create policy "professionals view explicitly shared media metadata"
on public.progress_media for select to authenticated
using (
  exists (
    select 1 from public.client_progress_shares share
    where share.media_id = progress_media.id
      and share.professional_id = auth.uid()
      and share.revoked_at is null
  )
);

drop policy if exists "clients manage own progress shares" on public.client_progress_shares;
create policy "clients manage own progress shares"
on public.client_progress_shares for all to authenticated
using (auth.uid() = client_id)
with check (auth.uid() = client_id);

drop policy if exists "professionals view shares addressed to them" on public.client_progress_shares;
create policy "professionals view shares addressed to them"
on public.client_progress_shares for select to authenticated
using (auth.uid() = professional_id and revoked_at is null);

grant select, insert, update, delete on table public.progress_media to authenticated;
grant select, insert, update, delete on table public.client_progress_shares to authenticated;
grant all privileges on table public.progress_media to service_role;
grant all privileges on table public.client_progress_shares to service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'progress-media',
  'progress-media',
  false,
  104857600,
  array['image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "clients upload own progress media files" on storage.objects;
create policy "clients upload own progress media files"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'progress-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "clients view own progress media files" on storage.objects;
create policy "clients view own progress media files"
on storage.objects for select to authenticated
using (
  bucket_id = 'progress-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "professionals view explicitly shared progress files" on storage.objects;
create policy "professionals view explicitly shared progress files"
on storage.objects for select to authenticated
using (
  bucket_id = 'progress-media'
  and exists (
    select 1
    from public.progress_media media
    join public.client_progress_shares share on share.media_id = media.id
    where media.storage_path = name
      and share.professional_id = auth.uid()
      and share.revoked_at is null
  )
);

drop policy if exists "clients update own progress media files" on storage.objects;
create policy "clients update own progress media files"
on storage.objects for update to authenticated
using (bucket_id = 'progress-media' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'progress-media' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "clients delete own progress media files" on storage.objects;
create policy "clients delete own progress media files"
on storage.objects for delete to authenticated
using (bucket_id = 'progress-media' and (storage.foldername(name))[1] = auth.uid()::text);


-- Session request workflow
-- ForgeFit session request workflow
-- Clients request sessions; professionals approve, decline, or propose another time.

create table if not exists public.session_requests (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.client_profiles(user_id) on delete cascade,
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  requested_start_at timestamptz not null,
  duration_minutes integer not null default 60,
  session_type text not null,
  format text not null,
  location_details text,
  client_message text,
  status text not null default 'pending',
  professional_response text,
  proposed_start_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint session_request_future_time check (requested_start_at > created_at),
  constraint session_request_duration check (duration_minutes between 15 and 240),
  constraint session_request_type_length check (char_length(session_type) between 2 and 120),
  constraint session_request_format check (format in ('virtual', 'in_person')),
  constraint session_request_status check (status in ('pending', 'approved', 'declined', 'reschedule_proposed', 'cancelled')),
  constraint session_request_location_length check (location_details is null or char_length(location_details) <= 500),
  constraint session_request_message_length check (client_message is null or char_length(client_message) <= 2000),
  constraint session_request_response_length check (professional_response is null or char_length(professional_response) <= 2000),
  constraint reschedule_requires_time check (status <> 'reschedule_proposed' or proposed_start_at is not null),
  constraint different_session_parties check (client_id <> professional_id)
);

create index if not exists session_requests_client_timeline_idx
  on public.session_requests (client_id, requested_start_at desc);

create index if not exists session_requests_professional_timeline_idx
  on public.session_requests (professional_id, requested_start_at desc);

alter table public.session_requests enable row level security;

drop policy if exists "clients view own session requests" on public.session_requests;
create policy "clients view own session requests"
on public.session_requests for select to authenticated
using (client_id = auth.uid());

drop policy if exists "professionals view assigned session requests" on public.session_requests;
create policy "professionals view assigned session requests"
on public.session_requests for select to authenticated
using (professional_id = auth.uid());

drop policy if exists "clients create session requests" on public.session_requests;
create policy "clients create session requests"
on public.session_requests for insert to authenticated
with check (
  client_id = auth.uid()
  and status = 'pending'
  and exists (
    select 1 from public.professional_profiles professional
    where professional.user_id = professional_id
      and professional.published = true
      and professional.accepting_clients = true
  )
);

drop policy if exists "clients update own requests" on public.session_requests;
create policy "clients update own requests"
on public.session_requests for update to authenticated
using (client_id = auth.uid())
with check (client_id = auth.uid() and status in ('pending', 'cancelled'));

drop policy if exists "professionals respond to assigned requests" on public.session_requests;
create policy "professionals respond to assigned requests"
on public.session_requests for update to authenticated
using (professional_id = auth.uid())
with check (professional_id = auth.uid() and status in ('approved', 'declined', 'reschedule_proposed'));

create or replace function public.guard_session_request_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() = 'service_role' then
    new.updated_at = now();
    return new;
  end if;

  if auth.uid() = old.client_id then
    if old.status not in ('pending', 'reschedule_proposed', 'approved') then
      raise exception 'This session request can no longer be changed by the client.';
    end if;
    if new.client_id is distinct from old.client_id
      or new.professional_id is distinct from old.professional_id
      or new.professional_response is distinct from old.professional_response
      or new.proposed_start_at is distinct from old.proposed_start_at then
      raise exception 'Clients cannot change the professional response fields.';
    end if;
    if new.status not in ('pending', 'cancelled') then
      raise exception 'Clients may only keep a request pending or cancel it.';
    end if;
    if old.status = 'approved' and new.status <> 'cancelled' then
      raise exception 'Approved sessions may only be cancelled by the client.';
    end if;
  elsif auth.uid() = old.professional_id then
    if new.client_id is distinct from old.client_id
      or new.professional_id is distinct from old.professional_id
      or new.requested_start_at is distinct from old.requested_start_at
      or new.duration_minutes is distinct from old.duration_minutes
      or new.session_type is distinct from old.session_type
      or new.format is distinct from old.format
      or new.location_details is distinct from old.location_details
      or new.client_message is distinct from old.client_message then
      raise exception 'Professionals cannot rewrite the client request.';
    end if;
    if new.status not in ('approved', 'declined', 'reschedule_proposed') then
      raise exception 'Choose approve, decline, or propose a new time.';
    end if;
  else
    raise exception 'You cannot update this session request.';
  end if;

  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists guard_session_request_update on public.session_requests;
create trigger guard_session_request_update
before update on public.session_requests
for each row execute function public.guard_session_request_update();

grant select, insert, update on table public.session_requests to authenticated;
grant all privileges on table public.session_requests to service_role;

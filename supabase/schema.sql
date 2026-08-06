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

create index if not exists professional_profiles_discovery_idx
  on public.professional_profiles (published, accepting_clients, category, service_format);
create index if not exists profiles_location_idx on public.profiles (country_code, region, city);
create index if not exists certifications_professional_idx on public.certifications (professional_id);
create index if not exists services_professional_idx on public.services (professional_id, active);

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

drop policy if exists "profiles visible to owner or for published professionals" on public.profiles;
create policy "profiles visible to owner or for published professionals"
on public.profiles for select
using (
  auth.uid() = id
  or exists (
    select 1 from public.professional_profiles pp
    where pp.user_id = profiles.id and pp.published = true
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

insert into public.specialties (slug, name) values
  ('strength-training', 'Strength Training'),
  ('mobility', 'Mobility'),
  ('weight-management', 'Weight Management'),
  ('sports-performance', 'Sports Performance'),
  ('nutrition', 'Nutrition'),
  ('military-preparation', 'Military Preparation'),
  ('accountability', 'Accountability Coaching')
on conflict (slug) do update set name = excluded.name, active = true;

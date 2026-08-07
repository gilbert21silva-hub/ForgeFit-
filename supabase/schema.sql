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

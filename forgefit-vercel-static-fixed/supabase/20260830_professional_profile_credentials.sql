-- Multi-service professional profiles, profile photos, and certifications
alter table public.professional_profiles
  add column if not exists service_areas text[] not null default '{}',
  add column if not exists profile_image_path text check (profile_image_path is null or char_length(profile_image_path) <= 1000);

update public.professional_profiles
set service_areas=array[category]
where coalesce(array_length(service_areas,1),0)=0 and category is not null;

create table if not exists public.professional_certifications (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  name text not null check (char_length(name) between 2 and 160),
  issuer text not null check (char_length(issuer) between 2 and 160),
  credential_id text check (credential_id is null or char_length(credential_id) <= 160),
  earned_year integer check (earned_year is null or earned_year between 1950 and 2100),
  verification_url text check (verification_url is null or (char_length(verification_url) <= 1000 and verification_url ~ '^https://')),
  verified boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists professional_certifications_owner_idx on public.professional_certifications(professional_id,earned_year desc);
alter table public.professional_certifications enable row level security;

drop policy if exists "professionals manage own certifications" on public.professional_certifications;
create policy "professionals manage own certifications" on public.professional_certifications
for all to authenticated using (professional_id=auth.uid()) with check (professional_id=auth.uid());

drop policy if exists "members view published professional certifications" on public.professional_certifications;
create policy "members view published professional certifications" on public.professional_certifications
for select to authenticated using (
  exists(select 1 from public.professional_profiles p where p.user_id=professional_id and p.published=true)
);

grant select,insert,update,delete on public.professional_certifications to authenticated;
grant all on public.professional_certifications to service_role;

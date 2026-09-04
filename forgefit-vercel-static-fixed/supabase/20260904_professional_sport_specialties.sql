-- Sport-specific professional discovery
alter table public.professional_profiles
  add column if not exists sport_specialties text[] not null default '{}';

grant select,update (sport_specialties) on public.professional_profiles to authenticated;
notify pgrst, 'reload schema';

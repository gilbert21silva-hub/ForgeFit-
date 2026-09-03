-- ForgeFit ZIP-radius professional discovery
-- Adds optional search coordinates to public profiles. Coordinates are populated
-- by the profile forms after a member enters a valid ZIP code.

alter table public.profiles
  add column if not exists postal_code text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_postal_code_format') then
    alter table public.profiles add constraint profiles_postal_code_format
      check (postal_code is null or postal_code ~ '^[0-9]{5}(-[0-9]{4})?$');
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_latitude_range') then
    alter table public.profiles add constraint profiles_latitude_range
      check (latitude is null or latitude between -90 and 90);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_longitude_range') then
    alter table public.profiles add constraint profiles_longitude_range
      check (longitude is null or longitude between -180 and 180);
  end if;
end $$;

create index if not exists profiles_postal_code_idx on public.profiles (postal_code);
grant select (postal_code, latitude, longitude) on public.profiles to authenticated;
grant update (postal_code, latitude, longitude) on public.profiles to authenticated;

notify pgrst, 'reload schema';

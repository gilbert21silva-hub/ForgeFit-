-- Add sport filters to an already-created ForgeFit marketplace.
alter table public.marketplace_listings
  add column if not exists sport_tags text[] not null default '{}';

grant select,insert,update (sport_tags) on public.marketplace_listings to authenticated;
notify pgrst, 'reload schema';

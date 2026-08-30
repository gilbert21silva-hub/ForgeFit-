-- ForgeFit professional links visible after accepted service terms

create table if not exists public.professional_links (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('website','instagram','facebook','youtube','tiktok','linkedin','x','other')),
  label text not null check (char_length(trim(label)) between 1 and 80),
  url text not null check (url ~* '^https://[^[:space:]]+$' and char_length(url)<=1000),
  created_at timestamptz not null default now()
);
create index if not exists professional_links_owner_idx on public.professional_links(professional_id,created_at);
alter table public.professional_links enable row level security;

drop policy if exists "professionals manage profile links" on public.professional_links;
create policy "professionals manage profile links" on public.professional_links
for all to authenticated
using (professional_id=auth.uid())
with check (professional_id=auth.uid());

drop policy if exists "accepted clients view professional links" on public.professional_links;
create policy "accepted clients view professional links" on public.professional_links
for select to authenticated
using (
  exists (
    select 1 from public.message_connections c
    where c.professional_id=professional_links.professional_id
      and c.client_id=auth.uid()
      and c.status='active'
  )
);

grant select,insert,delete on public.professional_links to authenticated;
grant all on public.professional_links to service_role;

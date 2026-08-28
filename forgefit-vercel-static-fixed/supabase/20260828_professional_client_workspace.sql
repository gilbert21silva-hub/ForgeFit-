-- ForgeFit professional client workspace
-- Active clients come from approved sessions. Progress remains client-controlled.

create table if not exists public.professional_client_notes (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references auth.users(id) on delete cascade,
  client_id uuid not null references auth.users(id) on delete cascade,
  note_text text not null check (char_length(note_text) between 1 and 4000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint professional_client_notes_distinct_parties check (professional_id <> client_id)
);

create index if not exists professional_client_notes_lookup_idx
  on public.professional_client_notes (professional_id, client_id, created_at desc);

alter table public.professional_client_notes enable row level security;

drop policy if exists "professionals manage private client notes" on public.professional_client_notes;
create policy "professionals manage private client notes"
on public.professional_client_notes
for all to authenticated
using (
  professional_id = auth.uid()
  and exists (
    select 1 from public.session_requests request
    where request.professional_id = auth.uid()
      and request.client_id = professional_client_notes.client_id
      and request.status = 'approved'
  )
)
with check (
  professional_id = auth.uid()
  and exists (
    select 1 from public.session_requests request
    where request.professional_id = auth.uid()
      and request.client_id = professional_client_notes.client_id
      and request.status = 'approved'
  )
);

drop policy if exists "professionals view active client preferences" on public.client_profiles;
create policy "professionals view active client preferences"
on public.client_profiles for select to authenticated
using (
  exists (
    select 1 from public.session_requests request
    where request.professional_id = auth.uid()
      and request.client_id = client_profiles.user_id
      and request.status = 'approved'
  )
);

drop policy if exists "professionals view shared client measurements" on public.client_measurements;
create policy "professionals view shared client measurements"
on public.client_measurements for select to authenticated
using (
  exists (
    select 1 from public.client_progress_shares share
    where share.professional_id = auth.uid()
      and share.client_id = client_measurements.client_id
      and share.measurement_id = client_measurements.id
      and share.revoked_at is null
  )
);

drop policy if exists "professionals view shared progress media records" on public.progress_media;
create policy "professionals view shared progress media records"
on public.progress_media for select to authenticated
using (
  exists (
    select 1 from public.client_progress_shares share
    where share.professional_id = auth.uid()
      and share.client_id = progress_media.client_id
      and share.media_id = progress_media.id
      and share.revoked_at is null
  )
);

grant select, insert, update, delete on table public.professional_client_notes to authenticated;
grant all privileges on table public.professional_client_notes to service_role;

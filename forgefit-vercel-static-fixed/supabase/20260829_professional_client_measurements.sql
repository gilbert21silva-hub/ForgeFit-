-- Allow professionals to record measurements for approved clients.
-- Clients retain access to every measurement in their own history.

alter table public.client_measurements
  add column if not exists entered_by uuid references auth.users(id) on delete set null,
  add column if not exists entered_by_role text not null default 'client'
    check (entered_by_role in ('client','professional'));

update public.client_measurements
set entered_by=client_id
where entered_by is null;

drop policy if exists "professionals add measurements for approved clients" on public.client_measurements;
create policy "professionals add measurements for approved clients"
on public.client_measurements
for insert to authenticated
with check (
  entered_by=auth.uid()
  and entered_by_role='professional'
  and exists (
    select 1 from public.session_requests request
    where request.professional_id=auth.uid()
      and request.client_id=client_measurements.client_id
      and request.status='approved'
  )
);

drop policy if exists "professionals view measurements they recorded" on public.client_measurements;
create policy "professionals view measurements they recorded"
on public.client_measurements
for select to authenticated
using (
  entered_by=auth.uid()
  and entered_by_role='professional'
  and exists (
    select 1 from public.session_requests request
    where request.professional_id=auth.uid()
      and request.client_id=client_measurements.client_id
      and request.status='approved'
  )
);

drop policy if exists "professionals update measurements they recorded" on public.client_measurements;
create policy "professionals update measurements they recorded"
on public.client_measurements
for update to authenticated
using (
  entered_by=auth.uid()
  and entered_by_role='professional'
  and exists (
    select 1 from public.session_requests request
    where request.professional_id=auth.uid()
      and request.client_id=client_measurements.client_id
      and request.status='approved'
  )
)
with check (
  entered_by=auth.uid()
  and entered_by_role='professional'
  and exists (
    select 1 from public.session_requests request
    where request.professional_id=auth.uid()
      and request.client_id=client_measurements.client_id
      and request.status='approved'
  )
);

drop policy if exists "professionals delete measurements they recorded" on public.client_measurements;
create policy "professionals delete measurements they recorded"
on public.client_measurements
for delete to authenticated
using (
  entered_by=auth.uid()
  and entered_by_role='professional'
  and exists (
    select 1 from public.session_requests request
    where request.professional_id=auth.uid()
      and request.client_id=client_measurements.client_id
      and request.status='approved'
  )
);

grant select, insert, update, delete on public.client_measurements to authenticated;

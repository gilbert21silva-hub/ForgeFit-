-- ForgeFit professional scheduling and virtual sessions
create table if not exists public.professional_availability (
 id uuid primary key default gen_random_uuid(),
 professional_id uuid not null references auth.users(id) on delete cascade,
 weekday smallint not null check (weekday between 0 and 6),
 start_time time not null,
 end_time time not null,
 format text not null default 'hybrid' check (format in ('virtual','in_person','hybrid')),
 active boolean not null default true,
 created_at timestamptz not null default now(),
 check (start_time < end_time)
);
create table if not exists public.professional_blocked_times (
 id uuid primary key default gen_random_uuid(),
 professional_id uuid not null references auth.users(id) on delete cascade,
 starts_at timestamptz not null,
 ends_at timestamptz not null,
 reason text check (char_length(reason)<=300),
 created_at timestamptz not null default now(),
 check (starts_at < ends_at)
);
alter table public.professional_availability enable row level security;
alter table public.professional_blocked_times enable row level security;
drop policy if exists "professionals manage availability" on public.professional_availability;
create policy "professionals manage availability" on public.professional_availability for all to authenticated using (professional_id=auth.uid()) with check (professional_id=auth.uid());
drop policy if exists "clients view published professional availability" on public.professional_availability;
create policy "clients view published professional availability" on public.professional_availability for select to authenticated using (active and exists(select 1 from public.professional_profiles p where p.user_id=professional_id and p.published and p.accepting_clients));
drop policy if exists "professionals manage blocked times" on public.professional_blocked_times;
create policy "professionals manage blocked times" on public.professional_blocked_times for all to authenticated using (professional_id=auth.uid()) with check (professional_id=auth.uid());
alter table public.session_requests add column if not exists meeting_url text;
alter table public.session_requests add column if not exists meeting_provider text check (meeting_provider is null or meeting_provider in ('zoom','google_meet','facetime','custom'));
alter table public.session_requests add column if not exists meeting_instructions text;
alter table public.session_requests add column if not exists cancelled_by uuid references auth.users(id);
alter table public.session_requests add column if not exists cancelled_at timestamptz;
grant select,insert,update,delete on public.professional_availability,public.professional_blocked_times to authenticated;
grant all on public.professional_availability,public.professional_blocked_times to service_role;

-- Allow either party to cancel while protecting client-authored and live-session fields.
drop policy if exists "professionals respond to assigned requests" on public.session_requests;
create policy "professionals respond to assigned requests"
on public.session_requests for update to authenticated
using (professional_id = auth.uid())
with check (professional_id = auth.uid() and status in ('approved', 'declined', 'reschedule_proposed', 'cancelled'));

create or replace function public.guard_session_request_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() = 'service_role' then new.updated_at = now(); return new; end if;

  if new.meeting_url is not null and (char_length(new.meeting_url) > 1000 or new.meeting_url !~ '^https://') then
    raise exception 'Meeting links must begin with https:// and be 1000 characters or fewer.';
  end if;
  if new.meeting_instructions is not null and char_length(new.meeting_instructions) > 2000 then
    raise exception 'Meeting instructions must be 2000 characters or fewer.';
  end if;

  if auth.uid() = old.client_id then
    if old.status not in ('pending', 'reschedule_proposed', 'approved') then raise exception 'This session request can no longer be changed by the client.'; end if;
    if new.client_id is distinct from old.client_id
      or new.professional_id is distinct from old.professional_id
      or new.professional_response is distinct from old.professional_response
      or new.proposed_start_at is distinct from old.proposed_start_at
      or new.meeting_url is distinct from old.meeting_url
      or new.meeting_provider is distinct from old.meeting_provider
      or new.meeting_instructions is distinct from old.meeting_instructions
      or new.cancelled_by is distinct from old.cancelled_by
      or new.cancelled_at is distinct from old.cancelled_at then
      raise exception 'Clients cannot change professional or system-managed session fields.';
    end if;
    if new.status not in ('pending', 'cancelled') then raise exception 'Clients may only keep a request pending or cancel it.'; end if;
    if old.status = 'approved' and new.status <> 'cancelled' then raise exception 'Approved sessions may only be cancelled by the client.'; end if;
  elsif auth.uid() = old.professional_id then
    if new.client_id is distinct from old.client_id
      or new.professional_id is distinct from old.professional_id
      or new.requested_start_at is distinct from old.requested_start_at
      or new.duration_minutes is distinct from old.duration_minutes
      or new.session_type is distinct from old.session_type
      or new.format is distinct from old.format
      or new.location_details is distinct from old.location_details
      or new.client_message is distinct from old.client_message
      or new.cancelled_by is distinct from old.cancelled_by
      or new.cancelled_at is distinct from old.cancelled_at then
      raise exception 'Professionals cannot rewrite the client request or system-managed fields.';
    end if;
    if new.status not in ('approved', 'declined', 'reschedule_proposed', 'cancelled') then
      raise exception 'Choose approve, decline, propose a new time, or cancel.';
    end if;
    if old.status <> 'approved' and new.meeting_url is distinct from old.meeting_url then
      raise exception 'Add live-session details only after approving the request.';
    end if;
  else
    raise exception 'You cannot update this session request.';
  end if;

  if new.status = 'cancelled' and old.status <> 'cancelled' then
    new.cancelled_by = auth.uid();
    new.cancelled_at = now();
  elsif new.status <> 'cancelled' then
    new.cancelled_by = null;
    new.cancelled_at = null;
  end if;
  new.updated_at = now();
  return new;
end;
$$;

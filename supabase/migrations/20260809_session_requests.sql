-- ForgeFit session request workflow
-- Clients request sessions; professionals approve, decline, or propose another time.

create table if not exists public.session_requests (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.client_profiles(user_id) on delete cascade,
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  requested_start_at timestamptz not null,
  duration_minutes integer not null default 60,
  session_type text not null,
  format text not null,
  location_details text,
  client_message text,
  status text not null default 'pending',
  professional_response text,
  proposed_start_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint session_request_future_time check (requested_start_at > created_at),
  constraint session_request_duration check (duration_minutes between 15 and 240),
  constraint session_request_type_length check (char_length(session_type) between 2 and 120),
  constraint session_request_format check (format in ('virtual', 'in_person')),
  constraint session_request_status check (status in ('pending', 'approved', 'declined', 'reschedule_proposed', 'cancelled')),
  constraint session_request_location_length check (location_details is null or char_length(location_details) <= 500),
  constraint session_request_message_length check (client_message is null or char_length(client_message) <= 2000),
  constraint session_request_response_length check (professional_response is null or char_length(professional_response) <= 2000),
  constraint reschedule_requires_time check (status <> 'reschedule_proposed' or proposed_start_at is not null),
  constraint different_session_parties check (client_id <> professional_id)
);

create index if not exists session_requests_client_timeline_idx
  on public.session_requests (client_id, requested_start_at desc);

create index if not exists session_requests_professional_timeline_idx
  on public.session_requests (professional_id, requested_start_at desc);

alter table public.session_requests enable row level security;

drop policy if exists "clients view own session requests" on public.session_requests;
create policy "clients view own session requests"
on public.session_requests for select to authenticated
using (client_id = auth.uid());

drop policy if exists "professionals view assigned session requests" on public.session_requests;
create policy "professionals view assigned session requests"
on public.session_requests for select to authenticated
using (professional_id = auth.uid());

drop policy if exists "clients create session requests" on public.session_requests;
create policy "clients create session requests"
on public.session_requests for insert to authenticated
with check (
  client_id = auth.uid()
  and status = 'pending'
  and exists (
    select 1 from public.professional_profiles professional
    where professional.user_id = professional_id
      and professional.published = true
      and professional.accepting_clients = true
  )
);

drop policy if exists "clients update own requests" on public.session_requests;
create policy "clients update own requests"
on public.session_requests for update to authenticated
using (client_id = auth.uid())
with check (client_id = auth.uid() and status in ('pending', 'cancelled'));

drop policy if exists "professionals respond to assigned requests" on public.session_requests;
create policy "professionals respond to assigned requests"
on public.session_requests for update to authenticated
using (professional_id = auth.uid())
with check (professional_id = auth.uid() and status in ('approved', 'declined', 'reschedule_proposed'));

create or replace function public.guard_session_request_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() = 'service_role' then
    new.updated_at = now();
    return new;
  end if;

  if auth.uid() = old.client_id then
    if old.status not in ('pending', 'reschedule_proposed') then
      raise exception 'This session request can no longer be changed by the client.';
    end if;
    if new.client_id is distinct from old.client_id
      or new.professional_id is distinct from old.professional_id
      or new.professional_response is distinct from old.professional_response
      or new.proposed_start_at is distinct from old.proposed_start_at then
      raise exception 'Clients cannot change the professional response fields.';
    end if;
    if new.status not in ('pending', 'cancelled') then
      raise exception 'Clients may only keep a request pending or cancel it.';
    end if;
  elsif auth.uid() = old.professional_id then
    if new.client_id is distinct from old.client_id
      or new.professional_id is distinct from old.professional_id
      or new.requested_start_at is distinct from old.requested_start_at
      or new.duration_minutes is distinct from old.duration_minutes
      or new.session_type is distinct from old.session_type
      or new.format is distinct from old.format
      or new.location_details is distinct from old.location_details
      or new.client_message is distinct from old.client_message then
      raise exception 'Professionals cannot rewrite the client request.';
    end if;
    if new.status not in ('approved', 'declined', 'reschedule_proposed') then
      raise exception 'Choose approve, decline, or propose a new time.';
    end if;
  else
    raise exception 'You cannot update this session request.';
  end if;

  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists guard_session_request_update on public.session_requests;
create trigger guard_session_request_update
before update on public.session_requests
for each row execute function public.guard_session_request_update();

grant select, insert, update on table public.session_requests to authenticated;
grant all privileges on table public.session_requests to service_role;

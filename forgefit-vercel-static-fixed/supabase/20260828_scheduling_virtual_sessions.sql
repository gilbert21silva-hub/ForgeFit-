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
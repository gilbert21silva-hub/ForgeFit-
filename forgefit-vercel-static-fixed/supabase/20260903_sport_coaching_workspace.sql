-- ForgeFit professional sport coaching workspace
-- Sport-specific plans, drills, performance results, and coach notes.

create table if not exists public.sport_coaching_entries (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  client_id uuid not null references public.client_profiles(user_id) on delete cascade,
  coaching_date date not null default current_date,
  sport text not null check (char_length(trim(sport)) between 2 and 100),
  position_or_event text check (position_or_event is null or char_length(position_or_event) <= 100),
  focus text not null check (char_length(trim(focus)) between 2 and 180),
  plan text not null check (char_length(trim(plan)) between 2 and 5000),
  metric_name text check (metric_name is null or char_length(metric_name) <= 120),
  metric_result text check (metric_result is null or char_length(metric_result) <= 120),
  coach_notes text check (coach_notes is null or char_length(coach_notes) <= 3000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists sport_coaching_entries_professional_idx
  on public.sport_coaching_entries(professional_id, coaching_date desc);
create index if not exists sport_coaching_entries_client_idx
  on public.sport_coaching_entries(client_id, coaching_date desc);

alter table public.sport_coaching_entries enable row level security;

drop policy if exists "professionals manage approved athlete coaching" on public.sport_coaching_entries;
create policy "professionals manage approved athlete coaching"
on public.sport_coaching_entries for all to authenticated
using (professional_id = auth.uid())
with check (
  professional_id = auth.uid()
  and exists (
    select 1 from public.session_requests request
    where request.professional_id = auth.uid()
      and request.client_id = sport_coaching_entries.client_id
      and request.status = 'approved'
  )
);

grant select, insert, update, delete on public.sport_coaching_entries to authenticated;
grant all on public.sport_coaching_entries to service_role;

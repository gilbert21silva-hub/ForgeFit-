-- ForgeFit personal daily and weekly workouts

create table if not exists public.quick_workouts (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  client_id uuid not null references public.client_profiles(user_id) on delete cascade,
  cadence text not null check (cadence in ('daily','weekly')),
  scheduled_for date not null,
  title text not null check (char_length(trim(title)) between 2 and 140),
  details text not null check (char_length(trim(details)) between 2 and 5000),
  status text not null default 'active' check (status in ('active','completed','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists quick_workouts_professional_date_idx on public.quick_workouts(professional_id,scheduled_for desc);
create index if not exists quick_workouts_client_date_idx on public.quick_workouts(client_id,scheduled_for desc);

alter table public.quick_workouts enable row level security;

drop policy if exists "professionals manage personal workouts" on public.quick_workouts;
create policy "professionals manage personal workouts"
on public.quick_workouts for all to authenticated
using (professional_id=auth.uid())
with check (
  professional_id=auth.uid()
  and exists (
    select 1 from public.session_requests s
    where s.professional_id=auth.uid()
      and s.client_id=quick_workouts.client_id
      and s.status='approved'
  )
);

drop policy if exists "clients view personal workouts" on public.quick_workouts;
create policy "clients view personal workouts"
on public.quick_workouts for select to authenticated
using (client_id=auth.uid());

grant select,insert,update,delete on public.quick_workouts to authenticated;
grant all on public.quick_workouts to service_role;

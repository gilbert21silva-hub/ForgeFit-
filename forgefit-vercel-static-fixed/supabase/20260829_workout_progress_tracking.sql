-- ForgeFit shared workout completion and performance tracking
create table if not exists public.exercise_progress_logs (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.program_assignments(id) on delete cascade,
  exercise_id uuid not null references public.workout_exercises(id) on delete cascade,
  client_id uuid not null references public.client_profiles(user_id) on delete cascade,
  logged_on date not null default current_date,
  completed boolean not null default false,
  weight_value numeric check (weight_value is null or weight_value between 0 and 5000),
  weight_unit text check (weight_unit is null or weight_unit in ('lb','kg')),
  reps_completed integer check (reps_completed is null or reps_completed between 0 and 100000),
  duration_seconds integer check (duration_seconds is null or duration_seconds between 0 and 86400),
  distance_value numeric check (distance_value is null or distance_value between 0 and 100000),
  distance_unit text check (distance_unit is null or distance_unit in ('mi','km','m','yd')),
  rest_seconds integer check (rest_seconds is null or rest_seconds between 0 and 3600),
  notes text check (notes is null or char_length(notes) <= 2000),
  recorded_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(assignment_id,exercise_id,logged_on)
);
create table if not exists public.workout_day_completions (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.program_assignments(id) on delete cascade,
  workout_id uuid not null references public.program_workouts(id) on delete cascade,
  client_id uuid not null references public.client_profiles(user_id) on delete cascade,
  completed_on date not null default current_date,
  completed boolean not null default true,
  recorded_by uuid not null references auth.users(id),
  updated_at timestamptz not null default now(),
  unique(assignment_id,workout_id,completed_on)
);
create index if not exists exercise_progress_assignment_timeline_idx on public.exercise_progress_logs(assignment_id,logged_on desc);
create index if not exists workout_completion_assignment_timeline_idx on public.workout_day_completions(assignment_id,completed_on desc);
alter table public.exercise_progress_logs enable row level security;
alter table public.workout_day_completions enable row level security;

create or replace function public.can_track_program_assignment(target_assignment_id uuid)
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select exists (
    select 1 from public.program_assignments a
    where a.id=target_assignment_id
      and (a.client_id=auth.uid() or a.professional_id=auth.uid())
      and a.status in ('active','paused','completed')
  );
$$;
revoke all on function public.can_track_program_assignment(uuid) from public;
grant execute on function public.can_track_program_assignment(uuid) to authenticated;

drop policy if exists "assignment parties manage exercise progress" on public.exercise_progress_logs;
create policy "assignment parties manage exercise progress"
on public.exercise_progress_logs for all to authenticated
using (public.can_track_program_assignment(assignment_id))
with check (
  public.can_track_program_assignment(assignment_id)
  and recorded_by=auth.uid()
  and exists(select 1 from public.program_assignments a where a.id=assignment_id and a.client_id=client_id)
  and exists(select 1 from public.workout_exercises e join public.program_workouts w on w.id=e.workout_id join public.program_assignments a on a.program_id=w.program_id where e.id=exercise_id and a.id=assignment_id)
);

drop policy if exists "assignment parties manage workout completion" on public.workout_day_completions;
create policy "assignment parties manage workout completion"
on public.workout_day_completions for all to authenticated
using (public.can_track_program_assignment(assignment_id))
with check (
  public.can_track_program_assignment(assignment_id)
  and recorded_by=auth.uid()
  and exists(select 1 from public.program_assignments a where a.id=assignment_id and a.client_id=client_id)
  and exists(select 1 from public.program_workouts w join public.program_assignments a on a.program_id=w.program_id where w.id=workout_id and a.id=assignment_id)
);
grant select,insert,update,delete on public.exercise_progress_logs,public.workout_day_completions to authenticated;
grant all on public.exercise_progress_logs,public.workout_day_completions to service_role;

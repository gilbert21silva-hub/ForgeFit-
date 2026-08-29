-- ForgeFit workout program builder and client assignments
create table if not exists public.workout_programs (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  title text not null check (char_length(title) between 2 and 140),
  description text check (description is null or char_length(description) <= 3000),
  duration_weeks integer not null default 4 check (duration_weeks between 1 and 52),
  status text not null default 'draft' check (status in ('draft','active','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.program_workouts (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references public.workout_programs(id) on delete cascade,
  day_number integer not null check (day_number between 1 and 365),
  title text not null check (char_length(title) between 2 and 140),
  notes text check (notes is null or char_length(notes) <= 3000),
  created_at timestamptz not null default now()
);
create table if not exists public.workout_exercises (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid not null references public.program_workouts(id) on delete cascade,
  exercise_order integer not null default 1 check (exercise_order between 1 and 100),
  name text not null check (char_length(name) between 2 and 160),
  sets integer check (sets is null or sets between 1 and 100),
  reps text check (reps is null or char_length(reps) <= 60),
  rest_seconds integer check (rest_seconds is null or rest_seconds between 0 and 3600),
  tempo text check (tempo is null or char_length(tempo) <= 60),
  instructions text check (instructions is null or char_length(instructions) <= 3000),
  video_url text check (video_url is null or (char_length(video_url) <= 1000 and video_url ~ '^https://')),
  created_at timestamptz not null default now()
);
create table if not exists public.program_assignments (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references public.workout_programs(id) on delete cascade,
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  client_id uuid not null references public.client_profiles(user_id) on delete cascade,
  start_date date not null default current_date,
  status text not null default 'active' check (status in ('active','completed','paused','cancelled')),
  professional_notes text check (professional_notes is null or char_length(professional_notes) <= 3000),
  created_at timestamptz not null default now(),
  unique(program_id,client_id)
);
create index if not exists workout_programs_professional_idx on public.workout_programs(professional_id,created_at desc);
create index if not exists program_workouts_program_idx on public.program_workouts(program_id,day_number);
create index if not exists workout_exercises_workout_idx on public.workout_exercises(workout_id,exercise_order);
create index if not exists program_assignments_client_idx on public.program_assignments(client_id,status,start_date);
alter table public.workout_programs enable row level security;
alter table public.program_workouts enable row level security;
alter table public.workout_exercises enable row level security;
alter table public.program_assignments enable row level security;
create policy "professionals manage own programs" on public.workout_programs for all to authenticated using (professional_id=auth.uid()) with check (professional_id=auth.uid());
create policy "clients view assigned programs" on public.workout_programs for select to authenticated using (exists(select 1 from public.program_assignments a where a.program_id=id and a.client_id=auth.uid() and a.status in ('active','completed','paused')));
create policy "professionals manage own program workouts" on public.program_workouts for all to authenticated using (exists(select 1 from public.workout_programs p where p.id=program_id and p.professional_id=auth.uid())) with check (exists(select 1 from public.workout_programs p where p.id=program_id and p.professional_id=auth.uid()));
create policy "clients view assigned program workouts" on public.program_workouts for select to authenticated using (exists(select 1 from public.program_assignments a where a.program_id=program_id and a.client_id=auth.uid() and a.status in ('active','completed','paused')));
create policy "professionals manage own exercises" on public.workout_exercises for all to authenticated using (exists(select 1 from public.program_workouts w join public.workout_programs p on p.id=w.program_id where w.id=workout_id and p.professional_id=auth.uid())) with check (exists(select 1 from public.program_workouts w join public.workout_programs p on p.id=w.program_id where w.id=workout_id and p.professional_id=auth.uid()));
create policy "clients view assigned exercises" on public.workout_exercises for select to authenticated using (exists(select 1 from public.program_workouts w join public.program_assignments a on a.program_id=w.program_id where w.id=workout_id and a.client_id=auth.uid() and a.status in ('active','completed','paused')));
create policy "professionals manage assignments" on public.program_assignments for all to authenticated using (professional_id=auth.uid()) with check (professional_id=auth.uid() and exists(select 1 from public.workout_programs p where p.id=program_id and p.professional_id=auth.uid()) and exists(select 1 from public.session_requests s where s.professional_id=auth.uid() and s.client_id=client_id and s.status='approved'));
create policy "clients view own assignments" on public.program_assignments for select to authenticated using (client_id=auth.uid());
grant select,insert,update,delete on public.workout_programs,public.program_workouts,public.workout_exercises,public.program_assignments to authenticated;
grant all on public.workout_programs,public.program_workouts,public.workout_exercises,public.program_assignments to service_role;

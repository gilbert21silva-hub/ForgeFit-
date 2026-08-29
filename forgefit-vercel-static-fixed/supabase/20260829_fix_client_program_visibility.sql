-- Fix recursive client visibility checks for assigned workout content
create or replace function public.client_has_workout_program(target_program_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.program_assignments
    where program_id = target_program_id
      and client_id = auth.uid()
      and status in ('active','completed','paused')
  );
$$;
revoke all on function public.client_has_workout_program(uuid) from public;
grant execute on function public.client_has_workout_program(uuid) to authenticated;

drop policy if exists "clients view assigned programs" on public.workout_programs;
create policy "clients view assigned programs"
on public.workout_programs for select to authenticated
using (public.client_has_workout_program(id));

drop policy if exists "clients view assigned program workouts" on public.program_workouts;
create policy "clients view assigned program workouts"
on public.program_workouts for select to authenticated
using (public.client_has_workout_program(program_id));

create or replace function public.client_has_assigned_workout(target_workout_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.program_workouts w
    join public.program_assignments a on a.program_id = w.program_id
    where w.id = target_workout_id
      and a.client_id = auth.uid()
      and a.status in ('active','completed','paused')
  );
$$;
revoke all on function public.client_has_assigned_workout(uuid) from public;
grant execute on function public.client_has_assigned_workout(uuid) to authenticated;

drop policy if exists "clients view assigned exercises" on public.workout_exercises;
create policy "clients view assigned exercises"
on public.workout_exercises for select to authenticated
using (public.client_has_assigned_workout(workout_id));

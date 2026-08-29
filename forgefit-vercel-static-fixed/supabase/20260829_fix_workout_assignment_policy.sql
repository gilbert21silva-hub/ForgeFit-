-- Fix recursive workout assignment RLS check
create or replace function public.professional_owns_workout_program(target_program_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.workout_programs
    where id = target_program_id
      and professional_id = auth.uid()
  );
$$;
revoke all on function public.professional_owns_workout_program(uuid) from public;
grant execute on function public.professional_owns_workout_program(uuid) to authenticated;
drop policy if exists "professionals manage assignments" on public.program_assignments;
create policy "professionals manage assignments"
on public.program_assignments
for all
to authenticated
using (professional_id = auth.uid())
with check (
  professional_id = auth.uid()
  and public.professional_owns_workout_program(program_id)
  and exists (
    select 1
    from public.session_requests s
    where s.professional_id = auth.uid()
      and s.client_id = client_id
      and s.status = 'approved'
  )
);

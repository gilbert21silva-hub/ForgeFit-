-- Preserve repeat program cycles instead of overwriting older assignments
alter table public.program_assignments
  drop constraint if exists program_assignments_program_id_client_id_key;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname='program_assignments_program_client_start_key'
      and conrelid='public.program_assignments'::regclass
  ) then
    alter table public.program_assignments
      add constraint program_assignments_program_client_start_key
      unique(program_id,client_id,start_date);
  end if;
end $$;

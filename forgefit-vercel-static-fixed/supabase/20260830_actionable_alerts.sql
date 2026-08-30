-- ForgeFit actionable alert support
-- Marks received direct messages read when a participant opens the conversation.

create or replace function public.mark_connection_messages_read(connection_uuid uuid)
returns integer
language plpgsql security definer set search_path=public,pg_temp
as $$
declare changed_count integer;
begin
  if not exists(
    select 1 from public.message_connections c
    where c.id=connection_uuid
      and auth.uid() in (c.client_id,c.professional_id,c.other_client_id)
  ) then raise exception 'You cannot update this conversation.'; end if;

  update public.direct_messages
  set read_at=now()
  where connection_id=connection_uuid
    and sender_id<>auth.uid()
    and read_at is null;
  get diagnostics changed_count=row_count;
  return changed_count;
end $$;

grant execute on function public.mark_connection_messages_read(uuid) to authenticated;

-- ForgeFit explicit end-service action
-- Either participant may end an active professional/client relationship at any time.

create or replace function public.end_service_connection(connection_uuid uuid)
returns public.message_connections
language plpgsql security definer set search_path=public,pg_temp
as $$
declare connection_record public.message_connections;
begin
  select * into connection_record
  from public.message_connections
  where id=connection_uuid
  for update;

  if connection_record.id is null
     or connection_record.connection_type<>'professional_client'
     or auth.uid() not in (connection_record.client_id,connection_record.professional_id) then
    raise exception 'You cannot end this service connection.';
  end if;

  if connection_record.status='ended' then
    return connection_record;
  end if;

  if connection_record.status<>'active' then
    raise exception 'Only an active service connection can be ended.';
  end if;

  update public.message_connections
  set status='ended',updated_at=now()
  where id=connection_uuid
  returning * into connection_record;

  return connection_record;
end $$;

grant execute on function public.end_service_connection(uuid) to authenticated;

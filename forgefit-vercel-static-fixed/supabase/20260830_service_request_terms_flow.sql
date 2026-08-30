-- ForgeFit service request and terms approval workflow
-- Run after 20260830_secure_direct_messages.sql.

drop index if exists public.one_professional_client_message_connection;
create unique index one_professional_client_message_connection
  on public.message_connections(professional_id,client_id)
  where connection_type='professional_client' and status in ('service_requested','terms_sent','active');

alter table public.message_connections drop constraint if exists message_connections_status_check;
alter table public.message_connections add constraint message_connections_status_check
  check (status in ('service_requested','terms_sent','pending','active','declined','ended','blocked'));

alter table public.message_connections drop constraint if exists message_connections_check;
alter table public.message_connections add constraint message_connections_parties_check check (
  (connection_type='professional_client' and professional_id is not null and other_client_id is null and professional_id<>client_id
    and (service_terms is null or char_length(trim(service_terms)) between 10 and 4000))
  or
  (connection_type='client_client' and professional_id is null and other_client_id is not null and client_id<>other_client_id)
);

update public.message_connections
set status=case when service_terms is null then 'service_requested' else 'terms_sent' end,
    client_accepted_at=null,
    professional_accepted_at=case when service_terms is null then null else coalesce(professional_accepted_at,now()) end,
    updated_at=now()
where connection_type='professional_client' and status='pending';

create or replace function public.prepare_message_connection()
returns trigger language plpgsql security definer set search_path=public,pg_temp
as $$
declare requester_role text; professional_role text; client_role text; other_role text;
begin
  if auth.uid() is null or new.requested_by<>auth.uid() then raise exception 'You must request this connection yourself.'; end if;
  select role into requester_role from public.profiles where id=auth.uid();
  select role into client_role from public.profiles where id=new.client_id;
  if new.connection_type='professional_client' then
    select role into professional_role from public.profiles where id=new.professional_id;
    if professional_role<>'professional' or client_role<>'client' or auth.uid()<>new.client_id then raise exception 'Only a client can request services from a professional.'; end if;
    if not exists(select 1 from public.session_requests s where s.professional_id=new.professional_id and s.client_id=new.client_id and s.status='approved') then raise exception 'Request services after an approved session relationship.'; end if;
    new.service_terms=null; new.client_accepted_at=null; new.professional_accepted_at=null; new.status='service_requested';
  else
    select role into other_role from public.profiles where id=new.other_client_id;
    if requester_role<>'client' or client_role<>'client' or other_role<>'client' or new.client_id<>auth.uid() then raise exception 'Client message requests must be sent by the requesting client.'; end if;
    new.status='pending';
  end if;
  new.updated_at=now(); return new;
end $$;

create or replace function public.send_service_terms(connection_uuid uuid, terms_text text)
returns public.message_connections
language plpgsql security definer set search_path=public,pg_temp
as $$
declare connection_record public.message_connections;
begin
  select * into connection_record from public.message_connections where id=connection_uuid for update;
  if connection_record.id is null or connection_record.connection_type<>'professional_client' or connection_record.professional_id<>auth.uid() then raise exception 'Only the requested professional can send terms.'; end if;
  if connection_record.status<>'service_requested' then raise exception 'This service request is not waiting for terms.'; end if;
  if char_length(trim(coalesce(terms_text,''))) not between 10 and 4000 then raise exception 'Terms must be between 10 and 4000 characters.'; end if;
  update public.message_connections set service_terms=trim(terms_text),professional_accepted_at=now(),client_accepted_at=null,status='terms_sent',updated_at=now() where id=connection_uuid returning * into connection_record;
  return connection_record;
end $$;

create or replace function public.respond_to_message_connection(connection_uuid uuid, decision text)
returns public.message_connections
language plpgsql security definer set search_path=public,pg_temp
as $$
declare connection_record public.message_connections;
begin
  select * into connection_record from public.message_connections where id=connection_uuid for update;
  if connection_record.id is null or auth.uid() is null then raise exception 'Connection not found.'; end if;
  if decision='block' and auth.uid() in (connection_record.client_id,connection_record.professional_id,connection_record.other_client_id) then
    update public.message_connections set status='blocked',updated_at=now() where id=connection_record.id returning * into connection_record; return connection_record;
  end if;
  if decision='end' and connection_record.status='active' and auth.uid() in (connection_record.client_id,connection_record.professional_id,connection_record.other_client_id) then
    update public.message_connections set status='ended',updated_at=now() where id=connection_record.id returning * into connection_record; return connection_record;
  end if;
  if connection_record.connection_type='client_client' then
    if connection_record.status<>'pending' or auth.uid()<>connection_record.other_client_id or decision not in ('accept','decline') then raise exception 'Only the invited client can respond.'; end if;
    update public.message_connections set status=case when decision='accept' then 'active' else 'declined' end,recipient_accepted_at=case when decision='accept' then now() else null end,updated_at=now() where id=connection_record.id returning * into connection_record;
  else
    if connection_record.status<>'terms_sent' or auth.uid()<>connection_record.client_id or decision not in ('accept','decline') then raise exception 'The client must accept or decline the professional terms.'; end if;
    update public.message_connections set status=case when decision='accept' then 'active' else 'declined' end,client_accepted_at=case when decision='accept' then now() else null end,updated_at=now() where id=connection_record.id returning * into connection_record;
  end if;
  return connection_record;
end $$;

create or replace function public.has_active_service_relationship(professional_uuid uuid, client_uuid uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp
as $$ select exists(select 1 from public.message_connections c where c.connection_type='professional_client' and c.professional_id=professional_uuid and c.client_id=client_uuid and c.status='active') $$;

grant execute on function public.send_service_terms(uuid,text) to authenticated;
grant execute on function public.respond_to_message_connection(uuid,text) to authenticated;
grant execute on function public.has_active_service_relationship(uuid,uuid) to authenticated;

-- ForgeFit secure direct messaging
-- Pro/client chat requires an approved service relationship plus explicit terms acceptance.
-- Client/client chat requires recipient approval.

create table if not exists public.message_connections (
  id uuid primary key default gen_random_uuid(),
  connection_type text not null check (connection_type in ('professional_client','client_client')),
  professional_id uuid references auth.users(id) on delete cascade,
  client_id uuid not null references auth.users(id) on delete cascade,
  other_client_id uuid references auth.users(id) on delete cascade,
  requested_by uuid not null references auth.users(id) on delete cascade,
  service_terms text,
  status text not null default 'pending' check (status in ('pending','active','declined','blocked')),
  client_accepted_at timestamptz,
  professional_accepted_at timestamptz,
  recipient_accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (connection_type='professional_client' and professional_id is not null and other_client_id is null and professional_id<>client_id and char_length(trim(service_terms)) between 10 and 4000)
    or
    (connection_type='client_client' and professional_id is null and other_client_id is not null and client_id<>other_client_id)
  )
);

create unique index if not exists one_professional_client_message_connection
  on public.message_connections(professional_id,client_id) where connection_type='professional_client' and status in ('pending','active');
create unique index if not exists one_client_pair_message_connection
  on public.message_connections(least(client_id,other_client_id),greatest(client_id,other_client_id)) where connection_type='client_client' and status in ('pending','active');
create index if not exists message_connections_participants_idx on public.message_connections(client_id,professional_id,other_client_id,status);

create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references public.message_connections(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 4000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists direct_messages_thread_idx on public.direct_messages(connection_id,created_at);

create or replace function public.is_message_participant(connection_record public.message_connections)
returns boolean language sql stable security definer set search_path=public,pg_temp
as $$ select auth.uid() in (connection_record.client_id,connection_record.professional_id,connection_record.other_client_id) $$;

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
    if professional_role<>'professional' or client_role<>'client' or auth.uid() not in (new.professional_id,new.client_id) then raise exception 'Invalid professional/client connection.'; end if;
    if char_length(trim(coalesce(new.service_terms,''))) not between 10 and 4000 then raise exception 'Add the agreed service terms before requesting messaging.'; end if;
    if not exists(select 1 from public.session_requests s where s.professional_id=new.professional_id and s.client_id=new.client_id and s.status='approved') then raise exception 'Messaging opens after an approved service relationship.'; end if;
    if auth.uid()=new.client_id then new.client_accepted_at=now(); else new.professional_accepted_at=now(); end if;
  else
    select role into other_role from public.profiles where id=new.other_client_id;
    if requester_role<>'client' or client_role<>'client' or other_role<>'client' or new.client_id<>auth.uid() then raise exception 'Client message requests must be sent by the requesting client.'; end if;
  end if;
  new.status='pending'; new.updated_at=now(); return new;
end $$;

drop trigger if exists prepare_message_connection_trigger on public.message_connections;
create trigger prepare_message_connection_trigger before insert on public.message_connections for each row execute function public.prepare_message_connection();

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
  if connection_record.status<>'pending' or decision not in ('accept','decline') then raise exception 'This request cannot be changed.'; end if;
  if connection_record.connection_type='client_client' then
    if auth.uid()<>connection_record.other_client_id then raise exception 'Only the invited client can respond.'; end if;
    update public.message_connections set status=case when decision='accept' then 'active' else 'declined' end,recipient_accepted_at=case when decision='accept' then now() else null end,updated_at=now() where id=connection_record.id returning * into connection_record;
  else
    if auth.uid()=connection_record.client_id and connection_record.client_accepted_at is null then connection_record.client_accepted_at=now();
    elsif auth.uid()=connection_record.professional_id and connection_record.professional_accepted_at is null then connection_record.professional_accepted_at=now();
    else raise exception 'The other person must respond.'; end if;
    update public.message_connections set client_accepted_at=connection_record.client_accepted_at,professional_accepted_at=connection_record.professional_accepted_at,status=case when decision='decline' then 'declined' when connection_record.client_accepted_at is not null and connection_record.professional_accepted_at is not null then 'active' else 'pending' end,updated_at=now() where id=connection_record.id returning * into connection_record;
  end if;
  return connection_record;
end $$;

alter table public.message_connections enable row level security;
alter table public.direct_messages enable row level security;
drop policy if exists "participants view message connections" on public.message_connections;
create policy "participants view message connections" on public.message_connections for select to authenticated using (public.is_message_participant(message_connections));
drop policy if exists "participants request message connections" on public.message_connections;
create policy "participants request message connections" on public.message_connections for insert to authenticated with check (requested_by=auth.uid() and auth.uid() in (client_id,professional_id,other_client_id));
drop policy if exists "participants view direct messages" on public.direct_messages;
create policy "participants view direct messages" on public.direct_messages for select to authenticated using (exists(select 1 from public.message_connections c where c.id=direct_messages.connection_id and public.is_message_participant(c)));
drop policy if exists "active participants send direct messages" on public.direct_messages;
create policy "active participants send direct messages" on public.direct_messages for insert to authenticated with check (sender_id=auth.uid() and exists(select 1 from public.message_connections c where c.id=direct_messages.connection_id and c.status='active' and public.is_message_participant(c)));

grant select,insert on public.message_connections to authenticated;
grant select,insert on public.direct_messages to authenticated;
grant execute on function public.respond_to_message_connection(uuid,text) to authenticated;
grant all on public.message_connections,public.direct_messages to service_role;

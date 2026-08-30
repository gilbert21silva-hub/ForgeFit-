-- ForgeFit private service-terms attachments
-- Adds optional PDF/document attachments to professional terms.

alter table public.message_connections
  add column if not exists terms_file_path text,
  add column if not exists terms_file_name text,
  add column if not exists terms_file_type text,
  add column if not exists terms_file_size_bytes bigint;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('service-terms','service-terms',false,10485760,array[
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'text/plain'
])
on conflict (id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "professionals upload service terms" on storage.objects;
create policy "professionals upload service terms"
on storage.objects for insert to authenticated
with check (
  bucket_id='service-terms'
  and exists (
    select 1 from public.message_connections c
    where c.id::text=(storage.foldername(name))[1]
      and c.professional_id=auth.uid()
      and c.status='service_requested'
  )
);

drop policy if exists "participants read service terms" on storage.objects;
create policy "participants read service terms"
on storage.objects for select to authenticated
using (
  bucket_id='service-terms'
  and exists (
    select 1 from public.message_connections c
    where c.id::text=(storage.foldername(name))[1]
      and auth.uid() in (c.client_id,c.professional_id)
  )
);

drop policy if exists "professionals delete service terms" on storage.objects;
create policy "professionals delete service terms"
on storage.objects for delete to authenticated
using (
  bucket_id='service-terms'
  and exists (
    select 1 from public.message_connections c
    where c.id::text=(storage.foldername(name))[1]
      and c.professional_id=auth.uid()
  )
);

drop function if exists public.send_service_terms(uuid,text);
create or replace function public.send_service_terms(
  connection_uuid uuid,
  terms_text text,
  file_path text default null,
  file_name text default null,
  file_type text default null,
  file_size_bytes bigint default null
)
returns public.message_connections
language plpgsql security definer set search_path=public,pg_temp
as $$
declare connection_record public.message_connections;
begin
  select * into connection_record from public.message_connections where id=connection_uuid for update;
  if connection_record.id is null or connection_record.connection_type<>'professional_client' or connection_record.professional_id<>auth.uid() then raise exception 'Only the requested professional can send terms.'; end if;
  if connection_record.status<>'service_requested' then raise exception 'This service request is not waiting for terms.'; end if;
  if char_length(trim(coalesce(terms_text,''))) not between 10 and 4000 then raise exception 'Add a clear written summary between 10 and 4000 characters.'; end if;
  if file_path is not null and (file_name is null or file_size_bytes is null or file_size_bytes<1 or file_size_bytes>10485760 or file_path not like connection_uuid::text||'/%') then raise exception 'The terms attachment is invalid.'; end if;
  update public.message_connections
  set service_terms=trim(terms_text),
      terms_file_path=file_path,
      terms_file_name=file_name,
      terms_file_type=file_type,
      terms_file_size_bytes=file_size_bytes,
      professional_accepted_at=now(),
      client_accepted_at=null,
      status='terms_sent',
      updated_at=now()
  where id=connection_uuid
  returning * into connection_record;
  return connection_record;
end $$;

grant execute on function public.send_service_terms(uuid,text,text,text,text,bigint) to authenticated;

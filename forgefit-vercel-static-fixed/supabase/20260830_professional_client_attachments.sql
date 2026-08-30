-- ForgeFit professional-to-client private attachments

create table if not exists public.professional_client_attachments (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references auth.users(id) on delete cascade,
  client_id uuid not null references auth.users(id) on delete cascade,
  category text not null check (category in ('questionnaire','workout_plan','agreement','exercise_log','other')),
  title text not null check (char_length(trim(title)) between 1 and 200),
  note text check (note is null or char_length(note)<=2000),
  storage_path text not null unique,
  file_name text not null,
  mime_type text not null,
  file_size_bytes bigint not null check (file_size_bytes between 1 and 26214400),
  created_at timestamptz not null default now(),
  check (professional_id<>client_id)
);
create index if not exists professional_client_attachments_lookup on public.professional_client_attachments(professional_id,client_id,created_at desc);
alter table public.professional_client_attachments enable row level security;

drop policy if exists "professionals manage client attachments" on public.professional_client_attachments;
create policy "professionals manage client attachments" on public.professional_client_attachments
for all to authenticated
using (professional_id=auth.uid())
with check (
  professional_id=auth.uid()
  and exists(select 1 from public.message_connections c where c.professional_id=auth.uid() and c.client_id=professional_client_attachments.client_id and c.status='active')
);

drop policy if exists "clients view professional attachments" on public.professional_client_attachments;
create policy "clients view professional attachments" on public.professional_client_attachments
for select to authenticated using (client_id=auth.uid());

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('client-attachments','client-attachments',false,26214400,array[
'application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document',
'application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
'text/csv','text/plain','image/jpeg','image/png','image/webp'
])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "professionals upload client attachments" on storage.objects;
create policy "professionals upload client attachments" on storage.objects for insert to authenticated
with check (
 bucket_id='client-attachments'
 and (storage.foldername(name))[1]=auth.uid()::text
 and exists(select 1 from public.message_connections c where c.professional_id=auth.uid() and c.client_id::text=(storage.foldername(name))[2] and c.status='active')
);
drop policy if exists "participants read client attachments" on storage.objects;
create policy "participants read client attachments" on storage.objects for select to authenticated
using (
 bucket_id='client-attachments'
 and (
   (storage.foldername(name))[1]=auth.uid()::text
   or (storage.foldername(name))[2]=auth.uid()::text
 )
);
drop policy if exists "professionals delete client attachments" on storage.objects;
create policy "professionals delete client attachments" on storage.objects for delete to authenticated
using (bucket_id='client-attachments' and (storage.foldername(name))[1]=auth.uid()::text);

grant select,insert,delete on public.professional_client_attachments to authenticated;
grant all on public.professional_client_attachments to service_role;

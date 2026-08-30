-- Fix professional client attachment access
-- Client Management includes clients with approved sessions, even when a later service connection ended.

drop policy if exists "professionals manage client attachments" on public.professional_client_attachments;
create policy "professionals manage client attachments"
on public.professional_client_attachments
for all to authenticated
using (professional_id=auth.uid())
with check (
  professional_id=auth.uid()
  and (
    exists(select 1 from public.message_connections c where c.professional_id=auth.uid() and c.client_id=professional_client_attachments.client_id and c.status='active')
    or exists(select 1 from public.session_requests s where s.professional_id=auth.uid() and s.client_id=professional_client_attachments.client_id and s.status='approved')
  )
);

drop policy if exists "professionals upload client attachments" on storage.objects;
create policy "professionals upload client attachments"
on storage.objects for insert to authenticated
with check (
  bucket_id='client-attachments'
  and (storage.foldername(name))[1]=auth.uid()::text
  and (
    exists(select 1 from public.message_connections c where c.professional_id=auth.uid() and c.client_id::text=(storage.foldername(name))[2] and c.status='active')
    or exists(select 1 from public.session_requests s where s.professional_id=auth.uid() and s.client_id::text=(storage.foldername(name))[2] and s.status='approved')
  )
);

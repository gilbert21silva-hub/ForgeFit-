-- Dedicated client profile pictures
alter table public.client_profiles
  add column if not exists profile_image_path text;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values (
  'client-profile-photos',
  'client-profile-photos',
  false,
  10485760,
  array['image/jpeg','image/png','image/webp']
)
on conflict (id) do update
set public=false,
    file_size_limit=excluded.file_size_limit,
    allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "clients upload own profile photo" on storage.objects;
create policy "clients upload own profile photo"
on storage.objects for insert to authenticated
with check (
  bucket_id='client-profile-photos'
  and (storage.foldername(name))[1]=auth.uid()::text
);

drop policy if exists "clients update own profile photo" on storage.objects;
create policy "clients update own profile photo"
on storage.objects for update to authenticated
using (
  bucket_id='client-profile-photos'
  and owner_id=auth.uid()::text
)
with check (
  bucket_id='client-profile-photos'
  and owner_id=auth.uid()::text
);

drop policy if exists "clients delete own profile photo" on storage.objects;
create policy "clients delete own profile photo"
on storage.objects for delete to authenticated
using (
  bucket_id='client-profile-photos'
  and owner_id=auth.uid()::text
);

drop policy if exists "clients and connected professionals view client profile photos" on storage.objects;
create policy "clients and connected professionals view client profile photos"
on storage.objects for select to authenticated
using (
  bucket_id='client-profile-photos'
  and (
    owner_id=auth.uid()::text
    or exists (
      select 1
      from public.client_profiles client_profile
      where client_profile.profile_image_path=storage.objects.name
        and public.has_active_service_relationship(auth.uid(),client_profile.user_id)
    )
  )
);

grant select,update (profile_image_path) on public.client_profiles to authenticated;
notify pgrst, 'reload schema';

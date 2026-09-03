-- Allow authenticated members to view dedicated photos for published professionals.
-- Existing owners retain access; private/unpublished professional photos remain protected.

drop policy if exists "members view professional profile photos" on storage.objects;
create policy "members view professional profile photos"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'professional-gallery'
  and (
    owner_id = auth.uid()::text
    or exists (
      select 1
      from public.professional_profiles professional
      where professional.profile_image_path = storage.objects.name
        and professional.published = true
    )
    or exists (
      select 1
      from public.professional_gallery_media media
      where media.storage_path = storage.objects.name
        and media.published = true
    )
  )
);

notify pgrst, 'reload schema';

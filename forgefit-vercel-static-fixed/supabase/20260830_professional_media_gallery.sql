-- ForgeFit professional media gallery
create table if not exists public.professional_gallery_media (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  storage_path text not null unique check (char_length(storage_path) between 3 and 1000),
  file_name text not null check (char_length(file_name) between 1 and 300),
  media_type text not null check (media_type in ('image','video')),
  mime_type text not null check (mime_type in ('image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime')),
  file_size_bytes bigint not null check (file_size_bytes between 1 and 104857600),
  category text not null default 'professional' check (category in ('workout','client_result','competition','education','professional')),
  caption text check (caption is null or char_length(caption) <= 500),
  published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists professional_gallery_owner_idx on public.professional_gallery_media(professional_id,created_at desc);
create index if not exists professional_gallery_public_idx on public.professional_gallery_media(published,created_at desc);
alter table public.professional_gallery_media enable row level security;

drop policy if exists "professionals manage own gallery" on public.professional_gallery_media;
create policy "professionals manage own gallery" on public.professional_gallery_media
for all to authenticated
using (professional_id=auth.uid())
with check (professional_id=auth.uid());

drop policy if exists "members view published professional gallery" on public.professional_gallery_media;
create policy "members view published professional gallery" on public.professional_gallery_media
for select to authenticated using (published=true);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('professional-gallery','professional-gallery',false,104857600,array['image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime'])
on conflict (id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "professionals upload own gallery files" on storage.objects;
create policy "professionals upload own gallery files" on storage.objects
for insert to authenticated
with check (bucket_id='professional-gallery' and (storage.foldername(name))[1]=auth.uid()::text);

drop policy if exists "professionals update own gallery files" on storage.objects;
create policy "professionals update own gallery files" on storage.objects
for update to authenticated
using (bucket_id='professional-gallery' and owner_id=auth.uid())
with check (bucket_id='professional-gallery' and owner_id=auth.uid());

drop policy if exists "professionals delete own gallery files" on storage.objects;
create policy "professionals delete own gallery files" on storage.objects
for delete to authenticated
using (bucket_id='professional-gallery' and owner_id=auth.uid());

drop policy if exists "members view permitted gallery files" on storage.objects;
create policy "members view permitted gallery files" on storage.objects
for select to authenticated
using (
  bucket_id='professional-gallery'
  and (
    owner_id=auth.uid()
    or exists (
      select 1 from public.professional_gallery_media media
      where media.storage_path=storage.objects.name and media.published=true
    )
  )
);

grant select,insert,update,delete on public.professional_gallery_media to authenticated;
grant all on public.professional_gallery_media to service_role;

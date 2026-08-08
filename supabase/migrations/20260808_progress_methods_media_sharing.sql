-- ForgeFit progress methods, private media, and revocable sharing
-- Apply after 20260808_client_competition_progress.sql.

alter table public.client_measurements
  add column if not exists measurement_method text not null default 'tape',
  add column if not exists calculation_profile text,
  add column if not exists age_years integer,
  add column if not exists chest_skinfold_mm numeric(5,2),
  add column if not exists midaxillary_skinfold_mm numeric(5,2),
  add column if not exists triceps_skinfold_mm numeric(5,2),
  add column if not exists subscapular_skinfold_mm numeric(5,2),
  add column if not exists abdomen_skinfold_mm numeric(5,2),
  add column if not exists suprailiac_skinfold_mm numeric(5,2),
  add column if not exists thigh_skinfold_mm numeric(5,2),
  add constraint measurement_method_allowed check (measurement_method in ('tape', 'caliper_3', 'caliper_7', 'device')),
  add constraint measurement_profile_allowed check (calculation_profile is null or calculation_profile in ('male', 'female')),
  add constraint measurement_age_range check (age_years is null or age_years between 18 and 100),
  add constraint measurement_skinfold_ranges check (
    (chest_skinfold_mm is null or chest_skinfold_mm between 1 and 100)
    and (midaxillary_skinfold_mm is null or midaxillary_skinfold_mm between 1 and 100)
    and (triceps_skinfold_mm is null or triceps_skinfold_mm between 1 and 100)
    and (subscapular_skinfold_mm is null or subscapular_skinfold_mm between 1 and 100)
    and (abdomen_skinfold_mm is null or abdomen_skinfold_mm between 1 and 100)
    and (suprailiac_skinfold_mm is null or suprailiac_skinfold_mm between 1 and 100)
    and (thigh_skinfold_mm is null or thigh_skinfold_mm between 1 and 100)
  );

create table if not exists public.progress_media (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.client_profiles(user_id) on delete cascade,
  storage_path text not null unique,
  media_type text not null,
  category text not null default 'progress',
  caption text,
  captured_at date not null default current_date,
  file_size_bytes bigint not null,
  created_at timestamptz not null default now(),
  constraint progress_media_type check (media_type in ('photo', 'video')),
  constraint progress_media_category check (category in ('progress', 'form_review', 'posing_review', 'virtual_checkin', 'competition_prep')),
  constraint progress_media_caption_length check (char_length(caption) <= 500),
  constraint progress_media_size check (file_size_bytes between 1 and 104857600)
);

create index if not exists progress_media_client_timeline_idx
  on public.progress_media (client_id, captured_at desc, created_at desc);

create table if not exists public.client_progress_shares (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.client_profiles(user_id) on delete cascade,
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  measurement_id uuid references public.client_measurements(id) on delete cascade,
  media_id uuid references public.progress_media(id) on delete cascade,
  shared_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint one_shared_progress_item check (
    (measurement_id is not null and media_id is null)
    or (measurement_id is null and media_id is not null)
  )
);

create unique index if not exists active_measurement_share_unique
  on public.client_progress_shares (client_id, professional_id, measurement_id)
  where measurement_id is not null and revoked_at is null;
create unique index if not exists active_media_share_unique
  on public.client_progress_shares (client_id, professional_id, media_id)
  where media_id is not null and revoked_at is null;

alter table public.progress_media enable row level security;
alter table public.client_progress_shares enable row level security;

drop policy if exists "clients privately manage own progress media" on public.progress_media;
create policy "clients privately manage own progress media"
on public.progress_media for all to authenticated
using (auth.uid() = client_id)
with check (auth.uid() = client_id);

drop policy if exists "professionals view explicitly shared measurements" on public.client_measurements;
create policy "professionals view explicitly shared measurements"
on public.client_measurements for select to authenticated
using (
  exists (
    select 1 from public.client_progress_shares share
    where share.measurement_id = client_measurements.id
      and share.professional_id = auth.uid()
      and share.revoked_at is null
  )
);

drop policy if exists "professionals view explicitly shared media metadata" on public.progress_media;
create policy "professionals view explicitly shared media metadata"
on public.progress_media for select to authenticated
using (
  exists (
    select 1 from public.client_progress_shares share
    where share.media_id = progress_media.id
      and share.professional_id = auth.uid()
      and share.revoked_at is null
  )
);

drop policy if exists "clients manage own progress shares" on public.client_progress_shares;
create policy "clients manage own progress shares"
on public.client_progress_shares for all to authenticated
using (auth.uid() = client_id)
with check (auth.uid() = client_id);

drop policy if exists "professionals view shares addressed to them" on public.client_progress_shares;
create policy "professionals view shares addressed to them"
on public.client_progress_shares for select to authenticated
using (auth.uid() = professional_id and revoked_at is null);

grant select, insert, update, delete on table public.progress_media to authenticated;
grant select, insert, update, delete on table public.client_progress_shares to authenticated;
grant all privileges on table public.progress_media to service_role;
grant all privileges on table public.client_progress_shares to service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'progress-media',
  'progress-media',
  false,
  104857600,
  array['image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime']
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "clients upload own progress media files" on storage.objects;
create policy "clients upload own progress media files"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'progress-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "clients view own progress media files" on storage.objects;
create policy "clients view own progress media files"
on storage.objects for select to authenticated
using (
  bucket_id = 'progress-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "professionals view explicitly shared progress files" on storage.objects;
create policy "professionals view explicitly shared progress files"
on storage.objects for select to authenticated
using (
  bucket_id = 'progress-media'
  and exists (
    select 1
    from public.progress_media media
    join public.client_progress_shares share on share.media_id = media.id
    where media.storage_path = name
      and share.professional_id = auth.uid()
      and share.revoked_at is null
  )
);

drop policy if exists "clients update own progress media files" on storage.objects;
create policy "clients update own progress media files"
on storage.objects for update to authenticated
using (bucket_id = 'progress-media' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'progress-media' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "clients delete own progress media files" on storage.objects;
create policy "clients delete own progress media files"
on storage.objects for delete to authenticated
using (bucket_id = 'progress-media' and (storage.foldername(name))[1] = auth.uid()::text);

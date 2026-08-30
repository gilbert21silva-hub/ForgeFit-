-- Add album organization to professional media galleries
alter table public.professional_gallery_media
  add column if not exists album_name text not null default 'General'
  check (char_length(album_name) between 1 and 120);

update public.professional_gallery_media
set album_name=case category
  when 'client_result' then 'Client Results'
  when 'workout' then 'Workout Demonstrations'
  when 'competition' then 'Competition'
  when 'education' then 'Education'
  else 'Professional Highlights'
end
where album_name='General';

create index if not exists professional_gallery_album_idx
  on public.professional_gallery_media(professional_id,album_name,created_at desc);

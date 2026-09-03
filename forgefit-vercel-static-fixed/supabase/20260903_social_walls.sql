-- ForgeFit social walls, connections, reactions, comments, reports, and private media
create table if not exists public.social_connections (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  addressee_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','approved','declined')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (requester_id <> addressee_id)
);
create unique index if not exists one_social_connection_pair
on public.social_connections (least(requester_id,addressee_id), greatest(requester_id,addressee_id));

create table if not exists public.social_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade default auth.uid(),
  body text,
  media_path text,
  media_type text check (media_type in ('image','video')),
  audience text not null default 'connections' check (audience in ('private','connections','public')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (nullif(trim(coalesce(body,'')),'') is not null or media_path is not null),
  check (char_length(coalesce(body,'')) <= 3000)
);
create index if not exists social_posts_author_created_idx on public.social_posts(author_id,created_at desc);

create table if not exists public.social_post_likes (
  post_id uuid not null references public.social_posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade default auth.uid(),
  created_at timestamptz not null default now(),
  primary key(post_id,user_id)
);
create table if not exists public.social_post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.social_posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade default auth.uid(),
  body text not null check (char_length(trim(body)) between 1 and 1000),
  created_at timestamptz not null default now()
);
create table if not exists public.social_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade default auth.uid(),
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(blocker_id,blocked_id),
  check (blocker_id <> blocked_id)
);
create table if not exists public.social_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade default auth.uid(),
  post_id uuid not null references public.social_posts(id) on delete cascade,
  reason text not null check (char_length(trim(reason)) between 3 and 500),
  status text not null default 'open' check (status in ('open','reviewed','closed')),
  created_at timestamptz not null default now(),
  unique(reporter_id,post_id)
);

create or replace function public.socially_connected(a uuid,b uuid)
returns boolean language sql stable security definer set search_path=public
as $$ select
  exists(select 1 from public.message_connections m where m.status='active' and ((m.professional_id=a and m.client_id=b) or (m.professional_id=b and m.client_id=a)))
  or exists(select 1 from public.social_connections s where s.status='approved' and ((s.requester_id=a and s.addressee_id=b) or (s.requester_id=b and s.addressee_id=a)));
$$;
create or replace function public.can_view_social_post(post_author uuid,post_audience text)
returns boolean language sql stable security definer set search_path=public
as $$ select auth.uid()=post_author or (
  not exists(select 1 from public.social_blocks b where (b.blocker_id=auth.uid() and b.blocked_id=post_author) or (b.blocker_id=post_author and b.blocked_id=auth.uid()))
  and (post_audience='public' or (post_audience='connections' and public.socially_connected(auth.uid(),post_author)))
); $$;

alter table public.social_connections enable row level security;
alter table public.social_posts enable row level security;
alter table public.social_post_likes enable row level security;
alter table public.social_post_comments enable row level security;
alter table public.social_blocks enable row level security;
alter table public.social_reports enable row level security;

drop policy if exists "participants view social connections" on public.social_connections;
create policy "participants view social connections" on public.social_connections for select using (auth.uid() in (requester_id,addressee_id));
drop policy if exists "request social connection" on public.social_connections;
create policy "request social connection" on public.social_connections for insert with check (auth.uid()=requester_id and status='pending');
drop policy if exists "respond social connection" on public.social_connections;
create policy "respond social connection" on public.social_connections for update using (auth.uid() in (requester_id,addressee_id)) with check (auth.uid() in (requester_id,addressee_id));
drop policy if exists "remove social connection" on public.social_connections;
create policy "remove social connection" on public.social_connections for delete using (auth.uid() in (requester_id,addressee_id));

drop policy if exists "view permitted social posts" on public.social_posts;
create policy "view permitted social posts" on public.social_posts for select using (public.can_view_social_post(author_id,audience));
drop policy if exists "author creates social posts" on public.social_posts;
create policy "author creates social posts" on public.social_posts for insert with check (auth.uid()=author_id);
drop policy if exists "author updates social posts" on public.social_posts;
create policy "author updates social posts" on public.social_posts for update using (auth.uid()=author_id) with check (auth.uid()=author_id);
drop policy if exists "author deletes social posts" on public.social_posts;
create policy "author deletes social posts" on public.social_posts for delete using (auth.uid()=author_id);

drop policy if exists "view likes on visible posts" on public.social_post_likes;
create policy "view likes on visible posts" on public.social_post_likes for select using (exists(select 1 from public.social_posts p where p.id=post_id));
drop policy if exists "manage own likes" on public.social_post_likes;
create policy "manage own likes" on public.social_post_likes for insert with check (auth.uid()=user_id and exists(select 1 from public.social_posts p where p.id=post_id));
drop policy if exists "remove own likes" on public.social_post_likes;
create policy "remove own likes" on public.social_post_likes for delete using (auth.uid()=user_id);

drop policy if exists "view comments on visible posts" on public.social_post_comments;
create policy "view comments on visible posts" on public.social_post_comments for select using (exists(select 1 from public.social_posts p where p.id=post_id));
drop policy if exists "comment on visible posts" on public.social_post_comments;
create policy "comment on visible posts" on public.social_post_comments for insert with check (auth.uid()=author_id and exists(select 1 from public.social_posts p where p.id=post_id));
drop policy if exists "manage own comments" on public.social_post_comments;
create policy "manage own comments" on public.social_post_comments for delete using (auth.uid()=author_id);

drop policy if exists "manage own blocks" on public.social_blocks;
create policy "manage own blocks" on public.social_blocks for all using (auth.uid()=blocker_id) with check (auth.uid()=blocker_id);
drop policy if exists "create own reports" on public.social_reports;
create policy "create own reports" on public.social_reports for insert with check (auth.uid()=reporter_id);
drop policy if exists "view own reports" on public.social_reports;
create policy "view own reports" on public.social_reports for select using (auth.uid()=reporter_id);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('social-media','social-media',false,104857600,array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/quicktime','video/webm'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists "upload own social media" on storage.objects;
create policy "upload own social media" on storage.objects for insert to authenticated
with check (bucket_id='social-media' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "view permitted social media" on storage.objects;
create policy "view permitted social media" on storage.objects for select to authenticated
using (bucket_id='social-media' and exists(select 1 from public.social_posts p where p.media_path=name and public.can_view_social_post(p.author_id,p.audience)));
drop policy if exists "manage own social media" on storage.objects;
create policy "manage own social media" on storage.objects for delete to authenticated
using (bucket_id='social-media' and (storage.foldername(name))[1]=auth.uid()::text);

grant execute on function public.socially_connected(uuid,uuid) to authenticated;
grant execute on function public.can_view_social_post(uuid,text) to authenticated;

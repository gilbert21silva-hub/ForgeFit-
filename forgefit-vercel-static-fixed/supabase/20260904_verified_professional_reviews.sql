-- ForgeFit verified professional reviews and ratings
create table if not exists public.professional_reviews (
  id uuid primary key default gen_random_uuid(),
  connection_id uuid not null references public.message_connections(id) on delete restrict,
  professional_id uuid not null references public.profiles(id) on delete cascade,
  client_id uuid not null references public.profiles(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  review_text text not null check (char_length(trim(review_text)) between 20 and 2000),
  professional_response text check (professional_response is null or char_length(trim(professional_response)) between 2 and 1500),
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(connection_id),
  check (professional_id<>client_id)
);
create index if not exists professional_reviews_professional_idx on public.professional_reviews(professional_id,created_at desc);

create table if not exists public.professional_review_reports (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.professional_reviews(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null check (char_length(trim(reason)) between 5 and 500),
  status text not null default 'pending' check (status in ('pending','reviewed','dismissed','removed')),
  created_at timestamptz not null default now(),
  unique(review_id,reporter_id)
);

alter table public.professional_reviews enable row level security;
alter table public.professional_review_reports enable row level security;

drop policy if exists "public reads professional reviews" on public.professional_reviews;
create policy "public reads professional reviews" on public.professional_reviews for select to anon,authenticated using (true);
drop policy if exists "eligible clients create reviews" on public.professional_reviews;
create policy "eligible clients create reviews" on public.professional_reviews for insert to authenticated
with check (
  client_id=auth.uid()
  and exists (
    select 1 from public.message_connections c
    where c.id=connection_id and c.connection_type='professional_client'
      and c.professional_id=professional_id and c.client_id=auth.uid()
      and c.status in ('active','ended')
  )
);
drop policy if exists "clients edit own reviews" on public.professional_reviews;
drop policy if exists "members report reviews" on public.professional_review_reports;
create policy "members report reviews" on public.professional_review_reports for insert to authenticated with check (reporter_id=auth.uid());
drop policy if exists "members see own reports" on public.professional_review_reports;
create policy "members see own reports" on public.professional_review_reports for select to authenticated using (reporter_id=auth.uid());

create or replace function public.edit_professional_review(review_uuid uuid,new_rating smallint,new_text text)
returns public.professional_reviews language plpgsql security definer set search_path=public,pg_temp
as $edit_review$
declare result public.professional_reviews;
begin
  if new_rating not between 1 and 5 then raise exception 'Rating must be between 1 and 5.'; end if;
  if char_length(trim(coalesce(new_text,''))) not between 20 and 2000 then raise exception 'Review must be between 20 and 2000 characters.'; end if;
  update public.professional_reviews set rating=new_rating,review_text=trim(new_text),updated_at=now()
  where id=review_uuid and client_id=auth.uid() returning * into result;
  if result.id is null then raise exception 'You can only edit your own review.'; end if;
  return result;
end $edit_review$;

create or replace function public.respond_to_professional_review(review_uuid uuid,response_text text)
returns public.professional_reviews language plpgsql security definer set search_path=public,pg_temp
as $respond_review$
declare result public.professional_reviews;
begin
  if char_length(trim(coalesce(response_text,''))) not between 2 and 1500 then raise exception 'Response must be between 2 and 1500 characters.'; end if;
  update public.professional_reviews set professional_response=trim(response_text),responded_at=now(),updated_at=now()
  where id=review_uuid and professional_id=auth.uid() returning * into result;
  if result.id is null then raise exception 'Only this professional can respond to the review.'; end if;
  return result;
end $respond_review$;

create or replace view public.professional_review_summary with (security_invoker=true) as
select professional_id,round(avg(rating)::numeric,1) average_rating,count(*)::integer review_count
from public.professional_reviews group by professional_id;

grant select on public.professional_reviews,public.professional_review_summary to anon,authenticated;
grant insert,update on public.professional_reviews to authenticated;
grant select,insert on public.professional_review_reports to authenticated;
grant execute on function public.edit_professional_review(uuid,smallint,text) to authenticated;
grant execute on function public.respond_to_professional_review(uuid,text) to authenticated;
notify pgrst, 'reload schema';

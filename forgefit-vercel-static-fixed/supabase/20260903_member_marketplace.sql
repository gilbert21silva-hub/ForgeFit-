-- ForgeFit member marketplace
create table if not exists public.marketplace_listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 3 and 120),
  description text not null check (char_length(trim(description)) between 10 and 3000),
  category text not null check (category in ('Strength equipment','Cardio equipment','CrossFit & functional','Sports equipment','Recovery & mobility','Nutrition & meal prep','Apparel & accessories','Other')),
  item_condition text not null check (item_condition in ('New','Like new','Good','Fair')),
  price numeric(10,2) not null check (price>=0),
  negotiable boolean not null default false,
  delivery_options text[] not null default '{}',
  city text,
  region text,
  postal_code text,
  latitude double precision check (latitude is null or latitude between -90 and 90),
  longitude double precision check (longitude is null or longitude between -180 and 180),
  status text not null default 'available' check (status in ('available','reserved','sold')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists marketplace_listings_browse_idx on public.marketplace_listings(status,category,created_at desc);
create index if not exists marketplace_listings_seller_idx on public.marketplace_listings(seller_id,created_at desc);

create table if not exists public.marketplace_listing_photos (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.marketplace_listings(id) on delete cascade,
  seller_id uuid not null references public.profiles(id) on delete cascade,
  storage_path text not null unique,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists marketplace_photos_listing_idx on public.marketplace_listing_photos(listing_id,sort_order);

create table if not exists public.marketplace_saved_listings (
  user_id uuid not null references public.profiles(id) on delete cascade,
  listing_id uuid not null references public.marketplace_listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id,listing_id)
);

create table if not exists public.marketplace_inquiries (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.marketplace_listings(id) on delete cascade,
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  seller_id uuid not null references public.profiles(id) on delete cascade,
  message text not null check (char_length(trim(message)) between 3 and 1000),
  status text not null default 'open' check (status in ('open','closed')),
  created_at timestamptz not null default now(),
  check (buyer_id<>seller_id)
);
create index if not exists marketplace_inquiries_participants_idx on public.marketplace_inquiries(buyer_id,seller_id,created_at desc);

alter table public.marketplace_listings enable row level security;
alter table public.marketplace_listing_photos enable row level security;
alter table public.marketplace_saved_listings enable row level security;
alter table public.marketplace_inquiries enable row level security;

drop policy if exists "members browse marketplace listings" on public.marketplace_listings;
create policy "members browse marketplace listings" on public.marketplace_listings for select to authenticated using (status in ('available','reserved') or seller_id=auth.uid());
drop policy if exists "members create own marketplace listings" on public.marketplace_listings;
create policy "members create own marketplace listings" on public.marketplace_listings for insert to authenticated with check (seller_id=auth.uid());
drop policy if exists "members update own marketplace listings" on public.marketplace_listings;
create policy "members update own marketplace listings" on public.marketplace_listings for update to authenticated using (seller_id=auth.uid()) with check (seller_id=auth.uid());
drop policy if exists "members delete own marketplace listings" on public.marketplace_listings;
create policy "members delete own marketplace listings" on public.marketplace_listings for delete to authenticated using (seller_id=auth.uid());

drop policy if exists "members view marketplace photos" on public.marketplace_listing_photos;
create policy "members view marketplace photos" on public.marketplace_listing_photos for select to authenticated using (exists(select 1 from public.marketplace_listings l where l.id=listing_id));
drop policy if exists "sellers add marketplace photos" on public.marketplace_listing_photos;
create policy "sellers add marketplace photos" on public.marketplace_listing_photos for insert to authenticated with check (seller_id=auth.uid() and exists(select 1 from public.marketplace_listings l where l.id=listing_id and l.seller_id=auth.uid()));
drop policy if exists "sellers delete marketplace photos" on public.marketplace_listing_photos;
create policy "sellers delete marketplace photos" on public.marketplace_listing_photos for delete to authenticated using (seller_id=auth.uid());

drop policy if exists "members manage saved marketplace listings" on public.marketplace_saved_listings;
create policy "members manage saved marketplace listings" on public.marketplace_saved_listings for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());

drop policy if exists "participants view marketplace inquiries" on public.marketplace_inquiries;
create policy "participants view marketplace inquiries" on public.marketplace_inquiries for select to authenticated using (auth.uid() in (buyer_id,seller_id));
drop policy if exists "buyers create marketplace inquiries" on public.marketplace_inquiries;
create policy "buyers create marketplace inquiries" on public.marketplace_inquiries for insert to authenticated with check (buyer_id=auth.uid() and buyer_id<>seller_id);
drop policy if exists "participants close marketplace inquiries" on public.marketplace_inquiries;
create policy "participants close marketplace inquiries" on public.marketplace_inquiries for update to authenticated using (auth.uid() in (buyer_id,seller_id));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('marketplace','marketplace',false,10485760,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "members upload own marketplace photos" on storage.objects;
create policy "members upload own marketplace photos" on storage.objects for insert to authenticated
with check (bucket_id='marketplace' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "members delete own marketplace photos" on storage.objects;
create policy "members delete own marketplace photos" on storage.objects for delete to authenticated
using (bucket_id='marketplace' and owner_id=auth.uid()::text);
drop policy if exists "members view listed marketplace photos" on storage.objects;
create policy "members view listed marketplace photos" on storage.objects for select to authenticated
using (bucket_id='marketplace' and exists(select 1 from public.marketplace_listing_photos p join public.marketplace_listings l on l.id=p.listing_id where p.storage_path=storage.objects.name and (l.status in ('available','reserved') or l.seller_id=auth.uid())));

grant select,insert,update,delete on public.marketplace_listings,public.marketplace_listing_photos,public.marketplace_saved_listings,public.marketplace_inquiries to authenticated;
notify pgrst, 'reload schema';

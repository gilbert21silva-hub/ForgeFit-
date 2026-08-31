-- ForgeFit nutrition workspaces

create or replace function public.can_access_client_nutrition(client_uuid uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp
as $$
  select auth.uid()=client_uuid or exists(
    select 1 from public.session_requests s
    where s.client_id=client_uuid and s.professional_id=auth.uid() and s.status='approved'
  ) or exists(
    select 1 from public.message_connections c
    where c.client_id=client_uuid and c.professional_id=auth.uid() and c.status='active'
  )
$$;

create table if not exists public.nutrition_targets (
  client_id uuid primary key references auth.users(id) on delete cascade,
  daily_calories integer check (daily_calories between 500 and 10000),
  protein_grams integer check (protein_grams between 0 and 1000),
  carbs_grams integer check (carbs_grams between 0 and 1500),
  fat_grams integer check (fat_grams between 0 and 500),
  goal text check (goal is null or goal in ('lose','maintain','gain','performance')),
  notes text check (notes is null or char_length(notes)<=2000),
  set_by uuid not null references auth.users(id),
  updated_at timestamptz not null default now()
);

create table if not exists public.nutrition_food_entries (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references auth.users(id) on delete cascade,
  entered_by uuid not null references auth.users(id),
  logged_at timestamptz not null default now(),
  meal text not null check (meal in ('breakfast','lunch','dinner','snack','other')),
  food_name text not null check (char_length(trim(food_name)) between 1 and 200),
  servings numeric(8,2) not null default 1 check (servings>0 and servings<=100),
  calories numeric(10,2) not null check (calories>=0 and calories<=20000),
  protein_grams numeric(10,2) not null default 0 check (protein_grams>=0 and protein_grams<=2000),
  carbs_grams numeric(10,2) not null default 0 check (carbs_grams>=0 and carbs_grams<=3000),
  fat_grams numeric(10,2) not null default 0 check (fat_grams>=0 and fat_grams<=1000),
  notes text check (notes is null or char_length(notes)<=1000),
  created_at timestamptz not null default now()
);
create index if not exists nutrition_food_client_date_idx on public.nutrition_food_entries(client_id,logged_at desc);

create table if not exists public.nutrition_activity_entries (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references auth.users(id) on delete cascade,
  entered_by uuid not null references auth.users(id),
  logged_at timestamptz not null default now(),
  activity_name text not null check (char_length(trim(activity_name)) between 1 and 200),
  duration_minutes integer check (duration_minutes between 0 and 1440),
  calories_burned numeric(10,2) not null check (calories_burned>=0 and calories_burned<=20000),
  notes text check (notes is null or char_length(notes)<=1000),
  created_at timestamptz not null default now()
);
create index if not exists nutrition_activity_client_date_idx on public.nutrition_activity_entries(client_id,logged_at desc);

alter table public.nutrition_targets enable row level security;
alter table public.nutrition_food_entries enable row level security;
alter table public.nutrition_activity_entries enable row level security;

drop policy if exists "nutrition participants view targets" on public.nutrition_targets;
create policy "nutrition participants view targets" on public.nutrition_targets for select to authenticated using (public.can_access_client_nutrition(client_id));
drop policy if exists "nutrition participants create targets" on public.nutrition_targets;
create policy "nutrition participants create targets" on public.nutrition_targets for insert to authenticated with check (public.can_access_client_nutrition(client_id) and set_by=auth.uid());
drop policy if exists "nutrition participants update targets" on public.nutrition_targets;
create policy "nutrition participants update targets" on public.nutrition_targets for update to authenticated using (public.can_access_client_nutrition(client_id)) with check (public.can_access_client_nutrition(client_id) and set_by=auth.uid());

drop policy if exists "nutrition participants view food" on public.nutrition_food_entries;
create policy "nutrition participants view food" on public.nutrition_food_entries for select to authenticated using (public.can_access_client_nutrition(client_id));
drop policy if exists "nutrition participants add food" on public.nutrition_food_entries;
create policy "nutrition participants add food" on public.nutrition_food_entries for insert to authenticated with check (public.can_access_client_nutrition(client_id) and entered_by=auth.uid());
drop policy if exists "nutrition owners manage food" on public.nutrition_food_entries;
create policy "nutrition owners manage food" on public.nutrition_food_entries for delete to authenticated using (entered_by=auth.uid() or client_id=auth.uid());

drop policy if exists "nutrition participants view activity" on public.nutrition_activity_entries;
create policy "nutrition participants view activity" on public.nutrition_activity_entries for select to authenticated using (public.can_access_client_nutrition(client_id));
drop policy if exists "nutrition participants add activity" on public.nutrition_activity_entries;
create policy "nutrition participants add activity" on public.nutrition_activity_entries for insert to authenticated with check (public.can_access_client_nutrition(client_id) and entered_by=auth.uid());
drop policy if exists "nutrition owners manage activity" on public.nutrition_activity_entries;
create policy "nutrition owners manage activity" on public.nutrition_activity_entries for delete to authenticated using (entered_by=auth.uid() or client_id=auth.uid());

grant select,insert,update on public.nutrition_targets to authenticated;
grant select,insert,delete on public.nutrition_food_entries,public.nutrition_activity_entries to authenticated;
grant execute on function public.can_access_client_nutrition(uuid) to authenticated;
grant all on public.nutrition_targets,public.nutrition_food_entries,public.nutrition_activity_entries to service_role;

-- ForgeFit nutrition meal plans

create table if not exists public.nutrition_meal_plan_items (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references auth.users(id) on delete cascade,
  client_id uuid not null references auth.users(id) on delete cascade,
  planned_date date not null,
  meal_time time not null,
  meal_type text not null check (meal_type in ('breakfast','morning_snack','lunch','afternoon_snack','dinner','evening_snack','other')),
  food_name text not null check (char_length(trim(food_name)) between 1 and 200),
  portion text check (portion is null or char_length(portion)<=200),
  calories numeric(10,2) check (calories is null or calories between 0 and 20000),
  protein_grams numeric(10,2) check (protein_grams is null or protein_grams between 0 and 2000),
  carbs_grams numeric(10,2) check (carbs_grams is null or carbs_grams between 0 and 3000),
  fat_grams numeric(10,2) check (fat_grams is null or fat_grams between 0 and 1000),
  instructions text check (instructions is null or char_length(instructions)<=1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists nutrition_meal_plan_client_date_idx
  on public.nutrition_meal_plan_items(client_id,planned_date,meal_time);

alter table public.nutrition_meal_plan_items enable row level security;

drop policy if exists "meal plan participants view" on public.nutrition_meal_plan_items;
create policy "meal plan participants view"
on public.nutrition_meal_plan_items for select to authenticated
using (auth.uid()=client_id or (auth.uid()=professional_id and public.can_access_client_nutrition(client_id)));

drop policy if exists "professionals create meal plans" on public.nutrition_meal_plan_items;
create policy "professionals create meal plans"
on public.nutrition_meal_plan_items for insert to authenticated
with check (
  auth.uid()=professional_id
  and public.can_access_client_nutrition(client_id)
  and exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='professional')
);

drop policy if exists "professionals update meal plans" on public.nutrition_meal_plan_items;
create policy "professionals update meal plans"
on public.nutrition_meal_plan_items for update to authenticated
using (auth.uid()=professional_id and public.can_access_client_nutrition(client_id))
with check (auth.uid()=professional_id and public.can_access_client_nutrition(client_id));

drop policy if exists "professionals delete meal plans" on public.nutrition_meal_plan_items;
create policy "professionals delete meal plans"
on public.nutrition_meal_plan_items for delete to authenticated
using (auth.uid()=professional_id and public.can_access_client_nutrition(client_id));

grant select,insert,update,delete on public.nutrition_meal_plan_items to authenticated;
grant all on public.nutrition_meal_plan_items to service_role;

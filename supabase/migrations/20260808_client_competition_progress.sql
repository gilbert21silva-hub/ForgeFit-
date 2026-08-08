-- ForgeFit client competition goals and private progress tracking
-- Apply once through the Supabase SQL editor before testing the related dashboard.

create table if not exists public.client_measurements (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.client_profiles(user_id) on delete cascade,
  measured_at date not null default current_date,
  unit_system text not null default 'imperial',
  height_cm numeric(5,2),
  weight_kg numeric(6,2),
  body_fat_percentage numeric(5,2),
  neck_cm numeric(5,2),
  chest_cm numeric(5,2),
  waist_cm numeric(5,2),
  hips_cm numeric(5,2),
  upper_arm_cm numeric(5,2),
  thigh_cm numeric(5,2),
  calf_cm numeric(5,2),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint measurement_unit_system check (unit_system in ('imperial', 'metric')),
  constraint measurement_height_range check (height_cm is null or height_cm between 50 and 275),
  constraint measurement_weight_range check (weight_kg is null or weight_kg between 20 and 500),
  constraint measurement_body_fat_range check (body_fat_percentage is null or body_fat_percentage between 1 and 75),
  constraint measurement_neck_range check (neck_cm is null or neck_cm between 10 and 100),
  constraint measurement_chest_range check (chest_cm is null or chest_cm between 30 and 250),
  constraint measurement_waist_range check (waist_cm is null or waist_cm between 25 and 250),
  constraint measurement_hips_range check (hips_cm is null or hips_cm between 25 and 250),
  constraint measurement_upper_arm_range check (upper_arm_cm is null or upper_arm_cm between 10 and 100),
  constraint measurement_thigh_range check (thigh_cm is null or thigh_cm between 15 and 150),
  constraint measurement_calf_range check (calf_cm is null or calf_cm between 10 and 100),
  constraint measurement_notes_length check (char_length(notes) <= 2000)
);

create index if not exists client_measurements_timeline_idx
  on public.client_measurements (client_id, measured_at desc, created_at desc);

drop trigger if exists client_measurements_set_updated_at on public.client_measurements;
create trigger client_measurements_set_updated_at before update on public.client_measurements
for each row execute function public.set_updated_at();

alter table public.client_measurements enable row level security;

drop policy if exists "clients privately manage own measurements" on public.client_measurements;
create policy "clients privately manage own measurements"
on public.client_measurements for all
to authenticated
using (auth.uid() = client_id)
with check (auth.uid() = client_id);

grant select, insert, update, delete on table public.client_measurements to authenticated;
grant all privileges on table public.client_measurements to service_role;

insert into public.specialties (slug, name) values
  ('ifbb-competition-prep', 'IFBB Competition Prep'),
  ('bodybuilding-competition-prep', 'Bodybuilding Competition Prep'),
  ('figure-competition-prep', 'Figure Competition Prep')
on conflict (slug) do update set name = excluded.name, active = true;

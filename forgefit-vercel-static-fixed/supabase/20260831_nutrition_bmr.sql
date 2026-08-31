-- ForgeFit optional BMR inputs
-- BMR is calculated in the dashboards from the latest height/weight measurement.

alter table public.nutrition_targets
  add column if not exists bmr_birth_date date,
  add column if not exists bmr_sex text;

alter table public.nutrition_targets
  drop constraint if exists nutrition_targets_bmr_birth_date_check;
alter table public.nutrition_targets
  add constraint nutrition_targets_bmr_birth_date_check
  check (bmr_birth_date is null or bmr_birth_date between date '1900-01-01' and current_date);

alter table public.nutrition_targets
  drop constraint if exists nutrition_targets_bmr_sex_check;
alter table public.nutrition_targets
  add constraint nutrition_targets_bmr_sex_check
  check (bmr_sex is null or bmr_sex in ('female','male'));

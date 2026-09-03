-- Let one ForgeFit account use both client and professional capabilities.
-- profiles.role remains the account's original/default landing role for compatibility.

create or replace function public.enable_client_mode()
returns public.client_profiles
language plpgsql
security definer
set search_path=public
as $$
declare result public.client_profiles;
begin
  if auth.uid() is null then raise exception 'Sign in required.'; end if;
  insert into public.client_profiles(user_id) values(auth.uid())
  on conflict(user_id) do nothing;
  select * into result from public.client_profiles where user_id=auth.uid();
  return result;
end;
$$;

create or replace function public.enable_professional_mode(category_name text default 'Fitness Professional')
returns public.professional_profiles
language plpgsql
security definer
set search_path=public
as $$
declare
  result public.professional_profiles;
  has_professional_membership boolean;
begin
  if auth.uid() is null then raise exception 'Sign in required.'; end if;
  select exists(
    select 1 from public.memberships m
    join public.membership_plans mp on mp.id=m.plan_id
    where m.user_id=auth.uid() and mp.role='professional'
      and m.status in ('free_beta','trialing','active')
  ) into has_professional_membership;
  if not has_professional_membership then
    raise exception 'A Professional membership upgrade is required to use Professional mode.';
  end if;
  insert into public.professional_profiles(user_id,category)
  values(auth.uid(),coalesce(nullif(trim(category_name),''),'Fitness Professional'))
  on conflict(user_id) do nothing;
  select * into result from public.professional_profiles where user_id=auth.uid();
  return result;
end;
$$;

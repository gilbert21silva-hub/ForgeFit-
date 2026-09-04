-- ForgeFit SECURITY DEFINER permission audit
-- Read-only. Lists who can execute each privileged public function.

select
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as arguments,
  p.prorettype='pg_catalog.trigger'::regtype as trigger_function,
  has_function_privilege('anon',p.oid,'EXECUTE') as anonymous_can_execute,
  has_function_privilege('authenticated',p.oid,'EXECUTE') as signed_in_can_execute,
  case
    when p.prorettype='pg_catalog.trigger'::regtype
      and has_function_privilege('authenticated',p.oid,'EXECUTE')
      then 'REVIEW: trigger functions should not be called directly'
    when has_function_privilege('anon',p.oid,'EXECUTE')
      then 'REVIEW: publicly executable'
    when has_function_privilege('authenticated',p.oid,'EXECUTE')
      then 'EXPECTED ONLY IF USED BY THE APP'
    else 'RESTRICTED'
  end as result
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.prosecdef
order by result,function_name,arguments;

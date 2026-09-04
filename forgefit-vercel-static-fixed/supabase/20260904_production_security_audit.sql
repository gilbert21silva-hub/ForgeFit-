-- ForgeFit production security audit
-- Read-only: this script does not change tables, policies, users, or data.

with public_tables as (
  select c.oid,c.relname as table_name,c.relrowsecurity as rls_enabled
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind in ('r','p')
),
policy_counts as (
  select schemaname,tablename,count(*)::integer as policy_count
  from pg_policies
  where schemaname='public'
  group by schemaname,tablename
),
table_audit as (
  select t.table_name,t.rls_enabled,coalesce(p.policy_count,0) policy_count,
    case
      when not t.rls_enabled then 'ACTION REQUIRED: enable RLS'
      when coalesce(p.policy_count,0)=0 then 'ACTION REQUIRED: add a policy'
      else 'OK'
    end as result
  from public_tables t
  left join policy_counts p on p.tablename=t.table_name
),
unsafe_functions as (
  select n.nspname as schema_name,p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments,
    p.prosecdef as security_definer,
    coalesce(array_to_string(p.proconfig,', '),'') as configuration,
    case
      when p.prosecdef and not coalesce(array_to_string(p.proconfig,', '),'') ilike '%search_path%'
        then 'ACTION REQUIRED: fixed search_path is missing'
      else 'OK'
    end as result
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.prosecdef
)
select 'TABLE' as object_type,table_name as object_name,
  'RLS='||rls_enabled||'; policies='||policy_count as details,result
from table_audit
union all
select 'FUNCTION',schema_name||'.'||function_name||'('||arguments||')',
  'security_definer='||security_definer||'; '||configuration,result
from unsafe_functions
order by result desc,object_type,object_name;

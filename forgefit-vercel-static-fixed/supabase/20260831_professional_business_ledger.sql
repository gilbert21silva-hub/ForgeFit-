-- ForgeFit private professional business ledger
-- Bookkeeping only. ForgeFit does not process or verify payments.

create table if not exists public.professional_client_billing (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  client_id uuid not null references public.client_profiles(user_id) on delete cascade,
  title text not null check (char_length(trim(title)) between 2 and 160),
  total_amount numeric(12,2) not null check (total_amount > 0 and total_amount <= 10000000),
  amount_paid numeric(12,2) not null default 0 check (amount_paid >= 0 and amount_paid <= total_amount),
  due_date date,
  next_payment_due date,
  installment_amount numeric(12,2) check (installment_amount is null or installment_amount > 0),
  notes text check (notes is null or char_length(notes) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.professional_business_expenses (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  incurred_on date not null default current_date,
  category text not null check (category in ('equipment','rent','software','education','marketing','insurance','travel','other')),
  description text not null check (char_length(trim(description)) between 2 and 200),
  amount numeric(12,2) not null check (amount > 0 and amount <= 10000000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists professional_client_billing_owner_idx on public.professional_client_billing(professional_id,created_at desc);
create index if not exists professional_client_billing_client_idx on public.professional_client_billing(professional_id,client_id,due_date);
create index if not exists professional_business_expenses_owner_idx on public.professional_business_expenses(professional_id,incurred_on desc);

alter table public.professional_client_billing enable row level security;
alter table public.professional_business_expenses enable row level security;

drop policy if exists "professionals manage private client billing" on public.professional_client_billing;
create policy "professionals manage private client billing"
on public.professional_client_billing for all to authenticated
using (professional_id=auth.uid())
with check (
  professional_id=auth.uid()
  and exists (
    select 1 from public.session_requests s
    where s.professional_id=auth.uid()
      and s.client_id=professional_client_billing.client_id
      and s.status='approved'
  )
);

drop policy if exists "professionals manage private expenses" on public.professional_business_expenses;
create policy "professionals manage private expenses"
on public.professional_business_expenses for all to authenticated
using (professional_id=auth.uid())
with check (professional_id=auth.uid());

grant select,insert,update,delete on public.professional_client_billing,public.professional_business_expenses to authenticated;
grant all on public.professional_client_billing,public.professional_business_expenses to service_role;

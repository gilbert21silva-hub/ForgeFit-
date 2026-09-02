-- ForgeFit client payment visibility
-- Safe to run more than once. Creates payment history when it does not exist,
-- preserves prior paid balances, and lets each client see only their own records.

create table if not exists public.professional_client_payments (
  id uuid primary key default gen_random_uuid(),
  billing_id uuid not null references public.professional_client_billing(id) on delete cascade,
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  client_id uuid not null references public.client_profiles(user_id) on delete cascade,
  amount numeric(12,2) not null check (amount > 0 and amount <= 10000000),
  paid_on date not null default current_date,
  note text check (note is null or char_length(note) <= 500),
  created_at timestamptz not null default now()
);

create index if not exists professional_client_payments_billing_idx
  on public.professional_client_payments(billing_id, paid_on desc, created_at desc);
create index if not exists professional_client_payments_client_idx
  on public.professional_client_payments(professional_id, client_id, paid_on desc);

alter table public.professional_client_payments enable row level security;

drop policy if exists "professionals manage private payment history" on public.professional_client_payments;
create policy "professionals manage private payment history"
on public.professional_client_payments for all to authenticated
using (professional_id = auth.uid())
with check (
  professional_id = auth.uid()
  and exists (
    select 1
    from public.professional_client_billing billing
    where billing.id = professional_client_payments.billing_id
      and billing.professional_id = auth.uid()
      and billing.client_id = professional_client_payments.client_id
  )
);

drop policy if exists "clients view their billing status" on public.professional_client_billing;
create policy "clients view their billing status"
on public.professional_client_billing
for select to authenticated
using (client_id = auth.uid());

drop policy if exists "clients view their payment history" on public.professional_client_payments;
create policy "clients view their payment history"
on public.professional_client_payments
for select to authenticated
using (client_id = auth.uid());

grant select, insert, update, delete on public.professional_client_payments to authenticated;
grant all on public.professional_client_payments to service_role;

insert into public.professional_client_payments
  (billing_id, professional_id, client_id, amount, paid_on, note)
select
  billing.id,
  billing.professional_id,
  billing.client_id,
  billing.amount_paid,
  coalesce(billing.updated_at::date, billing.created_at::date),
  'Opening payment balance imported from the original billing record'
from public.professional_client_billing billing
where billing.amount_paid > 0
  and not exists (
    select 1
    from public.professional_client_payments payment
    where payment.billing_id = billing.id
  );

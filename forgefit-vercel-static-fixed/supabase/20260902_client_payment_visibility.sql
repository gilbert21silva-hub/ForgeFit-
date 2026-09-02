-- Allow each client to see only their own billing status and payment history.
-- Professional private notes and business expenses remain private because the client UI
-- requests only the safe billing fields and no client policy is added to expense records.

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

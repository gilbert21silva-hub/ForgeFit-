-- ForgeFit edit permissions for nutrition entries and private links

drop policy if exists "nutrition owners update food" on public.nutrition_food_entries;
create policy "nutrition owners update food"
on public.nutrition_food_entries for update to authenticated
using (entered_by=auth.uid() or client_id=auth.uid())
with check (
  (entered_by=auth.uid() or client_id=auth.uid())
  and public.can_access_client_nutrition(client_id)
);

drop policy if exists "nutrition owners update activity" on public.nutrition_activity_entries;
create policy "nutrition owners update activity"
on public.nutrition_activity_entries for update to authenticated
using (entered_by=auth.uid() or client_id=auth.uid())
with check (
  (entered_by=auth.uid() or client_id=auth.uid())
  and public.can_access_client_nutrition(client_id)
);

grant update on public.nutrition_food_entries,public.nutrition_activity_entries to authenticated;
grant update on public.professional_links to authenticated;

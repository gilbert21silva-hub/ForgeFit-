-- Allow a professional to see the basic profile name of clients who requested sessions with them.
drop policy if exists "profiles visible to owner or for published professionals" on public.profiles;
create policy "profiles visible to owner published professionals or session parties"
on public.profiles for select to authenticated
using (
  auth.uid() = id
  or exists (
    select 1 from public.professional_profiles professional
    where professional.user_id = profiles.id and professional.published = true
  )
  or exists (
    select 1 from public.session_requests request
    where request.client_id = profiles.id
      and request.professional_id = auth.uid()
  )
);

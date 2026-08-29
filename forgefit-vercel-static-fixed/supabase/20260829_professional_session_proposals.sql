-- ForgeFit professional-initiated session proposals
alter table public.session_requests add column if not exists requested_by uuid references auth.users(id);
update public.session_requests set requested_by=client_id where requested_by is null;
alter table public.session_requests alter column requested_by set not null;
alter table public.session_requests drop constraint if exists session_request_status;
alter table public.session_requests add constraint session_request_status check (status in ('pending','approved','declined','reschedule_proposed','cancelled','client_confirmation_pending'));

drop policy if exists "professionals create client session proposals" on public.session_requests;
create policy "professionals create client session proposals"
on public.session_requests for insert to authenticated
with check (
  professional_id=auth.uid()
  and requested_by=auth.uid()
  and status='client_confirmation_pending'
  and exists(select 1 from public.session_requests existing where existing.professional_id=auth.uid() and existing.client_id=client_id and existing.status='approved')
);

drop policy if exists "clients update own requests" on public.session_requests;
create policy "clients update own requests"
on public.session_requests for update to authenticated
using (client_id=auth.uid())
with check (client_id=auth.uid() and status in ('pending','cancelled','approved'));

create or replace function public.guard_session_request_update()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if auth.role()='service_role' then new.updated_at=now(); return new; end if;
  if auth.uid()=old.client_id then
    if new.client_id is distinct from old.client_id or new.professional_id is distinct from old.professional_id
      or new.professional_response is distinct from old.professional_response
      or new.meeting_url is distinct from old.meeting_url or new.meeting_provider is distinct from old.meeting_provider
      or new.meeting_instructions is distinct from old.meeting_instructions
      or new.cancelled_by is distinct from old.cancelled_by or new.cancelled_at is distinct from old.cancelled_at
      or new.requested_by is distinct from old.requested_by then
      raise exception 'Clients cannot change professional or system-managed session fields.';
    end if;
    if old.status='client_confirmation_pending' then
      if new.requested_start_at is distinct from old.requested_start_at or new.duration_minutes is distinct from old.duration_minutes
        or new.session_type is distinct from old.session_type or new.format is distinct from old.format
        or new.location_details is distinct from old.location_details or new.client_message is distinct from old.client_message
        or new.proposed_start_at is distinct from old.proposed_start_at then
        raise exception 'Approve or decline this professional session proposal without rewriting it.';
      end if;
      if new.status not in ('approved','cancelled') then raise exception 'Approve or decline the professional session proposal.'; end if;
    else
      if old.status not in ('pending','reschedule_proposed','approved') then raise exception 'This session request can no longer be changed by the client.'; end if;
      if new.proposed_start_at is distinct from old.proposed_start_at then raise exception 'Clients cannot change the professional response fields.'; end if;
      if new.status not in ('pending','cancelled') then raise exception 'Clients may only keep a request pending or cancel it.'; end if;
      if old.status='approved' and new.status<>'cancelled' then raise exception 'Approved sessions may only be cancelled by the client.'; end if;
    end if;
  elsif auth.uid()=old.professional_id then
    if new.client_id is distinct from old.client_id or new.professional_id is distinct from old.professional_id
      or new.requested_start_at is distinct from old.requested_start_at or new.duration_minutes is distinct from old.duration_minutes
      or new.session_type is distinct from old.session_type or new.format is distinct from old.format
      or new.location_details is distinct from old.location_details or new.client_message is distinct from old.client_message
      or new.requested_by is distinct from old.requested_by
      or new.cancelled_by is distinct from old.cancelled_by or new.cancelled_at is distinct from old.cancelled_at then
      raise exception 'Professionals cannot rewrite the session request parties or details.';
    end if;
    if old.status='client_confirmation_pending' and new.status<>'cancelled' then
      raise exception 'This proposal is waiting for the client; the professional may only cancel it.';
    end if;
    if old.status<>'client_confirmation_pending' and new.status not in ('approved','declined','reschedule_proposed','cancelled') then
      raise exception 'Choose approve, decline, propose a new time, or cancel.';
    end if;
  else raise exception 'You cannot update this session request.';
  end if;
  if new.status='cancelled' and old.status<>'cancelled' then new.cancelled_by=auth.uid();new.cancelled_at=now();
  elsif new.status<>'cancelled' then new.cancelled_by=null;new.cancelled_at=null;end if;
  new.updated_at=now();return new;
end;$$;

-- ForgeFit SECURITY DEFINER permission hardening
-- Removes anonymous/default access while preserving authenticated app workflows.

-- Remove PostgreSQL's default PUBLIC execution access from all privileged app functions.
revoke execute on function public.can_access_client_nutrition(uuid) from public,anon;
revoke execute on function public.can_view_social_post(uuid,text) from public,anon;
revoke execute on function public.edit_professional_review(uuid,smallint,text) from public,anon;
revoke execute on function public.enable_client_mode() from public,anon;
revoke execute on function public.enable_professional_mode(text) from public,anon;
revoke execute on function public.end_service_connection(uuid) from public,anon;
revoke execute on function public.has_active_service_relationship(uuid,uuid) from public,anon;
revoke execute on function public.is_message_participant(public.message_connections) from public,anon;
revoke execute on function public.mark_connection_messages_read(uuid) from public,anon;
revoke execute on function public.respond_to_message_connection(uuid,text) from public,anon;
revoke execute on function public.respond_to_professional_review(uuid,text) from public,anon;
revoke execute on function public.send_service_terms(uuid,text,text,text,text,bigint) from public,anon;
revoke execute on function public.socially_connected(uuid,uuid) from public,anon;

-- These functions are invoked only by database triggers/event triggers.
revoke execute on function public.rls_auto_enable() from public,anon,authenticated;
revoke execute on function public.guard_session_request_update() from public,anon,authenticated;
revoke execute on function public.prepare_message_connection() from public,anon,authenticated;

-- Explicitly preserve only the signed-in application permissions.
grant execute on function public.can_access_client_nutrition(uuid) to authenticated;
grant execute on function public.can_view_social_post(uuid,text) to authenticated;
grant execute on function public.edit_professional_review(uuid,smallint,text) to authenticated;
grant execute on function public.enable_client_mode() to authenticated;
grant execute on function public.enable_professional_mode(text) to authenticated;
grant execute on function public.end_service_connection(uuid) to authenticated;
grant execute on function public.has_active_service_relationship(uuid,uuid) to authenticated;
grant execute on function public.is_message_participant(public.message_connections) to authenticated;
grant execute on function public.mark_connection_messages_read(uuid) to authenticated;
grant execute on function public.respond_to_message_connection(uuid,text) to authenticated;
grant execute on function public.respond_to_professional_review(uuid,text) to authenticated;
grant execute on function public.send_service_terms(uuid,text,text,text,text,bigint) to authenticated;
grant execute on function public.socially_connected(uuid,uuid) to authenticated;

-- Prevent future functions created by the migration owner from automatically becoming public.
alter default privileges in schema public revoke execute on functions from public;

notify pgrst, 'reload schema';

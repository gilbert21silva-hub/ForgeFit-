-- ForgeFit production query indexes
-- Safe to rerun. These indexes support the busiest dashboard, messaging, calendar, and discovery queries.

create index if not exists session_requests_client_status_start_idx
  on public.session_requests(client_id,status,requested_start_at);
create index if not exists session_requests_professional_status_start_idx
  on public.session_requests(professional_id,status,requested_start_at);

create index if not exists message_connections_client_status_updated_idx
  on public.message_connections(client_id,status,updated_at desc);
create index if not exists message_connections_professional_status_updated_idx
  on public.message_connections(professional_id,status,updated_at desc);
create index if not exists direct_messages_connection_created_idx
  on public.direct_messages(connection_id,created_at);
create index if not exists direct_messages_unread_recipient_lookup_idx
  on public.direct_messages(sender_id,read_at)
  where read_at is null;

create index if not exists professional_profiles_discovery_idx
  on public.professional_profiles(published,accepting_clients,category)
  where published=true;

create index if not exists professional_reviews_rating_lookup_idx
  on public.professional_reviews(professional_id,rating,created_at desc);

analyze public.session_requests;
analyze public.message_connections;
analyze public.direct_messages;
analyze public.professional_profiles;
analyze public.professional_reviews;

notify pgrst, 'reload schema';

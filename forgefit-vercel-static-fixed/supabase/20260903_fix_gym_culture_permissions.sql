-- Run once if the original Gym Culture / Social migration has already been installed.
-- RLS policies still control which rows each member can access.
grant select, insert, update, delete on table public.social_connections to authenticated;
grant select, insert, update, delete on table public.social_posts to authenticated;
grant select, insert, update, delete on table public.social_post_likes to authenticated;
grant select, insert, update, delete on table public.social_post_comments to authenticated;
grant select, insert, update, delete on table public.social_blocks to authenticated;
grant select, insert on table public.social_reports to authenticated;
grant execute on function public.socially_connected(uuid,uuid) to authenticated;
grant execute on function public.can_view_social_post(uuid,text) to authenticated;

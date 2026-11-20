-- Second migration (cloud_sync_grant_authenticated): the signed-in role needs
-- explicit table privileges; RLS still limits every statement to own rows.
grant select, insert, update on table public.khatas, public.transactions to authenticated;

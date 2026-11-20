# Supabase (cloud backup)

Project `kajgkcevlhhcsnyvjxvy`. These migrations are already applied there, in
this order; the files are the record of what the database contains.

| File | What it does |
| --- | --- |
| `migrations/20261120084706_cloud_sync_khatas_transactions.sql` | `khatas` and `transactions` mirrors keyed by `(user_id, id)`, the last-write-wins trigger, the `server_updated_at` pull cursor and row-level security (own rows only, no deletes) |
| `migrations/20261120084755_cloud_sync_grant_authenticated.sql` | table privileges for the signed-in role; RLS still limits every statement to the caller's rows |

The phone's SQLite database stays the source of truth. Google is the only sign-in
provider, and the app's redirect `in.keshab.khatabook://login-callback` is in the
project's allowed redirect URLs.

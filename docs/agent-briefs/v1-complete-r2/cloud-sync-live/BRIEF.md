# cloud-sync-live — Worker C (next task in your lane)

**Repository:** `Keshab1997/KhataBook` — attach this repo in Arena Agent Mode. Continue in the same chat on `arena/29ee62d4-khatabook`; your checkpoint `e20dbc3` is verified and landed on `main`.
**Goal:** Make cloud backup real. Build three things:
- a Supabase implementation of your `CloudBackend`;
- an app-level cloud-sync service that starts it and keeps it syncing;
- a Cloud Backup screen built from your `AccountCard` and `SignInScreen`.

After the Captain's wiring, a user can sign in with Google, have khatas and entries back up, and get them back on another phone. All of it covered by tests.
**Acceptance:**

1. **Sync your files first.** When `e20dbc3` landed, the Captain formatted your files and fixed what the analyzer and the full suite found (main `a0e3c0e`):
   - private fields renamed for `prefer_initializing_formals`;
   - the sign-in progress and result panels now scroll into view (they rendered below the fold);
   - the account-card test closes the engine and the database outside fake async (it hung);
   - the sign-in test scrolls the button fully into view.

   On main, `supabase_flutter ^2.18.3` is a dependency and `fake_async` and `http` are dev dependencies (`4730a41`).

   Before editing, run `git fetch origin main`. Then, for each of these paths, run `git show 4730a41fd4d77e3972073431ca662e74435c63ad:<path> > <path>`: `lib/features/sync/account_card.dart`, `lib/features/sync/sign_in_screen.dart`, `lib/features/sync/sync_engine.dart`, `lib/features/sync/sync_scheduler.dart`, `test/account_card_test.dart`, `test/local_ledger_test.dart`, `test/sign_in_screen_test.dart`, `test/support/fake_cloud_backend.dart`, `test/sync_test.dart`.

   Also read `supabase/README.md` and `supabase/migrations/` at that commit: they describe the live database.
2. **Supabase backend.** Create `lib/features/sync/supabase_cloud_backend.dart` with `SupabaseCloudBackend implements CloudBackend`. Construct it from a `SupabaseClient`, a `redirectTo` and timeouts. Inject the client; never read `Supabase.instance` inside the class.
   - **Auth:**
     - `currentUser` and `userChanges` come from `client.auth.currentUser` and `client.auth.onAuthStateChange` (`AuthState.session?.user`). Map `id` and `email`; treat a user without an email as signed out.
     - `signInWithGoogle()` calls `client.auth.signInWithOAuth(OAuthProvider.google, redirectTo: redirectTo, authScreenLaunchMode: LaunchMode.externalApplication)`, then waits for the signed-in auth event. If no session arrives within the timeout (default 3 minutes), it returns `null`, meaning cancelled.
     - `signOut()` signs out locally and never touches local data.
   - **Push:** `upsertKhatas` and `upsertTransactions` send:
     - `user_id` set to the signed-in user;
     - every column of the migration, in snake_case, with timestamps as UTC ISO-8601;
     - never `server_updated_at`.

     Call `upsert(rows, onConflict: 'user_id,id').select()` and return the rows the server returns, `serverUpdatedAt` included. The trigger may keep a newer server copy; return it as stored.
   - **Pull:** `fetchChanges(since)` reads both tables:
     - rows with `server_updated_at` strictly after `since`, or all rows when `since` is `null`;
     - ordered by `server_updated_at`, then `id`;
     - paged with `range()` until a short page comes back.

     It returns the highest `server_updated_at` seen as the cursor, or `since` when nothing came back.
   - **Errors:**
     - No network becomes `CloudOfflineException`. That covers socket and HTTP client failures, `AuthRetryableFetchException` and timeouts.
     - A call made while signed out throws `StateError`.
     - Other failures are rethrown with a short message that contains no secrets.
3. **Config.** Create `lib/features/sync/cloud_config.dart` with `CloudConfig`:
   - fields `url`, `publishableKey` and `redirectTo`, and an `isConfigured` getter;
   - a `const CloudConfig.fromEnvironment()` that reads the `--dart-define`s `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`, empty when absent;
   - the redirect `in.keshab.khatabook://login-callback`, or `null` on web (meaning the current page).

   Put no real key or URL in code.
4. **Cloud sync service.** Create `lib/features/sync/cloud_sync.dart` with `CloudSync`, which owns one backend, one `SyncEngine` and its scheduler.
   - `static Future<CloudSync?> start({required LocalLedger ledger, CloudConfig config = const CloudConfig.fromEnvironment()})` returns `null` when the config is not set, and the app stays local-only. Otherwise it calls `Supabase.initialize(url:, publishableKey:)` once and builds the backend.
   - A separate constructor takes any `CloudBackend`, for tests.
   - It exposes `statusStream`, `currentStatus`, `backend`, `backupNow()`, `confirmAccountSwitch()`, `signOut()`, `notifyLocalChange()` (a debounced kick after the app writes) and `dispose()`.
   - It syncs once at start when already signed in, after sign-in, and on app resume (`AppLifecycleListener`).
5. **Cloud Backup screen.** Create `lib/features/sync/cloud_backup_screen.dart` with `CloudBackupScreen({language, CloudSync? cloudSync})`.
   - It shows the S5 and S11 states through your `AccountCard`, bound to `cloudSync`.
   - `Sign in` pushes your `SignInScreen` with its backend.
   - When `cloudSync` is `null`, it explains in en and bn that cloud backup is not set up in this build and the data stays on the phone.
   - No blocking dialogs, and it renders clean at 320 dp and 200 % text.
6. **Rules.**
   - Every visible string has en and bn as local pairs; don't edit `app_strings.dart`.
   - Sign-out, an account switch or a failed sync never deletes local data.
   - Colours come only from `AppColors`, there are no new dependencies, and there are no keys or URLs in code.
7. **Tests.**
   - New `test/supabase_cloud_backend_test.dart`: drive a real `SupabaseClient('https://example.supabase.co', 'test-key', httpClient: MockClient(...), authOptions: const AuthClientOptions(autoRefreshToken: false))`, with `MockClient` from `package:http/testing.dart`. Check the REST requests (table, `on_conflict`, body columns, filters, order, paging), the row mapping both ways, and the offline mapping.
   - New `test/cloud_sync_test.dart`: the service over `FakeCloudBackend` — sync at start when signed in, sync after sign-in, debounced `notifyLocalChange`, the resume trigger, and dispose.
   - New `test/cloud_backup_screen_test.dart`: unconfigured, local-only, signed-in and error states, plus Bengali at 320 dp / 200 %.
   - Widget tests open and close drift through `tester.runAsync` and unmount before disposing; see the synced `account_card_test.dart`.
   - This sandbox cannot run Flutter. Read every change for compile errors against the API cheat sheet below, keep `python3 tool/preflight.py` clean and match `dart format`. The Captain runs format, `flutter analyze --fatal-infos` and the full suite in review.

**supabase_flutter 2.18.3 API cheat sheet (checked against the package source):**
- `import 'package:supabase_flutter/supabase_flutter.dart';` re-exports `package:supabase/supabase.dart` (including `SupabaseClient`, `OAuthProvider`, `AuthState`, `AuthChangeEvent`, `User`, `Session`, `AuthException`, `AuthRetryableFetchException`, `PostgrestException` and `AuthClientOptions`), plus `LaunchMode` and `Supabase`.
- `Supabase.initialize({required String url, String? publishableKey, ...})` returns `Future<Supabase>`; the client is `Supabase.instance.client`.
- `SupabaseClient(String supabaseUrl, String supabaseKey, {AuthClientOptions authOptions, Client? httpClient, ...})`.
- `client.auth.signInWithOAuth(OAuthProvider provider, {String? redirectTo, String? scopes, LaunchMode authScreenLaunchMode = LaunchMode.platformDefault, Map<String, String>? queryParams})` returns `Future<bool>`.
- `client.auth.onAuthStateChange` is a `Stream<AuthState>` with `.event` and `.session`. `client.auth.currentUser` is a `User?` with `.id` and `.email`. Sign out with `client.auth.signOut()`.
- `client.from('khatas').upsert(Object values, {String? onConflict, bool ignoreDuplicates = false, bool defaultToNull = true}).select()` returns `Future<List<Map<String, dynamic>>>`.
- Pull query: `client.from('transactions').select().gt('server_updated_at', iso).order('server_updated_at', ascending: true).order('id', ascending: true).range(from, to)`. `order` defaults to descending, so always pass `ascending: true`.

**Interface / exclusions:**
- Keep every existing public name and parameter; new ones are optional.
- Don't edit `main_shell.dart`, `main.dart`, `app.dart`, `app_strings.dart` or `pubspec.*`.
- Don't edit profile, entry, home, ledger-screen, counter, calculator or backup files, `android/` or `ios/`.
- After landing, the Captain wires `CloudSync.start` into `main.dart`, the screen into Profile, and `notifyLocalChange` into the shell.

**Scope and gate:** See [task.json](task.json) at this same commit. Do not edit it.
**Skill method (optional):** none.
**Report:** worker chat (GitHub mention pending)

Finish every acceptance item in this one task, deciding details yourself inside
the allowed files. If one item truly cannot be done, push the rest and name the
gap in your report. Use the current agent-bootstrap `captain/FASTLANE.md`.

Keep the real `arena/*` branch. After a verified `PUSHED`, include the brief
link, checkpoint block and commit link when reporting. If blocked, report the
reason. Do not change branch, use a standalone clone, re-pair, run CI, or
open, merge or close a PR.

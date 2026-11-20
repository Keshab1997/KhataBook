# web-backup-sync-2 — Worker C

**Repository:** `Keshab1997/KhataBook` — attach this repo in Arena Agent Mode.
**Goal:** Make backup and cloud sync behave correctly on web. Local-file backup uses `path_provider` / `file_picker` and is Android-only; cloud backup and the sync engine should work on web now that a real ledger exists. Base is the current `main` tip `f572a55`.
**Acceptance:**

1. Confirm `BackupFiles.save` / `pick` are not invoked on web (the shell already gates `onBackup` to Android) and that no code path calls them on web; if a web crash / exception is reachable, guard it without changing the Android behavior.
2. Ensure `cloud_backup_screen.dart` and the sync entry points work on web: `CloudSync.start` may run on web (Supabase supports it) or fail soft (already caught in `main`); verify the cloud backup screen renders and the sync engine does not throw on web. Edit `cloud_sync.dart` / `sync_engine.dart` only if a web-specific bug requires it; otherwise leave them untouched.
3. Preserve all public constructors, callbacks, keys and l10n strings.
4. `flutter analyze` clean; the pinned test passes; `flutter build web --release --no-web-resources-cdn` succeeds.

**Interface / exclusions:** Only `backup_files.dart`, `backup_screen.dart`, `cloud_backup_screen.dart` (and `cloud_sync.dart` / `sync_engine.dart` only if needed) plus their tests may change. Do NOT touch `profile_screen.dart` / `settings_screen.dart` (Worker B) or `main_shell.dart` (Worker A).
**Scope and gate:** See [task.json](task.json) at this same commit. Do not edit it.
**Skill method (optional):** none — a method only; this brief and the playbook still rule.
**Report:** worker chat (GitHub mention pending)

Finish every acceptance item in this one task, deciding details yourself inside the allowed files; if one item truly cannot be done, push the rest and name the gap in your report. Use the current agent-bootstrap `captain/FASTLANE.md`. Keep the real `arena/*` branch. After a verified `PUSHED`, include the brief link, checkpoint block and commit link when reporting. If blocked, report the reason; do not change branch, use a standalone clone, re-pair, run CI, or open/merge/close a PR.

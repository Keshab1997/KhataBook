# web-profile-settings-2 — Worker B

**Repository:** `Keshab1997/KhataBook` — attach this repo in Arena Agent Mode.
**Goal:** Make the Profile and Settings tabs real on web. Currently `profile_screen.dart` shows "Web design preview only. Local ledger storage and backup are not available on the web." and `settings_screen.dart` disables photo picking under `kIsWeb`. Remove those guards so web users get the real profile. Base is the current `main` tip `f572a55` on your branch `arena/f985725d-khatabook`.
**Acceptance:**

1. In `profile_screen.dart`, remove the `kIsWeb` branch that shows the "Web design preview only" message; render the real profile (name/avatar, cloud backup entry, settings) on web using the passed `profileStore`.
2. In `settings_screen.dart`, stop disabling features purely because `kIsWeb`; language change must work on web (the shell already passes `onLanguageChanged` once the ledger is live). Decide profile photo on web: enable `image_picker` web support (store picked bytes / object URL) OR keep it gracefully disabled with a clear reason — your call, but it must not crash on web.
3. Preserve every public constructor, callback, key and l10n string in these three files.
4. `flutter analyze` clean; the pinned test passes; `flutter build web --release --no-web-resources-cdn` succeeds.

**Interface / exclusions:** Only `profile_screen.dart`, `settings_screen.dart`, `profile_photo_picker.dart` (and their tests) may change. Do NOT touch `backup_screen.dart` / `backup_files.dart` (Worker C) or `main_shell.dart` (Worker A). Keep the cloud-backup callback signature stable.
**Scope and gate:** See [task.json](task.json) at this same commit. Do not edit it.
**Skill method (optional):** none — a method only; this brief and the playbook still rule.
**Report:** worker chat (GitHub mention pending)

Finish every acceptance item in this one task, deciding details yourself inside the allowed files; if one item truly cannot be done, push the rest and name the gap in your report. Use the current agent-bootstrap `captain/FASTLANE.md`. Keep the real `arena/*` branch. After a verified `PUSHED`, include the brief link, checkpoint block and commit link when reporting. If blocked, report the reason; do not change branch, use a standalone clone, re-pair, run CI, or open/merge/close a PR.

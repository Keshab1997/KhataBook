# web-shell-home-2 — Worker A

**Repository:** `Keshab1997/KhataBook` — attach this repo in Arena Agent Mode.
**Goal:** Retire MainShell's read-only web preview now that the web app opens a real WASM/IndexedDB ledger (the Captain foundation is already merged on `main`, current tip `f572a55`). On web the shell must render the real Home/ledger, enable language switching, cloud backup and wallet summary, and drop the "web preview only" banner.
**Acceptance:**

1. Remove the `_webPreview` getter and the `MaterialBanner` "webLedgerUnavailable" path from `main_shell.dart`; the web app must render the same real Home as native (no sample-data preview, no banner).
2. Keep `onBackup` Android-only (local-file backup stays native), but enable `onLanguageChanged`, `onCloudBackup` and `onWalletSummary` on web now that a live ledger exists.
3. Preserve every existing public widget constructor, callback, key and l10n string used by `MainShell` and the screens it hosts; do not change the shell's route map or `KhataBookApp` wiring.
4. `flutter analyze` clean; the pinned test file passes; and `flutter build web --release --no-web-resources-cdn` succeeds — the web build is the real gate for this batch.

**Interface / exclusions:** Only `lib/features/shell/main_shell.dart` (and its tests) may change. Do NOT touch `lib/main.dart`, `lib/features/ledger/**`, `pubspec.yaml`, `web/`, or any other worker's files. Use `AppColors` / theme tokens only.
**Scope and gate:** See [task.json](task.json) at this same commit. Do not edit it.
**Skill method (optional):** none — a method only; this brief and the playbook still rule.
**Report:** worker chat (GitHub mention pending)

Finish every acceptance item in this one task, deciding details yourself inside the allowed files; if one item truly cannot be done, push the rest and name the gap in your report. Use the current agent-bootstrap `captain/FASTLANE.md`. Keep the real `arena/*` branch. After a verified `PUSHED`, include the brief link, checkpoint block and commit link when reporting. If blocked, report the reason; do not change branch, use a standalone clone, re-pair, run CI, or open/merge/close a PR.

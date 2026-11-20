# backup-v2-counter-redesign — Worker A (same lane; next checkpoint)

**Repository:** `Keshab1997/KhataBook` — continue in the same Arena-linked chat and on `arena/3b5df89b-khatabook`.

The original `backup-v2` checkpoint `be027838a8e898773638be8382b195ae0644f635` has been reviewed, integrated against current main, and landed in merge commit **`c96a2a80046590507150c41d95597aa72485d736`**. That commit is now both `main` and the fast-forwarded Arena branch tip. The existing Arena branch was advanced by a fast-forward only; do not reset, rebase, or manually switch branches. Use the lane with this brief's `task.json`; it can reconcile the restored local checkout to the pinned base.

This is the next checkpoint in the same lane. The integrated base already contains current main, the backup-v2 implementation, the note/coin assets, and their integration fixes. **Do not overwrite/sync files from an older commit**; work directly on top of the pinned base.

## Counter redesign

The Counter tab is one full screen per khata, with no AppBar header on the app's tab (the shell keeps its own title), one row per denomination with an illustration, and the grand total at the bottom. The rows are:

- One row per note: ₹500, ₹200, ₹100, ₹50, ₹20, ₹10. Each row shows its illustration, quantity field, and that row's total.
- One coins row at the end with its illustration. **The user types the total coin amount in rupees**; do not ask for or infer a number of coins. The row total is the amount entered, represented internally as integer paise.
- The grand total at the bottom.

Every note denomination is always on screen: no selection, chips, or calculate button. The ₹2,000 note is withdrawn: it has no row. On load, repair away any stored ₹2,000 quantity and the old `show_two_thousand` flag; do not keep or silently ignore them. Keep per-khata persistence and the saved-sessions sheet working. Keep the small bottom actions: save, add-to-khata, and new count.

## Illustrations

Use the existing assets under `assets/notes/` (already listed in `pubspec.yaml` at the pinned base): `note_500.png`, `note_200.png`, `note_100.png`, `note_50.png`, `note_20.png`, `note_10.png`, and `coins.png`. `note_2000.png` remains unused because ₹2,000 has no row. Do not create or generate assets.

## Base and current backup-v2 behavior

The new full `base_sha` is **`c96a2a80046590507150c41d95597aa72485d736`**, the current main tip. It includes the verified backup-v2 work, merged and tested against the later main history. The existing Arena branch has already been fast-forwarded to this same commit.

Backup v2 is implemented at the base. Preserve it while redesigning the counter:

- Export version 2 with the offline profile, custom categories, and all note-counter state/saved sessions.
- Restore v1 and v2 atomically. A v1 file restores the ledger while preserving side data that can still belong to restored khatas; v2 replaces the included sections as one transaction.
- Keep preview details for profile, categories, and saved counts; keep the counter and saved-session copy consistent with backup behavior.

Do not re-implement or overwrite the base backup service. Add or adjust backup tests only as needed to prove the redesign does not regress the integrated v2 behavior.

## Work and rules

1. Start/resume with the original linked checkout and this exact task JSON. Let `worker_lane.py start` reconcile the old local checkpoint to the pinned base if needed; do not run `git show a0e3c0e... > path`, manually switch/reset/rebase, or overwrite files from an older commit.
2. Implement the counter row redesign above, retaining integer-paise arithmetic, per-khata persistence, and saved sessions. Keep every visible string in local English/Bengali pairs; do not edit `app_strings.dart`.
3. Keep existing public names and parameters for `LedgerBackup`, `exportJson`, `restoreReplacing`, `inspect`, `BackupScreen`, `BackupPreview`, `BackupFiles`, `NoteCounterScreen`, `NoteCounterStore`, and `NoteCounterSnapshot`. New parameters should remain optional where practical. No new dependencies. Colours come from `AppColors`.
4. Extend the existing backup, counter, and screen tests. In particular cover: the v2 round trip and v1 preservation still pass; the coin row accepts a total amount and adds that amount to the total; load repair removes stored ₹2,000 quantities/flags; the screen shows six note rows, one coin row, and the grand total; existing bottom actions still work.
5. Run the pinned task gate (`python3 -B tool/preflight.py` through `worker_lane.py check`), then read `diff` before `publish`. This gate is preflight only; do not claim Flutter tests/analyze unless you run them. Do not dispatch CI.

**Interface / exclusions:** Do not edit `main_shell.dart`, `main.dart`, `app_strings.dart`, `pubspec.*`, `local_ledger.dart`, `settings_screen.dart`, entry/home/All Transactions/profile-store files, sync files, `android/`, or `ios/`. The shell already receives backup preview details; the task is limited to the `allowed` paths in `task.json`.

**Scope and gate:** See the unchanged task structure and updated base in [`task.json`](task.json) at this same commit. Do not edit it.

**Report:** Return the `AGENT A PUSHED` block with branch, full base SHA, full tip SHA, files, check result, and commit link. No PR or CI. GitHub mention remains pending because no approved tracker was specified.

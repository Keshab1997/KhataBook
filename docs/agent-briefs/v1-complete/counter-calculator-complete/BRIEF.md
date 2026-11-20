# counter-calculator-complete — Worker A

**Repository:** `Keshab1997/KhataBook` — attach this repo in Arena Agent Mode.
**Goal:** Finish the Note Counter (spec S4) and the Calculator's `Use in entry` (spec S3): note counts persist offline per khata, saved sessions can be reopened and copied, the counter speaks Bengali, and both screens hand an amount to the entry form through optional callbacks — all covered by tests.
**Acceptance:**

1. **Store.** Start from the store an earlier worker wrote: `git fetch origin arena/4ab3d19e-khatabook`, then `git show 6a624d8:lib/features/counter/note_counter_store.dart` and `git show 6a624d8:test/note_counter_store_test.dart`. Review and adapt both to current `main` (lazy `CREATE TABLE IF NOT EXISTS` on the existing `LocalLedger`, no schema-version bump). Keep one definition of each denomination constant: the screen imports the store's instead of duplicating them. That commit's screen diff conflicts with today's screen, so rewrite the wiring rather than pasting it.
2. **Persistence.** `NoteCounterScreen` gains optional `language` (default `AppLanguage.en`), `NoteCounterStore? store` and `String? khataId`. With both store and khata id it loads that khata's session on open and saves every change (quantities, selected denomination, ₹2,000 visibility) without blocking the UI or dropping a fast tap sequence; a new `khataId` reloads and never carries quantities over (S4 acceptance). Without them it works in memory exactly as today, so the current shell keeps compiling, and only then does it show the existing "nothing is saved" hint.
3. **Saved sessions (S4 states).** `Save` stores a timestamped snapshot of a non-empty count for the khata. A sheet lists that khata's saved sessions newest first (time and Grand Total); tapping one restores it, confirming first when the current count is not empty; a saved session can be deleted. `Copy summary` puts readable text on the clipboard: each non-zero denomination × quantity = amount, the Grand Total and the date and time. `New count` still resets only the current session.
4. **Add to khata as income.** Optional `void Function(int amountPaise, String note)? onAddToKhata`. Its button shows only when the callback is set and the Grand Total is above zero. It passes the Grand Total and a short note and never writes a transaction itself: the caller opens the Add Entry form for the user to review and save, because the spec warns about double-counting cash that is already in the opening balance.
5. **Use in entry.** `CalculatorScreen` gains optional `ValueChanged<int>? onUseInEntry`. Its control appears only when the callback is set and sends the current result as integer paise, rounded half away from zero to 2 decimals. It is disabled for an empty, error, zero or negative result. Existing behaviour and the S3 acceptance stay (`250 × 4 → 1,000`, `C → 0`, …).
6. **Bengali.** Every visible counter string follows `language`. Use existing `AppString` entries where they exist (`newCount`, `grandTotal`, `totalAmount`, `enterQuantity`, …) and keep any new strings as local en/bn pairs in your files; don't edit `app_strings.dart`. Rupees and digits go through `AppStrings`.
7. **Layout.** No overflow or exception on either screen at 320×568, 360×640 and 800×600, at text scale 1.0 and 1.3.
8. **Tests.** `test/note_counter_test.dart` (the gate) covers the persistence round trip with an in-memory `LocalLedger`, per-khata isolation, save/restore/delete/copy, the add-to-khata callback and Bengali labels. `test/note_counter_store_test.dart` passes. `test/calculator_test.dart` covers `Use in entry` (paise value, hidden without a callback, disabled on error). Run `test/note_counter_store_test.dart`, `test/calculator_test.dart` and `test/utilities_language_test.dart` yourself before `check`.

**Interface / exclusions:** Keep the public names and existing parameters of `NoteCounterScreen` and `CalculatorScreen`; every new parameter is optional. Money stays integer paise, colours come only from `AppColors`, and there are no new dependencies. Don't edit `main_shell.dart` (the Captain wires store, khata, language and callbacks after landing), `app_strings.dart`, `pubspec.*`, `local_ledger.dart`, `ledger_backup.dart`, or any entry or profile file. Counter data is not in the JSON backup yet (the Captain adds backup v2 later), so the screen must not claim it is.
**Scope and gate:** See [task.json](task.json) at this same commit. Do not edit it.
**Skill method (optional):** none.
**Report:** worker chat (GitHub mention pending)

Finish every acceptance item in this one task, deciding details yourself inside
the allowed files; if one item truly cannot be done, push the rest and name the
gap in your report. Use the current agent-bootstrap `captain/FASTLANE.md`.
Keep the real `arena/*` branch. After a verified `PUSHED`, include the brief
link, checkpoint block and commit link when reporting. If blocked, report the
reason; do not change branch, use a standalone clone, re-pair, run CI, or
open/merge/close a PR.

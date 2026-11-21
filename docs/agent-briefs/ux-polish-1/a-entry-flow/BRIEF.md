# a-entry-flow — Worker A

**Repository:** `Keshab1997/KhataBook` — attach this repo in Arena Agent Mode.
**Batch:** `ux-polish-1` — visual/UX polish pass 1 (Keshab: "user experience barate hbe", priority = visual polish, first screen = Add Entry + Home).
**Goal:** Visual polish of the Add Entry flow: form hierarchy, spacing rhythm, section grouping, amount field prominence, category chip styling, save-area composition and empty/invalid/saving states.
**Acceptance:**

1. Restructure `add_entry_screen.dart` visual hierarchy: the amount field is the loudest element (large tabular amount text, ₹ prefix aligned to the first digit, calm helper line), then Expense/Income segmented control, then Date + Category, then Description, then the live 'After saving' preview and Save button; consistent 8 dp grid and 16 dp page padding, one card radius family (16-20 dp).
2. All colours come from `AppColors` / `Theme.of(context)` only - no literal `Color(0x...)` and no new token; keep the existing `_EntryHeaderPainter` artwork but make its contrast work with the new composition.
3. Category chips/rows in `category_picker.dart`: consistent selected/unselected styling, clear selected affordance beyond colour (border/weight/check), even wrap spacing, no clipped labels at 320 dp width.
4. Invalid, saving and edit-mode states read clearly (inline errors aligned under their field, disabled Save state visually distinct, Delete visually separated from Update) - no dialogs added.
5. Keyboard safety: with a 320x568 viewport and the keyboard inset applied, the Save button and the live preview stay reachable by scrolling and nothing overlaps them; the decorative illustration never covers inputs.
6. Preserve every existing public constructor, callback, key and `AppStrings` key. Do not add dependencies or change l10n text values.
7. Update/extend `test/add_entry_screen_test.dart` (plus given tests if a shared widget changed) so the changed visual contract is asserted (e.g. styles/structure via `find`, no golden files), and all listed test files pass.

**Interface / exclusions:** Do NOT touch `lib/core/theme/**`, `lib/core/l10n/**`, `lib/features/shell/**`, `lib/features/ledger/data/**`, `pubspec.yaml`, `pubspec.lock`, `.github/**`, or any file outside `task.json` `allowed`. Use `AppColors` and `Theme.of(context)` only — no literal `Color(0x...)`, no new colour tokens, no new dependency. Do not open, merge or close a PR.
**Gate note (Captain re-pin, batch ):** worker sandboxes in this batch have no outbound TLS to ,  or , so the Flutter gate cannot run worker-side.   is therefore  — run preflight, the credential/scope checks and  as normal. The Captain runs , full  and locked  during review, so do not claim test evidence you did not run; say  in your report.

**Scope and gate:** See [task.json](task.json) at this same commit. Do not edit it.
**Skill method (optional):** none — a method only; this brief and the playbook still rule.
**Report:** worker chat (GitHub mention pending)

Finish every acceptance item in this one task, deciding details yourself inside
the allowed files; if one item truly cannot be done, push the rest and name the
gap in your report. Use the current agent-bootstrap `captain/FASTLANE.md`.
Keep the real `arena/*` branch. After a verified `PUSHED`, include the brief
link, checkpoint block and commit link when reporting. If blocked, report the
reason; do not change branch, use a standalone clone, re-pair, run CI, or
open/merge/close a PR.

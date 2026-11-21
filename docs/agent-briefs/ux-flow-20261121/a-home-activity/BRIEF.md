# a-home-activity — Worker A

**Repository:** `Keshab1997/KhataBook`
**Starting point:** a fresh Arena branch from `main` at or after `9bc5f4ffcb4340ee811d155fb234c8ae6ed5e0f7`.
**Goal:** Make the Home dashboard's recent activity genuinely actionable, accessible and correctly bilingual without changing the ledger's data or its design language.

## Acceptance

1. In `HomeScreen`, a recent **persisted** transaction is a real, keyboard- and screen-reader-accessible tap target when an action is supplied; tapping calls it exactly once with that exact `LedgerEntry`. Rows with `entry.id == null`, sample/preview rows, or a null action must not look, announce or behave as editable. Never modify data or navigate inside Home.
2. **Exact integration interface:** `HomeScreen` adds the optional constructor parameter `ValueChanged<LedgerEntry>? onRecentEntry` (a field with the same name/type). Thread it through the private recent-list widgets. The Captain, not this worker, will wire `MainShell` to `TransactionEditorScreen`; your branch must compile and work with the callback omitted. Keep every existing public constructor argument and existing key.
3. Make each actionable row at least 44 dp high, provide a localized edit affordance and meaningful semantics including transaction direction, title and amount (do not rely on colour alone), and keep decorative artwork out of the announced content. Preserve the existing 4-newest order, balances, stored category IDs and View All/Add actions.
4. Fix the actual Home Bengali defects: `_EmptyTransactions` compares `strings.language.name` with `'Bengali'`, which cannot match `AppLanguage.bn`; the empty-state instruction must be Bengali in Bengali and English in English. The Home settings tooltip must come from `AppString.settings`, not hard-coded English. No edits to shared `lib/core/l10n/app_strings.dart`; use existing keys and localized copy in the owned screen.
5. Keep the primary action and the activity rows reachable with long names and money values on a 320 dp phone at 200% text in both languages, with no overflow or clipped controls. Preserve the warm, flat AppColors-based visual system; do not change calculations or data.
6. Extend all three assigned test files: `home_live_test.dart` checks persisted versus preview/null-action taps and the exact callback payload; `home_entry_language_test.dart` checks Bengali/English empty instruction and settings tooltip; `home_design_test.dart` checks row semantics, touch size and the small-phone/large-text layout. Keep existing meaningful assertions; change expectations only where the requested UX intentionally changes.

## Boundary shared with Captain and C

The Captain will connect `HomeScreen(onRecentEntry: ...)` to the existing `TransactionEditorScreen` API: `initial: EntryFormResult`, `onUpdate: Future<bool> Function(EntryFormResult)`, `onDelete: Future<bool> Function()`, optional `categoryStore`, and `language`; it returns `TransactionEditResult`. Worker C preserves that editor API. Do not touch the shell or editor; no prerequisite from C is needed on your branch.

## Scope, gate and delivery

- Only the exact `allowed` paths in the pinned `task.json`; do not edit the brief/spec, `lib/main.dart`, the shell, shared l10n, generated code, dependencies, assets, workflows, Android/iOS, versions or secrets. No new package.
- Stay on the fresh `arena/*` branch already bound to your attached repo. Before editing record the full `base` SHA; stop if the checkout is dirty, the branch is not `arena/*`, or the base is not on current `main` at/after the starting point. Do not switch, merge, reset or force-push.
- Run **one** cheap check: `python3 tool/preflight.py`. No full test suite, analyze, screenshots, CI, builds, PR, or main push. If the check fails, fix or report BLOCKED; never call a failed check a pass.
- Use the exact task commit message containing `[skip ci]`: it prevents the repo's push-triggered public Web Preview build/Pages update; the Captain still dispatches the mandatory manual Flutter CI on your branch. It does **not** waive that gate.
- Commit only the allowed paths, `git push origin HEAD`, then report `AGENT A PUSHED`, repo, task, branch, full base and pushed SHA, changed files and actual check result. If unable to push/check, report `AGENT A BLOCKED` with exact reason and preserved edits.
- Skill: none. Report in the worker chat; no public issue/comment.

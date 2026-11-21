# c-entry-confidence — Worker C

**Repository:** `Keshab1997/KhataBook`
**Starting point:** a fresh Arena branch from `main` at or after `9bc5f4ffcb4340ee811d155fb234c8ae6ed5e0f7`.
**Goal:** Make adding and editing entries forgiving and understandable: visible validation, safe draft exit and accessible keyboard/large-text behaviour, without changing financial semantics.

## Acceptance

1. **New-entry validation:** the main Save Entry control must be available when idle, including with an empty amount, so it can explain what is missing rather than silently disabling the only obvious action. Header and primary save use the same validation; an empty, zero, malformed, over-precision or too-large amount never calls `onSave` and shows the localized inline error; a missing expense category likewise shows its localized error. Bring the first invalid input into view and focus it when appropriate. A valid expense or income is submitted exactly once, with the same paise parsing, category IDs and date/description as before; preserve the host's existing duplicate-write protection and failure handling.
2. **Editing without losing work:** detect a changed amount, type, category, local date or description against the editor's initial values. Both the header back control and system back ask for a localized confirmation before discarding changed data. Keeping the draft or dismissing the dialog preserves every field and makes no update/delete call; explicitly discarding exits without writing. An unchanged editor exits immediately, and reverting all edits to their initial values removes the prompt. Treat the original date's time correctly: a date not changed by the user must preserve its original timestamp.
3. A pending update/delete must still block back and duplicate operations. A successful update or confirmed delete must exit exactly once without an unsaved-draft prompt; a failed or thrown operation stays editable, reports the existing honest error and retains the draft/guard. Do not introduce a new silent save or alter Undo/tombstone behaviour in the host.
4. Both forms and the confirmation dialog must remain scrollable, readable and operable at 320 dp / 200% text, with the keyboard visible and in English and Bengali; icon-only actions need localized accessible names and action targets at least 44 dp. Retain existing colours, form fields, custom categories, future-date warning and responsive design.
5. Extend **both** assigned test files: cover invalid and valid new-entry submission, both back paths, keep/discard/reverted drafts, changed field types, success/failure/in-flight operations, Bengali copy and a compact large-text/keyboard layout. Preserve meaningful existing assertions; adjust a disabled-save expectation only for the deliberate acceptance in item 1. Never remove coverage to make tests pass.

## Exact boundary with Captain and A

Preserve `EntryFormResult` and the public `AddEntryScreen.onSave: ValueChanged<EntryFormResult>` signature. Preserve `TransactionEditorScreen(initial: EntryFormResult, onUpdate: Future<bool> Function(EntryFormResult), onDelete: Future<bool> Function(), categoryStore: CategoryStore?, language: AppLanguage)` and its `TransactionEditResult` return contract and existing keys. A adds `HomeScreen(onRecentEntry: ValueChanged<LedgerEntry>?)`; the Captain will wire that callback to this unchanged editor API after A lands. No shell or Home changes are yours and no prerequisite from A is needed on your branch.

Use existing `AppStrings` where available. If discard-confirmation copy needs new words, put private English/Bengali feature copy in the owned editor file, following the existing `_DatePickerCopy` / screen-copy pattern; do not touch shared l10n. Preserve all storage, sync, category and callback interfaces; no new package.

## Scope, gate and delivery

- Only the exact `allowed` paths in the pinned `task.json`; do not edit the brief/spec, shell, shared l10n, `lib/main.dart`, generated code, dependencies, assets, workflows, Android/iOS, versions or secrets.
- Stay on the fresh `arena/*` branch already bound to your attached repo. Before editing record the full `base` SHA; stop if the checkout is dirty, the branch is not `arena/*`, or the base is not on current `main` at/after the starting point. Do not switch, merge, reset or force-push.
- Run **one** cheap check: `python3 tool/preflight.py`. No full test suite, analyze, screenshots, CI, builds, PR, or main push. If the check fails, fix or report BLOCKED; never call a failed check a pass.
- Use the exact task commit message containing `[skip ci]`: it prevents the repo's push-triggered public Web Preview build/Pages update; the Captain still dispatches the mandatory manual Flutter CI on your branch. It does **not** waive that gate.
- Commit only the allowed paths, `git push origin HEAD`, then report `AGENT C PUSHED`, repo, task, branch, full base and pushed SHA, changed files and actual check result. If unable to push/check, report `AGENT C BLOCKED` with exact reason and preserved edits.
- Skill: none. Report in the worker chat; no public issue/comment.

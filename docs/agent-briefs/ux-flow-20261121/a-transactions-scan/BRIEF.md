# a-transactions-scan — Worker A

**Repository:** `Keshab1997/KhataBook`
**Base:** `ba8575373c2cd1504101ef84dc44dd0508caa38d`, the verified tip of your own existing Arena branch.
**Goal:** Make the transaction history useful immediately: the user can see entries, search, understand active filters and recover from no matches without digging through three tall filter panels.

## Acceptance

1. On a typical 390×844 phone, the search field, a discoverable filter action and at least the first stored transaction are visible without scrolling when the list is non-empty. Keep the branded visual system and existing summary, but progressively disclose the date/type/category panels instead of hiding the ledger behind them. Small screens and 200% text must scroll without overflow.
2. Search stays available when panels are closed. A clearly labelled, keyboard- and screen-reader-accessible filter control opens and closes the panels without unexpectedly forcing the keyboard. When closed, active search/date/type/category choices remain visibly and semantically apparent, with one reachable **Clear filters** action that actually clears all of them. Do not imply no filters are active when one is.
3. Preserve and test combined filters, inclusive local-day boundaries, persisted category IDs and archived/custom category labels, current filtered totals/counts, empty-khata versus no-match states, refresh/retry, navigation, edit/delete/undo and scroll behaviour. Search must find the user's description and the category name shown to them in English/Bengali, including custom categories; do not mutate stored IDs. Keep the existing public `matchesSearchQuery` interface usable by current callers.
4. Keep all public `AllTransactionsScreen` constructor parameters and existing keys/callbacks. Do not alter calculations, storage, sync, or edit semantics. Reuse `AppStrings`; any new English/Bengali screen-specific copy belongs privately in this owned file, not shared l10n.
5. Extend both assigned test files: visible-first-row at 390×844; open/close/clear and active state; combinations, custom/Bengali category search, empty versus no matches, retained edit/undo; 320 dp/200% text and semantics. Keep existing meaningful assertions; adapt setup to open filters where previously assumed rather than deleting tests or weakening checks.

## Boundary / exclusions

This stacks directly on the exact A tip above; no C or Captain prerequisite. The Captain owns `MainShell`, category-store wiring, Home-to-editor integration, shared localization and all other shared surfaces. Do not touch them. This workstream owns only the three paths in its `task.json` and must not change entry/editor/Home files or the old B counter/calculator lane.

## Delivery

Stay on your existing `arena/*` branch. Verify HEAD equals the base above and the tree is clean; never switch, merge, rebase, amend, reset or force-push. Read this pinned brief and `task.json` by the Captain's docs SHA. Run only `python3 tool/preflight.py` as the local gate; no full suite/analyze/screenshots/builds/CI/PR/main push. Timeout or failed check means BLOCKED, not a pass. Commit the exact message including `[skip ci]` to prevent the automatic public Web Preview build; Captain will still dispatch mandatory manual Flutter CI on the branch. Push `git push origin HEAD` and report `AGENT A PUSHED`, repo, task, branch, full base and tip, changed files and actual check result. Skill: none; report in worker chat.

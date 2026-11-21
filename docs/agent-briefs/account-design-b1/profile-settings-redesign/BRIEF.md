# profile-settings-redesign — Worker A

**Repository:** `Keshab1997/KhataBook`
**Goal:** Polish Profile and Settings end-to-end as one consistent account area, with matching branded headers, improved identity card, section hierarchy, preferences rows, spacing, and actionable controls.

**Acceptance:**

1. Apply a matching header to both native and web-preview branches without losing settings gear, back navigation, safe areas or readable localized titles.
2. Make identity/edit-photo area and grouped account/settings rows feel intentional and cohesive, not a repaint only. Preserve editing, picker failure/cancellation, offline notices, licences, wallet/backup callbacks and real disabled states.
3. Preserve language selection commit/cancel/failure/busy behavior and honest fixed currency/light theme labels. Maintain route and accessibility semantics.
4. Add focused design/layout/navigation regression tests in test/profile_settings_design_test.dart; cover both languages, normal size and 320px/200% scale. Existing profile/settings/navigation/language tests must also pass.

**Interface / exclusions:** Match the CURRENT app, not an invented new style: inspect HomeScreen, CalculatorScreen and NoteCounterScreen first. Current Counter has a compact green rounded-bottom banner with a fine golden lower edge; Home/Calculator have their own branded title treatments. Give these account screens a deliberate matching family treatment (title, contextual icon, restrained subtitle if space allows, balanced safe-area/back/action layout). Keep existing palette tokens, cream background, warm ivory cards, rounded geometry and one soft shadow. Do not introduce new gradients beyond the existing reference header treatment, fonts, packages, remote assets or artwork generation. Use existing icons/assets only. Preserve every public constructor/callback, route result, key relied on by existing tests, data and real capability state. All new copy must work in English and Bengali. 320x568 at 200% text scale must scroll without overflow. Back and icon actions must remain accessible with >=48dp hit areas. No changes to authentication/storage/cloud logic. Tests must not simply weaken existing behavioral assertions to get green. Run relevant existing tests in addition to the named gate. No tracker is approved; report MENTION PENDING. Other worker owns the other account screens; Captain owns screenshots/shared surfaces. Do not edit main/app routing, theme, l10n shared files, pubspec/lock, generated code, native folders, workflows, AGENTS.md or brief files.

**Scope and gate:** See [task.json](task.json) at this same commit. Do not edit it. Device Flow is primary; old Arena-only text in app AGENTS does not override this pinned brief.
**Skill method:** none.
**Report:** worker chat (no tracker).

Finish the complete deliverable in one checkpoint using agent-bootstrap captain/FASTLANE.md. After verified PUSHED report pinned brief, full checkpoint block and commit link, with MENTION PENDING. Never push main, open/merge/close PRs, dispatch CI or share tokens.

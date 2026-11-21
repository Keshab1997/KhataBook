# login-cloud-redesign — Worker B

**Repository:** `Keshab1997/KhataBook`
**Goal:** Polish the complete login/cloud account presentation: SignInScreen, CloudBackupScreen and embedded AccountCard, matching the app and Profile/Settings header family without changing auth/sync behavior.

**Acceptance:**

1. Give pushed Login/Cloud Backup pages branded compact headers in the current app family; keep usable back navigation, localized ellipsized titles and safe-area handling.
2. Improve sign-in hero, benefits, Google CTA and secondary action hierarchy; retain truthful optional-backup/local-data copy and every loading/cancel/offline/error/success route result and callback.
3. Unify cloud backup/account cards with warm surfaces, clear account status and balanced spacing. Preserve real backup/retry/confirmation/logout behaviors and disabled/unconfigured states; no fake signed-in identity or sync claims.
4. Add focused design/layout regression tests in test/login_cloud_design_test.dart for English/Bengali, 320px and 200% text scale. Run existing sign-in/cloud/account tests; preserve their behavioral coverage.

**Interface / exclusions:** Match the CURRENT app, not an invented new style: inspect HomeScreen, CalculatorScreen and NoteCounterScreen first. Current Counter has a compact green rounded-bottom banner with a fine golden lower edge; Home/Calculator have their own branded title treatments. Give these account screens a deliberate matching family treatment (title, contextual icon, restrained subtitle if space allows, balanced safe-area/back/action layout). Keep existing palette tokens, cream background, warm ivory cards, rounded geometry and one soft shadow. Do not introduce new gradients beyond the existing reference header treatment, fonts, packages, remote assets or artwork generation. Use existing icons/assets only. Preserve every public constructor/callback, route result, key relied on by existing tests, data and real capability state. All new copy must work in English and Bengali. 320x568 at 200% text scale must scroll without overflow. Back and icon actions must remain accessible with >=48dp hit areas. No changes to authentication/storage/cloud logic. Tests must not simply weaken existing behavioral assertions to get green. Run relevant existing tests in addition to the named gate. No tracker is approved; report MENTION PENDING. Other worker owns the other account screens; Captain owns screenshots/shared surfaces. Do not edit main/app routing, theme, l10n shared files, pubspec/lock, generated code, native folders, workflows, AGENTS.md or brief files.

**Scope and gate:** See [task.json](task.json) at this same commit. Do not edit it. Device Flow is primary; old Arena-only text in app AGENTS does not override this pinned brief.
**Skill method:** none.
**Report:** worker chat (no tracker).

Finish the complete deliverable in one checkpoint using agent-bootstrap captain/FASTLANE.md. After verified PUSHED report pinned brief, full checkpoint block and commit link, with MENTION PENDING. Never push main, open/merge/close PRs, dispatch CI or share tokens.

# Workflows in this repository

Six files; the flutter-builder gates are pinned to
**`Keshab1997/flutter-builder@v1.18.9`**. Nothing here is installed without
Keshab's approval — the file is the source of truth for what each workflow
actually does.

## Approved — automatic PR gate (read-only, cheap)

| File | Workflow name (as shown in Actions) | Trigger | What it does |
| --- | --- | --- | --- |
| `pr-checks.yml` | **PR quick checks — pytest & analyze** | `pull_request` (path-filtered to `lib/`, `test/`, `tests/`, pubspec, analysis options) | `pytest tests/` (schema contract) + `flutter analyze` only — ~1 min, no `flutter test`, no builds |

This is the only workflow that runs without a dispatch. It exists so the 65
contract tests in `tests/test_ledger_schema.py` and the analyzer are never
skipped on a PR; the heavy suite still belongs to the manual gate below.

## Approved — manual gates (manual only, read-only)

| File | Workflow name (as shown in Actions) | Trigger | What it does |
| --- | --- | --- | --- |
| `ci.yml` | **Flutter CI — Format, Analyze & Test** | `workflow_dispatch` | `flutter analyze` → `flutter test` → format check; no build artifacts; CI scope |
| `widget-tests.yml` | **Flutter widget-test diagnostics** | `workflow_dispatch` | Fast manual widget-test diagnostic with a copyable failure report |

Run the first one once per finished batch: Actions → *Flutter CI — Format,
Analyze & Test* → **Run workflow**. Do not assume a push runs CI — it does not
for these two.

## Present but NOT approved — do not run without Keshab's explicit approval

| File | Workflow name | Trigger | What it does |
| --- | --- | --- | --- |
| `web-preview.yml` | **Deploy Flutter Web Preview (GitHub Pages)** | push (+ delete) → GitHub Pages + PR comments | Publishes the web build to `gh-pages` on every non-doc push |
| `manual-build.yml` | **Build Android APK or AAB (Manual)** | `workflow_dispatch` | Builds an APK or AAB (AAB needs signing secrets) |
| `publish-release.yml` | **Publish Signed Android Release** | `workflow_dispatch` | Tags, GitHub Release, Play Internal upload (opt-in) |

Documentation in this repo previously claimed only the two approved manual
workflows were installed — that was **stale**: all five are committed. The
three rows above publish builds, create releases or push to Pages; they need
Keshab's explicit approval before they are used, and Keshab owns whether they
should stay in the repository at all. Do not remove or edit them without him.

Quote the real workflow names exactly as they appear in Actions — never a
generic "Flutter CI" that does not exist in this repository.

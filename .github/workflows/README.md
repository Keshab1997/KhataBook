# Workflows in this repository

Both files are copies of `flutter-builder/examples/project-workflows/` pinned to
**`@v1.18.6`** (the same release as the installed agent pack). Both are
`workflow_dispatch` only — **nothing runs on a push**.

| File | Workflow name (as shown in Actions) | What it does |
| --- | --- | --- |
| `ci.yml` | **Flutter CI — Format, Analyze & Test** | `dart format` check → `flutter analyze` → `flutter test`; no build artifacts |
| `widget-tests.yml` | **Flutter widget-test diagnostics** | Manual widget-test target with a copyable failure report |

Run the first one once per finished batch: Actions → *Flutter CI — Format,
Analyze & Test* → **Run workflow**. Read the result with
`python3 tool/ci_watch.py`.

## Deliberately not installed

The builder also ships `web-preview.yml`, `manual-build.yml`,
`publish-release.yml` and `ui-screenshots.yml`. They publish to GitHub Pages,
create releases/tags, need signing secrets or write to branches — all of which
need Keshab's explicit approval first. No repository secrets, no Pages setup and
no release/tag exist here.

Quote the two real names above, never a generic "Flutter CI" that does not
exist in the Actions list (rule in `AGENTS.md`).

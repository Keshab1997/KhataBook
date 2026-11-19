# Screenshot-only fonts

`Roboto-Regular.ttf` and `Roboto-Bold.ttf` come from the Flutter SDK's
`bin/cache/artifacts/material_fonts/` and are licensed under Apache-2.0
(see `LICENSE-Roboto.txt`, copied from `Roboto_LICENSE.txt` in the SDK).

They are **not bundled into the app**: `pubspec.yaml` declares no font assets,
so the app uses platform fonts. They exist only so
`python3 tool/local_screenshots.py` can load a real font with
`FontLoader('Roboto')` in `tool/screenshots/shot_registry.dart`. Without a real
font, `flutter test` falls back to Ahem (every glyph is a square), which makes
correct layouts look like overflow bugs and produces unreadable screenshots.

The PNGs written to `.agent-screens/local/` are local evidence, git-ignored,
and never committed.

// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'app.dart';
import 'core/l10n/app_strings.dart';
import 'core/l10n/language_preference.dart';
import 'features/ledger/data/local_ledger.dart';
import 'features/ledger/data/web_ledger_stub.dart'
    if (dart.library.js_interop) 'features/ledger/data/web_ledger.dart'
    if (dart.library.html) 'features/ledger/data/web_ledger.dart';
import 'features/sync/cloud_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Read the saved language before the first frame, so a Bengali user never
  // sees an English flash.
  final AppLanguage language = await loadLanguagePreference();

  // Web opens the real WASM/IndexedDB ledger; native uses the on-device DB.
  // Passing a live ledger makes MainShell leave its read-only preview mode.
  final LocalLedger ledger = kIsWeb
      ? await openWebLedger()
      : LocalLedger.device();
  await ledger.initialize();

  CloudSync? cloudSync;
  try {
    cloudSync = await CloudSync.start(ledger: ledger);
  } catch (_) {
    // Sync must never block startup: a bad config or an unreachable project
    // leaves the app purely local-only.
    cloudSync = null;
  }
  runApp(
    KhataBookApp(
      ledger: ledger,
      cloudSync: cloudSync,
      initialLanguage: language,
    ),
  );
}

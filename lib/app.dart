// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'core/l10n/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/main_shell.dart';
import 'features/ledger/data/local_ledger.dart';

class KhataBookApp extends StatelessWidget {
  const KhataBookApp({
    super.key,
    this.ledger,
    this.initialLanguage = AppLanguage.en,
  });

  final LocalLedger? ledger;

  /// The language saved on this device, read before the first frame.
  final AppLanguage initialLanguage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KhataBook',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: MainShell(ledger: ledger, initialLanguage: initialLanguage),
    );
  }
}

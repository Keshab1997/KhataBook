// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/l10n/app_strings.dart';
import 'core/l10n/language_preference.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Read the saved language before the first frame, so a Bengali user never
  // sees an English flash.
  final AppLanguage language = await loadLanguagePreference();
  runApp(KhataBookApp(initialLanguage: language));
}

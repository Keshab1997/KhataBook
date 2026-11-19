// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/shell/main_shell.dart';

class KhataBookApp extends StatelessWidget {
  const KhataBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KhataBook',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const MainShell(),
    );
  }
}

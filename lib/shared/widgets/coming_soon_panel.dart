// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Shared placeholder for the three tabs whose logic lands in B3/B4/B5.
class ComingSoonPanel extends StatelessWidget {
  const ComingSoonPanel({
    super.key,
    required this.title,
    required this.icon,
    required this.headline,
    required this.batch,
  });

  final String title;
  final IconData icon;
  final String headline;
  final String batch;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.warmIvory,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 44, color: AppColors.primaryGreen),
                const SizedBox(height: 12),
                Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Spec: docs/spec/screens.md - implementation in $batch',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.softText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

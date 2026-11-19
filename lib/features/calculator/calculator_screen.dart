import 'package:flutter/material.dart';

import '../../shared/widgets/coming_soon_panel.dart';

/// S3 - Calculator. Keypad and expression evaluator arrive in B3;
/// the spec is docs/spec/screens.md#s3--calculator.
class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPanel(
      title: 'Calculator',
      icon: Icons.calculate_outlined,
      headline: '250 × 4 = 1,000',
      batch: 'B3',
    );
  }
}

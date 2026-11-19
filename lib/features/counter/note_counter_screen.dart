import 'package:flutter/material.dart';

import '../../shared/widgets/coming_soon_panel.dart';

/// S4 - Note Counter. Denomination stepper and grand total arrive in B3.
class NoteCounterScreen extends StatelessWidget {
  const NoteCounterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPanel(
      title: 'Note Counter',
      icon: Icons.payments_outlined,
      headline: '₹500 × 10 = ₹5,000',
      batch: 'B3',
    );
  }
}

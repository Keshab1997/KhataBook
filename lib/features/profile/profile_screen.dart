// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../shared/widgets/coming_soon_panel.dart';

/// S5 - Profile. Menu, avatar and Supabase backup arrive in B4/B5.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonPanel(
      title: 'Profile',
      icon: Icons.person_outline,
      headline: 'Plan · Track · Save',
      batch: 'B4',
    );
  }
}

// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/theme/app_colors.dart';

/// S9 - App Settings, docs/spec/screens.md#s9.
///
/// This build has no preference storage, no second currency, no dark theme and
/// no language switch, so the screen offers none: every row states the value
/// that is genuinely in force and is read-only. Nothing here is tappable
/// except the AppBar back arrow, which [Navigator] supplies, so no control
/// looks live and does nothing.
///
/// Currency (INR) and the light theme are current fixed values. English is the
/// only language wired up; Bengali is planned, not implemented. No choice made
/// here is saved, because no choice can be made yet - the notice at the top
/// says so instead of implying persisted preferences.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('App Settings')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Web design preview only. Local ledger storage, preferences and backup are not available on the web.',
            ),
          ),
        ),
      );
    }
    return Scaffold(
      key: const Key('settings-screen'),
      appBar: AppBar(
        // One line with ellipsis: at 200% text scale a wrapping title would
        // overflow the fixed AppBar height.
        title: const Text(
          'App Settings',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            const _ReadOnlyNotice(),
            const SizedBox(height: 20),
            const _SectionTitle('Preferences'),
            const SizedBox(height: 8),
            const _SettingsCard(
              children: <Widget>[
                _SettingRow(
                  key: Key('settings-currency-row'),
                  icon: Icons.currency_rupee,
                  title: 'Currency',
                  detail:
                      'Amounts are shown in Indian rupees with Indian digit '
                      'grouping. Other currencies are not available.',
                  value: 'INR (₹)',
                  status: 'Fixed in v1',
                ),
                _CardDivider(),
                _SettingRow(
                  key: Key('settings-theme-row'),
                  icon: Icons.light_mode_outlined,
                  title: 'Theme',
                  detail:
                      'KhataBook uses its light, paper-style theme. Dark mode '
                      'needs its own palette and is not implemented.',
                  value: 'Light',
                  status: 'Fixed in v1',
                ),
                _CardDivider(),
                _SettingRow(
                  key: Key('settings-language-row'),
                  icon: Icons.translate_outlined,
                  title: 'Language',
                  detail:
                      'English is the only language wired up. Bengali strings '
                      'are planned but not available, and choosing a language '
                      'is not possible yet.',
                  value: 'English',
                  status: 'Not available yet',
                ),
                _CardDivider(),
                _SettingRow(
                  key: Key('settings-backup-row'),
                  icon: Icons.cloud_off_outlined,
                  title: 'Cloud backup',
                  detail:
                      'There is no account, no sync and no cloud copy in this '
                      'build. The local database is your only copy.',
                  value: 'Off',
                  status: 'Not available yet',
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SectionTitle('Storage'),
            const SizedBox(height: 8),
            const _SettingsCard(
              children: <Widget>[
                _SettingRow(
                  key: Key('settings-storage-row'),
                  icon: Icons.smartphone_outlined,
                  title: 'Where entries are saved',
                  detail:
                      'Entries go straight into the local database on this '
                      'device. Uninstalling the app removes them.',
                  value: 'This device',
                  status: 'Local only',
                ),
                _CardDivider(),
                _SettingRow(
                  icon: Icons.wifi_off_outlined,
                  title: 'Internet required',
                  detail:
                      'Nothing in this build needs a connection, and nothing '
                      'is sent anywhere.',
                  value: 'No',
                  status: 'Offline-first',
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'These values describe how KhataBook behaves today. Changing them '
              'is not available yet, so no choice made here is saved.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.softText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'KhataBook 1.0.0 (build 1)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.softText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Green-tinted banner naming the state of the screen up front.
class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Read-only settings. These are the fixed values for this build. '
          'Nothing here can be changed and no preference is saved.',
      child: ExcludeSemantics(
        child: Container(
          key: const Key('settings-readonly-notice'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.lightGreen,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outline),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.info_outline, size: 26, color: AppColors.primaryGreen),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Read-only in this build',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'These are the fixed values for this version of '
                      'KhataBook. Nothing on this screen can be changed, and '
                      'no preference is saved.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.softText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.darkText,
      ),
    );
  }
}

/// Warm-ivory rounded card; no Material because no row is interactive.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: AppColors.outline);
  }
}

/// A fixed value: title, plain-language explanation, and the value plus its
/// status chip. Never tappable, and announced as one readable unit.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.value,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String value;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$title. $value. $status. $detail',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.lightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: AppColors.primaryGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: AppColors.softText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          _ValueChip(label: value, highlighted: true),
                          _ValueChip(label: status),
                        ],
                      ),
                    ],
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

/// Value or status pill. Its text wraps, so a long label never overflows.
class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.lightGreen : AppColors.warmIvory,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outline),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: highlighted ? AppColors.primaryGreen : AppColors.softText,
        ),
      ),
    );
  }
}

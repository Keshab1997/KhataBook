// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/theme/app_colors.dart';
import 'settings_screen.dart';

/// S5 - Profile, docs/spec/screens.md#s5--profile.
///
/// The honest, offline-first profile for this build. There is no signed-in
/// user, no avatar upload and no cloud backup yet, so the screen shows none of
/// them: no seeded name, no e-mail address and no "last synced" date. What it
/// does show is the state that is actually true - the khata lives on this
/// device and nothing is uploaded - plus a working route into App Settings.
///
/// Only controls that do something are enabled:
///   * [SettingsScreen], wired through [Navigator] so back works;
///   * the open-source licence page, rendered by Flutter itself.
///
/// Everything else (wallet summary, backup, sign-in) is visibly marked
/// *Not available yet* and is not tappable, rather than pretending to work.
///
/// Layout is one scrolling list with no fixed heights, so a 320 dp screen at
/// 200% text scale wraps instead of overflowing.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// Static build label, kept in step with `pubspec.yaml` by hand: this build
  /// ships no package-info dependency, so the number is stated, not read.
  static const String versionLabel = '1.0.0 (build 1)';

  /// Opens App Settings above the shell so its back arrow returns here.
  void _openSettings(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) => const SettingsScreen(),
      ),
    );
  }

  /// Flutter's own licence registry - real content, no network, no new file.
  void _openLicences(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'KhataBook',
      applicationVersion: versionLabel,
      applicationLegalese:
          'Offline-first personal khata. Data stays on this device.',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Web design preview only. Local ledger storage and backup are not available on the web.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _openSettings(context),
                  child: const Text('App Settings'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        // One line with ellipsis: at 200% text scale a wrapping title would
        // overflow the fixed AppBar height.
        title: const Text(
          'Profile',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          // Fixed 48 dp box keeps this icon-only control a 44 dp+ target at
          // every text scale.
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              key: const Key('profile-app-settings-gear'),
              onPressed: () => _openSettings(context),
              icon: const Icon(Icons.settings_outlined),
              color: AppColors.onPrimary,
              tooltip: 'App settings',
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            const _IdentityCard(),
            const SizedBox(height: 12),
            const _OfflineNotice(),
            const SizedBox(height: 20),
            const _SectionTitle('Account & backup'),
            const SizedBox(height: 8),
            _MenuCard(
              children: <Widget>[
                _MenuRow(
                  key: const Key('profile-app-settings-row'),
                  icon: Icons.settings_outlined,
                  title: 'App Settings',
                  subtitle: 'Currency, theme, language and backup.',
                  onTap: () => _openSettings(context),
                ),
                const _MenuDivider(),
                const _MenuRow(
                  key: Key('profile-wallet-row'),
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'My Wallet Summary',
                  subtitle:
                      'Opening balance, income and expense for each khata.',
                  status: 'Not available yet',
                ),
                const _MenuDivider(),
                const _MenuRow(
                  key: Key('profile-backup-row'),
                  icon: Icons.cloud_upload_outlined,
                  title: 'Back up to Supabase',
                  subtitle:
                      'Cloud backup needs a signed-in account, and sign-in is '
                      'not built in this version.',
                  status: 'Not available yet',
                ),
                const _MenuDivider(),
                const _MenuRow(
                  key: Key('profile-sign-in-row'),
                  icon: Icons.lock_outline,
                  title: 'Sign in',
                  subtitle:
                      'Accounts and cloud sync are not available in this '
                      'build. Your khata stays on this device.',
                  status: 'Not available yet',
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SectionTitle('About KhataBook'),
            const SizedBox(height: 8),
            _MenuCard(
              children: <Widget>[
                const _InfoRow(
                  key: Key('profile-version'),
                  label: 'Version',
                  value: versionLabel,
                ),
                const _MenuDivider(),
                const _InfoRow(
                  label: 'Where your data lives',
                  value: 'This device only',
                ),
                const _MenuDivider(),
                const _InfoRow(
                  label: 'Money',
                  value: 'Indian rupees (INR), Indian digit grouping',
                ),
                const _MenuDivider(),
                const _InfoRow(label: 'Theme', value: 'Light only'),
                const _MenuDivider(),
                _MenuRow(
                  key: const Key('profile-licences-row'),
                  icon: Icons.description_outlined,
                  title: 'Open-source licences',
                  subtitle: 'Software KhataBook is built with.',
                  onTap: () => _openLicences(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'KhataBook · Plan · Track · Save',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.softText, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Golden avatar circle with no personal data: a placeholder, not a fake user.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Container is not a const constructor; its decoration is.
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppColors.golden,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                size: 34,
                color: AppColors.headerGreen,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Local profile',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText,
                    ),
                  ),
                  SizedBox(height: 6),
                  _StatusChip(label: 'Not signed in'),
                  SizedBox(height: 8),
                  Text(
                    'No account is linked to KhataBook. Everything you enter '
                    'stays in the local database on this device.',
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
    );
  }
}

/// The truthful sync state, given its own card so it cannot be missed.
class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          'Offline and local-only. KhataBook works without internet. Entries '
          'are saved on this device only, and nothing is uploaded.',
      // Semantics has no const constructor; everything below it is const.
      child: const ExcludeSemantics(
        child: _Card(
          key: Key('profile-offline-status'),
          background: AppColors.lightGreen,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.cloud_off_outlined,
                  size: 28,
                  color: AppColors.primaryGreen,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Offline & local-only',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkText,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'KhataBook works without internet. Entries are written '
                        'to this device only - nothing is uploaded, and there '
                        'is no cloud copy to restore.',
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
      ),
    );
  }
}

/// Section heading above a card.
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

/// Rounded warm-ivory surface with the 1 dp beige border from theme.md.
class _Card extends StatelessWidget {
  const _Card({super.key, required this.child, this.background});

  final Widget child;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background ?? AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: child,
    );
  }
}

/// A card holding menu rows; a Material so enabled rows can ripple.
class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: AppColors.outline);
  }
}

/// One menu row.
///
/// With an [onTap] the row is a real 56 dp+ target with a chevron. Without
/// one the row is read-only: no ink, no tap handler, and a [status] chip that
/// says why it cannot be used.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.status,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final bool available = onTap != null;
    final Widget content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: available
                    ? AppColors.lightGreen
                    : AppColors.beige.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: available ? AppColors.primaryGreen : AppColors.softText,
              ),
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
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: AppColors.softText,
                    ),
                  ),
                  if (status != null) ...<Widget>[
                    const SizedBox(height: 8),
                    _StatusChip(label: status!),
                  ],
                ],
              ),
            ),
            if (available) ...<Widget>[
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (!available) {
      return content;
    }
    return InkWell(onTap: onTap, child: content);
  }
}

/// Static label/value line used by the About card. Stacked, so long values and
/// 200% text scale wrap rather than collide.
class _InfoRow extends StatelessWidget {
  const _InfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: AppColors.softText),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill used for "Not signed in" and "Not available yet".
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warmIvory,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outline),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: AppColors.softText,
        ),
      ),
    );
  }
}

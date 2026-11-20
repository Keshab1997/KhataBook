// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart' show AppLanguage;
import '../../core/theme/app_colors.dart';
import 'account_card.dart';
import 'cloud_backend.dart';
import 'cloud_sync.dart';
import 'sign_in_screen.dart';

/// The single soft card shadow from `theme.md` (blur 14, offset 0/4).
List<BoxShadow> _cardShadow() => <BoxShadow>[
  BoxShadow(
    color: AppColors.darkText.withValues(alpha: 0.05),
    blurRadius: 14,
    offset: const Offset(0, 4),
  ),
];

/// Dedicated Cloud Backup screen combining [AccountCard] (S5) and
/// [SignInScreen] (S11) navigation over [CloudSync].
///
/// * When [cloudSync] is provided, displays the live [AccountCard] bound to
///   `cloudSync.statusStream` (`Back up now`, `Retry`, `Confirm & Back up now`,
///   `Log out`, and `Sign in` pushing [SignInScreen]).
/// * When [cloudSync] is `null`, clearly explains in English and Bengali that
///   cloud backup is not set up in this build and that all khatas and entries
///   stay saved on this phone.
/// * Never shows a blocking progress dialog and wraps cleanly at 320 dp width
///   and 200 % text scale.
///
/// Cards share one look: warm ivory, radius 20, 1 dp beige border and the single
/// soft shadow, so the account card and the notes below it read as one system.
class CloudBackupScreen extends StatelessWidget {
  const CloudBackupScreen({
    super.key,
    this.language = AppLanguage.en,
    this.cloudSync,
    this.isOnline,
  });

  final AppLanguage language;
  final CloudSync? cloudSync;
  final Future<bool> Function()? isOnline;

  bool get _bn => language == AppLanguage.bn;

  String _pair(String en, String bn) => _bn ? bn : en;

  Future<void> _openSignIn(BuildContext context, CloudSync service) async {
    final CloudUser? signedInUser = await Navigator.of(context).push<CloudUser>(
      MaterialPageRoute<CloudUser>(
        builder: (BuildContext routeContext) =>
            SignInScreen(backend: service.backend, language: language),
      ),
    );
    if (signedInUser != null) {
      await service.backupNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final CloudSync? service = cloudSync;

    return Scaffold(
      key: const Key('cloud-backup-screen'),
      backgroundColor: AppColors.creamBackground,
      appBar: AppBar(
        title: Text(
          _pair('Cloud Backup', 'ক্লাউড ব্যাকআপ'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: <Widget>[
            if (service == null) ...<Widget>[
              _UnconfiguredCard(bn: _bn),
              const SizedBox(height: 16),
              _LocalFirstNoteCard(bn: _bn),
            ] else ...<Widget>[
              AccountCard(
                language: language,
                status: service.currentStatus,
                statusStream: service.statusStream,
                isOnline: isOnline,
                onSignIn: () => _openSignIn(context, service),
                onBackupNow: service.backupNow,
                onRetry: service.backupNow,
                onConfirmAccountSwitch: service.confirmAccountSwitch,
                onSignOut: service.signOut,
              ),
              const SizedBox(height: 16),
              _LocalFirstNoteCard(bn: _bn),
            ],
          ],
        ),
      ),
    );
  }
}

/// A card with a rounded-square leading badge, a heading and body copy.
class _NoteCard extends StatelessWidget {
  const _NoteCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
        boxShadow: _cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 22, color: AppColors.primaryGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.softText,
            ),
          ),
          if (footer != null) ...<Widget>[
            const SizedBox(height: 14),
            footer!,
          ],
        ],
      ),
    );
  }
}

class _UnconfiguredCard extends StatelessWidget {
  const _UnconfiguredCard({required this.bn});

  final bool bn;

  String _pair(String en, String bnText) => bn ? bnText : en;

  @override
  Widget build(BuildContext context) {
    return _NoteCard(
      key: const Key('cloud-backup-unconfigured-card'),
      icon: Icons.cloud_off_outlined,
      title: _pair(
        'Cloud backup is not set up in this build',
        'এই সংস্করণে ক্লাউড ব্যাকআপ সেট আপ করা নেই',
      ),
      body: _pair(
        'All of your khatas and entries stay safely saved on this phone and work completely offline.',
        'আপনার সব খাতা ও লেনদেন এই ফোনেই নিরাপদে সংরক্ষিত থাকে এবং সম্পূর্ণ অফলাইনে কাজ করে।',
      ),
      footer: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.lightGreen,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.check_circle_outline,
                size: 15,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _pair('Saved on this phone', 'এই ফোনে সংরক্ষিত'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalFirstNoteCard extends StatelessWidget {
  const _LocalFirstNoteCard({required this.bn});

  final bool bn;

  String _pair(String en, String bnText) => bn ? bnText : en;

  @override
  Widget build(BuildContext context) {
    return _NoteCard(
      key: const Key('cloud-backup-local-note'),
      icon: Icons.shield_outlined,
      title: _pair('Your phone is the primary copy', 'আপনার ফোনই মূল কপি'),
      body: _pair(
        'Entries work offline first and sync automatically when connected. Logging out never deletes local data.',
        'লেনদেন আগে অফলাইনে সংরক্ষিত হয় এবং ইন্টারনেট পেলে স্বয়ংক্রিয়ভাবে সিঙ্ক হয়। লগ আউট করলে ফোনের কোনো তথ্য মুছে যায় না।',
      ),
    );
  }
}

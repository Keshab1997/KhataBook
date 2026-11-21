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
///   stay saved on this phone. Automatic sync is only ever described as
///   contingent on setup, sign-in and connection - never as already active.
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

    // This page is pushed from Profile / Settings: the branded header keeps a
    // real back action, and on a short screen the whole body scrolls under it.
    final bool canPop = Navigator.of(context).canPop();

    return Scaffold(
      key: const Key('cloud-backup-screen'),
      backgroundColor: AppColors.creamBackground,
      body: Column(
        children: <Widget>[
          AccountPageHeader(
            title: _pair('Cloud Backup', 'ক্লাউড ব্যাকআপ'),
            subtitle: _pair('Optional backup & sync', 'ঐচ্ছিক ব্যাকআপ ও সিঙ্ক'),
            icon: Icons.cloud_outlined,
            backTooltip: _pair('Back', 'পেছনে'),
            onBack: canPop ? () => Navigator.of(context).maybePop() : null,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: <Widget>[
                  if (service == null) ...<Widget>[
                    _UnconfiguredCard(bn: _bn),
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
                  ],
                  const SizedBox(height: 14),
                  _LocalFirstNoteCard(bn: _bn, configured: service != null),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A card with a rounded-square leading badge, a heading and body copy.
///
/// [quiet] is the reassurance variant used under the account card: the same
/// geometry and border, but the cream background and no shadow, so it reads as
/// supporting copy rather than as a second, equal statement of state.
class _NoteCard extends StatelessWidget {
  const _NoteCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.footer,
    this.quiet = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? footer;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: quiet ? AppColors.creamBackground : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
        boxShadow: quiet ? null : _cardShadow(),
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
          if (footer != null) ...<Widget>[const SizedBox(height: 14), footer!],
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

/// The quiet reassurance under the account card: one warm surface, one short
/// statement, no action - it is the last thing read, so it asks for nothing.
///
/// The sync sentence is conditional on the build actually having a service:
/// unconfigured, it promises nothing and says what must happen first; either
/// way it states the coverage limit - cloud sync carries khatas and
/// transactions, not custom-category names/icons, the local profile or
/// note-counter data.
class _LocalFirstNoteCard extends StatelessWidget {
  const _LocalFirstNoteCard({required this.bn, required this.configured});

  final bool bn;

  /// Whether a cloud service exists at all. Even then, sync still needs
  /// sign-in and a connection, which the copy says.
  final bool configured;

  String _pair(String en, String bnText) => bn ? bnText : en;

  @override
  Widget build(BuildContext context) {
    return _NoteCard(
      key: const Key('cloud-backup-local-note'),
      quiet: true,
      icon: Icons.shield_outlined,
      title: _pair('Your phone is the primary copy', 'আপনার ফোনই মূল কপি'),
      body: configured
          ? _pair(
              'Entries are saved on this phone first and work fully offline. When you are signed in and online, khatas and transactions sync automatically. Custom category names and icons, your local profile and note counts are not synced. Signing out never deletes local data.',
              'লেনদেন আগে এই ফোনে সংরক্ষিত হয় এবং সম্পূর্ণ অফলাইনে চলে। সাইন-ইন ও অনলাইন থাকলে খাতা ও লেনদেন স্বয়ংক্রিয়ভাবে সিঙ্ক হয়। কাস্টম বিভাগের নাম ও আইকন, আপনার স্থানীয় প্রোফাইল ও নোট গণনার তথ্য সিঙ্ক হয় না। সাইন আউট করলে ফোনের কোনো তথ্য মুছে যায় না।',
            )
          : _pair(
              'Entries are saved on this phone first and work fully offline. Nothing syncs until cloud backup is set up and you sign in. When it is, khatas and transactions sync; custom category names and icons, your local profile and note counts stay on this phone only. Signing out never deletes local data.',
              'লেনদেন আগে এই ফোনে সংরক্ষিত হয় এবং সম্পূর্ণ অফলাইনে চলে। ক্লাউড ব্যাকআপ সেট আপ করে সাইন-ইন না করা পর্যন্ত কিছুই সিঙ্ক হয় না। সেট আপ হলে খাতা ও লেনদেন সিঙ্ক হয়; কাস্টম বিভাগের নাম ও আইকন, আপনার স্থানীয় প্রোফাইল ও নোট গণনার তথ্য শুধু এই ফোনেই থাকে। সাইন আউট করলে ফোনের কোনো তথ্য মুছে যায় না।',
            ),
    );
  }
}

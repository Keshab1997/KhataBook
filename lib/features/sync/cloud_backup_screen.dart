// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart' show AppLanguage;
import '../../core/theme/app_colors.dart';
import 'account_card.dart';
import 'cloud_backend.dart';
import 'cloud_sync.dart';
import 'sign_in_screen.dart';

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
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: <Widget>[
            if (service == null)
              _UnconfiguredCard(bn: _bn)
            else ...<Widget>[
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

class _UnconfiguredCard extends StatelessWidget {
  const _UnconfiguredCard({required this.bn});

  final bool bn;

  String _pair(String en, String bnText) => bn ? bnText : en;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('cloud-backup-unconfigured-card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
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
                decoration: const BoxDecoration(
                  color: AppColors.lightGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phonelink_lock_outlined,
                  size: 24,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _pair(
                        'Cloud backup is not set up in this build',
                        'এই সংস্করণে ক্লাউড ব্যাকআপ সেট আপ করা নেই',
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkText,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _pair(
                        'All of your khatas and entries stay safely saved on this phone and work completely offline.',
                        'আপনার সব খাতা ও লেনদেন এই ফোনেই নিরাপদে সংরক্ষিত থাকে এবং সম্পূর্ণ অফলাইনে কাজ করে।',
                      ),
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: AppColors.softText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.lightGreen,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _pair('Saved on this phone', 'এই ফোনে সংরক্ষিত'),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
    return Container(
      key: const Key('cloud-backup-local-note'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.shield_outlined,
            size: 20,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _pair(
                'Your phone is always the primary copy. Entries work offline first and sync automatically when connected. Logging out never deletes local data.',
                'আপনার ফোনই সবসময় মূল কপি। লেনদেন আগে অফলাইনে সংরক্ষিত হয় এবং ইন্টারনেট পেলে স্বয়ংক্রিয়ভাবে সিঙ্ক হয়। লগ আউট করলে ফোনের কোনো তথ্য মুছে যায় না।',
              ),
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.softText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

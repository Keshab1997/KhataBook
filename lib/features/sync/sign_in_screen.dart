// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart' show AppLanguage;
import '../../core/theme/app_colors.dart';
import 'cloud_backend.dart';

/// The single soft card shadow from `theme.md` (blur 14, offset 0/4).
List<BoxShadow> _cardShadow() => <BoxShadow>[
  BoxShadow(
    color: AppColors.darkText.withValues(alpha: 0.05),
    blurRadius: 14,
    offset: const Offset(0, 4),
  ),
];

/// S11 — Optional Google Sign-in screen for cloud backup & sync (B5).
///
/// Explains clearly that cloud backup is optional and that all local khatas and
/// entries stay on this phone whether or not the user signs in. Supports
/// English and Bengali through [language] using local en/bn string pairs.
///
/// Pops with the authenticated [CloudUser] on success (and invokes
/// [onSignedIn] when supplied). Cancellation and errors keep the screen open
/// with non-blocking inline feedback.
///
/// Visual system: a hero card with a cloud badge and a green "local data stays"
/// pill, a checklist of what signing in does and does not change, one clear
/// primary action, and a quiet outlined way back out. Cards share the warm ivory,
/// radius 20, 1 dp beige border and single soft shadow.
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.backend,
    this.language = AppLanguage.en,
    this.onSignedIn,
  });

  final CloudBackend backend;
  final AppLanguage language;
  final ValueChanged<CloudUser>? onSignedIn;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

enum _SignInFeedback { none, cancelled, offline, failed }

class _SignInScreenState extends State<SignInScreen> {
  bool _signingIn = false;
  _SignInFeedback _feedback = _SignInFeedback.none;
  String? _errorDetail;

  /// Wraps the progress or feedback panel so it can be scrolled into view: on
  /// a short screen or at a large text scale it sits below the fold.
  final GlobalKey _statusKey = GlobalKey();

  void _revealStatus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? target = _statusKey.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 250),
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  bool get _bn => widget.language == AppLanguage.bn;

  String _pair(String en, String bn) => _bn ? bn : en;

  Future<void> _handleGoogleSignIn() async {
    if (_signingIn) return;
    setState(() {
      _signingIn = true;
      _feedback = _SignInFeedback.none;
      _errorDetail = null;
    });
    _revealStatus();

    try {
      final CloudUser? user = await widget.backend.signInWithGoogle();
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _signingIn = false;
          _feedback = _SignInFeedback.cancelled;
        });
        _revealStatus();
        return;
      }
      setState(() {
        _signingIn = false;
      });
      widget.onSignedIn?.call(user);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(user);
      }
    } on CloudOfflineException {
      if (!mounted) return;
      setState(() {
        _signingIn = false;
        _feedback = _SignInFeedback.offline;
      });
      _revealStatus();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _signingIn = false;
        _feedback = _SignInFeedback.failed;
        _errorDetail = _sanitizeError(error);
      });
      _revealStatus();
    }
  }

  String? _sanitizeError(Object error) {
    final String text = error
        .toString()
        .replaceFirst(RegExp(r'^(Exception|StateError|Bad state):\s*'), '')
        .trim();
    if (text.isEmpty || text.length > 140) return null;
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('sign-in-screen'),
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
            _HeroCard(
              title: _pair('Optional Cloud Backup', 'ঐচ্ছিক ক্লাউড ব্যাকআপ'),
              subtitle: _pair(
                'Cloud backup is completely optional. Your khatas and entries always stay saved on this phone, even without an account or internet.',
                'ক্লাউড ব্যাকআপ সম্পূর্ণ ঐচ্ছিক। অ্যাকাউন্ট বা ইন্টারনেট ছাড়াই আপনার সব খাতা ও লেনদেন এই ফোনে সুরক্ষিত থাকে।',
              ),
              localBadge: _pair(
                'Local data stays on this phone',
                'স্থানীয় তথ্য এই ফোনেই থাকে',
              ),
            ),
            const SizedBox(height: 16),
            _BenefitsCard(
              title: _pair('What signing in does', 'সাইন ইন করলে যা হয়'),
              items: <String>[
                _pair(
                  'Keep your khatas backed up across devices when online.',
                  'অনলাইনে থাকলে আপনার খাতাগুলো ক্লাউডে ব্যাকআপ রাখুন।',
                ),
                _pair(
                  'Add and edit entries offline at any time — sync runs in the background.',
                  'যেকোনো সময় অফলাইনে লেনদেন যোগ বা সম্পাদনা করুন — সিঙ্ক পটভূমিতে চলে।',
                ),
                _pair(
                  'Signing out never deletes your local khatas or transactions.',
                  'লগ আউট করলে ফোনের কোনো খাতা বা লেনদেন মুছে যায় না।',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.outline),
                boxShadow: _cardShadow(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  FilledButton.icon(
                    key: const Key('continue-with-google-button'),
                    onPressed: _signingIn ? null : _handleGoogleSignIn,
                    icon: _signingIn
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : const Icon(Icons.account_circle_outlined),
                    label: Text(
                      _signingIn
                          ? _pair('Signing in…', 'সাইন ইন হচ্ছে…')
                          : _pair(
                              'Continue with Google',
                              'Google দিয়ে চালিয়ে যান',
                            ),
                    ),
                  ),
                  if (_signingIn) ...<Widget>[
                    const SizedBox(height: 12),
                    Semantics(
                      key: _statusKey,
                      liveRegion: true,
                      child: Container(
                        key: const Key('sign-in-progress'),
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreen,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.outline),
                        ),
                        child: Row(
                          children: <Widget>[
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _pair(
                                  'Connecting to Google… You can keep using KhataBook offline anytime.',
                                  'Google-এর সাথে সংযোগ করা হচ্ছে… আপনি যেকোনো সময় অফলাইনে খাতাবুক ব্যবহার করতে পারেন।',
                                ),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: AppColors.darkText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_feedback != _SignInFeedback.none) ...<Widget>[
                    const SizedBox(height: 12),
                    KeyedSubtree(
                      key: _statusKey,
                      child: _FeedbackBanner(
                        feedback: _feedback,
                        detail: _errorDetail,
                        bn: _bn,
                      ),
                    ),
                  ],
                  if (Navigator.of(context).canPop()) ...<Widget>[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      key: const Key('sign-in-not-now-button'),
                      onPressed: _signingIn
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.softText,
                        side: const BorderSide(color: AppColors.outline),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(
                        _pair(
                          'Keep local-only for now',
                          'এখন শুধু ফোনেই রাখুন',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A card with the shared warm-ivory surface, radius 20, beige border and the
/// single soft shadow. Card content decides the rest of its own layout.
class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
        boxShadow: _cardShadow(),
      ),
      child: child,
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.localBadge,
  });

  final String title;
  final String subtitle;
  final String localBadge;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.cloud_done_outlined,
                  color: AppColors.primaryGreen,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkText,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 260),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightGreen,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.smartphone_outlined,
                            size: 13,
                            color: AppColors.primaryGreen,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              localBadge,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.2,
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
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.softText,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 10),
          for (int index = 0; index < items.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 17,
                    color: AppColors.greenSuccess,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    items[index],
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.darkText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({
    required this.feedback,
    required this.detail,
    required this.bn,
  });

  final _SignInFeedback feedback;
  final String? detail;
  final bool bn;

  String _pair(String en, String bnText) => bn ? bnText : en;

  @override
  Widget build(BuildContext context) {
    final bool isCancel = feedback == _SignInFeedback.cancelled;
    final String heading = switch (feedback) {
      _SignInFeedback.cancelled => _pair(
        'Sign-in cancelled. Your local data is untouched.',
        'সাইন ইন বাতিল করা হয়েছে। আপনার ফোনের তথ্য অক্ষত আছে।',
      ),
      _SignInFeedback.offline => _pair(
        'You appear to be offline. Connect to the internet and try again.',
        'ইন্টারনেট সংযোগ নেই। অনলাইনে এসে আবার চেষ্টা করুন।',
      ),
      _SignInFeedback.failed => _pair(
        'Could not sign in with Google. Please try again.',
        'Google দিয়ে সাইন ইন করা যায়নি। অনুগ্রহ করে আবার চেষ্টা করুন।',
      ),
      _SignInFeedback.none => '',
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('sign-in-feedback'),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: isCancel ? AppColors.lightGreen : AppColors.warmIvory,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCancel ? AppColors.outline : AppColors.expenseRed,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              isCancel ? Icons.info_outline : Icons.error_outline,
              color: isCancel ? AppColors.primaryGreen : AppColors.expenseRed,
              size: 19,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    heading,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: AppColors.darkText,
                    ),
                  ),
                  if (!isCancel)
                    if (detail case final String errorText) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        errorText,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: AppColors.softText,
                        ),
                      ),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

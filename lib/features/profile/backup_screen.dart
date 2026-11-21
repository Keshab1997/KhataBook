// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';

enum BackupExportResult { saved, cancelled, failed }

class BackupPreview {
  const BackupPreview({
    required this.payload,
    required this.khataCount,
    required this.transactionCount,
    required this.deletedTransactionCount,
    this.profileIncluded,
    this.customCategoryCount,
    this.khatasWithSavedCount,
    this.savedSessionCount,
  });

  // payload opaque private string, never rendered or logged
  final String payload;
  final int khataCount;
  final int transactionCount;
  final int deletedTransactionCount;

  // The side areas a version 2 backup carries. Null when the caller did not
  // report them (an earlier wiring passes only the three counts above); the
  // screen shows the details line only when all four are present, so it
  // never invents counts it does not have.
  final bool? profileIncluded;
  final int? customCategoryCount;
  final int? khatasWithSavedCount;
  final int? savedSessionCount;
}

/// The single soft card shadow from `theme.md` (blur 14, offset 0/4).
List<BoxShadow> _cardShadow() => <BoxShadow>[
  BoxShadow(
    color: AppColors.darkText.withValues(alpha: 0.05),
    blurRadius: 14,
    offset: const Offset(0, 4),
  ),
];

/// S10-adjacent offline Backup / Restore screen.
///
/// Visual system: warm-ivory cards at radius 20 over the cream background, a
/// green privacy banner, a contents checklist on a light-green panel, a
/// numbered two-step flow (export, then pick + restore) and one clear primary
/// action per step. Destructive restore is red and confirms first. Every
/// colour is an [AppColors] token; the payload is never rendered.
class BackupScreen extends StatefulWidget {
  const BackupScreen({
    super.key,
    this.language = AppLanguage.en,
    required this.onExport,
    required this.onPickBackup,
    required this.onRestore,
  });

  final AppLanguage language;
  final Future<BackupExportResult> Function() onExport;
  final Future<BackupPreview?> Function() onPickBackup;
  final Future<bool> Function(BackupPreview) onRestore;

  @override
  State<BackupScreen> createState() => _BackupScreenContentState();
}

class _BackupScreenContentState extends State<BackupScreen> {
  bool _isPending = false;
  AppString? _message;
  AppStrings get _strings => AppStrings(widget.language);
  String _summary({bool loaded = false}) => _strings.backupPreview(
    khatas: _preview!.khataCount,
    transactions: _preview!.transactionCount,
    deleted: _preview!.deletedTransactionCount,
    loaded: loaded,
  );

  /// True when the preview carries all four side-area facts.
  bool _hasDetails(BackupPreview preview) =>
      preview.profileIncluded != null &&
      preview.customCategoryCount != null &&
      preview.khatasWithSavedCount != null &&
      preview.savedSessionCount != null;

  /// The side-area line under the counts summary, en+bn as a local pair.
  String _detailsLine(BackupPreview preview) {
    final bool bn = widget.language == AppLanguage.bn;
    final bool profile = preview.profileIncluded!;
    final int categories = preview.customCategoryCount!;
    final int khatas = preview.khatasWithSavedCount!;
    final int sessions = preview.savedSessionCount!;
    final String Function(int) n = _strings.number;
    if (bn) {
      return 'অন্তর্ভুক্ত: ${profile ? 'প্রোফাইল' : 'প্রোফাইল নেই'}, '
          '${n(categories)}টি কাস্টম ক্যাটাগরি, '
          '${n(khatas)}টি খাতায় সংরক্ষিত গণনা, '
          '${n(sessions)}টি সংরক্ষিত সেশন।';
    }
    return 'Includes: ${profile ? 'profile' : 'no profile'}, '
        '$categories custom ${categories == 1 ? 'category' : 'categories'}, '
        '$khatas ${khatas == 1 ? 'khata' : 'khatas'} with a saved count, '
        '$sessions saved ${sessions == 1 ? 'session' : 'sessions'}.';
  }

  /// A step heading in the screen's language. Kept as a local pair because the
  /// shared `AppString` table belongs to core and is not edited here.
  String _stepTitle({required String en, required String bn}) =>
      widget.language == AppLanguage.bn ? bn : en;

  /// The always-on list of what a backup carries, en+bn as local pairs.
  List<(String, String)> get _contents => const <(String, String)>[
    (
      'Every khata and every transaction, deleted entries included',
      'প্রতিটি খাতা ও প্রতিটি লেনদেন, মোছা এন্ট্রিগুলোসহ',
    ),
    (
      'Your offline profile (name and optional photo)',
      'আপনার অফলাইন প্রোফাইল (নাম ও ঐচ্ছিক ছবি)',
    ),
    (
      'Your custom categories (archived ones included)',
      'আপনার কাস্টম ক্যাটাগরি (আর্কাইভ করাগুলোসহ)',
    ),
    (
      'Note counter counts and saved sessions, for every khata',
      'প্রতিটি খাতার নোট কাউন্টারের গণনা ও সংরক্ষিত সেশন',
    ),
  ];

  Widget _contentsList() {
    final bool bn = widget.language == AppLanguage.bn;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            bn ? 'ব্যাকআপে যা থাকে:' : 'A backup file contains:',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 10),
          for (final (String en, String bng) in _contents)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_outlined,
                      size: 16,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bn ? bng : en,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.darkText,
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

  BackupPreview? _preview;

  Future<void> _handleExport() async {
    if (_isPending) return;
    setState(() => _isPending = true);
    _message = AppString.exportingBackup;
    try {
      final result = await widget.onExport();
      if (!mounted) return;
      setState(() {
        _isPending = false;
        _message = result == BackupExportResult.saved
            ? AppString.exportSaved
            : (result == BackupExportResult.cancelled
                  ? AppString.exportCancelled
                  : AppString.exportFailed);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isPending = false;
        _message = AppString.exportFailed;
      });
    }
  }

  Future<void> _handlePick() async {
    if (_isPending) return;
    setState(() => _isPending = true);
    _message = AppString.pickingBackup;
    try {
      final preview = await widget.onPickBackup();
      if (!mounted) return;
      setState(() {
        _isPending = false;
        _preview = preview;
        _message = preview != null ? null : AppString.pickCancelled;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isPending = false;
        _message = AppString.backupValidationFailed;
        _preview = null;
      });
    }
  }

  Future<void> _handleRestore() async {
    if (_isPending || _preview == null) return;
    setState(() => _isPending = true);
    _message = AppString.reviewRestore;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        backgroundColor: AppColors.surface,
        icon: const Icon(Icons.error_outline, color: AppColors.expenseRed),
        iconColor: AppColors.expenseRed,
        title: Text(_strings.text(AppString.restoreQuestion)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_summary()),
              if (_hasDetails(_preview!)) Text(_detailsLine(_preview!)),
              const SizedBox(height: 10),
              Text(
                widget.language == AppLanguage.en
                    ? 'WARNING: ALL current khatas and transactions on device will be replaced. This action is irreversible.'
                    : _strings.text(AppString.restoreWarning),
                style: const TextStyle(
                  color: AppColors.expenseRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
            ),
            child: Text(_strings.text(AppString.cancel)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.expenseRed,
              foregroundColor: AppColors.onPrimary,
              minimumSize: const Size(0, 44),
              // The dialog's actions can share one line with a long Bengali
              // label only if the text is allowed to wrap inside the button.
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(_strings.text(AppString.confirmRestore)),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed == true) {
      try {
        final success = await widget.onRestore(_preview!);
        if (!mounted) return;
        if (success) {
          setState(() => _isPending = false);
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _isPending = false;
            _message = AppString.restoreFailed;
          });
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isPending = false;
          _message = AppString.restoreFailed;
        });
      }
    } else {
      if (!mounted) return;
      setState(() {
        _isPending = false;
        _message = AppString.restoreCancelled;
      });
    }
  }

  /// The status line under the actions: what the last operation reported,
  /// plus the loaded counts when a backup is waiting to be restored.
  Widget _messagePanel(AppString message) {
    final bool isFailure =
        message == AppString.restoreFailed || message == AppString.exportFailed;
    final bool isSuccess =
        message == AppString.exportSaved || message == AppString.backupRestored;
    final Color accent = isFailure
        ? AppColors.expenseRed
        : (isSuccess ? AppColors.primaryGreen : AppColors.softText);
    final IconData icon = isFailure
        ? Icons.error_outline
        : (isSuccess ? Icons.check_circle_outlined : Icons.info_outline);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _strings.text(message),
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.darkText,
                  ),
                ),
                if (_preview != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    _summary(loaded: true),
                    style: const TextStyle(
                      fontSize: 12,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // 320dp/200% scrolling, accessible 44dp targets
    return PopScope(
      canPop: !_isPending,
      child: Scaffold(
        appBar: AppBar(title: Text(_strings.text(AppString.backupRestore))),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: <Widget>[
                    const _IconBadge(
                      icon: Icons.save_alt,
                      size: 44,
                      radius: 14,
                      iconSize: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _strings.text(AppString.offlineBackupRestore),
                        style: const TextStyle(
                          fontSize: 19,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warmIvory,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.lock_outlined,
                        size: 18,
                        color: AppColors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _strings.text(AppString.backupPrivacy),
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
                const SizedBox(height: 16),
                _contentsList(),
                const SizedBox(height: 20),
                _StepCard(
                  step: 1,
                  title: _stepTitle(
                    en: 'Save a copy',
                    bn: 'একটি কপি সংরক্ষণ করুন',
                  ),
                  child: FilledButton(
                    key: const Key('backup-export-button'),
                    onPressed: _isPending ? null : _handleExport,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: _ButtonLabel(
                      icon: Icons.file_upload_outlined,
                      label: _strings.text(AppString.exportBackup),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _StepCard(
                  step: 2,
                  title: _stepTitle(
                    en: 'Restore from a file',
                    bn: 'ফাইল থেকে পুনরুদ্ধার',
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      OutlinedButton(
                        key: const Key('backup-pick-button'),
                        onPressed: _isPending ? null : _handlePick,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: _ButtonLabel(
                          icon: Icons.folder_open_outlined,
                          label: _strings.text(AppString.pickBackup),
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      if (_preview != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warmIvory,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.outline),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Padding(
                                    padding: EdgeInsets.only(top: 1),
                                    child: Icon(
                                      Icons.insert_drive_file_outlined,
                                      size: 16,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _summary(),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.35,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.darkText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_hasDetails(_preview!))
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _detailsLine(_preview!),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      height: 1.4,
                                      color: AppColors.softText,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          key: const Key('backup-restore-button'),
                          onPressed: _isPending ? null : _handleRestore,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.expenseRed,
                            foregroundColor: AppColors.onPrimary,
                            minimumSize: const Size.fromHeight(52),
                          ),
                          child: _ButtonLabel(
                            icon: Icons.restore,
                            label: _strings.text(AppString.confirmReplaceAll),
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_message != null) ...<Widget>[
                  const SizedBox(height: 16),
                  _messagePanel(_message!),
                ],
                if (_isPending) ...<Widget>[
                  const SizedBox(height: 16),
                  // A calm, static working panel: the flow is short and the
                  // buttons already show it is running, so the screen never
                  // turns into a spinner with the content behind it.
                  Container(
                    key: const Key('backup-working-panel'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreen,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.sync,
                            size: 18,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _stepTitle(
                              en:
                                  'Working… keep this screen open until it '
                                  'finishes.',
                              bn:
                                  'কাজ চলছে… শেষ হওয়া পর্যন্ত এই স্ক্রিনটি '
                                  'খোলা রাখুন।',
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
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A numbered step card: small green step badge, a heading, then its actions.
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.title,
    required this.child,
  });

  final int step;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          Row(
            children: <Widget>[
              Container(
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$step',
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// A button's icon + label. A plain icon+label button cannot wrap gracefully
/// at 200 % text scale; this keeps the text in a [Flexible] so it wraps onto a
/// second line instead of overflowing.
class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({
    required this.icon,
    required this.label,
    this.color = AppColors.onPrimary,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    this.size = 40,
    this.radius = 12,
    this.iconSize = 20,
  });

  final IconData icon;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: AppColors.primaryGreen),
    );
  }
}

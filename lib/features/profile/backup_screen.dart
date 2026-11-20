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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            bn ? 'ব্যাকআপে যা থাকে:' : 'A backup file contains:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          for (final (String en, String bng) in _contents)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('\u2022  ${bn ? bng : en}'),
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
        title: Text(_strings.text(AppString.restoreQuestion)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_summary()),
              if (_hasDetails(_preview!))
                Text(_detailsLine(_preview!)),
              const SizedBox(height: 10),
              Text(
                widget.language == AppLanguage.en
                    ? 'WARNING: ALL current khatas and transactions on device will be replaced. This action is irreversible.'
                    : _strings.text(AppString.restoreWarning),
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_strings.text(AppString.cancel)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
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

  @override
  Widget build(BuildContext context) {
    // 320dp/200% scrolling, accessible 44dp targets
    return PopScope(
      canPop: !_isPending,
      child: Scaffold(
        appBar: AppBar(title: Text(_strings.text(AppString.backupRestore))),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _strings.text(AppString.offlineBackupRestore),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _strings.text(AppString.backupPrivacy),
                  style: const TextStyle(color: Colors.orange, fontSize: 14),
                ),
                const SizedBox(height: 16),
                _contentsList(),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isPending ? null : _handleExport,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: Text(_strings.text(AppString.exportBackup)),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isPending ? null : _handlePick,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: Text(_strings.text(AppString.pickBackup)),
                ),
                const SizedBox(height: 12),
                if (_preview != null) ...[
                  const Divider(),
                  Text(_summary()),
                  if (_hasDetails(_preview!))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_detailsLine(_preview!)),
                    ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isPending ? null : _handleRestore,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_strings.text(AppString.confirmReplaceAll)),
                  ),
                ],
                const SizedBox(height: 20),
                if (_message != null || _preview != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _message == null
                          ? _summary(loaded: true)
                          : _strings.text(_message!),
                    ),
                  ),
                ],
                if (_isPending)
                  const SizedBox(
                    height: 20,
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

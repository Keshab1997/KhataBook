// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';

enum BackupExportResult { saved, cancelled, failed }

class BackupPreview {
  const BackupPreview({
    required this.payload,
    required this.khataCount,
    required this.transactionCount,
    required this.deletedTransactionCount,
  });

  // payload opaque private string, never rendered or logged
  final String payload;
  final int khataCount;
  final int transactionCount;
  final int deletedTransactionCount;
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

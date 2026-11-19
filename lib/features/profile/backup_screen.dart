// ignore: deprecated_member_use
import 'package:flutter/material.dart';

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
    required this.onExport,
    required this.onPickBackup,
    required this.onRestore,
  });

  final Future<BackupExportResult> Function() onExport;
  final Future<BackupPreview?> Function() onPickBackup;
  final Future<bool> Function(BackupPreview) onRestore;

  @override
  State<BackupScreen> createState() => _BackupScreenContentState();
}

class _BackupScreenContentState extends State<BackupScreen> {
  bool _isPending = false;
  String _message = '';
  BackupPreview? _preview;

  Future<void> _handleExport() async {
    if (_isPending) return;
    setState(() => _isPending = true);
    _message = 'Exporting... (Warning: backup may contain sensitive unencrypted financial data; choose a safe location)';
    try {
      final result = await widget.onExport();
      if (!mounted) return;
      setState(() {
        _isPending = false;
        _message = result == BackupExportResult.saved
            ? 'Export saved successfully.'
            : (result == BackupExportResult.cancelled
                  ? 'Export cancelled.'
                  : 'Export failed.');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isPending = false;
        _message = 'Export failed.';
      });
    }
  }

  Future<void> _handlePick() async {
    if (_isPending) return;
    setState(() => _isPending = true);
    _message = 'Picking backup...';
    try {
      final preview = await widget.onPickBackup();
      if (!mounted) return;
      setState(() {
        _isPending = false;
        _preview = preview;
        _message = preview != null
            ? 'Preview loaded: ${preview.khataCount} khatas, ${preview.transactionCount} transactions, ${preview.deletedTransactionCount} deleted.'
            : 'Pick cancelled.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isPending = false;
        _message = 'Could not read or validate the backup.';
        _preview = null;
      });
    }
  }

  Future<void> _handleRestore() async {
    if (_isPending || _preview == null) return;
    setState(() => _isPending = true);
    _message = 'Review the confirmation before restoring.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preview: ${_preview!.khataCount} khatas, ${_preview!.transactionCount} transactions, ${_preview!.deletedTransactionCount} deleted.',
              ),
              const SizedBox(height: 10),
              const Text(
                'WARNING: ALL current khatas and transactions on device will be replaced. This action is irreversible.',
                style: TextStyle(
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm Restore'),
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
            _message = 'Restore failed. Your current data was not replaced.';
          });
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isPending = false;
          _message = 'Restore failed. Your current data was not replaced.';
        });
      }
    } else {
      if (!mounted) return;
      setState(() {
        _isPending = false;
        _message = 'Restore cancelled.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 320dp/200% scrolling, accessible 44dp targets
    return PopScope(
      canPop: !_isPending,
      child: Scaffold(
        appBar: AppBar(title: const Text('Backup / Restore')),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Offline Backup / Restore',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Text(
                  'WARNING: Backup may contain sensitive unencrypted financial data; ensure you choose a safe location.',
                  style: TextStyle(color: Colors.orange, fontSize: 14),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isPending ? null : _handleExport,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: const Text('Export Backup'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isPending ? null : _handlePick,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: const Text('Pick Backup to Restore'),
                ),
                const SizedBox(height: 12),
                if (_preview != null) ...[
                  const Divider(),
                  Text(
                    'Preview: ${_preview!.khataCount} khatas, ${_preview!.transactionCount} transactions, ${_preview!.deletedTransactionCount} deleted.',
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isPending ? null : _handleRestore,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Confirm Restore (Replace ALL Data)'),
                  ),
                ],
                const SizedBox(height: 20),
                if (_message.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_message),
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

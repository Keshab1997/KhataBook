// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart' show AppLanguage;
import '../../core/theme/app_colors.dart';
import '../ledger/data/local_ledger.dart';
import 'sign_in_screen.dart' show AccountPageHeader;

/// Read-only sync diagnostics over the on-device `sync_metadata` row.
///
/// Field errors must not die in the dark: when `CloudSync.start` fails at
/// startup (main.dart records the reason) or a sync attempt fails later
/// (the sync engine persists it), the reason lands in
/// `sync_metadata.last_error`. This screen surfaces that row — last error,
/// last successful sync, pull cursor and last synced account — so a user or
/// a support conversation can read the state without adb.
///
/// Purely local: one `readSyncMetadata()` call, no network, no mutation.
class SyncDiagnosticsScreen extends StatefulWidget {
  const SyncDiagnosticsScreen({
    super.key,
    required this.ledger,
    this.language = AppLanguage.en,
  });

  final LocalLedger ledger;
  final AppLanguage language;

  @override
  State<SyncDiagnosticsScreen> createState() => _SyncDiagnosticsScreenState();
}

class _SyncDiagnosticsScreenState extends State<SyncDiagnosticsScreen> {
  late final Future<LocalSyncMetadata> _metadata;

  bool get _bn => widget.language == AppLanguage.bn;

  String _pair(String en, String bn) => _bn ? bn : en;

  @override
  void initState() {
    super.initState();
    _metadata = widget.ledger.readSyncMetadata();
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.of(context).canPop();
    return Scaffold(
      key: const Key('sync-diagnostics-screen'),
      backgroundColor: AppColors.creamBackground,
      body: Column(
        children: <Widget>[
          AccountPageHeader(
            title: _pair('Diagnostics', 'ডায়াগনস্টিকস'),
            subtitle: _pair(
              'Sync state on this phone',
              'এই ফোনের সিঙ্ক অবস্থা',
            ),
            icon: Icons.troubleshoot_outlined,
            backTooltip: _pair('Back', 'পেছনে'),
            onBack: canPop ? () => Navigator.of(context).maybePop() : null,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: FutureBuilder<LocalSyncMetadata>(
                future: _metadata,
                builder: _buildBody,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncSnapshot<LocalSyncMetadata> snapshot,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    final LocalSyncMetadata meta = snapshot.data ?? LocalSyncMetadata();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        _lastErrorCard(meta.lastError),
        const SizedBox(height: 14),
        _stateCard(meta),
      ],
    );
  }

  /// The headline card: the most recent recorded failure, or a quiet
  /// all-clear. This is the row item 18 exists for.
  Widget _lastErrorCard(String? lastError) {
    final bool hasError = lastError != null && lastError.trim().isNotEmpty;
    return Container(
      key: const Key('diagnostics-last-error-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.darkText.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: hasError
                      ? AppColors.expenseRed.withValues(alpha: 0.12)
                      : AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  hasError ? Icons.error_outline : Icons.check_circle_outline,
                  size: 22,
                  color: hasError
                      ? AppColors.expenseRed
                      : AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _pair('Last error', 'শেষ ত্রুটি'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasError
                ? lastError
                : _pair(
                    'No sync errors recorded on this phone.',
                    'এই ফোনে কোনো সিঙ্ক ত্রুটি রেকর্ড হয়নি।',
                  ),
            key: const Key('diagnostics-last-error-text'),
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: hasError ? AppColors.expenseRed : AppColors.softText,
            ),
          ),
        ],
      ),
    );
  }

  /// The quiet facts under the headline: last successful sync, pull cursor
  /// and the account this device last synced with.
  Widget _stateCard(LocalSyncMetadata meta) {
    final String never = _pair('Never', 'কখনো নয়');
    final String none = _pair('None', 'নেই');
    return Container(
      key: const Key('diagnostics-state-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.creamBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _fact(
            _pair('Last successful sync', 'শেষ সফল সিঙ্ক'),
            meta.lastSyncedAt?.toIso8601String() ?? never,
          ),
          const SizedBox(height: 10),
          _fact(
            _pair('Pull cursor', 'পুল কার্সার'),
            meta.cursor?.toIso8601String() ?? none,
          ),
          const SizedBox(height: 10),
          _fact(
            _pair('Last synced account', 'শেষ সিঙ্ক করা অ্যাকাউন্ট'),
            meta.lastSyncedAccountId ?? none,
          ),
        ],
      ),
    );
  }

  Widget _fact(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.softText,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppColors.darkText,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../home/models.dart';
import 'data/local_ledger.dart';

/// S8 - My Wallet Summary. See docs/spec/screens.md (Wallet Summary).
///
/// Reads every active khata from the existing native [LocalLedger] and shows
/// the per-khata opening balance, income, expense and remaining, plus one
/// combined remaining figure across all active khatas (D6). Every value is
/// integer paise formatted by [formatPaise]; the screen never seeds, fakes or
/// caches figures, and it makes no network call.
///
/// [LedgerSummary.totalIncomePaise] already folds a khata's opening balance
/// into income, so the tile is labelled *Income (incl. opening)* and the
/// opening balance is never added a second time anywhere in the totals.
///
/// The ledger is owned by the caller: this screen never closes it. Loading and
/// failures are explicit - a failed read shows the reason and a retry, and
/// clears any previous figures so stale totals are never displayed.
class WalletSummaryScreen extends StatefulWidget {
  const WalletSummaryScreen({super.key, required this.ledger});

  /// The caller-owned database. This screen only reads from it.
  final LocalLedger ledger;

  @override
  State<WalletSummaryScreen> createState() => _WalletSummaryScreenState();
}

/// One khata with the summary that was read for it.
class _KhataTotals {
  const _KhataTotals({required this.khata, required this.summary});

  final LocalKhata khata;
  final LedgerSummary summary;
}

/// Everything one load produced, so the build step does no arithmetic on
/// half-updated state.
class _WalletData {
  const _WalletData(this.khatas);

  final List<_KhataTotals> khatas;

  /// Sum of the per-khata remaining balances. Each remaining already contains
  /// that khata's own opening balance exactly once.
  int get combinedRemainingPaise => khatas.fold<int>(
    0,
    (int sum, _KhataTotals khata) => sum + khata.summary.remainingPaise,
  );
}

class _WalletSummaryScreenState extends State<WalletSummaryScreen> {
  _WalletData? _data;
  Object? _error;
  bool _loading = true;

  /// Guards against an older, slower load overwriting a newer one.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final int request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final List<LocalKhata> khatas = await widget.ledger.listKhatas();
      final List<_KhataTotals> totals = <_KhataTotals>[];
      for (final LocalKhata khata in khatas) {
        totals.add(
          _KhataTotals(
            khata: khata,
            summary: await widget.ledger.readSummary(khataId: khata.id),
          ),
        );
      }
      if (!mounted || request != _request) return;
      setState(() {
        _data = _WalletData(List<_KhataTotals>.unmodifiable(totals));
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error;
        _data = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Wallet Summary',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Reload summary',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    final _WalletData? data = _data;
    if (data == null) {
      if (_error != null) {
        return _ErrorPanel(error: _error!, onRetry: _loading ? null : _load);
      }
      return const _LoadingPanel();
    }
    return _SummaryList(data: data);
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Semantics(
              label: 'Loading wallet summary',
              child: const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Reading your khatas…',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.softText),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the real failure reason and one retry. It never renders figures, so a
/// failed read can never leave old totals on screen.
class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.warmIvory,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(
                    Icons.error_outline,
                    color: AppColors.expenseRed,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Could not read your khatas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Nothing is shown until the data loads, so totals are never '
                'guessed. Your saved entries are untouched.',
                style: const TextStyle(fontSize: 13, color: AppColors.softText),
              ),
              const SizedBox(height: 12),
              Text(
                error.toString(),
                style: const TextStyle(fontSize: 12, color: AppColors.softText),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text(
                  'Try again',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryList extends StatelessWidget {
  const _SummaryList({required this.data});

  final _WalletData data;

  @override
  Widget build(BuildContext context) {
    if (data.khatas.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          Text(
            'No khatas on this device yet.',
            style: TextStyle(fontSize: 14, color: AppColors.softText),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _CombinedCard(data: data),
        const SizedBox(height: 12),
        for (final _KhataTotals totals in data.khatas) ...<Widget>[
          _KhataCard(totals: totals),
          const SizedBox(height: 12),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            Icon(Icons.info_outline, size: 16, color: AppColors.softText),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Income already includes each khata’s opening balance, so '
                'openings are never added twice.',
                style: TextStyle(fontSize: 12, color: AppColors.softText),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CombinedCard extends StatelessWidget {
  const _CombinedCard({required this.data});

  final _WalletData data;

  @override
  Widget build(BuildContext context) {
    final int count = data.khatas.length;
    final int combined = data.combinedRemainingPaise;
    final String caption = count == 1
        ? 'Across 1 khata'
        : 'Across $count khatas';
    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          'Combined remaining, $caption: ${formatPaise(combined)}. '
          'Income in each khata already includes its opening balance.',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Combined remaining',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onPrimary.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              formatPaise(combined),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.onPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.onPrimary.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One khata: name plus its four figures. Rows use bounded, wrapping text so
/// 320 dp width and 200% text scale cannot overflow.
class _KhataCard extends StatelessWidget {
  const _KhataCard({required this.totals});

  final _KhataTotals totals;

  @override
  Widget build(BuildContext context) {
    final LedgerSummary summary = totals.summary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warmIvory,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              totals.khata.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            summary.entries.length == 1
                ? '1 entry'
                : '${summary.entries.length} entries',
            style: const TextStyle(fontSize: 12, color: AppColors.softText),
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: 'Opening balance',
            value: formatPaise(totals.khata.openingBalancePaise),
          ),
          const SizedBox(height: 8),
          _StatRow(
            label: 'Income (incl. opening)',
            value: formatPaise(summary.totalIncomePaise),
            color: AppColors.incomeGreen,
          ),
          const SizedBox(height: 8),
          _StatRow(
            label: 'Expense',
            value: formatPaise(summary.totalExpensePaise),
            color: AppColors.expenseRed,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: AppColors.outline),
          ),
          _StatRow(
            label: 'Remaining',
            value: formatPaise(summary.remainingPaise),
            emphasized: true,
            color: summary.remainingPaise < 0
                ? AppColors.expenseRed
                : AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.color = AppColors.darkText,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.softText),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: emphasized ? 16 : 14,
                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

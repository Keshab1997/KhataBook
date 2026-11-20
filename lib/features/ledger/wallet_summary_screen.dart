// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../home/models.dart';
import 'data/local_ledger.dart';

/// Geometry shared by this screen, so the combined card and every khata card
/// sit on one radius with one hairline border.
const double _cardRadius = 20;
const double _edge = 0.85;

/// S8 - My Wallet Summary. See docs/spec/screens.md (Wallet Summary).
///
/// Reads every active khata from the existing native [LocalLedger] and shows
/// the per-khata opening balance, income, expense and remaining, plus one
/// combined remaining figure across all active khatas (D6). Every value is
/// integer paise formatted by [AppStrings.money] (the shared `formatPaise`,
/// with Bengali digits when that language is selected); the screen never seeds,
/// fakes or caches figures, and it makes no network call.
///
/// [LedgerSummary.totalIncomePaise] already folds a khata's opening balance
/// into income, so the tile is labelled *Income (incl. opening)* and the
/// opening balance is never added a second time anywhere in the totals.
///
/// The ledger is owned by the caller: this screen never closes it. Loading and
/// failures are explicit - a failed read shows the reason and a retry, and
/// clears any previous figures so stale totals are never displayed.
class WalletSummaryScreen extends StatefulWidget {
  const WalletSummaryScreen({
    super.key,
    required this.ledger,
    this.language = AppLanguage.en,
  });

  /// The caller-owned database. This screen only reads from it.
  final LocalLedger ledger;

  /// Copy language. Display only, default English, so the figures and the
  /// khata names keep their stored, canonical form in either language.
  final AppLanguage language;

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

  /// Copy for this screen and its panels. Display only.
  AppStrings get _strings => AppStrings(widget.language);

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
    final AppStrings strings = _strings;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          strings.text(AppString.walletSummary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          IconButton(
            tooltip: strings.text(AppString.reloadSummary),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(child: _body(strings)),
    );
  }

  Widget _body(AppStrings strings) {
    final _WalletData? data = _data;
    if (data == null) {
      if (_error != null) {
        return _ErrorPanel(
          error: _error!,
          strings: strings,
          onRetry: _loading ? null : _load,
        );
      }
      return _LoadingPanel(strings: strings);
    }
    return _SummaryList(data: data, strings: strings);
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Semantics(
              label: strings.text(AppString.loadingWallet),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              strings.text(AppString.readingKhatas),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.softText,
              ),
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
  const _ErrorPanel({
    required this.error,
    required this.strings,
    required this.onRetry,
  });

  final Object error;
  final AppStrings strings;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(_cardRadius),
            border: Border.all(
              color: AppColors.outline.withValues(alpha: _edge),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.expenseRed,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.text(AppString.readKhatasFailed),
                      style: const TextStyle(
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
                strings.text(AppString.walletLoadExplanation),
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
                label: Text(
                  _copy(strings, en: 'Try again', bn: 'আবার চেষ্টা করুন'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
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
  const _SummaryList({required this.data, required this.strings});

  final _WalletData data;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    if (data.khatas.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(_cardRadius),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: _edge),
              ),
            ),
            child: Row(
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
                    Icons.account_balance_wallet_outlined,
                    color: AppColors.primaryGreen,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    strings.text(AppString.noLocalKhatas),
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: AppColors.softText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _CombinedCard(data: data, strings: strings),
        const SizedBox(height: 12),
        for (final _KhataTotals totals in data.khatas) ...<Widget>[
          _KhataCard(totals: totals, strings: strings),
          const SizedBox(height: 12),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.info_outline, size: 16, color: AppColors.softText),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                strings.text(AppString.walletOpeningExplanation),
                style: const TextStyle(fontSize: 12, color: AppColors.softText),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CombinedCard extends StatelessWidget {
  const _CombinedCard({required this.data, required this.strings});

  final _WalletData data;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final int count = data.khatas.length;
    final int combined = data.combinedRemainingPaise;
    final String caption = strings.acrossKhatas(count);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: strings.walletTotal(khatas: count, paise: combined),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[AppColors.primaryGreen, AppColors.headerGreen],
          ),
          borderRadius: BorderRadius.circular(_cardRadius + 2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.darkText.withValues(alpha: 0.16),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              strings.text(AppString.combinedRemaining),
              style: TextStyle(
                fontSize: 12.5,
                letterSpacing: 0.3,
                fontWeight: FontWeight.w600,
                color: AppColors.onPrimary.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                strings.money(combined),
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.1,
                  letterSpacing: -0.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              caption,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
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
  const _KhataCard({required this.totals, required this.strings});

  final _KhataTotals totals;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final LedgerSummary summary = totals.summary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: AppColors.outline.withValues(alpha: _edge)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.darkText.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
                height: 1.25,
                letterSpacing: -0.2,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            strings.entryCount(summary.entries.length),
            style: const TextStyle(
              fontSize: 12,
              height: 1.3,
              letterSpacing: 0.2,
              color: AppColors.softText,
            ),
          ),
          const SizedBox(height: 12),
          _StatRow(
            label: strings.text(AppString.openingBalance),
            value: strings.money(totals.khata.openingBalancePaise),
          ),
          const SizedBox(height: 8),
          _StatRow(
            label: strings.text(AppString.incomeIncludingOpening),
            value: strings.money(summary.totalIncomePaise),
            color: AppColors.incomeGreen,
          ),
          const SizedBox(height: 8),
          _StatRow(
            label: strings.text(AppString.expense),
            value: strings.money(summary.totalExpensePaise),
            color: AppColors.expenseRed,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 1, color: AppColors.outline),
          ),
          _StatRow(
            label: strings.text(AppString.remaining),
            value: strings.money(summary.remainingPaise),
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
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.3,
                color: AppColors.softText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: emphasized ? 17 : 14,
                height: 1.25,
                letterSpacing: emphasized ? -0.2 : 0,
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Copy the shared [AppString] dictionary does not carry yet. The dictionary is
/// shared with the rest of the app, so a phrase nobody else needs stays private
/// to this file instead of being added there.
String _copy(AppStrings strings, {required String en, required String bn}) =>
    strings.language == AppLanguage.bn ? bn : en;

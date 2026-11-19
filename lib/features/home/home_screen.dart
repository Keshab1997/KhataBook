// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/format/date_format.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../profile/settings_screen.dart';
import 'models.dart';

/// S1 - Home / My Khata. See docs/spec/screens.md#s1--home--my-khata.
///
/// A presentational seam: the parent supplies a live [summary] and the
/// [onAddEntry] / [onViewAll] callbacks. With no [summary] the B1 preview of
/// the supplied design (`docs/design/ui-preview.png` and
/// `docs/design/style-guide.png`, style-guide header variant per D4) is kept
/// exactly as it was, including the seeded figures and the notice. This
/// screen reads no storage, navigates nowhere and holds no state; Captain
/// wires the ledger adapter and the parent in the next step.
///
/// Layout, top to bottom: green header (open-book mark, wordmark,
/// *Plan · Track · Save*, settings gear) · balance card · income/expense
/// summary · recent transactions (at most four, D5) · full-width
/// *Add New Entry* CTA.
///
/// Every text block is inside a bounded flex or a scaling box so that 200%
/// text scale and small phone widths cannot overflow.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.summary,
    this.onAddEntry,
    this.onViewAll,
    this.khataName,
    this.onSwitchKhata,
  });

  /// Live figures to render. `null` selects the seeded preview instead.
  final LedgerSummary? summary;

  /// CTA action; a null callback leaves the button visibly disabled.
  final VoidCallback? onAddEntry;

  /// *View All* action; a null callback leaves that affordance disabled.
  final VoidCallback? onViewAll;

  final String? khataName;
  final VoidCallback? onSwitchKhata;

  /// Page padding from the 8 dp grid in docs/spec/theme.md.
  static const double _pagePadding = 16;

  /// Gap between stacked cards.
  static const double _cardGap = 12;

  @override
  Widget build(BuildContext context) {
    final bool preview = summary == null;
    final LedgerSummary visibleSummary =
        summary ??
        LedgerSummary(
          openingBalancePaise: kSeedOpeningBalancePaise,
          entries: kSeedEntries,
        );
    final List<LedgerEntry> recent = visibleSummary.recent();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const _HomeHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(_pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (onSwitchKhata != null) ...<Widget>[
                      OutlinedButton.icon(
                        key: const Key('switch-khata'),
                        onPressed: onSwitchKhata,
                        icon: const Icon(Icons.account_balance_wallet_outlined),
                        label: Text(
                          khataName ?? 'Personal Khata',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: _cardGap),
                    ],
                    _BalanceCard(remainingPaise: visibleSummary.remainingPaise),
                    const SizedBox(height: _cardGap),
                    _summaryRow(visibleSummary),
                    const SizedBox(height: 20),
                    _SectionHeader(
                      title: 'Recent Transactions',
                      onViewAll: onViewAll,
                    ),
                    const SizedBox(height: 8),
                    if (recent.isEmpty)
                      const _EmptyTransactions()
                    else
                      for (final LedgerEntry entry in recent)
                        _RecentTransactionRow(entry: entry),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: onAddEntry,
                      icon: const Icon(Icons.add, size: 22),
                      label: const Text(
                        'Add New Entry',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // The 8 dp gap is kept in both modes so only the notice
                    // itself disappears once a live summary arrives.
                    const SizedBox(height: 8),
                    if (preview)
                      const Center(
                        child: Text(
                          'Preview data - local ledger arrives in B2',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.softText,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(LedgerSummary summary) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _SummaryTile(
              label: 'Total Income',
              paise: summary.totalIncomePaise,
              color: AppColors.incomeGreen,
              icon: Icons.arrow_upward,
              direction: 'income',
            ),
          ),
          const SizedBox(width: _cardGap),
          Expanded(
            child: _SummaryTile(
              label: 'Total Expense',
              paise: summary.totalExpensePaise,
              color: AppColors.expenseRed,
              icon: Icons.arrow_downward,
              direction: 'expense',
            ),
          ),
        ],
      ),
    );
  }
}

/// Green header bar: open-book mark, wordmark, tagline and the settings gear.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.headerGreen,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: <Widget>[
          // Illustration stand-in for the supplied open-book + quill artwork.
          const Icon(Icons.menu_book, color: AppColors.golden, size: 32),
          const SizedBox(width: 10),
          // FittedBox keeps the wordmark readable instead of clipped when the
          // text scale grows or the phone is narrow.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'KhataBook',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    'Plan · Track · Save',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: AppColors.golden,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings),
            color: AppColors.onPrimary,
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// `primaryGreen` balance card with the wallet treatment and a leaf motif.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.remainingPaise});

  final int remainingPaise;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.darkText.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ColoredBox(
          color: AppColors.primaryGreen,
          child: Stack(
            children: <Widget>[
              // Decorative leaves, echoing the artwork in the mockup. Purely
              // ornamental: excluded from semantics.
              Positioned(
                right: -18,
                bottom: -22,
                child: ExcludeSemantics(
                  child: Icon(
                    Icons.eco,
                    size: 108,
                    color: AppColors.headerGreen.withValues(alpha: 0.55),
                  ),
                ),
              ),
              Positioned(
                right: 34,
                top: -26,
                child: ExcludeSemantics(
                  child: Icon(
                    Icons.spa,
                    size: 64,
                    color: AppColors.headerGreen.withValues(alpha: 0.45),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.golden,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: AppColors.primaryGreen,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'Remaining Balance',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.onPrimary.withValues(
                                alpha: 0.86,
                              ),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // The hero number: scale it down rather than clip it.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatPaise(remainingPaise),
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                color: AppColors.onPrimary,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
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
        ),
      ),
    );
  }
}

/// One half of the income/expense summary row.
class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.paise,
    required this.color,
    required this.icon,
    required this.direction,
  });

  final String label;
  final int paise;
  final Color color;
  final IconData icon;

  /// Semantic direction, so the tile is readable without seeing an arrow.
  final String direction;

  @override
  Widget build(BuildContext context) {
    // One merged node ("Total Income, income, ₹10,000") so a screen reader
    // announces the label, direction and amount together.
    return Semantics(
      container: true,
      label: '$label, $direction, ${formatPaise(paise)}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        label,
                        maxLines: 2,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.15,
                          color: AppColors.softText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // 20 dp w800 clears the "large text" threshold in theme.md, so
              // the red/green amounts keep AA contrast on warm ivory.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatPaise(paise),
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
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

/// Friendly stand-in for the recent list when the supplied ledger is empty.
class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          'No transactions yet. Add an entry to see it here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.softText, fontSize: 13),
        ),
      ),
    );
  }
}

/// *Recent Transactions* with an accessible `View All` button.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onViewAll});

  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onViewAll != null;
    // A missing callback must not look like a working affordance: grey it out
    // and let TextButton's button semantics advertise the disabled state.
    final Color tint = enabled
        ? AppColors.primaryGreen
        : AppColors.navigationGrey;

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tint,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: tint),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One recent transaction: tinted category icon, title, timestamp, amount.
class _RecentTransactionRow extends StatelessWidget {
  const _RecentTransactionRow({required this.entry});

  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final bool isIncome = entry.type == EntryType.income;
    final Color amountColor = isIncome
        ? AppColors.incomeGreen
        : AppColors.expenseRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Semantics(
            label: 'Category ${entry.category}',
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _categoryTint(entry.category),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _categoryIcon(entry.category),
                size: 20,
                color: _categoryColor(entry.category),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                ),
                Text(
                  formatEntryDate(entry.at),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.softText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  isIncome
                      ? '+${formatPaise(entry.amountPaise)}'
                      : formatPaise(entry.amountPaise),
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: amountColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _categoryTint(String category) =>
      _categoryColor(category).withValues(alpha: 0.14);

  /// Category icon tints from the mockup, mapped onto palette tokens only
  /// (theme.md lists a blue for Travel that the palette does not define, so
  /// Travel reuses the green family).
  Color _categoryColor(String category) {
    switch (category) {
      case 'Shopping':
        return AppColors.primaryGreen;
      case 'Food':
        return AppColors.orange;
      case 'Travel':
        return AppColors.secondaryGreen;
      case 'Bills':
        return AppColors.golden;
      case 'Gifts':
        return AppColors.expenseRed;
      default:
        return AppColors.navigationGrey;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Shopping':
        return Icons.shopping_cart;
      case 'Food':
        return Icons.restaurant;
      case 'Travel':
        return Icons.directions_bus;
      case 'Bills':
        return Icons.phone_android;
      case 'Gifts':
        return Icons.card_giftcard;
      default:
        return Icons.more_horiz;
    }
  }
}

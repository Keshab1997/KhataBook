// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../entry/category_artwork.dart';
import '../profile/settings_screen.dart';
import 'models.dart';

/// S1 - Home / My Khata. See docs/spec/screens.md#s1--home--my-khata.
///
/// A presentational seam: the parent supplies a live [summary] and the
/// [onAddEntry] / [onViewAll] callbacks. With no [summary] the screen shows
/// clearly labelled sample figures. It reads no storage and holds no state.
///
/// The layout gives the active ledger and remaining balance first priority,
/// then keeps the income/expense split, recent activity and primary action
/// close together. Illustrations are local assets: the screen works offline.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.language = AppLanguage.en,
    this.summary,
    this.onAddEntry,
    this.onViewAll,
    this.khataName,
    this.onSwitchKhata,
  });

  final AppLanguage language;

  AppStrings get _strings => AppStrings(language);

  /// Live figures to render. `null` selects the seeded sample preview.
  final LedgerSummary? summary;

  /// CTA action; a null callback leaves the button visibly disabled.
  final VoidCallback? onAddEntry;

  /// *View All* action; a null callback leaves that affordance disabled.
  final VoidCallback? onViewAll;

  final String? khataName;
  final VoidCallback? onSwitchKhata;

  static const double _pagePadding = 16;
  static const double _cardGap = 10;

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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(_pagePadding, 8, _pagePadding, 8),
          decoration: BoxDecoration(
            color: AppColors.creamBackground,
            border: Border(
              top: BorderSide(color: AppColors.outline.withValues(alpha: 0.65)),
            ),
          ),
          child: FilledButton.icon(
            key: const Key('home-add-entry'),
            onPressed: onAddEntry,
            icon: const Icon(Icons.add, size: 22),
            label: Text(
              _strings.text(AppString.addNewEntry),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _HomeHeader(_strings),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  _pagePadding,
                  10,
                  _pagePadding,
                  16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (khataName != null || onSwitchKhata != null) ...<Widget>[
                      _ActiveKhataCard(
                        strings: _strings,
                        name:
                            khataName ?? _strings.text(AppString.personalKhata),
                        onTap: onSwitchKhata,
                      ),
                      const SizedBox(height: _cardGap),
                    ],
                    _BalanceCard(
                      strings: _strings,
                      remainingPaise: visibleSummary.remainingPaise,
                    ),
                    const SizedBox(height: _cardGap),
                    _summaryRow(visibleSummary),
                    const SizedBox(height: 16),
                    _SectionHeader(
                      strings: _strings,
                      title: _strings.text(AppString.recentTransactions),
                      onViewAll: onViewAll,
                    ),
                    const SizedBox(height: 8),
                    if (recent.isEmpty)
                      _EmptyTransactions(_strings)
                    else
                      for (final LedgerEntry entry in recent)
                        _RecentTransactionRow(
                          strings: _strings,
                          entry: entry,
                          preview: preview,
                        ),
                    const SizedBox(height: 4),
                    if (preview) ...<Widget>[
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          _strings.text(AppString.homePreview),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.softText,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
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
              strings: _strings,
              label: _strings.text(AppString.totalIncome),
              paise: summary.totalIncomePaise,
              color: AppColors.incomeGreen,
              icon: Icons.south_west_rounded,
              direction: _strings.text(AppString.income).toLowerCase(),
            ),
          ),
          const SizedBox(width: _cardGap),
          Expanded(
            child: _SummaryTile(
              strings: _strings,
              label: _strings.text(AppString.totalExpense),
              paise: summary.totalExpensePaise,
              color: AppColors.expenseRed,
              icon: Icons.north_east_rounded,
              direction: _strings.text(AppString.expense).toLowerCase(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Brand header: a compact book mark, wordmark, promise and a labelled action.
class _HomeHeader extends StatelessWidget {
  const _HomeHeader(this.strings);

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        HomeScreen._pagePadding,
        8,
        HomeScreen._pagePadding,
        0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[AppColors.headerGreen, AppColors.primaryGreen],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.warmIvory,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.menu_book,
              color: AppColors.primaryGreen,
              size: 25,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    strings.text(AppString.appName),
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                      letterSpacing: -0.35,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  strings.text(AppString.tagline),
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                    color: AppColors.lightGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.35,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(language: strings.language),
              ),
            ),
            icon: const Icon(Icons.settings, size: 21),
            color: AppColors.onPrimary,
            tooltip: strings.text(AppString.settings),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.onPrimary.withValues(alpha: 0.10),
              minimumSize: const Size(42, 42),
              maximumSize: const Size(42, 42),
              padding: EdgeInsets.zero,
              side: BorderSide(
                color: AppColors.onPrimary.withValues(alpha: 0.18),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An always-visible switcher row makes the active ledger easy to confirm.
class _ActiveKhataCard extends StatelessWidget {
  const _ActiveKhataCard({
    required this.strings,
    required this.name,
    required this.onTap,
  });

  final AppStrings strings;
  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('switch-khata'),
      button: onTap != null,
      enabled: onTap != null,
      label:
          '$name, ${strings.text(AppString.activeKhata)}${onTap == null ? '' : ', ${strings.text(AppString.tapToSwitch)}'}',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.lightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.menu_book,
                    color: AppColors.primaryGreen,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        strings.text(AppString.activeKhata).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                          color: AppColors.softText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  onTap == null
                      ? Icons.check_circle_outline_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primaryGreen,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Green balance card with a bundled AI wallet illustration.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.strings, required this.remainingPaise});

  final AppStrings strings;
  final int remainingPaise;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.darkText.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: <Widget>[
            Positioned(
              right: -34,
              top: -44,
              child: ExcludeSemantics(
                child: Container(
                  width: 134,
                  height: 134,
                  decoration: BoxDecoration(
                    color: AppColors.headerGreen.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.account_balance_wallet,
                              color: AppColors.golden,
                              size: 18,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                strings.text(AppString.remainingBalance),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.onPrimary.withValues(
                                    alpha: 0.9,
                                  ),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            strings.money(remainingPaise),
                            maxLines: 1,
                            softWrap: false,
                            style: const TextStyle(
                              color: AppColors.onPrimary,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        width: 84,
                        height: 84,
                        child: Image.asset(
                          'assets/illustrations/home_wallet.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const ColoredBox(
                                color: AppColors.lightGreen,
                                child: Icon(
                                  Icons.account_balance_wallet,
                                  size: 44,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One half of the income/expense summary row.
class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.strings,
    required this.label,
    required this.paise,
    required this.color,
    required this.icon,
    required this.direction,
  });

  final AppStrings strings;
  final String label;
  final int paise;
  final Color color;
  final IconData icon;
  final String direction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label, $direction, ${strings.money(paise)}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
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
                  const SizedBox(width: 6),
                  Expanded(
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
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  strings.money(paise),
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 19,
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

/// Empty ledger state, kept plain and actionable.
class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions(this.strings);

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.receipt_long_rounded,
            color: AppColors.primaryGreen,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            strings.text(AppString.homeEmpty),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.softText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// *Recent Transactions* with an accessible `View All` button.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.strings,
    required this.title,
    this.onViewAll,
  });

  final AppStrings strings;
  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onViewAll != null;
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
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.darkText,
              letterSpacing: -0.2,
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
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: tint,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    strings.text(AppString.viewAll),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tint,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: tint),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One recent transaction: category cue, clear description and signed amount.
class _RecentTransactionRow extends StatelessWidget {
  const _RecentTransactionRow({
    required this.strings,
    required this.entry,
    required this.preview,
  });

  final AppStrings strings;
  final LedgerEntry entry;
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final bool isIncome = entry.type == EntryType.income;
    final Color amountColor = isIncome
        ? AppColors.incomeGreen
        : AppColors.expenseRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: <Widget>[
          Semantics(
            label: strings.categoryLabel(
              _categoryLabel(strings, entry.category),
            ),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _categoryTint(entry.category),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: CategoryArtwork(
                  category: entry.category,
                  size: 38,
                  fallbackColor: _categoryColor(entry.category),
                ),
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
                  preview ? _previewTitle(strings, entry.title) : entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  strings.dateTime(entry.at),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
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
                      ? '+${strings.money(entry.amountPaise)}'
                      : strings.money(entry.amountPaise),
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 18,
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

  /// Category colours come from theme tokens only.
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
}

String _categoryLabel(AppStrings strings, String category) {
  final AppString? key = switch (category) {
    'Shopping' => AppString.shopping,
    'Food' => AppString.food,
    'Travel' => AppString.travel,
    'Bills' => AppString.bills,
    'Gifts' => AppString.gifts,
    'Income' => AppString.income,
    'Expense' => AppString.expense,
    _ => null,
  };
  return key == null ? category : strings.text(key);
}

String _previewTitle(AppStrings strings, String title) {
  final AppString? key = switch (title) {
    'Grocery Shopping' => AppString.groceryShopping,
    'Lunch with Friends' => AppString.lunchWithFriends,
    'Mobile Recharge' => AppString.mobileRecharge,
    'Gift for Mom' => AppString.giftForMom,
    'Bus Fare' => AppString.busFare,
    'Tea with Team' => AppString.teaWithTeam,
    _ => null,
  };
  return key == null ? title : strings.text(key);
}

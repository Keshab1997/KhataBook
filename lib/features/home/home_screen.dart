import 'package:flutter/material.dart';

import '../../core/format/date_format.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import 'models.dart';

/// S1 - Home / My Khata. See docs/spec/screens.md#s1--home--my-khata.
/// B1 is a faithful static preview of the supplied design; B2 wires the local
/// ledger, the entry form and the khata switcher.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final LedgerSummary summary = LedgerSummary(
      openingBalancePaise: kSeedOpeningBalancePaise,
      entries: kSeedEntries,
    );
    final List<LedgerEntry> recent = summary.recent();
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const <Widget>[
            Icon(Icons.menu_book, color: AppColors.golden),
            SizedBox(width: 10),
            Text(
              'KhataBook',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: const <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.settings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _balanceCard(summary.remainingPaise),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _summaryTile(
                    label: 'Total Income',
                    paise: summary.totalIncomePaise,
                    color: AppColors.incomeGreen,
                    icon: Icons.arrow_upward,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _summaryTile(
                    label: 'Total Expense',
                    paise: summary.totalExpensePaise,
                    color: AppColors.expenseRed,
                    icon: Icons.arrow_downward,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                // Flexible keeps the header safe at 200% text scale and with
                // longer translated (bn) labels.
                Flexible(
                  child: Text(
                    'Recent Transactions',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'View All >',
                  style: TextStyle(color: AppColors.primaryGreen),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final LedgerEntry entry in recent) _transactionRow(entry),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Add New Entry'),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Preview data - local ledger arrives in B2',
                style: TextStyle(color: AppColors.softText, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceCard(int remainingPaise) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.account_balance_wallet,
            color: AppColors.golden,
            size: 44,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Remaining Balance',
                style: TextStyle(color: AppColors.onPrimary, fontSize: 13),
              ),
              Text(
                formatPaise(remainingPaise),
                style: const TextStyle(
                  color: AppColors.onPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryTile({
    required String label,
    required int paise,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.warmIvory,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.softText),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                formatPaise(paise),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _transactionRow(LedgerEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.warmIvory,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            backgroundColor: AppColors.lightGreen,
            child: Icon(
              _iconFor(entry.category),
              color: AppColors.primaryGreen,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  formatEntryDate(entry.at),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.softText,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatPaise(entry.amountPaise),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.expenseRed,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String category) {
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

// Flutter 3.50 deprecates this import; migrate with the app's dependency update.
// ignore: deprecated_member_use
import 'package:flutter/semantics.dart';
// Flutter 3.50 deprecates this import; migrate with the app's dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/core/theme/app_theme.dart';
import 'package:khatabook/features/home/models.dart';
import 'package:khatabook/features/ledger/all_transactions_screen.dart';

const Size smallPhone = Size(320, 568);
const Size midPhone = Size(360, 640);

/// Tall enough that every lazily built list child is mounted, so a missing
/// string really means "not on the screen".
const Size tallPhone = Size(400, 2400);

/// ₹10,000. This must never appear on the screen: the screen reports
/// transaction totals only.
const int kOpeningPaise = 1000000;

LedgerEntry spent(String title, String category, DateTime at, int paise) =>
    LedgerEntry(title: title, category: category, at: at, amountPaise: paise);

LedgerEntry earned(String title, String category, DateTime at, int paise) =>
    LedgerEntry(
      title: title,
      category: category,
      at: at,
      amountPaise: paise,
      type: EntryType.income,
    );

/// Eight entries over three months:
///   Nov 2026 income ₹5,000, expense ₹2,280
///   Oct 2026 income ₹7,500, expense ₹2,500.50
///   Sep 2026 income ₹0, expense ₹25
LedgerSummary sampleSummary() => LedgerSummary(
  openingBalancePaise: kOpeningPaise,
  entries: <LedgerEntry>[
    spent(
      'Grocery Shopping',
      'Shopping',
      DateTime(2026, 11, 19, 20, 30),
      120000,
    ),
    spent('Lunch with Friends', 'Food', DateTime(2026, 11, 19, 13, 15), 58000),
    spent('Mobile Recharge', 'Bills', DateTime(2026, 11, 19, 10, 20), 19900),
    earned('Salary', 'Income', DateTime(2026, 11, 18, 19, 40), 500000),
    spent('Bus Fare', 'Travel', DateTime(2026, 11, 17, 9, 5), 30100),
    spent('Diwali Gift', 'Gifts', DateTime(2026, 10, 31, 18, 0), 250050),
    earned('Freelance Work', 'Income', DateTime(2026, 10, 15, 12, 0), 750000),
    spent('Tea Stall', 'Food', DateTime(2026, 9, 5, 8, 0), 2500),
  ],
);

/// Pumps the screen alone with the real app theme, at [scale] text size.
Future<void> pumpAllTransactions(
  WidgetTester tester,
  LedgerSummary summary, {
  Size size = tallPhone,
  double scale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: AllTransactionsScreen(summary: summary),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls the screen's list until [finder] exists and is visible.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.descendant(
      of: find.byType(AllTransactionsScreen),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls [finder] into view and taps it only if it can really be tapped.
Future<void> tapControl(WidgetTester tester, Finder finder) async {
  await reveal(tester, finder);
  expect(
    finder.hitTestable().evaluate().isNotEmpty,
    isTrue,
    reason: 'control is offscreen or covered and cannot be tapped',
  );
  await tester.tap(finder.hitTestable());
  await tester.pumpAndSettle();
}

Future<void> tapChip(WidgetTester tester, String key) =>
    tapControl(tester, find.byKey(Key(key)));

/// Whether the chip's selected state is visible as a check mark.
Finder chipCheck(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byIcon(Icons.check),
);

void main() {
  group('list content', () {
    testWidgets('shows every entry, more than four, newest first', (
      WidgetTester tester,
    ) async {
      await pumpAllTransactions(tester, sampleSummary());

      for (final String title in <String>[
        'Grocery Shopping',
        'Lunch with Friends',
        'Mobile Recharge',
        'Salary',
        'Bus Fare',
        'Diwali Gift',
        'Freelance Work',
        'Tea Stall',
      ]) {
        expect(find.text(title), findsOneWidget, reason: '$title is missing');
      }

      // Same day, newest time first.
      expect(
        tester.getTopLeft(find.text('Grocery Shopping')).dy,
        lessThan(tester.getTopLeft(find.text('Lunch with Friends')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Lunch with Friends')).dy,
        lessThan(tester.getTopLeft(find.text('Mobile Recharge')).dy),
      );
      // ...and across days and months.
      expect(
        tester.getTopLeft(find.text('Mobile Recharge')).dy,
        lessThan(tester.getTopLeft(find.text('Salary')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Bus Fare')).dy,
        lessThan(tester.getTopLeft(find.text('Diwali Gift')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Freelance Work')).dy,
        lessThan(tester.getTopLeft(find.text('Tea Stall')).dy),
      );
    });

    testWidgets('breaks same-instant ties deterministically', (
      WidgetTester tester,
    ) async {
      final DateTime sameTime = DateTime(2026, 11, 19, 9, 0);
      await pumpAllTransactions(
        tester,
        LedgerSummary(
          openingBalancePaise: 0,
          entries: <LedgerEntry>[
            spent('Zebra', 'Food', sameTime, 1000),
            spent('Alpha', 'Food', sameTime, 1000),
            spent(
              'Mango',
              'Food',
              sameTime.subtract(const Duration(minutes: 1)),
              1000,
            ),
          ],
        ),
      );

      // Equal timestamps fall back to title, so the order never depends on the
      // order the caller happened to supply.
      expect(
        tester.getTopLeft(find.text('Alpha')).dy,
        lessThan(tester.getTopLeft(find.text('Zebra')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Zebra')).dy,
        lessThan(tester.getTopLeft(find.text('Mango')).dy),
      );
    });

    testWidgets('groups by local day with month totals, opening excluded', (
      WidgetTester tester,
    ) async {
      await pumpAllTransactions(tester, sampleSummary());

      // Day headings come from the shared `dd MMM yyyy, h:mm a` helper.
      expect(find.text('19 Nov 2026'), findsOneWidget);
      expect(find.text('18 Nov 2026'), findsOneWidget);
      expect(find.text('31 Oct 2026'), findsOneWidget);
      expect(find.text('05 Sep 2026'), findsOneWidget);
      expect(find.text('Nov 2026'), findsOneWidget);
      expect(find.text('Oct 2026'), findsOneWidget);
      expect(find.text('Sep 2026'), findsOneWidget);

      // Rows keep the shared timestamp format and signed paise amounts.
      expect(find.text('Bills · 19 Nov 2026, 10:20 AM'), findsOneWidget);
      expect(find.text('-₹1,200'), findsOneWidget);
      expect(find.text('+₹5,000'), findsOneWidget);

      final Finder november = find.byKey(const Key('month-2026-11'));
      expect(
        find.descendant(of: november, matching: find.text('₹5,000')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: november, matching: find.text('₹2,280')),
        findsOneWidget,
      );

      final Finder october = find.byKey(const Key('month-2026-10'));
      expect(
        find.descendant(of: october, matching: find.text('₹7,500')),
        findsOneWidget,
      );
      // Paise survive: ₹2,500.50 is not rounded to ₹2,501.
      expect(find.text('₹2,500.50'), findsOneWidget);
      expect(find.textContaining('₹2,501'), findsNothing);

      // The opening balance never leaks into any total.
      expect(find.textContaining('₹10,000'), findsNothing);
      expect(find.textContaining('remaining balance.'), findsWidgets);
    });
  });

  group('filters', () {
    testWidgets('type filter changes rows and month totals together', (
      WidgetTester tester,
    ) async {
      await pumpAllTransactions(tester, sampleSummary());

      await tapChip(tester, 'type-filter-income');

      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Freelance Work'), findsOneWidget);
      expect(find.text('Grocery Shopping'), findsNothing);
      expect(find.text('Tea Stall'), findsNothing);
      // September holds no income, so that month disappears entirely.
      expect(find.text('Sep 2026'), findsNothing);

      final Finder november = find.byKey(const Key('month-2026-11'));
      expect(
        find.descendant(of: november, matching: find.text('₹5,000')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: november, matching: find.text('₹0')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('transactions-summary')),
          matching: find.text('₹0'),
        ),
        findsOneWidget,
      );
      expect(find.text('Showing 2 of 8 transactions'), findsOneWidget);
    });

    testWidgets('category filter, combined filter, and the no-match state', (
      WidgetTester tester,
    ) async {
      await pumpAllTransactions(tester, sampleSummary());

      await tapChip(tester, 'category-filter-Food');
      expect(find.text('Lunch with Friends'), findsOneWidget);
      expect(find.text('Tea Stall'), findsOneWidget);
      expect(find.text('Grocery Shopping'), findsNothing);
      expect(find.text('Showing 2 of 8 transactions'), findsOneWidget);
      expect(find.byKey(const Key('month-2026-10')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('month-2026-11')),
          matching: find.text('₹580'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('month-2026-09')),
          matching: find.text('₹25'),
        ),
        findsOneWidget,
      );

      // Both filters apply at once; no Food entry is income.
      await tapChip(tester, 'type-filter-income');
      expect(find.byKey(const Key('transactions-no-match')), findsOneWidget);
      expect(find.text('No transactions match these filters'), findsOneWidget);
      expect(find.text('Showing 0 of 8 transactions'), findsOneWidget);
      expect(find.byKey(const Key('transactions-empty')), findsNothing);

      // The clear action is a real, tappable control of a usable size.
      final Finder clear = find.byKey(const Key('clear-filters'));
      expect(tester.getSize(clear).height, greaterThanOrEqualTo(44));
      await tapControl(tester, clear);

      expect(find.byKey(const Key('transactions-no-match')), findsNothing);
      expect(find.text('Grocery Shopping'), findsOneWidget);
      expect(find.text('Showing 8 transactions'), findsOneWidget);
      // Both chip groups are back to "All", shown by the check mark.
      expect(chipCheck('type-filter-all'), findsOneWidget);
      expect(chipCheck('category-filter-all'), findsOneWidget);
      expect(chipCheck('type-filter-income'), findsNothing);
      expect(chipCheck('category-filter-Food'), findsNothing);
    });

    testWidgets('empty khata is a different, honest message', (
      WidgetTester tester,
    ) async {
      await pumpAllTransactions(
        tester,
        const LedgerSummary(
          openingBalancePaise: kOpeningPaise,
          entries: <LedgerEntry>[],
        ),
      );

      expect(find.byKey(const Key('transactions-empty')), findsOneWidget);
      expect(find.text('No transactions yet'), findsOneWidget);
      expect(find.text('No transactions match these filters'), findsNothing);
      // Nothing to filter, no totals to state, and no money invented.
      expect(find.byKey(const Key('transactions-summary')), findsNothing);
      expect(find.byKey(const Key('type-filter-all')), findsNothing);
      expect(find.byKey(const Key('category-filter-all')), findsNothing);
      expect(find.textContaining('₹'), findsNothing);
    });
  });

  group('accessibility and layout', () {
    testWidgets('filters are 44 dp+, labelled and show selection in words', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpAllTransactions(tester, sampleSummary());

      for (final String key in <String>[
        'type-filter-all',
        'type-filter-income',
        'type-filter-expense',
        'category-filter-all',
        'category-filter-Food',
      ]) {
        expect(
          tester.getSize(find.byKey(Key(key))).height,
          greaterThanOrEqualTo(44),
          reason: '$key must be at least 44 dp tall',
        );
      }

      expect(find.bySemanticsLabel('Type filter: all entries'), findsWidgets);
      expect(find.bySemanticsLabel('Type filter: income'), findsWidgets);
      expect(find.bySemanticsLabel('Category filter: Food'), findsWidgets);

      // Selection is not carried by colour alone.
      expect(chipCheck('type-filter-all'), findsOneWidget);
      expect(chipCheck('type-filter-expense'), findsNothing);
      handle.dispose();
    });

    testWidgets('fits 320 dp at 200% text scale and keeps working', (
      WidgetTester tester,
    ) async {
      await pumpAllTransactions(
        tester,
        sampleSummary(),
        size: smallPhone,
        scale: 2.0,
      );
      expect(tester.takeException(), isNull);

      await tapChip(tester, 'type-filter-income');
      expect(tester.takeException(), isNull);

      // Income-only rows are further down a 568 dp window: scroll to them.
      await reveal(tester, find.text('Salary'));
      expect(find.text('Salary'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await reveal(tester, find.text('Freelance Work'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits the default phone at 100%', (WidgetTester tester) async {
      await pumpAllTransactions(tester, sampleSummary(), size: midPhone);
      expect(tester.takeException(), isNull);
      expect(find.text('All Transactions'), findsOneWidget);
      expect(find.text('Showing 8 transactions'), findsOneWidget);
    });
  });
}

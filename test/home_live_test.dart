// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/core/format/money.dart';
import 'package:khatabook/core/theme/app_colors.dart';
import 'package:khatabook/core/theme/app_theme.dart';
import 'package:khatabook/features/home/home_screen.dart';
import 'package:khatabook/features/home/models.dart';

/// A supplied ledger with more than four entries: only the newest four may
/// reach the preview list, and none of the seeded B1 titles may appear.
LedgerSummary liveSummary() {
  return LedgerSummary(
    openingBalancePaise: 125000,
    entries: <LedgerEntry>[
      LedgerEntry(
        title: 'Freelance Payment',
        category: 'Income',
        at: DateTime(2026, 11, 19, 18, 30),
        amountPaise: 300000,
        type: EntryType.income,
      ),
      LedgerEntry(
        title: 'Live Groceries',
        category: 'Shopping',
        at: DateTime(2026, 11, 19, 17),
        amountPaise: 45000,
      ),
      LedgerEntry(
        title: 'Live Coffee',
        category: 'Food',
        at: DateTime(2026, 11, 19, 9, 15),
        amountPaise: 8000,
      ),
      LedgerEntry(
        title: 'Live Bus Pass',
        category: 'Travel',
        at: DateTime(2026, 11, 18, 8),
        amountPaise: 12000,
      ),
      LedgerEntry(
        title: 'Live Electricity',
        category: 'Bills',
        at: DateTime(2026, 11, 17, 16, 30),
        amountPaise: 25000,
      ),
    ],
  );
}

/// A different live snapshot used to prove the widget rebuilds on new data.
LedgerSummary replacementSummary() {
  return LedgerSummary(
    openingBalancePaise: 0,
    entries: <LedgerEntry>[
      LedgerEntry(
        title: 'Replacement Salary',
        category: 'Income',
        at: DateTime(2026, 11, 19, 12),
        amountPaise: 750000,
        type: EntryType.income,
      ),
      LedgerEntry(
        title: 'Replacement Taxi',
        category: 'Travel',
        at: DateTime(2026, 11, 18, 11),
        amountPaise: 25000,
      ),
    ],
  );
}

/// Pumps the home screen as a parent would: with live data and only the
/// callbacks the parent chooses to supply.
Future<void> pumpLive(
  WidgetTester tester, {
  required LedgerSummary summary,
  VoidCallback? onAddEntry,
  VoidCallback? onViewAll,
  Size size = const Size(320, 568),
  double scale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: HomeScreen(
        summary: summary,
        onAddEntry: onAddEntry,
        onViewAll: onViewAll,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void expectNoLayoutErrors(WidgetTester tester) {
  expect(
    tester.takeException(),
    isNull,
    reason: 'live home layout must not overflow or throw',
  );
}

void main() {
  group('supplied live data', () {
    testWidgets(
      'renders supplied totals, four newest rows and no preview notice',
      (WidgetTester tester) async {
        final LedgerSummary summary = liveSummary();
        await pumpLive(tester, summary: summary);

        expect(find.text('Remaining Balance'), findsOneWidget);
        expect(find.text(formatPaise(summary.remainingPaise)), findsOneWidget);
        expect(
          find.text(formatPaise(summary.totalIncomePaise)),
          findsOneWidget,
        );
        expect(
          find.text(formatPaise(summary.totalExpensePaise)),
          findsOneWidget,
        );

        for (final String title in <String>[
          'Freelance Payment',
          'Live Groceries',
          'Live Coffee',
          'Live Bus Pass',
        ]) {
          expect(find.text(title), findsOneWidget, reason: title);
        }
        // The fifth entry and every seeded preview entry stay out of the list.
        expect(find.text('Live Electricity'), findsNothing);
        expect(find.text('Grocery Shopping'), findsNothing);
        expect(find.text('Sample ledger · preview data only'), findsNothing);
        expectNoLayoutErrors(tester);
      },
    );

    testWidgets('rebuilds figures and rows when a new summary arrives', (
      WidgetTester tester,
    ) async {
      final LedgerSummary first = liveSummary();
      final LedgerSummary second = replacementSummary();
      await pumpLive(tester, summary: first);

      expect(find.text(formatPaise(first.remainingPaise)), findsOneWidget);
      expect(find.text('Live Groceries'), findsOneWidget);

      await pumpLive(tester, summary: second);

      expect(find.text(formatPaise(first.remainingPaise)), findsNothing);
      expect(find.text('Live Groceries'), findsNothing);
      expect(find.text('Freelance Payment'), findsNothing);
      expect(find.text(formatPaise(second.remainingPaise)), findsOneWidget);
      expect(find.text(formatPaise(second.totalIncomePaise)), findsOneWidget);
      expect(
        find.text(formatPaise(second.totalExpensePaise)),
        findsNWidgets(2),
      );
      expect(find.text('Replacement Salary'), findsOneWidget);
      expect(find.text('Replacement Taxi'), findsOneWidget);
      expectNoLayoutErrors(tester);
    });

    testWidgets('an empty ledger shows a meaningful state and zero totals', (
      WidgetTester tester,
    ) async {
      const LedgerSummary empty = LedgerSummary(
        openingBalancePaise: 100000,
        entries: <LedgerEntry>[],
      );
      await pumpLive(tester, summary: empty);

      expect(find.text('Recent Transactions'), findsOneWidget);
      expect(
        find.text('No transactions yet. Add an entry to see it here.'),
        findsOneWidget,
      );
      expect(
        find.text(formatPaise(empty.remainingPaise)),
        findsNWidgets(empty.openingBalancePaise == 0 ? 3 : 2),
      );
      expect(find.text(formatPaise(empty.totalIncomePaise)), findsNWidgets(2));
      expect(find.text(formatPaise(empty.totalExpensePaise)), findsOneWidget);
      expect(
        find.text('Preview data - local ledger arrives in B2'),
        findsNothing,
      );
      expectNoLayoutErrors(tester);
    });
  });

  group('callbacks', () {
    testWidgets('the CTA and View All call their supplied handlers', (
      WidgetTester tester,
    ) async {
      int addTaps = 0;
      int viewTaps = 0;
      await pumpLive(
        tester,
        summary: liveSummary(),
        onAddEntry: () => addTaps++,
        onViewAll: () => viewTaps++,
      );

      final Finder cta = find.text('Add New Entry');
      await tester.ensureVisible(cta);
      await tester.pumpAndSettle();
      await tester.tap(cta);
      await tester.pumpAndSettle();
      expect(addTaps, 1);

      final Finder viewAll = find.text('View All');
      await tester.ensureVisible(viewAll);
      await tester.pumpAndSettle();
      await tester.tap(viewAll);
      await tester.pumpAndSettle();
      expect(viewTaps, 1);
      expectNoLayoutErrors(tester);
    });

    testWidgets('null handlers leave both controls visibly disabled', (
      WidgetTester tester,
    ) async {
      await pumpLive(tester, summary: liveSummary());

      final FilledButton addButton = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(addButton.onPressed, isNull);

      final TextButton viewButton = tester.widget<TextButton>(
        find.byType(TextButton),
      );
      expect(viewButton.onPressed, isNull);
      final Text label = tester.widget<Text>(find.text('View All'));
      expect(label.style?.color, AppColors.navigationGrey);

      // Disabled controls are inert, not fake actions that throw or navigate.
      await tester.tap(find.text('View All'));
      await tester.pumpAndSettle();
      final Finder cta = find.text('Add New Entry');
      await tester.ensureVisible(cta);
      await tester.pumpAndSettle();
      await tester.tap(cta);
      await tester.pumpAndSettle();
      expectNoLayoutErrors(tester);
    });
  });

  group('responsive live layout', () {
    testWidgets('200% text scale keeps live rows and controls reachable', (
      WidgetTester tester,
    ) async {
      final LedgerSummary summary = liveSummary();
      await pumpLive(tester, summary: summary, scale: 2.0);

      expectNoLayoutErrors(tester);
      expect(find.text(formatPaise(summary.remainingPaise)), findsOneWidget);
      expect(find.text(formatPaise(summary.totalIncomePaise)), findsOneWidget);
      expect(find.text(formatPaise(summary.totalExpensePaise)), findsOneWidget);
      for (final String title in <String>[
        'Freelance Payment',
        'Live Groceries',
        'Live Coffee',
        'Live Bus Pass',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }

      final Finder cta = find.text('Add New Entry');
      await tester.ensureVisible(cta);
      await tester.pumpAndSettle();
      expectNoLayoutErrors(tester);
    });

    testWidgets('200% text scale keeps the empty state readable', (
      WidgetTester tester,
    ) async {
      const LedgerSummary empty = LedgerSummary(
        openingBalancePaise: 0,
        entries: <LedgerEntry>[],
      );
      await pumpLive(tester, summary: empty, scale: 2.0);

      expect(
        find.text('No transactions yet. Add an entry to see it here.'),
        findsOneWidget,
      );
      expect(
        find.text(formatPaise(empty.remainingPaise)),
        findsNWidgets(empty.openingBalancePaise == 0 ? 3 : 2),
      );
      expectNoLayoutErrors(tester);
    });
  });
}

// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/core/format/money.dart';
import 'package:khatabook/core/theme/app_theme.dart';
import 'package:khatabook/features/home/home_screen.dart';
import 'package:khatabook/features/home/models.dart';

/// Sizes used by the layout tests: a small phone (320 x 568 logical px) and a
/// common mid-range device (360 x 640).
const Size smallPhone = Size(320, 568);
const Size midPhone = Size(360, 640);

/// Pumps the Home screen alone, with the real app theme, at [scale] text size.
Future<void> pumpHome(
  WidgetTester tester, {
  Size size = midPhone,
  double scale = 1.0,
  VoidCallback? onAddEntry,
  VoidCallback? onViewAll,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      // The builder override is how a test can change the text scale without
      // touching the ambient MediaQuery that MaterialApp installs.
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: HomeScreen(onAddEntry: onAddEntry, onViewAll: onViewAll),
    ),
  );
  await tester.pumpAndSettle();
}

/// Fails with the recorded exception when a layout overflows or throws.
void expectNoLayoutErrors(WidgetTester tester) {
  final Object? exception = tester.takeException();
  expect(
    exception,
    isNull,
    reason: 'layout must not overflow at this size/scale: $exception',
  );
}

void main() {
  group('seeded balance and totals', () {
    testWidgets('shows the seeded remaining, income and expense amounts', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      expect(find.text('Remaining Balance'), findsOneWidget);
      expect(find.text('₹6,420'), findsOneWidget);
      expect(find.text('Total Income'), findsOneWidget);
      expect(find.text('₹10,000'), findsOneWidget);
      expect(find.text('Total Expense'), findsOneWidget);
      expect(find.text('₹3,580'), findsOneWidget);
      expectNoLayoutErrors(tester);
    });

    testWidgets('keeps the seeded numbers identical to the model', (
      WidgetTester tester,
    ) async {
      final LedgerSummary summary = LedgerSummary(
        openingBalancePaise: kSeedOpeningBalancePaise,
        entries: kSeedEntries,
      );
      await pumpHome(tester);

      // The screen must not invent its own arithmetic: these are the same
      // strings the formatter produces for the model values.
      expect(find.text(formatPaise(summary.remainingPaise)), findsOneWidget);
      expect(find.text(formatPaise(summary.totalIncomePaise)), findsOneWidget);
      expect(find.text(formatPaise(summary.totalExpensePaise)), findsOneWidget);
    });

    testWidgets('shows Home content without a full-width brand header', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      expect(find.text('KhataBook'), findsNothing);
      expect(find.text('Plan · Track · Save'), findsNothing);
      expect(find.byIcon(Icons.settings), findsNothing);
      expect(find.text('Recent Transactions'), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);
      expect(find.text('Add New Entry'), findsOneWidget);
      expect(find.text('Sample ledger · preview data only'), findsOneWidget);
    });

    testWidgets('the Add New Entry CTA remains tappable without a header', (
      WidgetTester tester,
    ) async {
      int addTaps = 0;
      await pumpHome(tester, onAddEntry: () => addTaps++);

      expect(find.byIcon(Icons.settings), findsNothing);
      expect(find.byIcon(Icons.add), findsOneWidget);
      final Finder cta = find.text('Add New Entry');
      await tester.ensureVisible(cta);
      await tester.pumpAndSettle();
      await tester.tap(cta);
      await tester.pumpAndSettle();
      expect(addTaps, 1);
      expectNoLayoutErrors(tester);
    });
  });

  group('recent transactions', () {
    testWidgets('renders exactly the four newest seeded entries', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      for (final String title in <String>[
        'Grocery Shopping',
        'Lunch with Friends',
        'Mobile Recharge',
        'Gift for Mom',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }

      // Older entries exist in the model but must not reach the preview list.
      expect(find.text('Bus Fare'), findsNothing);
      expect(find.text('Tea with Team'), findsNothing);
    });

    testWidgets('shows the formatted timestamp and amount for a row', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      expect(find.text('19 Nov 2026, 8:30 PM'), findsOneWidget);
      expect(find.text('19 Nov 2026, 1:15 PM'), findsOneWidget);
      expect(find.text('19 Nov 2026, 10:20 AM'), findsOneWidget);
      expect(find.text('18 Nov 2026, 7:40 PM'), findsOneWidget);

      expect(find.text('₹1,200'), findsOneWidget);
      expect(find.text('₹580'), findsOneWidget);
      expect(find.text('₹199'), findsOneWidget);
      expect(find.text('₹1,000'), findsOneWidget);
    });

    testWidgets('orders rows newest first, top to bottom', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      final List<String> titles = <String>[
        'Grocery Shopping',
        'Lunch with Friends',
        'Mobile Recharge',
        'Gift for Mom',
      ];
      final List<double> tops = <double>[
        for (final String title in titles)
          tester.getTopLeft(find.text(title)).dy,
      ];

      for (int index = 1; index < tops.length; index++) {
        expect(
          tops[index],
          greaterThan(tops[index - 1]),
          reason: '${titles[index]} must sit below ${titles[index - 1]}',
        );
      }
    });

    testWidgets('every visible row shows its category icon', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      expect(
        find.byKey(const Key('category-artwork-Shopping')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('category-artwork-Food')), findsOneWidget);
      expect(find.byKey(const Key('category-artwork-Bills')), findsOneWidget);
      expect(find.byKey(const Key('category-artwork-Gifts')), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet), findsOneWidget);
    });
  });

  group('accessibility and responsive layout', () {
    testWidgets('layout is clean at the default scale on a small phone', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester, size: smallPhone);
      expectNoLayoutErrors(tester);
      expect(find.text('₹6,420'), findsOneWidget);
    });

    testWidgets('200% text scale does not overflow on a small phone', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester, size: smallPhone, scale: 2.0);

      expectNoLayoutErrors(tester);
      // Numbers stay present (they scale down inside their own boxes).
      expect(find.text('₹6,420'), findsOneWidget);
      expect(find.text('₹10,000'), findsOneWidget);
      expect(find.text('₹3,580'), findsOneWidget);
    });

    testWidgets('200% text scale does not overflow on a mid-range phone', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester, size: midPhone, scale: 2.0);
      expectNoLayoutErrors(tester);
    });

    testWidgets('200% text scale keeps the four recent rows visible', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester, size: smallPhone, scale: 2.0);

      for (final String title in <String>[
        'Grocery Shopping',
        'Lunch with Friends',
        'Mobile Recharge',
        'Gift for Mom',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(find.text('Add New Entry'), findsOneWidget);
    });

    testWidgets('the primary CTA stays visible while content scrolls at 200%', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester, size: smallPhone, scale: 2.0);

      final Finder cta = find.text('Add New Entry');
      expect(tester.getRect(cta).top, greaterThan(0));
      expect(
        tester.getRect(cta).bottom,
        lessThanOrEqualTo(smallPhone.height),
        reason: 'the primary action stays pinned above the device edge',
      );
      expect(cta.hitTestable(), findsOneWidget);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(cta.hitTestable(), findsOneWidget);
      expectNoLayoutErrors(tester);
    });

    testWidgets('summary tiles expose direction in their semantics', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpHome(tester);

      // The tile announces label, direction and amount as one node.
      expect(
        find.bySemanticsLabel(RegExp(r'Total Income, income, ₹10,000')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Total Expense, expense, ₹3,580')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Category Shopping')),
        findsOneWidget,
      );
      expect(find.byTooltip('Settings'), findsNothing);
      handle.dispose();
    });
  });
}

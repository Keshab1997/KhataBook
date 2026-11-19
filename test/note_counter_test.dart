import 'package:flutter/semantics.dart';
// Flutter 3.50 deprecates this import; migrate with the app's dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/core/theme/app_theme.dart';
import 'package:khatabook/features/counter/note_counter_screen.dart';

/// A small phone (320 x 568 logical px) and a mid-range one (360 x 640).
const Size smallPhone = Size(320, 568);
const Size midPhone = Size(360, 640);

Future<void> pumpCounter(
  WidgetTester tester, {
  Size size = midPhone,
  double scale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Deliberately NO `FlutterError.onError` override. flutter_test's binding
  // already captures framework errors (including "A RenderFlex overflowed")
  // and fails the test at teardown, so replacing the handler would hide real
  // failures and break the binding's own assertions.
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
      home: const NoteCounterScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Fails if the last frame raised a framework error.
///
/// `tester.takeException()` only *reads* the binding's pending error, so the
/// binding keeps ownership of failure reporting: an overflow reported at any
/// other point still fails the test through the normal binding path. The
/// unused return value is intentional - `expect` is the assertion.
void expectNoLayoutErrors(WidgetTester tester) {
  final Object? exception = tester.takeException();
  expect(
    exception,
    isNull,
    reason: 'the last frame raised a framework error: $exception',
  );
}

/// Taps the chip for [denominationPaise], e.g. `50000` for ₹500.
Future<void> selectDenomination(
  WidgetTester tester,
  int denominationPaise,
) async {
  await tapHittable(tester, find.byKey(Key('denomination-$denominationPaise')));
}

Future<void> tapIncrement(WidgetTester tester, {int times = 1}) async {
  for (int index = 0; index < times; index++) {
    await tapHittable(tester, find.byKey(const Key('note-counter-increment')));
  }
}

Future<void> tapDecrement(WidgetTester tester, {int times = 1}) async {
  for (int index = 0; index < times; index++) {
    await tapHittable(tester, find.byKey(const Key('note-counter-decrement')));
  }
}

/// Types [value] straight into the quantity field, replacing what is there.
Future<void> typeQuantity(WidgetTester tester, String value) async {
  final Finder field = find.byKey(const Key('note-counter-quantity-field'));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

/// The quantity currently in the text field, read from its controller.
///
/// Reading the controller avoids `find.text('0')`, which matches every zero
/// wearing text on the screen (both cards, the hint, the empty chips...).
String fieldText(WidgetTester tester) {
  final EditableText editable = tester.widget<EditableText>(
    find.descendant(
      of: find.byKey(const Key('note-counter-quantity-field')),
      matching: find.byType(EditableText),
    ),
  );
  return editable.controller.text;
}

/// Scrolls [finder] into view and asserts it can actually receive a tap.
Future<void> tapHittable(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(
    finder.hitTestable().evaluate().isNotEmpty,
    isTrue,
    reason: 'control is offscreen or covered and cannot be tapped',
  );
  await tester.tap(finder.hitTestable());
  await tester.pumpAndSettle();
}

/// The grand total card's rendered amount.
Finder grandTotalText(String formatted) => find.descendant(
  of: find.byKey(const Key('note-counter-grand-total')),
  matching: find.text(formatted),
);

/// The "Total Amount" card's rendered amount.
///
/// Anchored on the label's `Column` (the card body) and then on the card
/// `Container` above it, so the finder cannot accidentally resolve to a row
/// that merely contains the label.
Finder totalAmountText(String formatted) => find.descendant(
  of: find
      .ancestor(of: find.text('Total Amount'), matching: find.byType(Container))
      .last,
  matching: find.text(formatted),
);

void main() {
  group('initial state', () {
    testWidgets('starts empty at ₹500 with a zero grand total', (
      WidgetTester tester,
    ) async {
      await pumpCounter(tester);

      expect(find.text('Note Counter'), findsOneWidget);
      expect(find.text('Enter Quantity'), findsOneWidget);
      expect(find.text('Total Amount'), findsOneWidget);
      expect(find.text('Grand Total'), findsOneWidget);
      expect(grandTotalText('₹0'), findsOneWidget);
      // The state is explicitly not persisted - say so on screen.
      expect(
        find.text('In-memory session - nothing is saved or added to a khata'),
        findsOneWidget,
      );
    });

    testWidgets('offers ₹10 to ₹500 but not ₹2,000 by default', (
      WidgetTester tester,
    ) async {
      await pumpCounter(tester);

      for (final int denomination in <int>[
        1000,
        2000,
        5000,
        10000,
        20000,
        50000,
      ]) {
        expect(
          find.byKey(Key('denomination-$denomination')),
          findsOneWidget,
          reason: 'missing $denomination paise chip',
        );
      }
      expect(find.byKey(const Key('denomination-200000')), findsNothing);
      expect(find.text('Include ₹2,000 notes'), findsOneWidget);
    });
  });

  group('arithmetic', () {
    testWidgets('₹500 × 10 gives ₹5,000', (WidgetTester tester) async {
      await pumpCounter(tester);

      await tapIncrement(tester, times: 10);

      expect(totalAmountText('₹5,000'), findsOneWidget);
      expect(grandTotalText('₹5,000'), findsOneWidget);
      expectNoLayoutErrors(tester);
    });

    testWidgets('adding ₹100 × 5 gives a grand total of ₹5,500', (
      WidgetTester tester,
    ) async {
      await pumpCounter(tester);

      await tapIncrement(tester, times: 10); // ₹500 x 10
      await selectDenomination(tester, 10000); // ₹100
      await tapIncrement(tester, times: 5);

      // The per-denomination card follows the selection...
      expect(totalAmountText('₹500'), findsOneWidget);
      // ...while the grand total adds both counts.
      expect(grandTotalText('₹5,500'), findsOneWidget);
    });

    testWidgets('direct numeric input gives the same totals as the stepper', (
      WidgetTester tester,
    ) async {
      await pumpCounter(tester);

      await typeQuantity(tester, '10');
      expect(grandTotalText('₹5,000'), findsOneWidget);

      await selectDenomination(tester, 10000);
      await typeQuantity(tester, '5');
      expect(grandTotalText('₹5,500'), findsOneWidget);
    });

    testWidgets('small denominations multiply exactly', (
      WidgetTester tester,
    ) async {
      await pumpCounter(tester);

      await selectDenomination(tester, 1000); // ₹10
      await typeQuantity(tester, '99999');
      // 1000 x 99999 = 99999000 paise = ₹9,99,990 with Indian grouping.
      expect(grandTotalText('₹9,99,990'), findsOneWidget);
      expectNoLayoutErrors(tester);
    });
  });

  group('quantity limits', () {
    testWidgets('the maximum is 99,999 and cannot be exceeded', (
      WidgetTester tester,
    ) async {
      await pumpCounter(tester);

      await typeQuantity(tester, '999999');
      // Clamped to the documented maximum, and the field shows the clamp.
      expect(fieldText(tester), '99999');
      expect(grandTotalText('₹4,99,99,500'), findsOneWidget); // 50000 x 99999

      await tapIncrement(tester);
      expect(grandTotalText('₹4,99,99,500'), findsOneWidget);
    });

    testWidgets('decrement is disabled at zero and enabled above it', (
      WidgetTester tester,
    ) async {
      await pumpCounter(tester);

      // Tapping the disabled control must not push the count below zero.
      await tapDecrement(tester);
      expect(grandTotalText('₹0'), findsOneWidget);

      await tapIncrement(tester);
      await tapIncrement(tester);
      expect(grandTotalText('₹1,000'), findsOneWidget);

      await tapDecrement(tester);
      await tapDecrement(tester);
      await tapDecrement(tester); // one extra tap past zero
      expect(grandTotalText('₹0'), findsOneWidget);
      expectNoLayoutErrors(tester);
    });

    testWidgets('negative input is rejected with its own message', (
      WidgetTester tester,
    ) async {
      await pumpCounter(tester);
      await typeQuantity(tester, '7');
      expect(grandTotalText('₹3,500'), findsOneWidget);

      await typeQuantity(tester, '-5');

      expect(
        find.textContaining('Quantity cannot be negative'),
        findsOneWidget,
      );
      // The generic message must NOT appear: the screen has a specific one.
      expect(find.textContaining('Enter a whole number'), findsNothing);
      // Nothing was counted, so the total is still the last valid one.
      expect(grandTotalText('₹3,500'), findsOneWidget);
      expectNoLayoutErrors(tester);
    });

    testWidgets('decimal input is rejected with the generic message', (
      WidgetTester tester,
    ) async {
      await pumpCounter(tester);
      await typeQuantity(tester, '7');

      for (final String decimal in <String>['1.5', '0.5', '.5', '100.25']) {
        await typeQuantity(tester, decimal);

        expect(
          find.textContaining('Enter a whole number of notes'),
          findsOneWidget,
          reason: '"$decimal" must show the whole-number message',
        );
        expect(
          find.textContaining('Quantity cannot be negative'),
          findsNothing,
        );
        expect(
          grandTotalText('₹3,500'),
          findsOneWidget,
          reason: '"$decimal" must not alter the counted total',
        );
        expectNoLayoutErrors(tester);
      }
    });

    testWidgets('non-numeric input is rejected with the generic message', (
      WidgetTester tester,
    ) async {
      await pumpCounter(tester);
      await typeQuantity(tester, '7');

      for (final String junk in <String>['abc', '0x10', '1e3']) {
        await typeQuantity(tester, junk);

        expect(
          find.textContaining('Enter a whole number of notes'),
          findsOneWidget,
          reason: '"$junk" must show the whole-number message',
        );
        expect(
          grandTotalText('₹3,500'),
          findsOneWidget,
          reason: '"$junk" must not alter the counted total',
        );
        expectNoLayoutErrors(tester);
      }
    });

    testWidgets('whitespace is rejected, not treated as an empty field', (
      WidgetTester tester,
    ) async {
      // `' '` trims to empty, so a trimming validator would silently reset the
      // count and show no error. Whitespace is something the user typed: it
      // must be rejected and must preserve the last good count.
      await pumpCounter(tester);
      await typeQuantity(tester, '7');
      expect(grandTotalText('₹3,500'), findsOneWidget);

      for (final String whitespace in <String>[' ', '   ', ' 5', '5 ', '5 0']) {
        await typeQuantity(tester, whitespace);

        expect(
          find.textContaining('Enter a whole number of notes'),
          findsOneWidget,
          reason: '"$whitespace" must be rejected with an error',
        );
        expect(
          grandTotalText('₹3,500'),
          findsOneWidget,
          reason: '"$whitespace" must preserve the last valid count',
        );
        expectNoLayoutErrors(tester);
      }
    });

    testWidgets('only a genuinely empty field resets the count', (
      WidgetTester tester,
    ) async {
      await pumpCounter(tester);
      await typeQuantity(tester, '7');
      expect(grandTotalText('₹3,500'), findsOneWidget);

      // Empty is not an error: it means "nothing counted right now".
      await typeQuantity(tester, '');
      expect(find.textContaining('Enter a whole number'), findsNothing);
      expect(grandTotalText('₹0'), findsOneWidget);

      // A rejected value after that still shows an error and keeps the zero.
      await typeQuantity(tester, ' ');
      expect(
        find.textContaining('Enter a whole number of notes'),
        findsOneWidget,
      );
      expect(grandTotalText('₹0'), findsOneWidget);
    });

    testWidgets('a valid value clears the error and counts normally', (
      WidgetTester tester,
    ) async {
      await pumpCounter(tester);

      await typeQuantity(tester, '-5');
      expect(
        find.textContaining('Quantity cannot be negative'),
        findsOneWidget,
      );

      await typeQuantity(tester, '2');
      expect(find.textContaining('Enter a whole number'), findsNothing);
      expect(find.textContaining('Quantity cannot be negative'), findsNothing);
      expect(grandTotalText('₹1,000'), findsOneWidget);
      expect(fieldText(tester), '2');
    });

    testWidgets(
      'an overflowing digit string clamps to 99,999 and rewrites the field',
      (WidgetTester tester) async {
        // Regression: `int.tryParse` returns null for a digit string longer
        // than 64 bits. The old `?? kMaxNoteQuantity` fallback counted the
        // maximum but left the field showing the entire huge string, so the
        // visible number and the counted number disagreed.
        await pumpCounter(tester);

        final String overflowing = '9' * 30; // far beyond int64
        await typeQuantity(tester, overflowing);

        expectNoLayoutErrors(tester);
        expect(
          fieldText(tester),
          '99999',
          reason: 'the field must show the same number that is counted',
        );
        // ₹500 x 99,999 = 49,99,95,000 paise -> ₹4,99,99,500
        expect(grandTotalText('₹4,99,99,500'), findsOneWidget);
        expect(
          find.textContaining('Enter a whole number'),
          findsNothing,
          reason: 'an over-long count clamps; it is not a validation error',
        );

        // Still consistent afterwards: the stepper works from the clamp.
        await tapDecrement(tester);
        expect(fieldText(tester), '99998');
        // ₹500 x 99,998 = 49,99,90,000 paise -> ₹4,99,99,000
        expect(grandTotalText('₹4,99,99,000'), findsOneWidget);
      },
    );

    testWidgets('an empty field counts nothing rather than throwing', (
      WidgetTester tester,
    ) async {
      await pumpCounter(tester);
      await tapIncrement(tester, times: 3);
      expect(grandTotalText('₹1,500'), findsOneWidget);

      await typeQuantity(tester, '');
      expectNoLayoutErrors(tester);
      expect(grandTotalText('₹0'), findsOneWidget);
      expect(find.textContaining('Enter a whole number'), findsNothing);
    });
  });

  group('denomination switching keeps quantities', () {
    testWidgets('switching away and back restores the previous count', (
      WidgetTester tester,
    ) async {
      await pumpCounter(tester);

      await tapIncrement(tester, times: 4); // ₹500 x 4 = ₹2,000
      await selectDenomination(tester, 10000);
      await tapIncrement(tester, times: 2); // ₹100 x 2 = ₹200
      expect(grandTotalText('₹2,200'), findsOneWidget);

      await selectDenomination(tester, 50000);
      expect(totalAmountText('₹2,000'), findsOneWidget);
      expect(grandTotalText('₹2,200'), findsOneWidget);

      await selectDenomination(tester, 10000);
      expect(totalAmountText('₹200'), findsOneWidget);
      expect(grandTotalText('₹2,200'), findsOneWidget);
    });

    testWidgets('the quantity field follows the selected denomination', (
      WidgetTester tester,
    ) async {
      await pumpCounter(tester);

      await tapIncrement(tester, times: 3);
      await selectDenomination(tester, 20000);
      expect(fieldText(tester), '0');

      await selectDenomination(tester, 50000);
      expect(fieldText(tester), '3');
    });
  });

  group('₹2,000 toggle', () {
    testWidgets('showing ₹2,000 adds a chipless option that counts', (
      WidgetTester tester,
    ) async {
      await pumpCounter(tester);

      await tapHittable(
        tester,
        find.byKey(const Key('note-counter-show-2000')),
      );

      expect(find.byKey(const Key('denomination-200000')), findsOneWidget);

      await selectDenomination(tester, 200000);
      await tapIncrement(tester, times: 2);
      expect(totalAmountText('₹4,000'), findsOneWidget);
      expect(grandTotalText('₹4,000'), findsOneWidget);
      expectNoLayoutErrors(tester);
    });

    testWidgets('hiding ₹2,000 never silently drops counted notes', (
      WidgetTester tester,
    ) async {
      await pumpCounter(tester);

      await tapHittable(
        tester,
        find.byKey(const Key('note-counter-show-2000')),
      );
      await selectDenomination(tester, 200000);
      await tapIncrement(tester); // ₹2,000 x 1

      // Turn the denomination back off while it is selected.
      await tapHittable(
        tester,
        find.byKey(const Key('note-counter-show-2000')),
      );

      expect(find.byKey(const Key('denomination-200000')), findsNothing);
      // The money is still counted, and the card explains why.
      expect(grandTotalText('₹2,000'), findsOneWidget);
      expect(
        find.text('Includes ₹2,000 × 1 (denomination hidden)'),
        findsOneWidget,
      );
      expectNoLayoutErrors(tester);
    });
  });

  group('New count', () {
    testWidgets('clears every denomination, not just the selected one', (
      WidgetTester tester,
    ) async {
      await pumpCounter(tester);

      await tapIncrement(tester, times: 2); // ₹500 x 2
      await selectDenomination(tester, 10000);
      await tapIncrement(tester, times: 3); // ₹100 x 3
      expect(grandTotalText('₹1,300'), findsOneWidget);

      await typeQuantity(tester, ''); // leave the field empty mid-edit
      await tapHittable(
        tester,
        find.byKey(const Key('note-counter-new-count')),
      );

      expect(grandTotalText('₹0'), findsOneWidget);
      expect(totalAmountText('₹0'), findsOneWidget);

      // Clearing is real: switching back shows zero, not the old count.
      await selectDenomination(tester, 50000);
      expect(totalAmountText('₹0'), findsOneWidget);
      expect(fieldText(tester), '0');
    });
  });

  group('accessibility and layout', () {
    testWidgets('stepper buttons expose semantic labels', (
      WidgetTester tester,
    ) async {
      // `ensureSemantics()` promotes the accessibility tree for the test.
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpCounter(tester);

      expect(find.bySemanticsLabel('Increase quantity'), findsOneWidget);
      expect(find.bySemanticsLabel('Decrease quantity'), findsOneWidget);
      // The chip keeps its `₹` label, so it must read as "₹500 note".
      expect(find.bySemanticsLabel(RegExp(r'^₹500 note$')), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the quantity field has a real accessible name', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpCounter(tester);

      // In the *actual* semantics tree, not just a widget-level label. The
      // default selection is ₹500.
      expect(
        find.bySemanticsLabel(RegExp(r'Quantity of ₹500 notes')),
        findsOneWidget,
        reason: 'the quantity field must expose an accessible name',
      );

      // It is a text field, so the node must carry the textField flag and the
      // field's own current value.
      final SemanticsNode node = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'Quantity of ₹500 notes')),
      );
      expect(node.flagsCollection.isTextField, isTrue);

      // The name follows the selected denomination.
      await selectDenomination(tester, 10000);
      expect(
        find.bySemanticsLabel(RegExp(r'Quantity of ₹100 notes')),
        findsOneWidget,
        reason: 'the accessible name must track the selection',
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Quantity of ₹500 notes')),
        findsNothing,
      );

      handle.dispose();
    });

    testWidgets('chips are at least 44 dp tall for touch targets', (
      WidgetTester tester,
    ) async {
      await pumpCounter(tester);

      final Size chip = tester.getSize(
        find.byKey(const Key('denomination-50000')),
      );
      expect(chip.height, greaterThanOrEqualTo(44));
      expect(chip.width, greaterThanOrEqualTo(44));

      final Size button = tester.getSize(
        find.byKey(const Key('note-counter-increment')),
      );
      expect(button.height, greaterThanOrEqualTo(44));
      expect(button.width, greaterThanOrEqualTo(44));
    });

    testWidgets('layout survives a 320 dp phone at 200% text scale', (
      WidgetTester tester,
    ) async {
      await pumpCounter(tester, size: smallPhone, scale: 2.0);
      expectNoLayoutErrors(tester);

      await tapIncrement(tester, times: 10);
      await tapHittable(
        tester,
        find.byKey(const Key('note-counter-show-2000')),
      );
      expectNoLayoutErrors(tester);
    });

    testWidgets('chips stay compact and adjacent chips share a row', (
      WidgetTester tester,
    ) async {
      // Regression: an aligned `Container` inside the `Wrap` stretched each
      // chip to the full width, giving one chip per row.
      //
      // Render order is ₹500, ₹200, ₹100, ₹50, ₹20, ₹10 (largest
      // first), so ₹500 and ₹200 are adjacent - the pair that can
      // share a row. ₹500 and ₹100 sit two apart and legitimately wrap
      // apart; asserting on those was a bad test, not a bad layout.
      await pumpCounter(tester, size: smallPhone, scale: 2.0);
      expectNoLayoutErrors(tester);

      const double contentWidth = 320 - 32; // page padding on both sides

      final Rect fiveHundred = tester.getRect(
        find.byKey(const Key('denomination-50000')),
      );
      final Rect twoHundred = tester.getRect(
        find.byKey(const Key('denomination-20000')),
      );

      // Adjacent chips share a row.
      expect(
        fiveHundred.center.dy,
        closeTo(twoHundred.center.dy, 1.0),
        reason: '₹500 and ₹200 are adjacent and must share a row at 200%',
      );

      // Each chip is compact: under half the content column, still a legal
      // touch target, and two of them plus the 8 dp gap fit one row.
      final List<Rect> pair = <Rect>[fiveHundred, twoHundred];
      for (final Rect chip in pair) {
        expect(chip.width, lessThan(contentWidth / 2));
        expect(chip.width, greaterThanOrEqualTo(44));
        expect(chip.height, greaterThanOrEqualTo(44));
        expect(chip.left, greaterThanOrEqualTo(0));
        expect(chip.right, lessThanOrEqualTo(smallPhone.width));
      }
      expect(
        fiveHundred.width + twoHundred.width + 8,
        lessThanOrEqualTo(contentWidth),
      );
    });

    testWidgets('chips wrap without overflowing when text is huge', (
      WidgetTester tester,
    ) async {
      // 300% is beyond the 200% requirement but must still render: on the
      // previous revision a Run overflowed by 12 px here because the ₹2,000
      // label grew wider than the content column.
      await pumpCounter(tester, size: smallPhone, scale: 3.0);
      expectNoLayoutErrors(tester);

      // ₹2,000 is hidden by default, so it is covered by the toggle tests.
      for (final int denomination in <int>[
        50000,
        20000,
        10000,
        5000,
        2000,
        1000,
      ]) {
        final Rect chip = tester.getRect(
          find.byKey(Key('denomination-$denomination')),
        );
        expect(chip.left, greaterThanOrEqualTo(0));
        expect(chip.right, lessThanOrEqualTo(smallPhone.width));
        expect(chip.left, lessThan(smallPhone.width));
        expect(chip.height, greaterThanOrEqualTo(44));
        expect(chip.width, lessThanOrEqualTo(320 - 32));
      }

      // Chips still work at this scale.
      await selectDenomination(tester, 10000);
      expect(grandTotalText('₹0'), findsOneWidget);
      expectNoLayoutErrors(tester);
    });

    testWidgets('large totals do not overflow at 200% text scale', (
      WidgetTester tester,
    ) async {
      await pumpCounter(tester, size: smallPhone, scale: 2.0);

      await typeQuantity(tester, '99999');
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expectNoLayoutErrors(tester);
      expect(grandTotalText('₹4,99,99,500'), findsOneWidget);
    });
  });
}

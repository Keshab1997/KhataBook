// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/core/theme/app_theme.dart';
import 'package:khatabook/features/entry/add_entry_screen.dart';

void main() {
  // The redesign puts a bold caption above each framed input instead of a
  // floating `labelText`, so the fields are addressed by key.
  const Key amountField = Key('amount-field');
  const Key descriptionField = Key('description-field');

  Future<void> showForm(
    WidgetTester tester,
    List<EntryFormResult> saved, {
    int balance = 100000,
    double textScale = 1,
    Size? size,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: AddEntryScreen(openingBalancePaise: balance, onSave: saved.add),
      ),
    );
  }

  /// Scrolls [finder] to the middle of the scroll view and lets that layout
  /// settle. `WidgetController.ensureVisible` jumps the scroll offset without
  /// laying out, so anything tapped straight afterwards is hit-tested against
  /// the pre-scroll geometry - which is how the Food tile ended up under the
  /// app bar and the category stayed unselected.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, Key key, String value) async {
    await scrollTo(tester, find.byKey(key));
    await tester.enterText(find.byKey(key), value);
    await tester.pump();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    expect(finder, findsOneWidget);
    await scrollTo(tester, finder);
    // A tap that misses only prints a warning, so assert hit testing rather
    // than silencing it: the target must be the top-most widget at its centre.
    expect(
      finder.hitTestable(),
      findsOneWidget,
      reason: '$finder is not hittable after scrolling it into view.',
    );
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  String labelOf(WidgetTester tester, Finder finder) =>
      tester.getSemantics(finder).getSemanticsData().label;

  testWidgets('validates amount, category and description inline', (
    tester,
  ) async {
    final List<EntryFormResult> saved = <EntryFormResult>[];
    await showForm(tester, saved);
    await tapVisible(tester, find.text('Save Entry'));
    expect(saved, isEmpty);
    expect(find.text('Enter a valid amount'), findsOneWidget);
    expect(find.text('Pick a category'), findsOneWidget);

    for (final String invalid in <String>[
      '0',
      '0.00',
      '-1',
      '1.234',
      '1000000000',
      '1.',
      'abc',
    ]) {
      await enter(tester, amountField, invalid);
      await tapVisible(tester, find.text('Save Entry'));
      expect(saved, isEmpty, reason: 'Rejected amount: $invalid');
      expect(find.text('Enter a valid amount'), findsOneWidget);
    }

    await enter(tester, amountField, '1.25');
    await tapVisible(tester, find.text('Food'));
    await enter(tester, descriptionField, 'x' * 121);
    await tapVisible(tester, find.text('Save Entry'));
    expect(
      find.text('Description must be 120 characters or fewer'),
      findsOneWidget,
    );
    expect(saved, isEmpty);
    await enter(tester, descriptionField, 'x' * 120);
    await tapVisible(tester, find.text('Save Entry'));
    expect(saved, hasLength(1));
    expect(saved.single.description, 'x' * 120);
  });

  testWidgets(
    'expense preview and callback use exact paise and selected category',
    (tester) async {
      final List<EntryFormResult> saved = <EntryFormResult>[];
      await showForm(tester, saved);
      await enter(tester, amountField, '999999999.99');
      expect(find.text('After saving: -₹99,99,98,999.99'), findsOneWidget);
      await enter(tester, amountField, '12.05');
      expect(find.text('After saving: ₹987.95'), findsOneWidget);
      await tapVisible(tester, find.text('Gifts'));
      await enter(tester, descriptionField, 'A gift');
      await tapVisible(tester, find.text('Save Entry'));
      expect(saved, hasLength(1));
      expect(saved.single.kind, EntryFormKind.expense);
      expect(saved.single.amountPaise, 1205);
      expect(saved.single.category, 'Gifts');
      expect(saved.single.description, 'A gift');
      final DateTime now = DateTime.now();
      expect(saved.single.occurredAt, DateTime(now.year, now.month, now.day));
      await tapVisible(tester, find.text('Save Entry'));
      expect(saved, hasLength(2));
    },
  );

  testWidgets('income needs no category and updates balance live', (
    tester,
  ) async {
    final List<EntryFormResult> saved = <EntryFormResult>[];
    await showForm(tester, saved, balance: -100);
    await enter(tester, amountField, '0.5');
    await tapVisible(tester, find.text('Income'));
    expect(find.text('Category: Income'), findsOneWidget);
    expect(find.text('After saving: -₹0.50'), findsOneWidget);
    await tapVisible(tester, find.text('Save Entry'));
    expect(saved, hasLength(1));
    expect(saved.single.kind, EntryFormKind.income);
    expect(saved.single.amountPaise, 50);
    expect(saved.single.category, 'Income');
    expect(saved.single.description, isEmpty);
  });

  testWidgets('a future date is warned about but can be saved', (tester) async {
    final List<EntryFormResult> saved = <EntryFormResult>[];
    await showForm(tester, saved);
    await enter(tester, amountField, '1');
    await tapVisible(tester, find.text('Food'));
    await tapVisible(tester, find.byIcon(Icons.calendar_today));
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('This date is in the future.'), findsOneWidget);
    await tapVisible(tester, find.text('Save Entry'));
    expect(saved, hasLength(1));
    final DateTime now = DateTime.now();
    final DateTime expected = DateTime(now.year, now.month + 1, 15);
    expect(saved.single.occurredAt, expected);
    // Proves the Food tap registered: a missed tap leaves the category unset
    // and save returns no result at all.
    expect(saved.single.category, 'Food');
    expect(saved.single.amountPaise, 100);
  });

  testWidgets('exposes field labels and selected state', (tester) async {
    // Semantics has to be enabled for the tree to be inspectable; the handle
    // is disposed when the test ends.
    final SemanticsHandle semantics = tester.ensureSemantics();
    final List<EntryFormResult> saved = <EntryFormResult>[];
    await showForm(tester, saved);

    // The captions above the frames are their own Texts, so each field also
    // names itself for a screen reader.
    expect(labelOf(tester, find.byKey(amountField)), contains('Amount'));
    expect(
      labelOf(tester, find.byKey(descriptionField)),
      contains('Description'),
    );

    // Expense is the default; both segments are buttons that report selection.
    expect(
      tester.getSemantics(find.text('Expense')),
      isSemantics(label: 'Expense', isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('Income')),
      isSemantics(label: 'Income', isButton: true, isSelected: false),
    );

    // Category tiles expose the same state.
    expect(
      tester.getSemantics(find.text('Shopping')),
      isSemantics(label: 'Shopping', isSelected: false),
    );
    await tapVisible(tester, find.text('Food'));
    expect(
      tester.getSemantics(find.text('Food')),
      isSemantics(label: 'Food', isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('Shopping')),
      isSemantics(label: 'Shopping', isSelected: false),
    );

    await tapVisible(tester, find.text('Income'));
    expect(
      tester.getSemantics(find.text('Income')),
      isSemantics(label: 'Income', isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('Expense')),
      isSemantics(label: 'Expense', isSelected: false),
    );
    semantics.dispose();
  });

  testWidgets('renders the notebook illustration and the design chrome', (
    tester,
  ) async {
    final List<EntryFormResult> saved = <EntryFormResult>[];
    await showForm(tester, saved, size: const Size(390, 844));
    expect(find.text('Add Entry'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    // The asset is registered by the shared-surface change; until then (and in
    // a stripped build) the screen falls back to a drawn notebook.
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stays usable at 200% text scale', (tester) async {
    final List<EntryFormResult> saved = <EntryFormResult>[];
    await showForm(tester, saved, textScale: 2, size: const Size(390, 844));
    expect(find.text('Save Entry'), findsOneWidget);
    await enter(tester, amountField, '12.05');
    await tapVisible(tester, find.text('Food'));
    expect(find.text('After saving: ₹987.95'), findsOneWidget);
    await tapVisible(tester, find.text('Save Entry'));
    expect(saved, hasLength(1));
    expect(saved.single.amountPaise, 1205);
    expect(saved.single.category, 'Food');
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out on a 320px wide screen without overflow', (
    tester,
  ) async {
    final List<EntryFormResult> saved = <EntryFormResult>[];
    await showForm(tester, saved, size: const Size(320, 640));
    expect(find.text('Shopping'), findsOneWidget);
    expect(find.text('Save Entry'), findsOneWidget);
    await enter(tester, amountField, '0.5');
    await tapVisible(tester, find.text('Income'));
    expect(find.text('Category: Income'), findsOneWidget);
    await tapVisible(tester, find.text('Save Entry'));
    expect(saved, hasLength(1));
    expect(saved.single.amountPaise, 50);
    expect(tester.takeException(), isNull);
  });
}

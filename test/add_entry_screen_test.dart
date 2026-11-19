import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/core/theme/app_theme.dart';
import 'package:khatabook/features/entry/add_entry_screen.dart';

void main() {
  Future<void> showForm(
    WidgetTester tester,
    List<EntryFormResult> saved, {
    int balance = 100000,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AddEntryScreen(openingBalancePaise: balance, onSave: saved.add),
      ),
    );
  }

  Finder field(String label) => find.ancestor(
    of: find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField && widget.decoration?.labelText == label,
    ),
    matching: find.byType(TextFormField),
  );

  Future<void> enter(WidgetTester tester, String label, String value) async {
    await tester.ensureVisible(field(label));
    await tester.enterText(field(label), value);
    await tester.pump();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

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
      await enter(tester, 'Amount', invalid);
      await tapVisible(tester, find.text('Save Entry'));
      expect(saved, isEmpty, reason: 'Rejected amount: $invalid');
      expect(find.text('Enter a valid amount'), findsOneWidget);
    }

    await enter(tester, 'Amount', '1.25');
    await tapVisible(tester, find.text('Food'));
    await enter(tester, 'Description (optional)', 'x' * 121);
    await tapVisible(tester, find.text('Save Entry'));
    expect(
      find.text('Description must be 120 characters or fewer'),
      findsOneWidget,
    );
    expect(saved, isEmpty);
    await enter(tester, 'Description (optional)', 'x' * 120);
    await tapVisible(tester, find.text('Save Entry'));
    expect(saved, hasLength(1));
    expect(saved.single.description, 'x' * 120);
  });

  testWidgets(
    'expense preview and callback use exact paise and selected category',
    (tester) async {
      final List<EntryFormResult> saved = <EntryFormResult>[];
      await showForm(tester, saved);
      await enter(tester, 'Amount', '999999999.99');
      expect(find.text('After saving: -₹99,99,98,999.99'), findsOneWidget);
      await enter(tester, 'Amount', '12.05');
      expect(find.text('After saving: ₹987.95'), findsOneWidget);
      await tapVisible(tester, find.text('Gifts'));
      await enter(tester, 'Description (optional)', 'A gift');
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
    await enter(tester, 'Amount', '0.5');
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
    await enter(tester, 'Amount', '1');
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
  });
}

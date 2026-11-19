// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/app.dart';
import 'package:khatabook/features/ledger/data/local_ledger.dart';

void main() {
  testWidgets('create and switch khatas keep entries and balances isolated', (
    tester,
  ) async {
    final ledger = LocalLedger(NativeDatabase.memory());
    await tester.runAsync(() => ledger.initialize());
    await tester.pumpWidget(KhataBookApp(ledger: ledger));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('switch-khata')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('switch-khata')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('new-khata')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new-khata')).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const Key('new-khata')).hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('khata-name')), 'Business');
    await tester.enterText(find.byKey(const Key('khata-opening')), '100.50');
    await tester.tap(find.byKey(const Key('create-khata')));
    await tester.pumpAndSettle();
    expect(find.text('Business'), findsOneWidget);
    expect(find.text('₹100.50'), findsWidgets);
    await tester.ensureVisible(find.text('Add New Entry'));
    await tester.tap(find.text('Add New Entry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount-field')), '20');
    await tester.tap(find.text('Food'));
    await tester.ensureVisible(find.byKey(const Key('description-field')));
    await tester.enterText(
      find.byKey(const Key('description-field')),
      'Business lunch',
    );
    await tester.ensureVisible(find.text('Save Entry'));
    await tester.pumpAndSettle();
    expect(find.text('Save Entry').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Save Entry').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Business lunch'), findsOneWidget);
    expect(find.text('₹80.50'), findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('switch-khata')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('switch-khata')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('khata-personal')));
    await tester.pumpAndSettle();
    expect(find.text('Business lunch'), findsNothing);
    expect(find.text('Personal Khata'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('switch-khata')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('switch-khata')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Business').last);
    await tester.pumpAndSettle();
    expect(find.text('Business lunch'), findsOneWidget);
    expect(find.text('₹80.50'), findsWidgets);
  });

  testWidgets('invalid opening and empty name do not create a khata', (
    tester,
  ) async {
    final ledger = LocalLedger(NativeDatabase.memory());
    await tester.runAsync(() => ledger.initialize());
    await tester.pumpWidget(KhataBookApp(ledger: ledger));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('switch-khata')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('switch-khata')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('new-khata')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new-khata')).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const Key('new-khata')).hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('khata-opening')), '-1');
    await tester.tap(find.byKey(const Key('create-khata')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name of up to 40 characters'), findsOneWidget);
    expect(find.text('Enter 0 to 999999999.99'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('switch-khata')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('khata-personal')), findsOneWidget);
    expect(find.text('New Khata'), findsOneWidget);
  });
  testWidgets('switcher and create form fit a small phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final ledger = LocalLedger(NativeDatabase.memory());
    await tester.runAsync(() => ledger.initialize());
    await tester.pumpWidget(KhataBookApp(ledger: ledger));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('switch-khata')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('switch-khata')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('new-khata')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new-khata')).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const Key('new-khata')).hitTestable());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('khata-name')), findsOneWidget);
    expect(find.byKey(const Key('khata-opening')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('khata-name')), 'Shop');
    await tester.ensureVisible(find.byKey(const Key('create-khata')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-khata')).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const Key('create-khata')).hitTestable());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Shop'), findsOneWidget);
  });
}

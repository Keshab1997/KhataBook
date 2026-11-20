// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/features/calculator/calculator_screen.dart';
import 'package:khatabook/features/counter/note_counter_screen.dart';
import 'package:khatabook/features/profile/settings_screen.dart';

void main() {
  for (final Widget screen in <Widget>[
    const CalculatorScreen(),
    const NoteCounterScreen(),
  ]) {
    testWidgets('${screen.runtimeType} settings gear opens and returns', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(screen.runtimeType), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

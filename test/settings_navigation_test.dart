// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/features/counter/note_counter_screen.dart';

void main() {
  testWidgets('the full-screen counter has no settings app bar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: NoteCounterScreen()));
    expect(find.byType(AppBar), findsNothing);
    expect(find.byTooltip('Settings'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

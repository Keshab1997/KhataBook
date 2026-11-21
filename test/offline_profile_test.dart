import 'package:drift/native.dart';
// Flutter 3.50 deprecates this import; migrate with the app's dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/core/l10n/app_strings.dart';
import 'package:khatabook/features/ledger/data/local_ledger.dart';
import 'package:khatabook/features/profile/profile_screen.dart';
import 'package:khatabook/features/profile/profile_store.dart';
import 'package:khatabook/features/profile/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile forwards language and callback to settings', (
    tester,
  ) async {
    Future<bool> change(AppLanguage language) async => true;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          language: AppLanguage.bn,
          onLanguageChanged: change,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('profile-app-settings-gear')));
    await tester.pumpAndSettle();
    final settings = tester.widget<SettingsScreen>(find.byType(SettingsScreen));
    expect(settings.language, AppLanguage.bn);
    expect(settings.onLanguageChanged, same(change));
  });

  test('name persists in the same local database', () async {
    final ledger = LocalLedger(NativeDatabase.memory());
    addTearDown(ledger.close);
    final first = ProfileStore(ledger);
    await first.save(LocalProfile(name: '  বাংলা  '));
    final second = ProfileStore(ledger);
    expect((await second.load()).name, 'বাংলা');
  });

  testWidgets('Bengali profile shows localized offline and menu copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: ProfileScreen(language: AppLanguage.bn)),
    );
    expect(find.text('ইন্টারনেট ছাড়াই চলে'), findsOneWidget);
    expect(find.text('অ্যাপ সেটিংস'), findsOneWidget);
    expect(find.text('খাতাবুক সম্পর্কে'), findsOneWidget);
    // The profile asserts no sign-in state it cannot know, in Bengali too.
    expect(find.text('সাইন ইন করা হয়নি'), findsNothing);
    expect(find.textContaining('কিছু আপলোড হয় না'), findsNothing);
  });

  testWidgets('editable identity card stays neutral about account state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Open outside the fake-async zone, as the other database widget tests
    // do, or the card's load future can never complete.
    final ledger = LocalLedger(NativeDatabase.memory());
    await tester.runAsync(ledger.initialize);
    addTearDown(() => tester.runAsync(ledger.close));
    await tester.pumpWidget(
      MaterialApp(home: ProfileScreen(profileStore: ProfileStore(ledger))),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-identity-card')), findsOneWidget);
    expect(find.text('On this device'), findsOneWidget);
    expect(find.text('Not signed in'), findsNothing);
    expect(find.textContaining('nothing is uploaded'), findsNothing);
    expect(find.textContaining('open Cloud Backup below'), findsOneWidget);
    // Editing still works against the real local store.
    expect(find.text('Edit name'), findsOneWidget);
    expect(find.text('Choose photo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

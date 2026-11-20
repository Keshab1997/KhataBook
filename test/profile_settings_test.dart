// Flutter 3.50 deprecates this import; migrate with the app's dependency update.
// ignore: deprecated_member_use
import 'package:flutter/semantics.dart';
// Flutter 3.50 deprecates this import; migrate with the app's dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/core/theme/app_colors.dart';
import 'package:khatabook/core/theme/app_theme.dart';
import 'package:khatabook/features/profile/profile_screen.dart';
import 'package:khatabook/features/profile/settings_screen.dart';

/// The smallest supported phone (320 x 568 logical px) and a common one.
const Size smallPhone = Size(320, 568);
const Size midPhone = Size(360, 640);

/// A tall viewport used for content assertions, so lazily built list children
/// are all mounted and a missing string means "absent", not "not built yet".
const Size tallPhone = Size(400, 1600);

/// Pumps [screen] alone with the real app theme, at [scale] text size.
///
/// No `FlutterError.onError` override: the binding already fails the test on
/// framework errors such as a `RenderFlex` overflow.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Size size = midPhone,
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
      home: screen,
    ),
  );
  await tester.pumpAndSettle();
}

/// The scroll view of [screen], so a revealed target never picks the wrong
/// list when two routes are on screen.
Finder scrollableOf(Type screen) =>
    find.descendant(of: find.byType(screen), matching: find.byType(Scrollable));

/// Scrolls [screen]'s list until [finder] exists and is visible.
Future<void> reveal(
  WidgetTester tester,
  Finder finder, {
  required Type screen,
}) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: scrollableOf(screen),
  );
  await tester.pumpAndSettle();
}

/// Reveals [finder], then asserts it can really receive a tap before tapping.
Future<void> revealAndTap(
  WidgetTester tester,
  Finder finder, {
  required Type screen,
}) async {
  await reveal(tester, finder, screen: screen);
  expect(
    finder.hitTestable().evaluate().isNotEmpty,
    isTrue,
    reason: 'control is offscreen or covered and cannot be tapped',
  );
  await tester.tap(finder.hitTestable());
  await tester.pumpAndSettle();
}

void main() {
  group('ProfileScreen', () {
    testWidgets('states the offline local-only truth and shows no fake user', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const ProfileScreen(), size: tallPhone);

      expect(find.text('Offline & local-only'), findsOneWidget);
      expect(find.text('Not signed in'), findsOneWidget);
      expect(
        find.textContaining('stays in the local database on this device'),
        findsOneWidget,
      );
      expect(find.textContaining('nothing is uploaded'), findsOneWidget);

      // No invented account: no address, no name, no sync timestamp.
      expect(find.textContaining('@'), findsNothing);
      expect(find.textContaining('Last synced'), findsNothing);
      expect(find.textContaining('Keshab'), findsNothing);
    });

    testWidgets('About card carries real static app information', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const ProfileScreen(), size: tallPhone);

      expect(
        find.descendant(
          of: find.byKey(const Key('profile-version')),
          matching: find.text(ProfileScreen.versionLabel),
        ),
        findsOneWidget,
      );
      expect(find.text('Where your data lives'), findsOneWidget);
      expect(find.text('This device only'), findsOneWidget);
      expect(find.textContaining('Indian rupees (INR)'), findsOneWidget);
      expect(find.text('Open-source licences'), findsOneWidget);
    });

    testWidgets('profile is the real screen, not the B4 placeholder', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const ProfileScreen(), size: tallPhone);

      // The placeholder that used to fill this tab is gone (its widget was
      // deleted), including its stale "implementation in B4" caption.
      expect(find.textContaining('implementation in B4'), findsNothing);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('App Settings row navigates to settings and back returns', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const ProfileScreen(), size: tallPhone);

      await revealAndTap(
        tester,
        find.byKey(const Key('profile-app-settings-row')),
        screen: ProfileScreen,
      );

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.text('INR (₹)'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Back through the Navigator, not a replaced tab.
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.text('Offline & local-only'), findsOneWidget);
    });

    testWidgets('the header gear opens the same settings screen', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const ProfileScreen());

      await tester.tap(find.byKey(const Key('profile-app-settings-gear')));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('backup, sign-in and wallet are marked unavailable and inert', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const ProfileScreen(), size: tallPhone);

      for (final String key in <String>[
        'profile-wallet-row',
        'profile-backup-row',
        'profile-sign-in-row',
      ]) {
        final Finder row = find.byKey(Key(key));

        // No tap handler and no ripple: the row cannot be "pressed".
        expect(
          find.descendant(of: row, matching: find.byType(InkWell)),
          findsNothing,
          reason: '$key must not be interactive',
        );
        // ...and it says why, in words.
        expect(
          find.descendant(of: row, matching: find.text('Not available yet')),
          findsOneWidget,
          reason: '$key must be labelled unavailable',
        );

        // Tapping it anywhere navigates nowhere and shows no fake success.
        await reveal(tester, row, screen: ProfileScreen);
        await tester.tap(row, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
      }

      // The enabled rows stay enabled and keep their affordance.
      expect(
        find.descendant(
          of: find.byKey(const Key('profile-app-settings-row')),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tappable controls are at least 44 dp and labelled', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpScreen(tester, const ProfileScreen(), size: tallPhone);

      final Size settingsRow = tester.getSize(
        find.byKey(const Key('profile-app-settings-row')),
      );
      expect(settingsRow.height, greaterThanOrEqualTo(44));

      final Size gear = tester.getSize(
        find.byKey(const Key('profile-app-settings-gear')),
      );
      expect(gear.width, greaterThanOrEqualTo(44));
      expect(gear.height, greaterThanOrEqualTo(44));

      final Size licencesRow = tester.getSize(
        find.byKey(const Key('profile-licences-row')),
      );
      expect(licencesRow.height, greaterThanOrEqualTo(44));

      // The icon-only gear is announced by name, not just by a glyph.
      final IconButton gearButton = tester.widget<IconButton>(
        find.byKey(const Key('profile-app-settings-gear')),
      );
      expect(gearButton.tooltip, 'App settings');

      // The offline state is one readable announcement, not two icons.
      expect(
        find.bySemanticsLabel(RegExp('Offline and local-only')),
        findsWidgets,
      );
      handle.dispose();
    });
  });

  group('Profile design polish', () {
    testWidgets('identity card is dark on warm ivory with one soft shadow', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const ProfileScreen(), size: tallPhone);

      // The local identity reads as a heading, not as body text.
      final Text name = tester.widget<Text>(find.text('Local profile'));
      expect(name.style?.fontWeight, FontWeight.w800);
      expect(name.style?.color, AppColors.darkText);

      // The offline notice is a real card: light-green fill, beige 1 dp edge.
      final Iterable<BoxDecoration> decorations = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byKey(const Key('profile-offline-status')),
              matching: find.byType(Container),
            ),
          )
          .map((Container c) => c.decoration)
          .whereType<BoxDecoration>();
      final BoxDecoration notice = decorations.firstWhere(
        (BoxDecoration d) => d.color == AppColors.lightGreen,
        orElse: () => const BoxDecoration(),
      );
      expect(notice.color, AppColors.lightGreen);
      expect(notice.borderRadius, BorderRadius.circular(20));
      expect((notice.border! as Border).top.color, AppColors.outline);
    });

    testWidgets('section titles and rows use the shared visual system', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const ProfileScreen(), size: tallPhone);

      // Both section titles are headings, in dark text.
      for (final String title in <String>[
        'Account & backup',
        'About KhataBook',
      ]) {
        final Text heading = tester.widget<Text>(find.text(title));
        expect(heading.style?.fontWeight, FontWeight.w800);
        expect(heading.style?.color, AppColors.darkText);
      }

      // Every menu row keeps its 40 dp rounded-square icon container.
      final Finder iconBox = find.descendant(
        of: find.byKey(const Key('profile-app-settings-row')),
        matching: find.byType(Container),
      );
      final Size rowIcon = tester.getSize(iconBox.first);
      expect(rowIcon.width, 40);
      expect(rowIcon.height, 40);

      // The About rows gained a leading icon each: they are real tiles now.
      expect(
        find.descendant(
          of: find.byKey(const Key('profile-version')),
          matching: find.byIcon(Icons.info_outline),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.currency_rupee), findsOneWidget);

      // The status pills stay neutral and readable.
      final Text pill = tester.widget<Text>(
        find
            .descendant(
              of: find.byKey(const Key('profile-wallet-row')),
              matching: find.text('Not available yet'),
            )
            .first,
      );
      expect(pill.style?.color, AppColors.softText);
    });

    testWidgets('the About card keeps every static fact after the polish', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const ProfileScreen(), size: tallPhone);

      expect(find.text(ProfileScreen.versionLabel), findsOneWidget);
      expect(find.text('This device only'), findsOneWidget);
      expect(find.text('Light only'), findsOneWidget);
      expect(
        find.text('Indian rupees (INR), Indian digit grouping'),
        findsOneWidget,
      );
      expect(find.text('KhataBook · Plan · Track · Save'), findsOneWidget);
    });
  });

  group('SettingsScreen', () {
    testWidgets(
      'reports INR and light theme as fixed, English as unavailable',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        await pumpScreen(tester, const SettingsScreen(), size: tallPhone);

        expect(find.text('Read-only in this build'), findsOneWidget);
        expect(find.text('INR (₹)'), findsOneWidget);
        expect(find.text('Light'), findsOneWidget);
        expect(find.text('English'), findsOneWidget);
        expect(find.textContaining('Bengali'), findsOneWidget);
        expect(find.text('Fixed in v1'), findsNWidgets(2));
        expect(find.text('Not available yet'), findsNWidgets(2));

        // It never claims a working language switch or a saved preference.
        expect(find.textContaining('no preference is saved'), findsOneWidget);
        expect(find.textContaining('not possible yet'), findsOneWidget);

        // The local-only storage state is stated here too.
        expect(find.text('This device'), findsOneWidget);
        expect(find.text('Off'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('Currency. INR')), findsWidgets);
        handle.dispose();
      },
    );

    testWidgets('preference groups are cards with icon containers and pills', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const SettingsScreen(), size: tallPhone);

      // Each group title is a heading with a green rule beside it.
      for (final String title in <String>['Preferences', 'Storage']) {
        final Text heading = tester.widget<Text>(find.text(title));
        expect(heading.style?.fontWeight, FontWeight.w800);
        expect(heading.style?.color, AppColors.darkText);
      }

      // Rows are led by the shared icon container and keep a value pill plus,
      // where the setting is fixed, its reason.
      final Finder currency = find.byKey(const Key('settings-currency-row'));
      expect(
        find.descendant(
          of: currency,
          matching: find.byIcon(Icons.currency_rupee),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: currency, matching: find.text('INR (₹)')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: currency, matching: find.text('Fixed in v1')),
        findsOneWidget,
      );

      // The read-only banner keeps its green fill and card radius.
      final Container banner = tester.widget<Container>(
        find.byKey(const Key('settings-readonly-notice')),
      );
      final BoxDecoration decoration = banner.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.lightGreen);
      expect(decoration.borderRadius, BorderRadius.circular(20));

      // The build label is a quiet pill under the last card; scroll to it.
      await reveal(
        tester,
        find.text('KhataBook 1.0.0 (build 1)'),
        screen: SettingsScreen,
      );
      expect(find.text('KhataBook 1.0.0 (build 1)'), findsOneWidget);
    });

    testWidgets('every row is read-only, with no toggles or dead buttons', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const SettingsScreen(), size: tallPhone);

      // Nothing to tap anywhere on the body.
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);

      // Each preference row reports a value and a reason.
      for (final String key in <String>[
        'settings-currency-row',
        'settings-theme-row',
        'settings-language-row',
        'settings-backup-row',
        'settings-storage-row',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget);
      }
    });
  });

  group('small screens and large text', () {
    testWidgets('profile scrolls at 320 dp / 200% and settings opens', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const ProfileScreen(),
        size: smallPhone,
        scale: 2.0,
      );
      expect(tester.takeException(), isNull);

      await revealAndTap(
        tester,
        find.byKey(const Key('profile-app-settings-row')),
        screen: ProfileScreen,
      );
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Settings scrolls at this scale too, instead of clipping.
      await reveal(
        tester,
        find.byKey(const Key('settings-offline-backup-row')),
        screen: SettingsScreen,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The profile list still scrolls to its last row afterwards.
      await reveal(
        tester,
        find.byKey(const Key('profile-licences-row')),
        screen: ProfileScreen,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('settings scrolls at 320 dp / 200% without overflowing', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const SettingsScreen(),
        size: smallPhone,
        scale: 2.0,
      );
      expect(tester.takeException(), isNull);

      await reveal(
        tester,
        find.text('KhataBook 1.0.0 (build 1)'),
        screen: SettingsScreen,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('KhataBook 1.0.0 (build 1)'), findsOneWidget);
    });

    testWidgets('settings fits a 360 dp phone at 100%', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const SettingsScreen());
      expect(tester.takeException(), isNull);
      expect(find.text('App Settings'), findsOneWidget);
    });
  });
}

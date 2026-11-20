import 'dart:async';

// Flutter 3.50 deprecates this import; migrate with the app's dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/core/l10n/app_strings.dart' show AppLanguage;
import 'package:khatabook/core/theme/app_theme.dart';
import 'package:khatabook/features/sync/cloud_backend.dart';
import 'package:khatabook/features/sync/sign_in_screen.dart';

import 'support/fake_cloud_backend.dart';

Future<void> _pumpSignIn(
  WidgetTester tester,
  SignInScreen screen, {
  Size size = const Size(360, 720),
  double textScale = 1.0,
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
          data: media.copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: screen,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('SignInScreen (S11)', () {
    testWidgets(
      'explains optional cloud backup and local data staying on phone, handles progress, cancel, error, and success',
      (WidgetTester tester) async {
        final FakeCloudBackend backend = FakeCloudBackend();
        CloudUser? signedInUser;

        final Completer<CloudUser?> pendingSignIn = Completer<CloudUser?>();
        backend.onSignInWithGoogle = () => pendingSignIn.future;

        await _pumpSignIn(
          tester,
          SignInScreen(
            backend: backend,
            onSignedIn: (CloudUser u) => signedInUser = u,
          ),
        );

        expect(find.text('Optional Cloud Backup'), findsOneWidget);
        expect(find.text('Local data stays on this phone'), findsOneWidget);
        expect(find.text('Continue with Google'), findsOneWidget);

        // Start sign-in -> shows inline progress and disables duplicate tap.
        await tester.tap(find.byKey(const Key('continue-with-google-button')));
        await tester.pump();
        expect(find.byKey(const Key('sign-in-progress')), findsOneWidget);
        expect(find.text('Signing in…'), findsOneWidget);

        // 1. User cancels Google picker -> null returned, cancel notice shown.
        pendingSignIn.complete(null);
        await tester.pumpAndSettle();
        expect(signedInUser, isNull);
        expect(
          find.text('Sign-in cancelled. Your local data is untouched.'),
          findsOneWidget,
        );

        // 2. Backend throws an error -> error banner shown.
        backend.onSignInWithGoogle = () async =>
            throw Exception('OAuth provider unavailable');
        await tester.tap(find.byKey(const Key('continue-with-google-button')));
        await tester.pumpAndSettle();
        expect(
          find.text('Could not sign in with Google. Please try again.'),
          findsOneWidget,
        );
        expect(find.text('OAuth provider unavailable'), findsOneWidget);

        // 3. Successful Google sign-in -> returns CloudUser.
        final CloudUser alice = CloudUser(
          id: 'u-alice',
          email: 'alice@example.com',
        );
        backend.onSignInWithGoogle = () async => alice;
        await tester.tap(find.byKey(const Key('continue-with-google-button')));
        await tester.pumpAndSettle();
        expect(signedInUser, alice);
        expect(backend.currentUser, alice);

        await backend.dispose();
      },
    );

    testWidgets('renders Bengali copy cleanly at 320dp and 200% text scale', (
      WidgetTester tester,
    ) async {
      final FakeCloudBackend backend = FakeCloudBackend();
      backend.onSignInWithGoogle = () async => null;

      await _pumpSignIn(
        tester,
        SignInScreen(backend: backend, language: AppLanguage.bn),
        size: const Size(320, 640),
        textScale: 2.0,
      );

      expect(find.text('ঐচ্ছিক ক্লাউড ব্যাকআপ'), findsOneWidget);
      expect(find.text('স্থানীয় তথ্য এই ফোনেই থাকে'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('continue-with-google-button')),
        120,
      );
      await tester.tap(find.byKey(const Key('continue-with-google-button')));
      await tester.pumpAndSettle();

      expect(
        find.text('সাইন ইন বাতিল করা হয়েছে। আপনার ফোনের তথ্য অক্ষত আছে।'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await backend.dispose();
    });
  });
}

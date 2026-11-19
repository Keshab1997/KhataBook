import 'dart:async';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/core/l10n/app_strings.dart';
import 'package:khatabook/features/calculator/calculator_screen.dart';
import 'package:khatabook/features/profile/backup_screen.dart';

void main() {
  testWidgets('Bengali calculator keeps expressions editable and numeric', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(home: CalculatorScreen(language: AppLanguage.bn)),
    );
    expect(find.text('ক্যালকুলেটর'), findsOneWidget);
    for (final key in ['8', '÷', '0', '=']) {
      await t.tap(find.byKey(Key('calc-key-$key')));
      await t.pump();
    }
    expect(find.text('8 ÷ 0'), findsOneWidget);
    expect(find.text(AppString.divideByZero.bn), findsOneWidget);
    await t.tap(find.byTooltip(AppString.backspace.bn));
    await t.pump();
    expect(find.text('8 ÷'), findsOneWidget);
  });

  testWidgets('Bengali backup protects pending work and confirms replacement', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(320, 640);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    const preview = BackupPreview(
      payload: 'PRIVATE_JSON',
      khataCount: 2,
      transactionCount: 4,
      deletedTransactionCount: 1,
    );
    final exporting = Completer<BackupExportResult>();
    var restores = 0;
    bool? restored;
    final screen = BackupScreen(
      language: AppLanguage.bn,
      onExport: () => exporting.future,
      onPickBackup: () async => preview,
      onRestore: (snapshot) async {
        expect(snapshot, same(preview));
        if (++restores == 1) throw StateError(preview.payload);
        return true;
      },
    );
    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Open'),
              onPressed: () async {
                restored = await Navigator.of(context)
                    .push<bool>(MaterialPageRoute(builder: (_) => screen));
              },
            ),
          ),
        ),
      ),
    );
    Future<void> tap(AppString key) async {
      final target = find.text(key.bn);
      await t.ensureVisible(target);
      await t.tap(target);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
    }

    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(find.text(AppString.backupPrivacy.bn), findsOneWidget);
    await tap(AppString.exportBackup);
    await t.binding.handlePopRoute();
    await t.pump();
    expect(find.text(AppString.exportingBackup.bn), findsOneWidget);
    exporting.complete(BackupExportResult.cancelled);
    await t.pumpAndSettle();
    expect(find.text(AppString.exportCancelled.bn), findsOneWidget);
    await tap(AppString.pickBackup);
    await tap(AppString.confirmReplaceAll);
    expect(find.text(AppString.restoreWarning.bn), findsOneWidget);
    expect(find.textContaining(preview.payload), findsNothing);
    await tap(AppString.cancel);
    expect(restores, 0);
    expect(find.text(AppString.restoreCancelled.bn), findsOneWidget);
    await tap(AppString.confirmReplaceAll);
    await tap(AppString.confirmRestore);
    expect(find.text(AppString.restoreFailed.bn), findsOneWidget);
    expect(find.textContaining(preview.payload), findsNothing);
    expect(restored, isNull);
    await tap(AppString.confirmReplaceAll);
    await tap(AppString.confirmRestore);
    await t.pumpAndSettle();
    expect(restored, isTrue);
    expect(t.takeException(), isNull);
  });
}

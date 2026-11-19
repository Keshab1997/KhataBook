import 'dart:convert';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/app.dart';
import 'package:khatabook/features/ledger/data/ledger_backup.dart';
import 'package:khatabook/features/ledger/data/local_ledger.dart';

void main() {
  testWidgets(
    'Android backup export and confirmed restore refresh the selected khata',
    (t) async {
      const channel = MethodChannel('in.keshab.khatabook/backup_files');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final original = LocalLedger(NativeDatabase.memory());
      await original.initialize();
      final json = await LedgerBackup(original).exportJson();
      await original.close();
      final ledger = LocalLedger(NativeDatabase.memory());
      await ledger.initialize();
      final old = await ledger.createKhata(
        name: 'Old Shop',
        openingBalancePaise: 5000,
      );
      await ledger.setActiveKhataId(old.id);
      int saves = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'pick') return Uint8List.fromList(utf8.encode(json));
        if (call.method == 'save') {
          saves++;
          final bytes = (call.arguments as Map)['bytes'] as Uint8List;
          expect(utf8.decode(bytes), contains('Old Shop'));
          return true;
        }
        throw PlatformException(code: 'unknown');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await t.pumpWidget(KhataBookApp(ledger: ledger));
      await t.pumpAndSettle();
      expect(find.text('Old Shop'), findsOneWidget);
      await t.tap(find.text('Profile').last);
      await t.pumpAndSettle();
      await t.drag(find.byType(ListView).last, const Offset(0, -300));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('profile-backup-row')));
      await t.pumpAndSettle();
      await t.tap(find.text('Export Backup'));
      await t.pumpAndSettle();
      expect(saves, 1);
      expect(find.text('Export saved successfully.'), findsOneWidget);
      await t.tap(find.text('Pick Backup to Restore'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Confirm Restore (Replace ALL Data)'));
      await t.tap(find.text('Confirm Restore (Replace ALL Data)'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('Confirm Restore'));
      await t.pumpAndSettle();
      await t.tap(find.text('Home').last);
      await t.pumpAndSettle();
      expect(find.text('Personal Khata'), findsOneWidget);
      expect(find.text('Old Shop'), findsNothing);
      expect(await ledger.readActiveKhataId(), 'personal');
    },
  );
}

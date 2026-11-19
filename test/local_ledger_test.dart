import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/features/entry/add_entry_screen.dart';
import 'package:khatabook/features/ledger/data/local_ledger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('entries persist across close and reopen with exact paise', () async {
    final Directory dir = await Directory.systemTemp.createTemp('khata_test_');
    final File file = File('${dir.path}/ledger.sqlite');
    try {
      LocalLedger ledger = LocalLedger(NativeDatabase(file));
      await ledger.initialize();
      expect((await ledger.readSummary()).remainingPaise, 0);
      await ledger.addEntry(
        EntryFormResult(
          kind: EntryFormKind.income,
          amountPaise: 1000000,
          category: 'Income',
          description: '',
          occurredAt: DateTime(2026, 1, 2),
        ),
      );
      await ledger.addEntry(
        EntryFormResult(
          kind: EntryFormKind.expense,
          amountPaise: 58005,
          category: 'Food',
          description: 'Lunch',
          occurredAt: DateTime(2026, 1, 3),
        ),
      );
      await ledger.close();
      ledger = LocalLedger(NativeDatabase(file));
      await ledger.initialize();
      final summary = await ledger.readSummary();
      expect(summary.totalIncomePaise, 1000000);
      expect(summary.totalExpensePaise, 58005);
      expect(summary.remainingPaise, 941995);
      expect(summary.entries.first.title, 'Lunch');
      expect(summary.entries.length, 2);
      await ledger.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });
}

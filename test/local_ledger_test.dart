import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/features/entry/add_entry_screen.dart';
import 'package:khatabook/features/home/models.dart';
import 'package:khatabook/features/ledger/data/local_ledger.dart';

EntryFormResult _entry({
  required EntryFormKind kind,
  required int amountPaise,
  required String category,
  String description = '',
  required DateTime occurredAt,
}) {
  return EntryFormResult(
    kind: kind,
    amountPaise: amountPaise,
    category: category,
    description: description,
    occurredAt: occurredAt,
  );
}

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
        _entry(
          kind: EntryFormKind.income,
          amountPaise: 1000000,
          category: 'Income',
          occurredAt: DateTime(2026, 1, 2),
        ),
      );
      await ledger.addEntry(
        _entry(
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
      final LedgerSummary summary = await ledger.readSummary();
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

  test('initialize is idempotent and keeps the default khata empty', () async {
    final LocalLedger ledger = LocalLedger(NativeDatabase.memory());
    await ledger.initialize();
    await ledger.initialize();
    await ledger.initialize();

    final List<LocalKhata> khatas = await ledger.listKhatas();
    expect(khatas.length, 1);
    expect(khatas.single.id, 'personal');
    expect(khatas.single.name, 'Personal Khata');
    expect(khatas.single.openingBalancePaise, 0);

    final LedgerSummary summary = await ledger.readSummary();
    expect(summary.openingBalancePaise, 0);
    expect(summary.entries, isEmpty);
    expect(summary.totalIncomePaise, 0);
    expect(summary.totalExpensePaise, 0);
    expect(summary.remainingPaise, 0);

    // A second initialize after data exists changes nothing.
    await ledger.addEntry(
      _entry(
        kind: EntryFormKind.income,
        amountPaise: 500,
        category: 'Income',
        occurredAt: DateTime(2026, 2, 1),
      ),
    );
    await ledger.initialize();
    expect((await ledger.listKhatas()).length, 1);
    expect((await ledger.readSummary()).remainingPaise, 500);
    await ledger.close();
  });

  test('two khatas keep opening balances and summaries isolated', () async {
    final LocalLedger ledger = LocalLedger(NativeDatabase.memory());
    await ledger.initialize();

    final LocalKhata business = await ledger.createKhata(
      name: '  Business Khata  ',
      openingBalancePaise: 250000,
    );
    expect(business.name, 'Business Khata'); // trimmed on the way in
    expect(business.openingBalancePaise, 250000);
    expect(business.id, isNot('personal'));
    expect(business.id.length, greaterThan(0));

    final List<LocalKhata> khatas = await ledger.listKhatas();
    expect(khatas.length, 2);
    expect(khatas.first.id, 'personal'); // default khata is deterministic first
    expect(khatas.map((LocalKhata k) => k.id), contains(business.id));
    expect(
      (await ledger.listKhatas()).map((LocalKhata k) => k.id).toList(),
      khatas.map((LocalKhata k) => k.id).toList(),
    );

    // Personal: income only.
    await ledger.addEntry(
      _entry(
        kind: EntryFormKind.income,
        amountPaise: 700000,
        category: 'Income',
        occurredAt: DateTime(2026, 3, 1),
      ),
    );
    // Business: its own income and expense.
    await ledger.addEntry(
      _entry(
        kind: EntryFormKind.income,
        amountPaise: 300000,
        category: 'Income',
        description: 'Client payment',
        occurredAt: DateTime(2026, 3, 2),
      ),
      khataId: business.id,
    );
    await ledger.addEntry(
      _entry(
        kind: EntryFormKind.expense,
        amountPaise: 45000,
        category: 'Bills',
        description: 'Electricity',
        occurredAt: DateTime(2026, 3, 3),
      ),
      khataId: business.id,
    );

    final LedgerSummary personal = await ledger.readSummary();
    expect(personal.openingBalancePaise, 0);
    expect(personal.entries.length, 1);
    expect(personal.totalIncomePaise, 700000);
    expect(personal.totalExpensePaise, 0);
    expect(personal.remainingPaise, 700000);

    final LedgerSummary businessSummary = await ledger.readSummary(
      khataId: business.id,
    );
    expect(businessSummary.openingBalancePaise, 250000);
    expect(businessSummary.entries.length, 2);
    expect(businessSummary.totalIncomePaise, 550000);
    expect(businessSummary.totalExpensePaise, 45000);
    expect(businessSummary.remainingPaise, 505000);
    expect(
      businessSummary.entries.map((LedgerEntry e) => e.title),
      containsAll(<String>['Client payment', 'Electricity']),
    );
    // No entry from one khata leaks into the other.
    expect(
      businessSummary.entries.any((LedgerEntry e) => e.title == 'Income'),
      isFalse,
    );

    await ledger.close();
  });

  test('createKhata rejects bad names and amounts', () async {
    final LocalLedger ledger = LocalLedger(NativeDatabase.memory());
    await ledger.initialize();
    final int before = (await ledger.listKhatas()).length;

    for (final String bad in <String>['', '   ', '\n\t']) {
      await expectLater(
        ledger.createKhata(name: bad, openingBalancePaise: 0),
        throwsArgumentError,
      );
    }
    final String forty = List<String>.filled(40, 'a').join();
    await expectLater(
      ledger.createKhata(name: '$forty!', openingBalancePaise: 0),
      throwsArgumentError,
    );
    // Exactly 40 characters is allowed.
    final LocalKhata maxName = await ledger.createKhata(
      name: forty,
      openingBalancePaise: 0,
    );
    expect(maxName.name.length, 40);

    await expectLater(
      ledger.createKhata(name: 'Negative', openingBalancePaise: -1),
      throwsArgumentError,
    );
    await expectLater(
      ledger.createKhata(name: 'Too big', openingBalancePaise: 100000000000),
      throwsArgumentError,
    );

    // Only the valid khata was written; failures left no partial rows.
    expect((await ledger.listKhatas()).length, before + 1);
    await ledger.close();
  });

  test('summary and addEntry reject missing or deleted khatas', () async {
    final LocalLedger ledger = LocalLedger(NativeDatabase.memory());
    await ledger.initialize();

    await expectLater(
      ledger.readSummary(khataId: 'does-not-exist'),
      throwsA(isA<KhataNotFoundException>()),
    );
    await expectLater(
      ledger.addEntry(
        _entry(
          kind: EntryFormKind.expense,
          amountPaise: 100,
          category: 'Food',
          occurredAt: DateTime(2026, 4, 1),
        ),
        khataId: 'does-not-exist',
      ),
      throwsA(isA<KhataNotFoundException>()),
    );
    // A blank id is just another unknown khata, not a fallback to personal.
    await expectLater(
      ledger.readSummary(khataId: '  '),
      throwsA(isA<KhataNotFoundException>()),
    );

    final LocalKhata temp = await ledger.createKhata(
      name: 'Temp',
      openingBalancePaise: 1000,
    );
    await ledger.addEntry(
      _entry(
        kind: EntryFormKind.expense,
        amountPaise: 100,
        category: 'Food',
        occurredAt: DateTime(2026, 4, 2),
      ),
      khataId: temp.id,
    );
    // Tombstone it (tombstones are the schema's delete) and check it is gone.
    await ledger.customStatement(
      'UPDATE khatas SET deleted_at = ? WHERE id = ?',
      <Object?>[DateTime.now().toUtc().toIso8601String(), temp.id],
    );
    expect(
      (await ledger.listKhatas()).map((LocalKhata k) => k.id),
      isNot(contains(temp.id)),
    );
    await expectLater(
      ledger.readSummary(khataId: temp.id),
      throwsA(isA<KhataNotFoundException>()),
    );
    await expectLater(
      ledger.addEntry(
        _entry(
          kind: EntryFormKind.expense,
          amountPaise: 100,
          category: 'Food',
          occurredAt: DateTime(2026, 4, 3),
        ),
        khataId: temp.id,
      ),
      throwsA(isA<KhataNotFoundException>()),
    );

    // The rejected write did not land in the personal khata either.
    final LedgerSummary personal = await ledger.readSummary();
    expect(personal.entries, isEmpty);
    expect(personal.remainingPaise, 0);
    // The deleted khata's own row is untouched.
    final int kept =
        (await ledger
                .customSelect(
                  'SELECT COUNT(*) AS n FROM "transactions" WHERE khata_id = ?',
                  variables: <Variable<Object>>[Variable<String>(temp.id)],
                )
                .getSingle())
            .read<int>('n');
    expect(kept, 1);

    await ledger.close();
  });

  test('multiple khatas and their entries persist across reopen', () async {
    final Directory dir = await Directory.systemTemp.createTemp('khata_multi_');
    final File file = File('${dir.path}/ledger.sqlite');
    try {
      LocalLedger ledger = LocalLedger(NativeDatabase(file));
      await ledger.initialize();
      final LocalKhata shop = await ledger.createKhata(
        name: 'Shop Khata',
        openingBalancePaise: 123456,
      );
      await ledger.addEntry(
        _entry(
          kind: EntryFormKind.expense,
          amountPaise: 2345,
          category: 'Shopping',
          description: 'Stock',
          occurredAt: DateTime(2026, 5, 1),
        ),
        khataId: shop.id,
      );
      await ledger.close();

      ledger = LocalLedger(NativeDatabase(file));
      await ledger.initialize();
      final List<LocalKhata> khatas = await ledger.listKhatas();
      expect(khatas.length, 2);
      final LocalKhata reopened = khatas.firstWhere(
        (LocalKhata k) => k.id == shop.id,
      );
      expect(reopened.name, 'Shop Khata');
      expect(reopened.openingBalancePaise, 123456);

      final LedgerSummary shopSummary = await ledger.readSummary(
        khataId: shop.id,
      );
      expect(shopSummary.openingBalancePaise, 123456);
      expect(shopSummary.totalExpensePaise, 2345);
      expect(shopSummary.remainingPaise, 121111);
      expect(shopSummary.entries.single.title, 'Stock');

      final LedgerSummary personal = await ledger.readSummary();
      expect(personal.entries, isEmpty);
      expect(personal.remainingPaise, 0);
      await ledger.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });
}

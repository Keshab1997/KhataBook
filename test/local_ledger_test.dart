import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
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

  group('entry ids and descriptions', () {
    test('reads expose the stored id and raw nullable description', () async {
      final LocalLedger ledger = LocalLedger(NativeDatabase.memory());
      await ledger.initialize();
      await ledger.addEntry(
        _entry(
          kind: EntryFormKind.expense,
          amountPaise: 45000,
          category: 'Bills',
          description: '  Electricity  ',
          occurredAt: DateTime(2026, 1, 1),
        ),
      );
      await ledger.addEntry(
        _entry(
          kind: EntryFormKind.income,
          amountPaise: 300000,
          category: 'Income',
          occurredAt: DateTime(2026, 1, 2),
        ),
      );

      final LedgerSummary summary = await ledger.readSummary();
      final LedgerEntry withText = summary.entries.firstWhere(
        (LedgerEntry e) => e.category == 'Bills',
      );
      final LedgerEntry noText = summary.entries.firstWhere(
        (LedgerEntry e) => e.category == 'Income',
      );

      // Real ids, unique and non-empty.
      expect(withText.id, isNotNull);
      expect(noText.id, isNotNull);
      expect(withText.id, isNot(noText.id));
      expect(withText.id, isNotEmpty);

      // Stored description is trimmed before insert and reported as stored.
      expect(withText.description, 'Electricity');
      expect(withText.title, 'Electricity');

      // An empty description stays null; the category is only the title
      // fallback and is never reported as stored data.
      expect(noText.description, isNull);
      expect(noText.title, 'Income');

      // The default constructor's optional fields stay compatible.
      final LedgerEntry legacy = LedgerEntry(
        title: 'Lunch',
        category: 'Food',
        at: DateTime(2026, 1, 1),
        amountPaise: 1,
      );
      expect(legacy.id, isNull);
      expect(legacy.description, isNull);
      await ledger.close();
    });
  });

  group('edit, soft delete and restore', () {
    late LocalLedger ledger;
    late String personalEntryId;
    late String businessEntryId;
    late LocalKhata business;

    setUp(() async {
      ledger = LocalLedger(NativeDatabase.memory());
      await ledger.initialize();
      business = await ledger.createKhata(
        name: 'Business',
        openingBalancePaise: 100000,
      );
      await ledger.addEntry(
        _entry(
          kind: EntryFormKind.expense,
          amountPaise: 45000,
          category: 'Bills',
          description: 'Electricity',
          occurredAt: DateTime(2026, 2, 1),
        ),
      );
      await ledger.addEntry(
        _entry(
          kind: EntryFormKind.expense,
          amountPaise: 10000,
          category: 'Food',
          description: 'Stock lunch',
          occurredAt: DateTime(2026, 2, 2),
        ),
        khataId: business.id,
      );
      personalEntryId = (await ledger.readSummary()).entries.single.id!;
      businessEntryId = (await ledger.readSummary(khataId: business.id))
          .entries
          .single
          .id!;
    });

    tearDown(() async {
      await ledger.close();
    });

    Future<QueryRow> row(String id) => ledger
        .customSelect(
          'SELECT * FROM "transactions" WHERE id = ?',
          variables: <Variable<Object>>[Variable<String>(id)],
        )
        .getSingle();

    test('update edits the exact row and moves the balance', () async {
      final QueryRow before = await row(personalEntryId);
      final String createdAt = before.read<String>('created_at');

      final bool ok = await ledger.updateEntry(
        khataId: 'personal',
        entryId: personalEntryId,
        entry: _entry(
          kind: EntryFormKind.income,
          amountPaise: 99900,
          category: 'Gifts',
          description: 'Diwali gift',
          occurredAt: DateTime(2026, 3, 5),
        ),
      );
      expect(ok, isTrue);

      final LedgerSummary summary = await ledger.readSummary();
      expect(summary.entries.length, 1);
      final LedgerEntry edited = summary.entries.single;
      expect(edited.id, personalEntryId);
      expect(edited.type, EntryType.income);
      expect(edited.amountPaise, 99900);
      expect(edited.category, 'Gifts');
      expect(edited.description, 'Diwali gift');
      expect(edited.title, 'Diwali gift');
      expect(edited.at, DateTime(2026, 3, 5).toLocal());
      expect(summary.totalExpensePaise, 0);
      expect(summary.remainingPaise, 99900);

      // id and created_at are preserved; updated_at and sync_state are bumped.
      final QueryRow after = await row(personalEntryId);
      expect(after.read<String>('id'), personalEntryId);
      expect(after.read<String>('created_at'), createdAt);
      expect(after.read<String>('sync_state'), 'pending');
      expect(after.readNullable<String>('deleted_at'), isNull);

      // The other khata is untouched.
      final LedgerSummary other = await ledger.readSummary(
        khataId: business.id,
      );
      expect(other.entries.single.amountPaise, 10000);
      expect(other.remainingPaise, 90000);
    });

    test(
      'update can clear a description back to NULL, never the category',
      () async {
        final bool ok = await ledger.updateEntry(
          khataId: 'personal',
          entryId: personalEntryId,
          entry: _entry(
            kind: EntryFormKind.expense,
            amountPaise: 45000,
            category: 'Bills',
            occurredAt: DateTime(2026, 2, 1),
          ),
        );
        expect(ok, isTrue);
        expect(
          (await row(personalEntryId)).readNullable<String>('description'),
          isNull,
        );
        final LedgerEntry entry = (await ledger.readSummary()).entries.single;
        expect(entry.description, isNull);
        expect(entry.title, 'Bills'); // display fallback only
      },
    );

    test('soft delete removes an entry and restore brings it back', () async {
      expect((await ledger.readSummary()).remainingPaise, -45000);

      expect(
        await ledger.softDeleteEntry(
          khataId: 'personal',
          entryId: personalEntryId,
        ),
        isTrue,
      );
      LedgerSummary deleted = await ledger.readSummary();
      expect(deleted.entries, isEmpty);
      expect(deleted.remainingPaise, 0);
      // The row survives as a tombstone; nothing was destroyed.
      final QueryRow tombstone = await row(personalEntryId);
      expect(tombstone.readNullable<String>('deleted_at'), isNotNull);
      expect(tombstone.read<String>('sync_state'), 'pending');

      expect(
        await ledger.restoreEntry(
          khataId: 'personal',
          entryId: personalEntryId,
        ),
        isTrue,
      );
      deleted = await ledger.readSummary();
      expect(deleted.entries.single.id, personalEntryId);
      expect(deleted.entries.single.title, 'Electricity');
      expect(deleted.remainingPaise, -45000);
      expect(
        (await row(personalEntryId)).readNullable<String>('deleted_at'),
        isNull,
      );
    });

    test('wrong khata, missing ids and wrong states are no-ops', () async {
      // Cross-khata: a real id addressed through the other khata.
      expect(
        await ledger.updateEntry(
          khataId: business.id,
          entryId: personalEntryId,
          entry: _entry(
            kind: EntryFormKind.income,
            amountPaise: 1,
            category: 'Income',
            occurredAt: DateTime(2026, 4, 4),
          ),
        ),
        isFalse,
      );
      expect(
        await ledger.softDeleteEntry(
          khataId: business.id,
          entryId: personalEntryId,
        ),
        isFalse,
      );
      // Missing ids.
      expect(
        await ledger.softDeleteEntry(khataId: 'personal', entryId: 'nope'),
        isFalse,
      );
      expect(
        await ledger.restoreEntry(khataId: 'personal', entryId: 'nope'),
        isFalse,
      );
      // Unknown khata is reported false, not redirected to personal.
      expect(
        await ledger.softDeleteEntry(
          khataId: 'ghost',
          entryId: personalEntryId,
        ),
        isFalse,
      );

      // Nothing changed anywhere.
      expect((await row(personalEntryId)).read<int>('amount_paise'), 45000);
      expect(
        (await row(personalEntryId)).readNullable<String>('deleted_at'),
        isNull,
      );
      expect((await ledger.readSummary()).entries.length, 1);
      expect(
        (await ledger.readSummary(khataId: business.id)).entries.length,
        1,
      );

      // Already deleted: second delete is false; restoring an active row is
      // false.
      expect(
        await ledger.softDeleteEntry(
          khataId: 'personal',
          entryId: personalEntryId,
        ),
        isTrue,
      );
      expect(
        await ledger.softDeleteEntry(
          khataId: 'personal',
          entryId: personalEntryId,
        ),
        isFalse,
      );
      expect(
        await ledger.restoreEntry(
          khataId: business.id,
          entryId: businessEntryId,
        ),
        isFalse,
      );
      expect(
        await ledger.restoreEntry(
          khataId: 'personal',
          entryId: personalEntryId,
        ),
        isTrue,
      );
      expect(
        await ledger.restoreEntry(
          khataId: 'personal',
          entryId: personalEntryId,
        ),
        isFalse,
      );
    });

    test('an edit inside a deleted khata writes nothing', () async {
      await ledger.customStatement(
        'UPDATE khatas SET deleted_at = ? WHERE id = ?',
        <Object?>[DateTime.now().toUtc().toIso8601String(), business.id],
      );
      expect(
        await ledger.updateEntry(
          khataId: business.id,
          entryId: businessEntryId,
          entry: _entry(
            kind: EntryFormKind.income,
            amountPaise: 7,
            category: 'Income',
            occurredAt: DateTime(2026, 5, 5),
          ),
        ),
        isFalse,
      );
      expect(
        await ledger.restoreEntry(
          khataId: business.id,
          entryId: businessEntryId,
        ),
        isFalse,
      );
      expect((await row(businessEntryId)).read<int>('amount_paise'), 10000);
    });

    test(
      'invalid edits throw and leave the row byte-for-byte unchanged',
      () async {
        Map<String, Object?> snapshot(QueryRow r) => <String, Object?>{
          for (final String column in <String>[
            'type',
            'amount_paise',
            'category_id',
            'description',
            'occurred_at',
            'updated_at',
            'deleted_at',
            'sync_state',
          ])
            column: r.data[column],
        };
        final Map<String, Object?> before = snapshot(
          await row(personalEntryId),
        );

        for (final EntryFormResult invalid in <EntryFormResult>[
          // Zero and negative amounts.
          _entry(
            kind: EntryFormKind.expense,
            amountPaise: 0,
            category: 'Bills',
            occurredAt: DateTime(2026, 6, 1),
          ),
          _entry(
            kind: EntryFormKind.expense,
            amountPaise: -500,
            category: 'Bills',
            occurredAt: DateTime(2026, 6, 1),
          ),
          // Blank and whitespace-only categories.
          _entry(
            kind: EntryFormKind.expense,
            amountPaise: 100,
            category: '',
            occurredAt: DateTime(2026, 6, 1),
          ),
          _entry(
            kind: EntryFormKind.expense,
            amountPaise: 100,
            category: '   ',
            occurredAt: DateTime(2026, 6, 1),
          ),
          // 121 Unicode characters (runes, not bytes).
          _entry(
            kind: EntryFormKind.expense,
            amountPaise: 100,
            category: 'Bills',
            description: List<String>.filled(121, '₹').join(),
            occurredAt: DateTime(2026, 6, 1),
          ),
        ]) {
          await expectLater(
            ledger.updateEntry(
              khataId: 'personal',
              entryId: personalEntryId,
              entry: invalid,
            ),
            throwsArgumentError,
          );
        }

        expect(snapshot(await row(personalEntryId)), before);

        // A 120-rune description with multi-byte characters is accepted.
        expect(
          await ledger.updateEntry(
            khataId: 'personal',
            entryId: personalEntryId,
            entry: _entry(
              kind: EntryFormKind.expense,
              amountPaise: 45000,
              category: 'Bills',
              description: List<String>.filled(120, '₹').join(),
              occurredAt: DateTime(2026, 2, 1),
            ),
          ),
          isTrue,
        );
      },
    );

    test('edits, deletes and restores survive close and reopen', () async {
      final Directory dir = await Directory.systemTemp.createTemp('khata_upd_');
      final File file = File('${dir.path}/ledger.sqlite');
      try {
        LocalLedger store = LocalLedger(NativeDatabase(file));
        await store.initialize();
        final LocalKhata shop = await store.createKhata(
          name: 'Shop',
          openingBalancePaise: 50000,
        );
        await store.addEntry(
          _entry(
            kind: EntryFormKind.expense,
            amountPaise: 12000,
            category: 'Shopping',
            description: 'Boxes',
            occurredAt: DateTime(2026, 7, 1),
          ),
          khataId: shop.id,
        );
        await store.addEntry(
          _entry(
            kind: EntryFormKind.income,
            amountPaise: 8000,
            category: 'Income',
            occurredAt: DateTime(2026, 7, 2),
          ),
          khataId: shop.id,
        );
        final List<LedgerEntry> entries = (await store.readSummary(
          khataId: shop.id,
        )).entries;
        final String boxesId = entries
            .firstWhere((LedgerEntry e) => e.description == 'Boxes')
            .id!;
        final String salaryId = entries
            .firstWhere((LedgerEntry e) => e.description == null)
            .id!;

        await store.updateEntry(
          khataId: shop.id,
          entryId: boxesId,
          entry: _entry(
            kind: EntryFormKind.expense,
            amountPaise: 15000,
            category: 'Shopping',
            description: 'Bigger boxes',
            occurredAt: DateTime(2026, 7, 1),
          ),
        );
        await store.softDeleteEntry(khataId: shop.id, entryId: salaryId);
        await store.close();

        store = LocalLedger(NativeDatabase(file));
        await store.initialize();
        LedgerSummary reopened = await store.readSummary(khataId: shop.id);
        expect(reopened.entries.length, 1);
        expect(reopened.entries.single.id, boxesId);
        expect(reopened.entries.single.amountPaise, 15000);
        expect(reopened.entries.single.description, 'Bigger boxes');
        expect(reopened.totalExpensePaise, 15000);
        expect(reopened.remainingPaise, 35000);

        // The tombstone persisted, so it can still be restored after a reopen.
        expect(
          await store.restoreEntry(khataId: shop.id, entryId: salaryId),
          isTrue,
        );
        reopened = await store.readSummary(khataId: shop.id);
        expect(reopened.entries.length, 2);
        expect(reopened.remainingPaise, 43000);
        expect((await store.readSummary()).entries, isEmpty);
        await store.close();
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}

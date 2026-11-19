import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/features/entry/add_entry_screen.dart';
import 'package:khatabook/features/home/models.dart';
import 'package:khatabook/features/ledger/data/ledger_backup.dart';
import 'package:khatabook/features/ledger/data/local_ledger.dart';

const String _t1 = '2026-11-20T10:30:00.000Z';

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

/// A ledger with two khatas, income and expense, non-ASCII text, a nullable
/// description, exact paise and one tombstoned entry.
Future<LocalLedger> _seededLedger() async {
  final LocalLedger ledger = LocalLedger(NativeDatabase.memory());
  await ledger.initialize();
  final LocalKhata business = await ledger.createKhata(
    name: 'Business Khata',
    openingBalancePaise: 250075,
  );
  await ledger.addEntry(
    _entry(
      kind: EntryFormKind.income,
      amountPaise: 1000000,
      category: 'Income',
      description: 'বেতন — Salary',
      occurredAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
    ),
  );
  await ledger.addEntry(
    _entry(
      kind: EntryFormKind.expense,
      amountPaise: 58005,
      category: 'Food',
      description: 'Lunch with Friends',
      occurredAt: DateTime.utc(2026, 1, 3, 12, 0),
    ),
    khataId: business.id,
  );
  // No description: stored as NULL, never as "".
  await ledger.addEntry(
    _entry(
      kind: EntryFormKind.expense,
      amountPaise: 7450,
      category: 'Bills',
      occurredAt: DateTime.utc(2026, 1, 4, 8, 15),
    ),
    khataId: business.id,
  );
  // One tombstone, so deleted history must survive the round trip.
  final List<QueryRow> rows = await ledger
      .customSelect(
        'SELECT id FROM "transactions" WHERE category_id = ?',
        variables: <Variable<Object>>[const Variable<String>('Bills')],
      )
      .get();
  await ledger.softDeleteEntry(
    khataId: business.id,
    entryId: rows.single.read<String>('id'),
  );
  return ledger;
}

/// Every row of both tables, exactly as stored, for "nothing changed" checks.
Future<String> _dump(LocalLedger ledger) async {
  final List<QueryRow> khatas = await ledger
      .customSelect(
        'SELECT id, name, opening_balance_paise, currency, sort_order, '
        'created_at, updated_at, deleted_at, sync_state '
        'FROM khatas ORDER BY id',
      )
      .get();
  final List<QueryRow> transactions = await ledger
      .customSelect(
        'SELECT id, khata_id, type, amount_paise, category_id, description, '
        'occurred_at, note_session_id, created_at, updated_at, deleted_at, '
        'sync_state FROM "transactions" ORDER BY id',
      )
      .get();
  return jsonEncode(<String, Object?>{
    'khatas': khatas.map((QueryRow r) => r.data).toList(),
    'transactions': transactions.map((QueryRow r) => r.data).toList(),
  });
}

/// Raw read of a few columns, for the checks that compare stored values
/// rather than the app's own summary models.
Future<List<Map<String, Object?>>> _rows(LocalLedger ledger, String sql) async {
  final List<QueryRow> rows = await ledger.customSelect(sql).get();
  return rows.map((QueryRow row) => row.data).toList();
}

/// A valid exported document with one optional mutation applied, so each
/// malformed-file test changes exactly one thing.
Future<Map<String, Object?>> _validBackup(LocalLedger ledger) async {
  final String json = await LedgerBackup(ledger).exportJson();
  return jsonDecode(json) as Map<String, Object?>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('export', () {
    test('writes a versioned document with every khata and entry', () async {
      final LocalLedger ledger = await _seededLedger();
      final String json = await LedgerBackup(ledger).exportJson();
      final Map<String, Object?> root =
          jsonDecode(json) as Map<String, Object?>;

      expect(root['format'], 'khatabook-ledger-backup');
      expect(root['version'], 1);
      expect(root.keys.toSet(), <String>{
        'format',
        'version',
        'khatas',
        'transactions',
      });

      final List<Object?> khatas = root['khatas']! as List<Object?>;
      final List<Object?> transactions = root['transactions']! as List<Object?>;
      expect(khatas.length, 2);
      // Three entries: two active and one tombstone.
      expect(transactions.length, 3);

      final Map<String, Object?> personal = khatas
          .cast<Map<String, Object?>>()
          .firstWhere((Map<String, Object?> k) => k['id'] == 'personal');
      expect(personal['name'], 'Personal Khata');
      expect(personal['opening_balance_paise'], 0);
      expect(personal['currency'], 'INR');
      expect(personal['deleted_at'], isNull);

      final List<Map<String, Object?>> entries = transactions
          .cast<Map<String, Object?>>();
      final Map<String, Object?> income = entries.firstWhere(
        (Map<String, Object?> t) => t['type'] == 'income',
      );
      // Exact integer paise, non-ASCII text kept verbatim, UTC timestamps.
      expect(income['amount_paise'], 1000000);
      expect(income['description'], 'বেতন — Salary');
      expect(income['category_id'], 'Income');
      expect(income['occurred_at'], '2026-01-02T03:04:05.000Z');
      expect(income['khata_id'], 'personal');
      expect(income['note_session_id'], isNull);
      expect(income['sync_state'], isNull); // never exported as a field

      final Map<String, Object?> lunch = entries.firstWhere(
        (Map<String, Object?> t) => t['description'] == 'Lunch with Friends',
      );
      expect(lunch['amount_paise'], 58005);
      expect(lunch['type'], 'expense');
      expect(lunch['category_id'], 'Food');

      final Map<String, Object?> noText = entries.firstWhere(
        (Map<String, Object?> t) => t['category_id'] == 'Bills',
      );
      expect(noText['description'], isNull);
      expect(noText['deleted_at'], isNotNull);

      await ledger.close();
    });

    test('amounts are JSON integers, never floating point', () async {
      final LocalLedger ledger = await _seededLedger();
      final String json = await LedgerBackup(ledger).exportJson();
      // A JSON double would serialise as 58005.0 or 1e6; an int cannot.
      expect(json, contains('"amount_paise": 58005'));
      expect(json, isNot(contains('58005.0')));
      expect(json, isNot(contains('1000000.0')));
      expect(json, isNot(contains('1e+06')));
      // Nine integer digits of rupees: a double cannot hold them exactly.
      final RegExp amount = RegExp(r'"amount_paise": ([-0-9.]+)');
      final Iterable<String> amounts = amount
          .allMatches(json)
          .map((RegExpMatch m) => m.group(1)!);
      expect(amounts, isNotEmpty);
      for (final String value in amounts) {
        expect(int.tryParse(value), isNotNull, reason: 'not an int: $value');
        expect(value, isNot(contains('.')));
      }
      await ledger.close();
    });

    test('contains no credentials, tokens or device settings', () async {
      final LocalLedger ledger = await _seededLedger();
      final String json = (await LedgerBackup(
        ledger,
      ).exportJson()).toLowerCase();
      for (final String forbidden in <String>[
        'password',
        'token',
        'secret',
        'api_key',
        'apikey',
        'service_role',
        'anon_key',
        'supabase',
        '/data/',
        'sqlite',
        '.sqlite',
        'device',
      ]) {
        expect(json, isNot(contains(forbidden)), reason: forbidden);
      }
      await ledger.close();
    });

    test('a second export of the same data is byte-identical', () async {
      final LocalLedger ledger = await _seededLedger();
      final LedgerBackup backup = LedgerBackup(ledger);
      expect(await backup.exportJson(), await backup.exportJson());
      await ledger.close();
    });
  });

  group('inspect', () {
    test('counts khatas, entries and tombstones without writing', () async {
      final LocalLedger ledger = await _seededLedger();
      final String before = await _dump(ledger);
      final LedgerBackup backup = LedgerBackup(ledger);

      final BackupInspection inspection = backup.inspect(
        await backup.exportJson(),
      );
      expect(inspection.khataCount, 2);
      expect(inspection.transactionCount, 3);
      expect(inspection.deletedTransactionCount, 1);
      // Inspect is read-only: the database is untouched.
      expect(await _dump(ledger), before);
      await ledger.close();
    });

    test('rejects malformed files without touching the ledger', () async {
      final LocalLedger ledger = await _seededLedger();
      final String before = await _dump(ledger);
      final LedgerBackup backup = LedgerBackup(ledger);
      final Map<String, Object?> valid = await _validBackup(ledger);

      const Map<String, String> cases = <String, String>{
        'blank': '   ',
        'not json': '{not json',
        'root is a list': '[]',
        'root is a string': r'"hello"',
        'empty object': '{}',
      };
      for (final MapEntry<String, String> entry in cases.entries) {
        expect(
          () => backup.inspect(entry.value),
          throwsA(isA<LedgerBackupException>()),
          reason: entry.key,
        );
      }

      // One bad field at a time, always from an otherwise valid document.
      final List<void Function(Map<String, Object?>)> mutations =
          <void Function(Map<String, Object?>)>[
            (Map<String, Object?> root) => root['version'] = 2,
            (Map<String, Object?> root) => root['version'] = '1',
            (Map<String, Object?> root) => root['version'] = null,
            (Map<String, Object?> root) => root.remove('version'),
            (Map<String, Object?> root) =>
                root['format'] = 'khatabook-ledger-backup-v2',
            (Map<String, Object?> root) => root['extra'] = true,
            (Map<String, Object?> root) => root['khatas'] = <Object?>[],
            (Map<String, Object?> root) => root['transactions'] = null,
            (Map<String, Object?> root) =>
                (root['khatas']! as List<Object?>)[0] = 'nope',
            (Map<String, Object?> root) =>
                (root['transactions']! as List<Object?>)[0] =
                    <String, Object?>{},
          ];
      for (final void Function(Map<String, Object?>) mutate in mutations) {
        final Map<String, Object?> copy = _copy(valid);
        mutate(copy);
        expect(
          () => backup.inspect(jsonEncode(copy)),
          throwsA(isA<LedgerBackupException>()),
        );
      }
      expect(await _dump(ledger), before);
      await ledger.close();
    });
  });

  group('round trip', () {
    test('restores khatas, entries, tombstones and exact paise', () async {
      final LocalLedger source = await _seededLedger();
      final String json = await LedgerBackup(source).exportJson();
      final String sourceDump = await _dump(source);
      await source.close();

      final LocalLedger target = LocalLedger(NativeDatabase.memory());
      await target.initialize();
      final LedgerBackup backup = LedgerBackup(target);
      await backup.restoreReplacing(json);

      expect(await _dump(target), sourceDump);
      final LedgerSummary personal = await target.readSummary();
      expect(personal.totalIncomePaise, 1000000);
      expect(personal.totalExpensePaise, 0);
      expect(personal.remainingPaise, 1000000);
      expect(personal.entries.single.title, 'বেতন — Salary');

      final List<LocalKhata> khatas = await target.listKhatas();
      expect(khatas.length, 2);
      final LocalKhata business = khatas.firstWhere(
        (LocalKhata k) => k.id != 'personal',
      );
      expect(business.name, 'Business Khata');
      expect(business.openingBalancePaise, 250075);

      final LedgerSummary businessSummary = await target.readSummary(
        khataId: business.id,
      );
      expect(businessSummary.openingBalancePaise, 250075);
      expect(businessSummary.totalExpensePaise, 58005);
      // The tombstoned entry stays hidden from totals after restore.
      expect(businessSummary.entries.length, 1);
      expect(businessSummary.entries.single.title, 'Lunch with Friends');

      final List<Map<String, Object?>> tombstones = await _rows(
        target,
        'SELECT id, deleted_at FROM "transactions" '
        'WHERE deleted_at IS NOT NULL',
      );
      expect(tombstones.length, 1);

      // A second restore from the same string is idempotent.
      final String restoredDump = await _dump(target);
      await backup.restoreReplacing(json);
      expect(await _dump(target), restoredDump);
      await target.close();
    });

    test('replaced rows are pending sync and sync is never enabled', () async {
      final LocalLedger source = await _seededLedger();
      // Pretend the source was already synced; restoring must reset that.
      await source.customStatement(
        'UPDATE khatas SET sync_state = ?',
        <Object?>['synced'],
      );
      await source.customStatement(
        'UPDATE "transactions" SET sync_state = ?',
        <Object?>['synced'],
      );
      final String json = await LedgerBackup(source).exportJson();
      await source.close();

      final LocalLedger target = LocalLedger(NativeDatabase.memory());
      await target.initialize();
      await LedgerBackup(target).restoreReplacing(json);

      for (final Map<String, Object?> table in <Map<String, Object?>>[
        (await _rows(target, 'SELECT sync_state FROM khatas')).first,
        (await _rows(target, 'SELECT sync_state FROM "transactions"')).first,
      ]) {
        expect(table['sync_state'], 'pending');
      }
      await target.close();
    });

    test('replaces an existing populated ledger completely', () async {
      final LocalLedger source = await _seededLedger();
      final String json = await LedgerBackup(source).exportJson();
      await source.close();

      final LocalLedger target = LocalLedger(NativeDatabase.memory());
      await target.initialize();
      final LocalKhata stale = await target.createKhata(
        name: 'Old Shop',
        openingBalancePaise: 999,
      );
      await target.addEntry(
        _entry(
          kind: EntryFormKind.expense,
          amountPaise: 123456,
          category: 'Travel',
          description: 'Stale row',
          occurredAt: DateTime.utc(2025, 12, 31),
        ),
        khataId: stale.id,
      );
      await target.addEntry(
        _entry(
          kind: EntryFormKind.income,
          amountPaise: 500,
          category: 'Income',
          description: 'Stale personal row',
          occurredAt: DateTime.utc(2025, 12, 30),
        ),
      );

      await LedgerBackup(target).restoreReplacing(json);

      final List<LocalKhata> khatas = await target.listKhatas();
      expect(khatas.length, 2);
      expect(
        khatas.any((LocalKhata k) => k.name == 'Old Shop'),
        isFalse,
        reason: 'the old khata must be gone, not merged',
      );
      final LedgerSummary personal = await target.readSummary();
      expect(
        personal.entries.any(
          (LedgerEntry e) => e.title == 'Stale personal row',
        ),
        isFalse,
      );
      expect(personal.remainingPaise, 1000000);
      expect((await _rows(target, 'SELECT id FROM "transactions"')).length, 3);
      await target.close();
    });

    test('persists across close and reopen', () async {
      final Directory dir = await Directory.systemTemp.createTemp(
        'khata_backup_',
      );
      final File file = File('${dir.path}/ledger.sqlite');
      try {
        final LocalLedger source = await _seededLedger();
        final String json = await LedgerBackup(source).exportJson();
        await source.close();

        LocalLedger ledger = LocalLedger(NativeDatabase(file));
        await ledger.initialize();
        await LedgerBackup(ledger).restoreReplacing(json);
        final String afterRestore = await LedgerBackup(ledger).exportJson();
        await ledger.close();

        ledger = LocalLedger(NativeDatabase(file));
        await ledger.initialize();
        expect(await LedgerBackup(ledger).exportJson(), afterRestore);
        expect((await ledger.listKhatas()).length, 2);
        await ledger.close();
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });

  group('restore rejects bad files and changes nothing', () {
    /// Each case must throw [LedgerBackupException] from `restoreReplacing`
    /// *and* leave the target ledger exactly as it was.
    Future<void> expectRejected(
      Map<String, Object?> Function(Map<String, Object?> root) mutate, {
      required String reason,
    }) async {
      final (LocalLedger target, String json) = await _restoreFixture();
      final Map<String, Object?> document =
          jsonDecode(json) as Map<String, Object?>;
      final Map<String, Object?> mutated = mutate(_copy(document));
      final String before = await _dump(target);
      await expectLater(
        LedgerBackup(target).restoreReplacing(jsonEncode(mutated)),
        throwsA(isA<LedgerBackupException>()),
        reason: reason,
      );
      expect(await _dump(target), before, reason: '$reason left data changed');
      await target.close();
    }

    test('unknown version', () async {
      await expectRejected(
        (Map<String, Object?> root) => root..['version'] = 99,
        reason: 'unknown version',
      );
      await expectRejected(
        (Map<String, Object?> root) => root..remove('version'),
        reason: 'missing version',
      );
    });

    test('foreign format marker and unexpected fields', () async {
      await expectRejected(
        (Map<String, Object?> root) => root..['format'] = 'other-app',
        reason: 'foreign format',
      );
      await expectRejected(
        (Map<String, Object?> root) => root..['settings'] = <String, Object?>{},
        reason: 'extra root field',
      );
      await expectRejected((Map<String, Object?> root) {
        final Map<String, Object?> khata =
            (root['khatas']! as List<Object?>)[0] as Map<String, Object?>;
        khata['color_token'] = 'green';
        return root;
      }, reason: 'extra khata field');
      await expectRejected((Map<String, Object?> root) {
        final Map<String, Object?> entry =
            (root['transactions']! as List<Object?>)[0] as Map<String, Object?>;
        entry['server_id'] = 1;
        return root;
      }, reason: 'extra transaction field');
    });

    test('missing fields and wrong types', () async {
      await expectRejected((Map<String, Object?> root) {
        final Map<String, Object?> khata =
            (root['khatas']! as List<Object?>)[0] as Map<String, Object?>;
        khata.remove('currency');
        return root;
      }, reason: 'missing currency');
      await expectRejected((Map<String, Object?> root) {
        final Map<String, Object?> entry =
            (root['transactions']! as List<Object?>)[0] as Map<String, Object?>;
        entry['amount_paise'] = '1000';
        return root;
      }, reason: 'amount as string');
      await expectRejected((Map<String, Object?> root) {
        final Map<String, Object?> entry =
            (root['transactions']! as List<Object?>)[0] as Map<String, Object?>;
        entry['amount_paise'] = 1000.0;
        return root;
      }, reason: 'amount as float');
      await expectRejected((Map<String, Object?> root) {
        final Map<String, Object?> entry =
            (root['transactions']! as List<Object?>)[0] as Map<String, Object?>;
        entry['description'] = 42;
        return root;
      }, reason: 'description as number');
      await expectRejected((Map<String, Object?> root) {
        root['khatas'] = <String, Object?>{};
        return root;
      }, reason: 'khatas not an array');
    });

    test('duplicate and blank ids', () async {
      await expectRejected((Map<String, Object?> root) {
        final List<Object?> khatas = root['khatas']! as List<Object?>;
        final Map<String, Object?> second = _copy(
          khatas[1] as Map<String, Object?>,
        );
        second['id'] = (khatas[0] as Map<String, Object?>)['id'];
        khatas[1] = second;
        return root;
      }, reason: 'duplicate khata id');
      await expectRejected((Map<String, Object?> root) {
        final List<Object?> entries = root['transactions']! as List<Object?>;
        final Map<String, Object?> second = _copy(
          entries[1] as Map<String, Object?>,
        );
        second['id'] = (entries[0] as Map<String, Object?>)['id'];
        entries[1] = second;
        return root;
      }, reason: 'duplicate transaction id');
      await expectRejected((Map<String, Object?> root) {
        final Map<String, Object?> entry =
            (root['transactions']! as List<Object?>)[0] as Map<String, Object?>;
        entry['id'] = '   ';
        return root;
      }, reason: 'blank transaction id');
      await expectRejected((Map<String, Object?> root) {
        final Map<String, Object?> khata =
            (root['khatas']! as List<Object?>)[0] as Map<String, Object?>;
        khata['id'] = '';
        return root;
      }, reason: 'blank khata id');
    });

    test('dangling foreign key', () async {
      await expectRejected((Map<String, Object?> root) {
        final Map<String, Object?> entry =
            (root['transactions']! as List<Object?>)[0] as Map<String, Object?>;
        entry['khata_id'] = 'no-such-khata';
        return root;
      }, reason: 'transaction points at a missing khata');
    });

    test('invalid amounts', () async {
      for (final Object? amount in <Object?>[0, -1]) {
        await expectRejected((Map<String, Object?> root) {
          final Map<String, Object?> entry =
              (root['transactions']! as List<Object?>)[0]
                  as Map<String, Object?>;
          entry['amount_paise'] = amount;
          return root;
        }, reason: 'amount $amount');
      }
    });

    test('wrong or unknown entry type', () async {
      await expectRejected((Map<String, Object?> root) {
        final Map<String, Object?> entry =
            (root['transactions']! as List<Object?>)[0] as Map<String, Object?>;
        entry['type'] = 'transfer';
        return root;
      }, reason: 'unknown type');
      await expectRejected((Map<String, Object?> root) {
        final Map<String, Object?> entry =
            (root['transactions']! as List<Object?>)[0] as Map<String, Object?>;
        entry['type'] = 'Income';
        return root;
      }, reason: 'capitalised type');
    });

    test('a category that differs from the type is accepted', () async {
      // The editor lets a user switch expense -> income and keep the category,
      // so this is data the app itself writes; a restore must not reject it.
      final (LocalLedger target, String json) = await _restoreFixture();
      final Map<String, Object?> document =
          jsonDecode(json) as Map<String, Object?>;
      final Map<String, Object?> mutated = _copy(document);
      final Map<String, Object?> entry =
          (mutated['transactions']! as List<Object?>)
              .cast<Map<String, Object?>>()
              .firstWhere((row) => row['khata_id'] == 'personal');
      entry['category_id'] = 'Food';
      await LedgerBackup(target).restoreReplacing(jsonEncode(mutated));
      final LedgerSummary summary = await target.readSummary();
      expect(summary.entries.single.category, 'Food');
      expect(summary.totalIncomePaise, 1000000);
      await target.close();
    });

    test('invalid timestamps', () async {
      for (final Object? stamp in <Object?>[
        '2026-01-02 03:04:05',
        '2026-01-02T03:04:05+05:30',
        '2026-01-02T03:04:05',
        '2026-02-31T03:04:05Z',
        '2026-01-02T25:04:05Z',
        'not a date',
        '',
        12345,
      ]) {
        await expectRejected((Map<String, Object?> root) {
          final Map<String, Object?> entry =
              (root['transactions']! as List<Object?>)[0]
                  as Map<String, Object?>;
          entry['occurred_at'] = stamp;
          return root;
        }, reason: 'occurred_at $stamp');
      }
    });

    test('invalid khata names and descriptions', () async {
      await expectRejected((Map<String, Object?> root) {
        final Map<String, Object?> khata =
            (root['khatas']! as List<Object?>)[1] as Map<String, Object?>;
        khata['name'] = '   ';
        return root;
      }, reason: 'blank khata name');
      await expectRejected((Map<String, Object?> root) {
        final Map<String, Object?> khata =
            (root['khatas']! as List<Object?>)[1] as Map<String, Object?>;
        khata['name'] = List<String>.filled(41, 'a').join();
        return root;
      }, reason: 'khata name too long');
      await expectRejected((Map<String, Object?> root) {
        final Map<String, Object?> entry =
            (root['transactions']! as List<Object?>)[1] as Map<String, Object?>;
        entry['description'] = List<String>.filled(121, 'x').join();
        return root;
      }, reason: 'description too long');
    });

    test('missing active personal khata', () async {
      await expectRejected((Map<String, Object?> root) {
        final List<Object?> khatas = root['khatas']! as List<Object?>;
        khatas.removeAt(0);
        // Keep the remaining entries valid by re-pointing them at khata 1.
        for (final Object? item in root['transactions']! as List<Object?>) {
          (item! as Map<String, Object?>)['khata_id'] =
              (khatas.first! as Map<String, Object?>)['id'];
        }
        return root;
      }, reason: 'no personal khata');
      await expectRejected((Map<String, Object?> root) {
        final Map<String, Object?> personal =
            (root['khatas']! as List<Object?>)[0] as Map<String, Object?>;
        personal['deleted_at'] = _t1;
        return root;
      }, reason: 'personal khata is a tombstone');
    });

    test('oversized payload (> 10 MiB UTF-8)', () async {
      final (LocalLedger target, String json) = await _restoreFixture();
      final String before = await _dump(target);
      // Valid JSON, but far past the cap; two-byte characters prove the limit
      // is counted in UTF-8 bytes, not in code units.
      final String padded = <String>[
        '{"format":"khatabook-ledger-backup","version":1,',
        '"khatas":[],"transactions":[],"pad":"',
        '${'é' * (6 * 1024 * 1024)}"}',
      ].join();
      await expectLater(
        LedgerBackup(target).restoreReplacing(padded),
        throwsA(isA<LedgerBackupException>()),
      );
      final String huge = '$json${' ' * (11 * 1024 * 1024)}';
      await expectLater(
        LedgerBackup(target).restoreReplacing(huge),
        throwsA(isA<LedgerBackupException>()),
      );
      expect(await _dump(target), before);
      await target.close();
    });

    test('a forced SQL error rolls everything back', () async {
      final (LocalLedger target, String json) = await _restoreFixture();
      // A trigger that fails on the last row inserted: validation passes, the
      // replace has already deleted the old data, and the transaction must
      // still leave the ledger exactly as it was.
      await target.customStatement(
        'CREATE TRIGGER reject_last_transaction '
        'BEFORE INSERT ON "transactions" '
        "WHEN NEW.description = 'Lunch with Friends' "
        "BEGIN SELECT RAISE(ABORT, 'forced failure'); END",
      );
      final String before = await _dump(target);
      await expectLater(
        LedgerBackup(target).restoreReplacing(json),
        throwsA(anything),
      );
      expect(await _dump(target), before);
      await target.close();
    });
  });

  group('boundaries', () {
    test('an empty personal ledger round-trips', () async {
      final LocalLedger ledger = LocalLedger(NativeDatabase.memory());
      await ledger.initialize();
      final String json = await LedgerBackup(ledger).exportJson();
      expect(LedgerBackup(ledger).inspect(json).khataCount, 1);
      expect(LedgerBackup(ledger).inspect(json).transactionCount, 0);

      final LocalLedger target = LocalLedger(NativeDatabase.memory());
      await target.initialize();
      await LedgerBackup(target).restoreReplacing(json);
      expect((await target.listKhatas()).single.id, 'personal');
      expect((await target.readSummary()).entries, isEmpty);
      await ledger.close();
      await target.close();
    });

    test('padded names and blank descriptions are preserved', () async {
      final (LocalLedger target, String json) = await _restoreFixture();
      final Map<String, Object?> document =
          jsonDecode(json) as Map<String, Object?>;
      final List<Object?> khatas = document['khatas']! as List<Object?>;
      (khatas[1]! as Map<String, Object?>)['name'] = '  Shop Khata  ';
      final List<Object?> entries = document['transactions']! as List<Object?>;
      Map<String, Object?> entryWithCategory(String category) {
        return entries.cast<Map<String, Object?>>().firstWhere(
          (Map<String, Object?> t) => t['category_id'] == category,
        );
      }

      entryWithCategory('Food')['description'] = '  Padded text  ';
      // Preserve whitespace exactly rather than silently converting to null.
      entryWithCategory('Bills')['description'] = '   ';

      await LedgerBackup(target).restoreReplacing(jsonEncode(document));

      final List<LocalKhata> restored = await target.listKhatas();
      expect(
        restored.map((LocalKhata k) => k.name),
        contains('  Shop Khata  '),
      );
      final List<Map<String, Object?>> stored = await _rows(
        target,
        'SELECT category_id, description FROM "transactions" '
        'ORDER BY category_id ASC',
      );
      expect(
        stored.firstWhere(
          (Map<String, Object?> r) => r['category_id'] == 'Food',
        )['description'],
        '  Padded text  ',
      );
      expect(
        stored.firstWhere(
          (Map<String, Object?> r) => r['category_id'] == 'Bills',
        )['description'],
        '   ',
      );
      await target.close();
    });

    test(
      'valid historical negative opening and large amounts survive',
      () async {
        final (LocalLedger target, String json) = await _restoreFixture();
        final document = jsonDecode(json) as Map<String, Object?>;
        final khatas = (document['khatas']! as List<Object?>)
            .cast<Map<String, Object?>>();
        khatas.firstWhere(
          (row) => row['id'] == 'personal',
        )['opening_balance_paise'] = -5;
        final entries = (document['transactions']! as List<Object?>)
            .cast<Map<String, Object?>>();
        entries.firstWhere(
          (row) => row['khata_id'] == 'personal',
        )['amount_paise'] = 100000000000;
        await LedgerBackup(target).restoreReplacing(jsonEncode(document));
        final summary = await target.readSummary();
        expect(summary.openingBalancePaise, -5);
        expect(summary.entries.single.amountPaise, 100000000000);
        await target.close();
      },
    );

    test('descriptions and names in Bengali survive verbatim', () async {
      final LocalLedger ledger = LocalLedger(NativeDatabase.memory());
      await ledger.initialize();
      await ledger.addEntry(
        _entry(
          kind: EntryFormKind.expense,
          amountPaise: 12345,
          category: 'Food',
          description: 'দুপুরের খাবার 🍛',
          occurredAt: DateTime.utc(2026, 2, 3, 4, 5),
        ),
      );
      final String json = await LedgerBackup(ledger).exportJson();
      // The JSON is valid UTF-8 and keeps the text readable, not escaped octal.
      expect(utf8.decode(utf8.encode(json)), json);
      expect(json, contains('দুপুরের খাবার 🍛'));

      final LocalLedger target = LocalLedger(NativeDatabase.memory());
      await target.initialize();
      await LedgerBackup(target).restoreReplacing(json);
      expect(
        (await target.readSummary()).entries.single.description,
        'দুপুরের খাবার 🍛',
      );
      await ledger.close();
      await target.close();
    });

    test(
      'restore safely falls back when selected khata no longer exists',
      () async {
        final source = LocalLedger(NativeDatabase.memory());
        await source.initialize();
        final backup = await LedgerBackup(source).exportJson();
        final target = LocalLedger(NativeDatabase.memory());
        await target.initialize();
        final old = await target.createKhata(
          name: 'Old',
          openingBalancePaise: 5,
        );
        await target.setActiveKhataId(old.id);
        await LedgerBackup(target).restoreReplacing(backup);
        expect(await target.readActiveKhataId(), 'personal');
        expect(
          (await target.listKhatas()).map((k) => k.id),
          isNot(contains(old.id)),
        );
        await source.close();
        await target.close();
      },
    );

    test('export and restore leave the schema untouched', () async {
      final LocalLedger ledger = await _seededLedger();
      Future<String> schema() async => jsonEncode(
        await _rows(
          ledger,
          'SELECT type, name, sql FROM sqlite_master ORDER BY name',
        ),
      );
      final String before = await schema();
      expect(before, contains('CREATE TABLE khatas'));

      final LedgerBackup backup = LedgerBackup(ledger);
      final String json = await backup.exportJson();
      backup.inspect(json);
      await backup.restoreReplacing(json);

      expect(await schema(), before);
      await ledger.close();
    });
  });
}

/// A full copy of a decoded document, so a mutation cannot leak into the next
/// test case through shared nested maps.
Map<String, Object?> _copy(Map<String, Object?> value) {
  return jsonDecode(jsonEncode(value)) as Map<String, Object?>;
}

/// A populated target ledger plus a backup of a *different* ledger, which is
/// what a failed restore must leave untouched.
Future<(LocalLedger, String)> _restoreFixture() async {
  final LocalLedger source = await _seededLedger();
  final String json = await LedgerBackup(source).exportJson();
  await source.close();

  final LocalLedger target = LocalLedger(NativeDatabase.memory());
  await target.initialize();
  await target.addEntry(
    _entry(
      kind: EntryFormKind.expense,
      amountPaise: 777,
      category: 'Gifts',
      description: 'Keep me',
      occurredAt: DateTime.utc(2025, 6, 1),
    ),
  );
  return (target, json);
}

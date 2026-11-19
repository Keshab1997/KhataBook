import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../entry/add_entry_screen.dart';
import '../../home/models.dart';

/// A single local database. The SQL schema is also exercised independently
/// by tests/test_ledger_schema.py. Sync is deliberately not implemented here.
class LocalLedger extends GeneratedDatabase {
  LocalLedger(super.executor);

  factory LocalLedger.device() => LocalLedger(driftDatabase(name: 'khatabook'));

  static const String _defaultKhata = 'personal';
  static const Uuid _uuid = Uuid();

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      final String sql = await rootBundle.loadString(
        'lib/features/ledger/data/schema.sql',
      );
      // Schema comments can contain semicolons; strip them before splitting.
      final String ddl = sql
          .split('\n')
          .where((String line) => !line.trimLeft().startsWith('--'))
          .join('\n');
      for (final String statement in ddl.split(';')) {
        if (statement.trim().isNotEmpty) await customStatement(statement);
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Creates a zero-balance local khata once, never replacing existing data.
  Future<void> initialize() async {
    final String now = DateTime.now().toUtc().toIso8601String();
    await customStatement(
      'INSERT OR IGNORE INTO khatas (id, name, opening_balance_paise, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
      <Object>[_defaultKhata, 'Personal Khata', 0, now, now],
    );
  }

  Future<LedgerSummary> readSummary() async {
    final QueryRow khata = await customSelect(
      'SELECT opening_balance_paise FROM khatas WHERE id = ? AND deleted_at IS NULL',
      variables: <Variable<Object>>[Variable<String>(_defaultKhata)],
    ).getSingle();
    final List<QueryRow> rows = await customSelect(
      'SELECT type, amount_paise, category_id, description, occurred_at FROM "transactions" WHERE khata_id = ? AND deleted_at IS NULL ORDER BY occurred_at DESC, id ASC',
      variables: <Variable<Object>>[Variable<String>(_defaultKhata)],
    ).get();
    return LedgerSummary(
      openingBalancePaise: khata.read<int>('opening_balance_paise'),
      entries: rows
          .map((QueryRow row) {
            final String category = row.read<String>('category_id');
            final String? description = row.readNullable<String>('description');
            return LedgerEntry(
              title: description == null || description.trim().isEmpty
                  ? category
                  : description,
              category: category,
              at: DateTime.parse(row.read<String>('occurred_at')).toLocal(),
              amountPaise: row.read<int>('amount_paise'),
              type: row.read<String>('type') == 'income'
                  ? EntryType.income
                  : EntryType.expense,
            );
          })
          .toList(growable: false),
    );
  }

  Future<void> addEntry(EntryFormResult entry) async {
    if (entry.amountPaise <= 0 || entry.category.trim().isEmpty) {
      throw ArgumentError('Invalid transaction');
    }
    final String description = entry.description.trim();
    if (description.runes.length > 120) {
      throw ArgumentError('Description too long');
    }
    final String now = DateTime.now().toUtc().toIso8601String();
    await customStatement(
      'INSERT INTO "transactions" (id, khata_id, type, amount_paise, category_id, description, occurred_at, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Object?>[
        _uuid.v4(),
        _defaultKhata,
        entry.kind.name,
        entry.amountPaise,
        entry.category,
        description.isEmpty ? null : description,
        entry.occurredAt.toUtc().toIso8601String(),
        now,
        now,
      ],
    );
  }
}

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../entry/add_entry_screen.dart';
import '../../home/models.dart';

/// A local khata (one ledger) as stored in the existing `khatas` table.
///
/// This is an immutable value: it is a snapshot, not a live handle, so callers
/// cannot accidentally write through it and so it is safe to compare in tests.
/// Money is always integer paise.
final class LocalKhata {
  const LocalKhata({
    required this.id,
    required this.name,
    required this.openingBalancePaise,
  });

  final String id;
  final String name;
  final int openingBalancePaise;

  @override
  bool operator ==(Object other) =>
      other is LocalKhata &&
      other.id == id &&
      other.name == name &&
      other.openingBalancePaise == openingBalancePaise;

  @override
  int get hashCode => Object.hash(id, name, openingBalancePaise);

  @override
  String toString() =>
      'LocalKhata(id: $id, name: $name, '
      'openingBalancePaise: $openingBalancePaise)';
}

/// Thrown when a caller names a khata that does not exist (or was tombstoned).
///
/// Reads and writes reject an unknown id instead of falling back to the
/// personal khata, so a bug can never silently file an entry under the wrong
/// ledger.
class KhataNotFoundException implements Exception {
  const KhataNotFoundException(this.khataId);

  final String khataId;

  @override
  String toString() => 'KhataNotFoundException: no active khata $khataId';
}

/// A single local database. The SQL schema is also exercised independently
/// by tests/test_ledger_schema.py. Sync is deliberately not implemented here.
class LocalLedger extends GeneratedDatabase {
  LocalLedger(super.executor);

  factory LocalLedger.device() => LocalLedger(driftDatabase(name: 'khatabook'));

  static const String _defaultKhata = 'personal';
  static const Uuid _uuid = Uuid();

  /// Khata names are trimmed and must be 1…40 characters
  /// (docs/spec/data-model.md, validation rules).
  static const int _maxKhataNameLength = 40;

  /// Nine integer digits of rupees in paise: the largest opening balance the
  /// amount rule allows (₹99,99,99,999.99). SQLite would store more, but the
  /// spec does not, and an out-of-range value would break totals later.
  static const int _maxOpeningBalancePaise = 99999999999;

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
  ///
  /// Idempotent: running it against a populated database only re-confirms the
  /// default row, so the personal khata stays empty/zero on a fresh install and
  /// keeps every existing entry on later launches.
  Future<void> initialize() async {
    final String now = DateTime.now().toUtc().toIso8601String();
    await customStatement(
      'INSERT OR IGNORE INTO khatas (id, name, opening_balance_paise, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
      <Object>[_defaultKhata, 'Personal Khata', 0, now, now],
    );
  }

  /// Active (non-tombstoned) khatas in a stable order: the default personal
  /// khata first, then `sort_order`, then creation time and id.
  Future<List<LocalKhata>> listKhatas() async {
    final List<QueryRow> rows = await customSelect(
      'SELECT id, name, opening_balance_paise FROM khatas '
      'WHERE deleted_at IS NULL '
      'ORDER BY CASE WHEN id = ? THEN 0 ELSE 1 END, sort_order ASC, '
      'created_at ASC, id ASC',
      variables: <Variable<Object>>[Variable<String>(_defaultKhata)],
    ).get();
    return List<LocalKhata>.unmodifiable(
      rows.map(
        (QueryRow row) => LocalKhata(
          id: row.read<String>('id'),
          name: row.read<String>('name'),
          openingBalancePaise: row.read<int>('opening_balance_paise'),
        ),
      ),
    );
  }

  /// Creates one UUID-backed khata in the existing schema.
  ///
  /// [name] is trimmed before validation and storage; blank or
  /// longer-than-40-character names are rejected, as are negative or
  /// out-of-range [openingBalancePaise] values. Nothing is written on error.
  Future<LocalKhata> createKhata({
    required String name,
    required int openingBalancePaise,
  }) async {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Khata name must not be blank');
    }
    if (trimmedName.runes.length > _maxKhataNameLength) {
      throw ArgumentError.value(
        name,
        'name',
        'Khata name must be at most $_maxKhataNameLength characters',
      );
    }
    if (openingBalancePaise < 0 ||
        openingBalancePaise > _maxOpeningBalancePaise) {
      throw ArgumentError.value(
        openingBalancePaise,
        'openingBalancePaise',
        'Opening balance must be between 0 and $_maxOpeningBalancePaise paise',
      );
    }
    final String id = _uuid.v4();
    final String now = DateTime.now().toUtc().toIso8601String();
    await customStatement(
      'INSERT INTO khatas (id, name, opening_balance_paise, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
      <Object>[id, trimmedName, openingBalancePaise, now, now],
    );
    return LocalKhata(
      id: id,
      name: trimmedName,
      openingBalancePaise: openingBalancePaise,
    );
  }

  /// Reads the opening balance and every non-deleted entry of exactly one
  /// khata. Totals are never mixed across khatas.
  Future<LedgerSummary> readSummary({String khataId = 'personal'}) async {
    final QueryRow? khata = await _findKhata(khataId);
    if (khata == null) throw KhataNotFoundException(khataId);
    final List<QueryRow> rows = await customSelect(
      'SELECT type, amount_paise, category_id, description, occurred_at FROM "transactions" WHERE khata_id = ? AND deleted_at IS NULL ORDER BY occurred_at DESC, id ASC',
      variables: <Variable<Object>>[Variable<String>(khataId)],
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

  /// Appends one entry to the named khata.
  ///
  /// The khata must exist and be active; a missing id throws
  /// [KhataNotFoundException] instead of writing to another ledger.
  Future<void> addEntry(
    EntryFormResult entry, {
    String khataId = 'personal',
  }) async {
    if (entry.amountPaise <= 0 || entry.category.trim().isEmpty) {
      throw ArgumentError('Invalid transaction');
    }
    final String description = entry.description.trim();
    if (description.runes.length > 120) {
      throw ArgumentError('Description too long');
    }
    final String now = DateTime.now().toUtc().toIso8601String();
    // One transaction so the existence check and the insert cannot be
    // interleaved with a tombstone written elsewhere.
    await transaction(() async {
      if (await _findKhata(khataId) == null) {
        throw KhataNotFoundException(khataId);
      }
      await customStatement(
        'INSERT INTO "transactions" (id, khata_id, type, amount_paise, category_id, description, occurred_at, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Object?>[
          _uuid.v4(),
          khataId,
          entry.kind.name,
          entry.amountPaise,
          entry.category,
          description.isEmpty ? null : description,
          entry.occurredAt.toUtc().toIso8601String(),
          now,
          now,
        ],
      );
    });
  }

  /// The active khata matching [khataId], or `null` when the id is blank,
  /// unknown or tombstoned — all of which callers must reject.
  Future<QueryRow?> _findKhata(String khataId) async {
    if (khataId.trim().isEmpty) return null;
    final List<QueryRow> rows = await customSelect(
      'SELECT opening_balance_paise FROM khatas WHERE id = ? AND deleted_at IS NULL',
      variables: <Variable<Object>>[Variable<String>(khataId)],
    ).get();
    return rows.isEmpty ? null : rows.single;
  }
}

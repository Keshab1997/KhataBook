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
      'SELECT id, type, amount_paise, category_id, description, occurred_at FROM "transactions" WHERE khata_id = ? AND deleted_at IS NULL ORDER BY occurred_at DESC, id ASC',
      variables: <Variable<Object>>[Variable<String>(khataId)],
    ).get();
    return LedgerSummary(
      openingBalancePaise: khata.read<int>('opening_balance_paise'),
      entries: rows
          .map((QueryRow row) {
            final String category = row.read<String>('category_id');
            // Kept exactly as stored; the category is only a display fallback
            // for `title`, never written back as data.
            final String? description = row.readNullable<String>('description');
            return LedgerEntry(
              id: row.read<String>('id'),
              title: description == null || description.trim().isEmpty
                  ? category
                  : description,
              description: description,
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
    final String description = _validateEntry(entry);
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

  /// Edits one active entry inside one active khata.
  ///
  /// Only the editable columns change - type, amount, category, description and
  /// `occurred_at`; `id` and `created_at` are preserved. Returns `false` (and
  /// writes nothing) when the khata is unknown/tombstoned, the entry is
  /// missing, belongs to another khata, or is already soft-deleted. Invalid
  /// values throw [ArgumentError] without touching the row, using the same
  /// rules as [addEntry]. Never falls back to the personal khata.
  Future<bool> updateEntry({
    required String khataId,
    required String entryId,
    required EntryFormResult entry,
  }) async {
    final String description = _validateEntry(entry);
    final bool hasDescription = description.isNotEmpty;
    // `description` is bound as a real NULL when it is empty, never as the
    // category text: only the placeholder (or the literal NULL) goes into the
    // SQL, and every actual value stays a bound parameter.
    final String setDescription = hasDescription ? '?' : 'NULL';
    final List<Variable<Object>> fields = <Variable<Object>>[
      Variable<String>(entry.kind.name),
      Variable<int>(entry.amountPaise),
      Variable<String>(entry.category),
      if (hasDescription) Variable<String>(description),
      Variable<String>(entry.occurredAt.toUtc().toIso8601String()),
    ];
    return _mutateActiveEntry(khataId, (String now) {
      return customUpdate(
        'UPDATE "transactions" SET type = ?, amount_paise = ?, '
        'category_id = ?, description = $setDescription, occurred_at = ?, '
        "updated_at = ?, sync_state = 'pending' WHERE id = ? AND khata_id = ? "
        'AND deleted_at IS NULL',
        variables: <Variable<Object>>[
          ...fields,
          Variable<String>(now),
          Variable<String>(entryId),
          Variable<String>(khataId),
        ],
      );
    });
  }

  /// Soft-deletes one active entry inside one active khata by setting
  /// `deleted_at`; the row is never destroyed. Returns `false` and writes
  /// nothing for an unknown khata, a missing/wrong-khata entry or an entry that
  /// is already deleted.
  Future<bool> softDeleteEntry({
    required String khataId,
    required String entryId,
  }) async {
    return _mutateActiveEntry(
      khataId,
      (String now) => customUpdate(
        'UPDATE "transactions" SET deleted_at = ?, updated_at = ?, '
        "sync_state = 'pending' WHERE id = ? AND khata_id = ? "
        'AND deleted_at IS NULL',
        variables: <Variable<Object>>[
          Variable<String>(now),
          Variable<String>(now),
          Variable<String>(entryId),
          Variable<String>(khataId),
        ],
      ),
    );
  }

  /// Clears `deleted_at` on one soft-deleted entry inside one active khata.
  /// Returns `false` and writes nothing when the entry is missing, belongs to
  /// another khata, or is already active.
  Future<bool> restoreEntry({
    required String khataId,
    required String entryId,
  }) async {
    return _mutateActiveEntry(
      khataId,
      (String now) => customUpdate(
        'UPDATE "transactions" SET deleted_at = NULL, updated_at = ?, '
        "sync_state = 'pending' WHERE id = ? AND khata_id = ? "
        'AND deleted_at IS NOT NULL',
        variables: <Variable<Object>>[
          Variable<String>(now),
          Variable<String>(entryId),
          Variable<String>(khataId),
        ],
      ),
    );
  }

  /// Runs one conditional [statement] against the single matching row, inside a
  /// transaction that first proves the khata is active.
  ///
  /// The statement itself carries `khata_id` and the deleted/active condition,
  /// so a row in another khata or in the wrong state can never be touched: the
  /// update simply matches nothing and this returns `false`.
  Future<bool> _mutateActiveEntry(
    String khataId,
    Future<int> Function(String nowUtc) statement,
  ) async {
    final String now = DateTime.now().toUtc().toIso8601String();
    return transaction(() async {
      // A tombstoned or unknown khata is inactive: report false and never let a
      // restore resurrect an entry inside a deleted khata.
      if (await _findKhata(khataId) == null) return false;
      final int changed = await statement(now);
      return changed == 1;
    });
  }

  /// The add/edit rules shared by [addEntry], [updateEntry] and the form:
  /// positive integer-paise amount, non-blank category and a trimmed
  /// description of at most 120 Unicode characters. Returns the trimmed
  /// description; throws [ArgumentError] without writing anything.
  String _validateEntry(EntryFormResult entry) {
    if (entry.amountPaise <= 0) {
      throw ArgumentError('Invalid transaction amount');
    }
    if (entry.category.trim().isEmpty) {
      throw ArgumentError('Category must not be blank');
    }
    final String description = entry.description.trim();
    if (description.runes.length > 120) {
      throw ArgumentError('Description too long');
    }
    return description;
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

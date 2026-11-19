/// Offline, versioned JSON backup of the local KhataBook ledger.
///
/// This file is a standalone service with **no** file I/O, platform code,
/// network, UI or new dependency: it reads and writes the two existing tables
/// (`khatas`, `"transactions"`) through [LocalLedger] and nothing else. The
/// caller owns the file picker, the confirmation dialog and the share sheet.
///
/// ```text
/// exportJson()          -> String (the whole ledger, one read transaction)
/// inspect(json)         -> BackupInspection (synchronous, no writes)
/// restoreReplacing(json)-> Future<void>  (destructive, one write transaction)
/// ```
///
/// Rules this file exists to enforce:
///
/// * **Money stays integer paise.** A JSON number that is a `double` (even
///   `1000.0`) is rejected, so no value can lose precision on the way in.
/// * **Only this build's own format is accepted** - a fixed marker plus
///   `version: 1`. Unknown versions, extra fields, missing fields and wrong
///   types are errors, not things to tolerate.
/// * **The file is validated in full, then written, in one transaction.**
///   `restoreReplacing` re-validates the string itself; it never trusts an
///   earlier [LedgerBackup.inspect]. Any failure leaves the existing ledger
///   byte-for-byte unchanged.
/// * **Restore is a destructive replacement by design.** Every khata and
///   transaction row is removed first (child rows before parents) and replaced
///   by the file's rows, with `sync_state = 'pending'` so a later sync pushes
///   the restored data. Nothing else is touched: no settings, no preferences,
///   no schema, no other tables, and cloud sync is never switched on.
/// * **Tombstones travel with the data.** `deleted_at` is exported and
///   restored, so deleted entries stay deleted and history is preserved.
/// * **No secrets.** Only the ledger columns are serialised - never
///   credentials, tokens, device settings, database paths or account data.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import 'local_ledger.dart';

/// Marker that identifies a KhataBook ledger backup. The marker is checked
/// before anything else so a foreign JSON file is rejected as such.
const String kLedgerBackupFormat = 'khatabook-ledger-backup';

/// The only backup format version this build writes or reads.
const int kLedgerBackupVersion = 1;

/// Largest backup accepted, in UTF-8 bytes (10 MiB).
///
/// A whole cash-book ledger is far smaller than this; the cap exists so a
/// malformed or hostile file cannot be decoded into a huge object graph.
const int kLedgerBackupMaxBytes = 10 * 1024 * 1024;

/// Thrown for anything that makes a backup unusable: bad JSON, a foreign or
/// unknown format, an unexpected field, an out-of-range amount, a duplicate id,
/// a dangling foreign key, a missing active personal khata or an oversized
/// payload.
class LedgerBackupException implements Exception {
  const LedgerBackupException(this.message);

  /// What is wrong, naming the offending field (e.g. `backup.khatas[0].name`).
  final String message;

  @override
  String toString() => 'LedgerBackupException: $message';
}

/// What one backup file contains, without touching the database.
///
/// [khataCount] counts every khata in the file including tombstoned ones;
/// [transactionCount] counts every entry; [deletedTransactionCount] counts the
/// tombstoned (soft-deleted) entries among them.
class BackupInspection {
  const BackupInspection({
    required this.khataCount,
    required this.transactionCount,
    required this.deletedTransactionCount,
  });

  final int khataCount;
  final int transactionCount;
  final int deletedTransactionCount;
}

/// One khatas row as it travels in a backup file.
class _KhataRecord {
  const _KhataRecord({
    required this.id,
    required this.name,
    required this.openingBalancePaise,
    required this.currency,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final String name;
  final int openingBalancePaise;
  final String currency;
  final int sortOrder;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'opening_balance_paise': openingBalancePaise,
    'currency': currency,
    'sort_order': sortOrder,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };
}

/// One `"transactions"` row as it travels in a backup file.
class _TransactionRecord {
  const _TransactionRecord({
    required this.id,
    required this.khataId,
    required this.type,
    required this.amountPaise,
    required this.categoryId,
    required this.description,
    required this.occurredAt,
    required this.noteSessionId,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
  });

  final String id;
  final String khataId;
  final String type;
  final int amountPaise;
  final String categoryId;
  final String? description;
  final String occurredAt;
  final String? noteSessionId;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'khata_id': khataId,
    'type': type,
    'amount_paise': amountPaise,
    'category_id': categoryId,
    'description': description,
    'occurred_at': occurredAt,
    'note_session_id': noteSessionId,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };
}

/// A whole validated backup file, in memory.
class _Backup {
  const _Backup({required this.khatas, required this.transactions});

  final List<_KhataRecord> khatas;
  final List<_TransactionRecord> transactions;
}

/// The default personal khata, which every backup must carry exactly once and
/// must not be tombstoned. It is the khata the app opens on.
const String _personalKhataId = 'personal';

/// Khata names are 1...40 characters (docs/spec/data-model.md).
const int _maxKhataNameLength = 40;

/// Descriptions are at most 120 characters (schema + spec).
const int _maxDescriptionLength = 120;

/// Ids are client-generated strings; UUID v4 is 36 characters, `personal` is
/// short, and anything wildly longer is junk rather than data.
const int _maxIdLength = 64;

/// Expense categories are short labels (`Shopping`, `Food`, ...).
const int _maxCategoryLength = 64;

const Set<String> _rootKeys = <String>{
  'format',
  'version',
  'khatas',
  'transactions',
};

const Set<String> _khataKeys = <String>{
  'id',
  'name',
  'opening_balance_paise',
  'currency',
  'sort_order',
  'created_at',
  'updated_at',
  'deleted_at',
};

const Set<String> _transactionKeys = <String>{
  'id',
  'khata_id',
  'type',
  'amount_paise',
  'category_id',
  'description',
  'occurred_at',
  'note_session_id',
  'created_at',
  'updated_at',
  'deleted_at',
};

/// UTC ISO-8601 with a mandatory `Z`, optional fraction. Local-time strings
/// and `+05:30` offsets are rejected: storage is always UTC.
final RegExp _utcTimestampPattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$',
);

/// Versioned JSON export and validated, atomic restore of the local ledger.
///
/// Construct it around the app's [LocalLedger]; it holds no state of its own,
/// so one instance can export, inspect and restore in any order.
class LedgerBackup {
  LedgerBackup(this.ledger);

  /// The database this backup reads from and restores into.
  final LocalLedger ledger;

  /// Serialises every khata and every transaction - tombstones included - to
  /// this build's JSON format.
  ///
  /// Both tables are read inside one transaction, so the snapshot is
  /// consistent: an entry written after the export started cannot appear
  /// without its khata (or the other way round).
  ///
  /// Throws [LedgerBackupException] when the database does not hold exactly one
  /// active personal khata, or when a stored row could not itself be restored.
  /// Exporting something that would be rejected on the way back in is worse
  /// than refusing: the caller would keep a backup that cannot be used. So the
  /// finished document is run through the same validation [inspect] and
  /// [restoreReplacing] use before it is returned.
  Future<String> exportJson() async {
    return ledger.transaction<String>(() async {
      final List<_KhataRecord> khatas = await _readKhatas();
      final List<_TransactionRecord> transactions = await _readTransactions();
      final Map<String, Object?> root = <String, Object?>{
        'format': kLedgerBackupFormat,
        'version': kLedgerBackupVersion,
        'khatas': khatas.map((_KhataRecord k) => k.toJson()).toList(),
        'transactions': transactions
            .map((_TransactionRecord t) => t.toJson())
            .toList(),
      };
      final String json = const JsonEncoder.withIndent('  ').convert(root);
      _decodeAndValidate(json);
      return json;
    });
  }

  /// Counts what [json] would restore, without writing anything.
  ///
  /// Fully validates the file, so a caller can show "N khatas, M entries (K
  /// deleted) - this will replace your current ledger" from a trustworthy
  /// number, and can throw the same [LedgerBackupException] it would get from
  /// [restoreReplacing]. The result is advisory: [restoreReplacing] validates
  /// the string again before it touches the database.
  BackupInspection inspect(String json) {
    final _Backup backup = _decodeAndValidate(json);
    int deleted = 0;
    for (final _TransactionRecord transaction in backup.transactions) {
      if (transaction.deletedAt != null) deleted++;
    }
    return BackupInspection(
      khataCount: backup.khatas.length,
      transactionCount: backup.transactions.length,
      deletedTransactionCount: deleted,
    );
  }

  /// Replaces the local ledger with the contents of [json].
  ///
  /// **Destructive by design:** every existing khata and transaction is
  /// removed. The caller is responsible for explicit user confirmation; a
  /// backup codec cannot know whether the user meant it.
  ///
  /// The whole file is validated first, then the replace runs in a single
  /// SQLite transaction (child rows deleted before parents, khatas inserted
  /// before their entries). Any error - a bad field or a failing statement -
  /// rolls the transaction back, so a failed restore leaves the previous
  /// ledger exactly as it was. Restored rows get `sync_state = 'pending'`;
  /// settings and every other table are untouched.
  Future<void> restoreReplacing(String json) async {
    // Validate the entire file again here; a prior `inspect` is not a licence
    // to skip it, because the string may have changed since.
    final _Backup backup = _decodeAndValidate(json);
    await ledger.transaction<void>(() async {
      await ledger.customStatement('DELETE FROM "transactions"');
      await ledger.customStatement('DELETE FROM khatas');
      for (final _KhataRecord khata in backup.khatas) {
        await ledger.customStatement(
          'INSERT INTO khatas (id, name, opening_balance_paise, currency, '
          'sort_order, created_at, updated_at, deleted_at, sync_state) '
          "VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending')",
          <Object?>[
            khata.id,
            khata.name,
            khata.openingBalancePaise,
            khata.currency,
            khata.sortOrder,
            khata.createdAt,
            khata.updatedAt,
            khata.deletedAt,
          ],
        );
      }
      for (final _TransactionRecord transaction in backup.transactions) {
        await ledger.customStatement(
          'INSERT INTO "transactions" (id, khata_id, type, amount_paise, '
          'category_id, description, occurred_at, note_session_id, '
          'created_at, updated_at, deleted_at, sync_state) '
          "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')",
          <Object?>[
            transaction.id,
            transaction.khataId,
            transaction.type,
            transaction.amountPaise,
            transaction.categoryId,
            transaction.description,
            transaction.occurredAt,
            transaction.noteSessionId,
            transaction.createdAt,
            transaction.updatedAt,
            transaction.deletedAt,
          ],
        );
      }
    });
  }

  /// Every khata, tombstoned ones included, in the app's display order.
  Future<List<_KhataRecord>> _readKhatas() async {
    const String sql =
        'SELECT id, name, opening_balance_paise, currency, sort_order, '
        'created_at, updated_at, deleted_at FROM khatas '
        'ORDER BY sort_order ASC, created_at ASC, id ASC';
    final List<QueryRow> rows = await ledger.customSelect(sql).get();
    return rows
        .map((QueryRow row) {
          final String id = row.read<String>('id');
          return _KhataRecord(
            id: id,
            name: row.read<String>('name'),
            openingBalancePaise: row.read<int>('opening_balance_paise'),
            currency: row.read<String>('currency'),
            sortOrder: row.read<int>('sort_order'),
            createdAt: _checkTimestamp(
              row.read<String>('created_at'),
              'khatas[$id].created_at',
            ),
            updatedAt: _checkTimestamp(
              row.read<String>('updated_at'),
              'khatas[$id].updated_at',
            ),
            deletedAt: _readTimestamp(
              row.readNullable<String>('deleted_at'),
              'khatas[$id].deleted_at',
            ),
          );
        })
        .toList(growable: false);
  }

  /// Every transaction, tombstoned ones included, in a stable order.
  Future<List<_TransactionRecord>> _readTransactions() async {
    const String sql =
        'SELECT id, khata_id, type, amount_paise, category_id, description, '
        'occurred_at, note_session_id, created_at, updated_at, deleted_at '
        'FROM "transactions" ORDER BY khata_id ASC, occurred_at ASC, id ASC';
    final List<QueryRow> rows = await ledger.customSelect(sql).get();
    return rows
        .map((QueryRow row) {
          final String id = row.read<String>('id');
          return _TransactionRecord(
            id: id,
            khataId: row.read<String>('khata_id'),
            type: row.read<String>('type'),
            amountPaise: row.read<int>('amount_paise'),
            categoryId: row.read<String>('category_id'),
            description: row.readNullable<String>('description'),
            occurredAt: _checkTimestamp(
              row.read<String>('occurred_at'),
              'transactions[$id].occurred_at',
            ),
            noteSessionId: row.readNullable<String>('note_session_id'),
            createdAt: _checkTimestamp(
              row.read<String>('created_at'),
              'transactions[$id].created_at',
            ),
            updatedAt: _checkTimestamp(
              row.read<String>('updated_at'),
              'transactions[$id].updated_at',
            ),
            deletedAt: _readTimestamp(
              row.readNullable<String>('deleted_at'),
              'transactions[$id].deleted_at',
            ),
          );
        })
        .toList(growable: false);
  }

  /// Parses and validates one complete backup file.
  ///
  /// Every check that `restoreReplacing` relies on lives here, so `inspect` and
  /// `restoreReplacing` reject exactly the same inputs.
  _Backup _decodeAndValidate(String json) {
    if (json.trim().isEmpty) {
      throw const LedgerBackupException('Backup is empty');
    }
    final int byteLength = utf8.encode(json).length;
    if (byteLength > kLedgerBackupMaxBytes) {
      throw LedgerBackupException(
        'Backup is $byteLength bytes; the limit is $kLedgerBackupMaxBytes',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (error) {
      throw LedgerBackupException('Backup is not valid JSON: ${error.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw const LedgerBackupException('Backup root must be a JSON object');
    }
    _expectExactKeys(decoded, _rootKeys, 'backup');
    if (decoded['format'] != kLedgerBackupFormat) {
      throw const LedgerBackupException(
        'Backup format marker is missing or not recognised',
      );
    }
    final Object? version = decoded['version'];
    if (version is! int) {
      throw const LedgerBackupException('Backup version must be an integer');
    }
    if (version != kLedgerBackupVersion) {
      throw LedgerBackupException(
        'Unsupported backup version $version; this build reads '
        'version $kLedgerBackupVersion',
      );
    }

    final List<Object?> khataItems = _expectList(decoded, 'khatas', 'backup');
    final List<Object?> transactionItems = _expectList(
      decoded,
      'transactions',
      'backup',
    );
    final List<_KhataRecord> khatas = <_KhataRecord>[
      for (int i = 0; i < khataItems.length; i++)
        _parseKhata(khataItems[i], 'backup.khatas[$i]'),
    ];
    final List<_TransactionRecord> transactions = <_TransactionRecord>[
      for (int i = 0; i < transactionItems.length; i++)
        _parseTransaction(transactionItems[i], 'backup.transactions[$i]'),
    ];

    _requireActivePersonalKhata(khatas);
    _checkRelationships(khatas, transactions);
    return _Backup(khatas: khatas, transactions: transactions);
  }

  /// Exactly one `personal` khata, and it must be active.
  void _requireActivePersonalKhata(List<_KhataRecord> khatas) {
    int personalKhatas = 0;
    int activePersonalKhatas = 0;
    for (final _KhataRecord khata in khatas) {
      if (khata.id != _personalKhataId) continue;
      personalKhatas++;
      if (khata.deletedAt == null) activePersonalKhatas++;
    }
    if (personalKhatas != 1 || activePersonalKhatas != 1) {
      throw const LedgerBackupException(
        'Backup must contain exactly one active $_personalKhataId khata',
      );
    }
  }

  /// Duplicate ids and dangling foreign keys are rejected: both would break
  /// the app's own reads, and the schema's `REFERENCES`/`PRIMARY KEY` would
  /// refuse them anyway once the rows reach SQLite.
  ///
  /// Deliberately *not* checked: whether `category_id` matches `type`. The
  /// editor lets a user flip an entry from expense to income without touching
  /// its category, so income + `Food` is real data this app has written, not
  /// corruption. The category is a label; the direction is `type`.
  void _checkRelationships(
    List<_KhataRecord> khatas,
    List<_TransactionRecord> transactions,
  ) {
    final Set<String> khataIds = <String>{};
    for (final _KhataRecord khata in khatas) {
      if (!khataIds.add(khata.id)) {
        throw LedgerBackupException('Duplicate khata id ${khata.id}');
      }
    }
    final Set<String> transactionIds = <String>{};
    for (final _TransactionRecord transaction in transactions) {
      if (!transactionIds.add(transaction.id)) {
        throw LedgerBackupException(
          'Duplicate transaction id ${transaction.id}',
        );
      }
      if (!khataIds.contains(transaction.khataId)) {
        throw LedgerBackupException(
          'Transaction ${transaction.id} refers to missing khata '
          '${transaction.khataId}',
        );
      }
    }
  }

  _KhataRecord _parseKhata(Object? value, String path) {
    final Map<String, Object?> map = _expectObject(value, path);
    _expectExactKeys(map, _khataKeys, path);
    final String id = _expectId(map, 'id', path);
    final Object? rawName = map['name'];
    if (rawName is! String) {
      throw LedgerBackupException('$path.name must be a string');
    }
    // Preserve exact stored names while rejecting blank names.
    final String name = rawName;
    if (name.trim().isEmpty) {
      throw LedgerBackupException('$path.name must not be blank');
    }
    if (name.runes.length > _maxKhataNameLength) {
      throw LedgerBackupException(
        '$path.name must be at most $_maxKhataNameLength characters',
      );
    }
    final int openingBalancePaise = _expectInt(
      map,
      'opening_balance_paise',
      path,
    );
    final String currency = _expectString(map, 'currency', path, maxLength: 8);
    if (currency != 'INR') {
      throw LedgerBackupException(
        '$path.currency must be INR in this version, not $currency',
      );
    }
    return _KhataRecord(
      id: id,
      name: name,
      openingBalancePaise: openingBalancePaise,
      currency: currency,
      sortOrder: _expectInt(map, 'sort_order', path),
      createdAt: _expectTimestamp(map, 'created_at', path),
      updatedAt: _expectTimestamp(map, 'updated_at', path),
      deletedAt: _expectNullableTimestamp(map, 'deleted_at', path),
    );
  }

  _TransactionRecord _parseTransaction(Object? value, String path) {
    final Map<String, Object?> map = _expectObject(value, path);
    _expectExactKeys(map, _transactionKeys, path);
    final String type = _expectString(map, 'type', path, maxLength: 16);
    if (type != 'income' && type != 'expense') {
      throw LedgerBackupException(
        '$path.type must be income or expense, not $type',
      );
    }
    final int amountPaise = _expectInt(map, 'amount_paise', path);
    if (amountPaise <= 0) {
      throw LedgerBackupException('$path.amount_paise must be positive');
    }
    final Object? rawCategory = map['category_id'];
    if (rawCategory is! String) {
      throw LedgerBackupException('$path.category_id must be a string');
    }
    final String categoryId = rawCategory;
    if (categoryId.trim().isEmpty) {
      throw LedgerBackupException('$path.category_id must not be blank');
    }
    if (categoryId.runes.length > _maxCategoryLength) {
      throw LedgerBackupException(
        '$path.category_id must be at most $_maxCategoryLength characters',
      );
    }
    // Preserve raw descriptions, including whitespace, empty string and null.
    final String? rawDescription = _expectNullableText(
      map,
      'description',
      path,
      maxLength: _maxDescriptionLength,
    );
    final String? description = rawDescription;
    return _TransactionRecord(
      id: _expectId(map, 'id', path),
      khataId: _expectId(map, 'khata_id', path),
      type: type,
      amountPaise: amountPaise,
      categoryId: categoryId,
      description: description,
      occurredAt: _expectTimestamp(map, 'occurred_at', path),
      noteSessionId: _expectNullableText(
        map,
        'note_session_id',
        path,
        maxLength: _maxIdLength,
      ),
      createdAt: _expectTimestamp(map, 'created_at', path),
      updatedAt: _expectTimestamp(map, 'updated_at', path),
      deletedAt: _expectNullableTimestamp(map, 'deleted_at', path),
    );
  }
}

/// A JSON object, or a clear exception naming [path].
Map<String, Object?> _expectObject(Object? value, String path) {
  if (value is! Map<String, Object?>) {
    throw LedgerBackupException('$path must be a JSON object');
  }
  return value;
}

/// Both directions of the field-set check: an extra field is as much an error
/// as a missing one, so a file from a different writer cannot slip through.
void _expectExactKeys(
  Map<String, Object?> map,
  Set<String> expected,
  String path,
) {
  for (final String key in map.keys) {
    if (!expected.contains(key)) {
      throw LedgerBackupException('$path has unexpected field $key');
    }
  }
  for (final String key in expected) {
    if (!map.containsKey(key)) {
      throw LedgerBackupException('$path is missing field $key');
    }
  }
}

List<Object?> _expectList(Map<String, Object?> map, String key, String path) {
  final Object? value = map[key];
  if (value is! List<Object?>) {
    throw LedgerBackupException('$path.$key must be a JSON array');
  }
  return value;
}

/// A non-blank string of at most [maxLength] characters (Unicode code points,
/// the same unit SQLite's `length()` and the schema's description limit use).
String _expectString(
  Map<String, Object?> map,
  String key,
  String path, {
  int? maxLength,
}) {
  final Object? value = map[key];
  if (value is! String) {
    throw LedgerBackupException('$path.$key must be a string');
  }
  if (value.trim().isEmpty) {
    throw LedgerBackupException('$path.$key must not be blank');
  }
  if (maxLength != null && value.runes.length > maxLength) {
    throw LedgerBackupException(
      '$path.$key must be at most $maxLength characters',
    );
  }
  return value;
}

/// An optional free-text field: `null` (or absent-null) is fine, and a present
/// value may be any string within [maxLength] - including one that needs
/// trimming. Only the *type* is enforced here; `description` is the one field
/// with an extra rule, applied by the caller.
String? _expectNullableText(
  Map<String, Object?> map,
  String key,
  String path, {
  int? maxLength,
}) {
  final Object? value = map[key];
  if (value == null) return null;
  if (value is! String) {
    throw LedgerBackupException('$path.$key must be a string or null');
  }
  if (maxLength != null && value.runes.length > maxLength) {
    throw LedgerBackupException(
      '$path.$key must be at most $maxLength characters',
    );
  }
  return value;
}

/// An integer id: non-blank, not padded with whitespace, and short enough to be
/// a real client id rather than a blob.
String _expectId(Map<String, Object?> map, String key, String path) {
  final String value = _expectString(map, key, path, maxLength: _maxIdLength);
  if (value.trim() != value) {
    throw LedgerBackupException(
      '$path.$key must not start or end with whitespace',
    );
  }
  return value;
}

/// A JSON **integer**. `1000.0`, `1e3` and `"1000"` are all rejected: only an
/// `int` can carry paise without a rounding step.
int _expectInt(Map<String, Object?> map, String key, String path) {
  final Object? value = map[key];
  if (value is! int) {
    throw LedgerBackupException('$path.$key must be an integer');
  }
  return value;
}

String _expectTimestamp(Map<String, Object?> map, String key, String path) {
  final Object? value = map[key];
  if (value is! String) {
    throw LedgerBackupException('$path.$key must be a UTC timestamp');
  }
  return _checkTimestamp(value, '$path.$key');
}

String? _expectNullableTimestamp(
  Map<String, Object?> map,
  String key,
  String path,
) {
  if (map[key] == null) return null;
  return _expectTimestamp(map, key, path);
}

/// Parses one stored or supplied timestamp and returns it in the single
/// canonical form every writer uses (`toUtc().toIso8601String()`), so an
/// export can always be restored and re-exported unchanged.
String _checkTimestamp(String value, String path) {
  if (!_utcTimestampPattern.hasMatch(value)) {
    throw LedgerBackupException(
      '$path must be a UTC ISO-8601 timestamp ending in Z, not $value',
    );
  }
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null ||
      !parsed.isUtc ||
      parsed.year != int.parse(value.substring(0, 4)) ||
      parsed.month != int.parse(value.substring(5, 7)) ||
      parsed.day != int.parse(value.substring(8, 10)) ||
      parsed.hour != int.parse(value.substring(11, 13)) ||
      parsed.minute != int.parse(value.substring(14, 16)) ||
      parsed.second != int.parse(value.substring(17, 19))) {
    throw LedgerBackupException('$path is not a valid timestamp: $value');
  }
  return parsed.toUtc().toIso8601String();
}

/// [_checkTimestamp] for a nullable column read from the database.
String? _readTimestamp(String? value, String path) {
  if (value == null) return null;
  return _checkTimestamp(value, path);
}

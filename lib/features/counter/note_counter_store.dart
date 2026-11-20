// Offline, per-khata persistence for the S4 note counter.
//
// Scope, stated plainly: this file owns three tables of its own on the existing
// [LocalLedger] connection. It does not bump the schema version, does not touch
// `khatas` or `"transactions"`, and never creates a ledger entry: a saved note
// count is a saved session, not income, so no balance moves.
//
// The tables are created lazily with `CREATE TABLE IF NOT EXISTS`, so an
// existing database gains them without a migration and a fresh one gets them on
// the first load or save. All carry a `khata_id` that cascades from `khatas`
// and every statement is scoped by that id, so one khata's count can never be
// read into, or written over, another's.
//
// Besides the current count, the store also keeps *named-in-time* saved
// sessions ([saveSession], [listSessions], [deleteSession]): a timestamped
// snapshot the user explicitly asked to keep. Saving one never touches the
// current count, and restoring one goes through the screen, which writes the
// restored values back through [save] like any other edit.
//
// Archiving a khata does not delete its count or its saved sessions (the rows
// stay and [NoteCounterStore.load] still reads them); writes reject an archived
// khata instead of quietly filing the count under the personal khata.
//
// The JSON backup codec (lib/features/ledger/data/ledger_backup.dart) carries
// these rows in format version 2, so a backup restored on another phone brings
// the counts and the saved sessions along with the ledger.
//
// The ₹2,000 note is withdrawn: it has no row and no flag any more. Loading a
// khata repairs away any stored ₹2,000 quantity rows and the old
// `show_two_thousand` flag (in the state row and in saved sessions), so the
// retired note can never resurface - not kept, not silently ignored.

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../ledger/data/local_ledger.dart';

/// Largest quantity a single denomination accepts (docs/spec/data-model.md).
const int kMaxNoteQuantity = 99999;

/// The ₹1 coin, in paise. The counter's one-and-only coin row stores how many
/// rupees of coins the user counted there (1 coin = ₹1), so a quantity of 37
/// is ₹37 of coins - the user never enters a number of coins.
const int kCoinDenominationPaise = 100;

/// The ₹2,000 note was withdrawn from the counter. It has no row and cannot be
/// stored any more; the constant only names the retired value so the load-time
/// repair can find and remove stored rows for it.
const int kRetiredTwoThousandPaise = 200000;

/// Note denominations always offered, in paise, smallest first.
const List<int> kStandardDenominationsPaise = <int>[
  1000, // ₹10
  2000, // ₹20
  5000, // ₹50
  10000, // ₹100
  20000, // ₹200
  50000, // ₹500
];

/// Every storable denomination in paise, ascending.
///
/// Derived from the lists above so a denomination cannot be offered on
/// screen without also being storable, and the store cannot accept one the
/// screen will never show. The retired ₹2,000 note is deliberately absent, so
/// no code path can write or resurrect it any more.
final List<int> kAllDenominationsPaise = List<int>.unmodifiable(<int>[
  kCoinDenominationPaise,
  ...kStandardDenominationsPaise,
]);

/// The denomination a saved session starts on when it has none of its own.
const int kDefaultDenominationPaise = 50000; // ₹500, as in the mockup.

/// One khata's note-count session: how many of each denomination are counted.
///
/// [selectedDenominationPaise] and [showTwoThousand] are kept for API
/// compatibility with the retired selected-denomination UI: the screen always
/// passes the default selection and `false`, and the load-time repair clears
/// any stored ₹2,000 flag, so neither carries meaning any more.
///
/// Immutable: [quantities] is copied and unmodifiable, and every value is
/// validated in the constructor, so a snapshot is either a real count or an
/// error - never a half-counted map that would be saved as if it were complete.
///
/// [quantities] always has one entry per known denomination, including zero
/// (the seven storable denominations: six notes and the ₹1 coin): "not counted
/// yet" and "counted zero" are the same stored value, which is what lets a
/// restart show the same screen it was left on.
final class NoteCounterSnapshot {
  /// Validates and copies [quantities].
  ///
  /// Throws [ArgumentError] for a denomination the counter does not know, a
  /// quantity that is not an integer in 0…[kMaxNoteQuantity], or a selected
  /// denomination the counter cannot show. Nothing is guessed or clamped here;
  /// [NoteCounterStore.load] repairs unreadable *stored* rows instead, and
  /// reports that it did.
  NoteCounterSnapshot({
    required Map<int, int> quantities,
    required int selectedDenominationPaise,
    required this.showTwoThousand,
    this.hasUnreadableRows = false,
  }) : quantities = Map<int, int>.unmodifiable(
         _validatedQuantities(quantities),
       ),
       selectedDenominationPaise = _validatedSelection(
         selectedDenominationPaise,
       );

  /// Quantity counted per denomination in paise.
  final Map<int, int> quantities;

  /// The denomination the screen has selected, in paise.
  final int selectedDenominationPaise;

  /// Kept for API compatibility; always `false` on load - the load-time
  /// repair clears the retired ₹2,000 flag.
  final bool showTwoThousand;

  /// True when [NoteCounterStore.load] had to skip or adjust stored rows that
  /// this version cannot represent. The caller shows that instead of pretending
  /// the count was read cleanly.
  final bool hasUnreadableRows;

  /// The count for [denominationPaise], or 0 for a denomination that is not
  /// counted.
  int quantityFor(int denominationPaise) => quantities[denominationPaise] ?? 0;

  /// Value of every counted note in paise.
  int get totalPaise => quantities.entries.fold<int>(
    0,
    (int sum, MapEntry<int, int> entry) => sum + entry.key * entry.value,
  );

  /// An empty count on the default denomination.
  NoteCounterSnapshot.empty()
    : this(
        quantities: const <int, int>{},
        selectedDenominationPaise: kDefaultDenominationPaise,
        showTwoThousand: false,
      );

  /// The same session with the named values replaced. [hasUnreadableRows]
  /// survives a copy, because "the stored rows were odd" stays true until a
  /// save rewrites them.
  NoteCounterSnapshot copyWith({
    Map<int, int>? quantities,
    int? selectedDenominationPaise,
    bool? showTwoThousand,
    bool? hasUnreadableRows,
  }) => NoteCounterSnapshot(
    quantities: quantities ?? this.quantities,
    selectedDenominationPaise:
        selectedDenominationPaise ?? this.selectedDenominationPaise,
    showTwoThousand: showTwoThousand ?? this.showTwoThousand,
    hasUnreadableRows: hasUnreadableRows ?? this.hasUnreadableRows,
  );

  /// The same session with [denominationPaise] set to [quantity].
  NoteCounterSnapshot withQuantity(int denominationPaise, int quantity) =>
      copyWith(
        quantities: <int, int>{...quantities, denominationPaise: quantity},
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! NoteCounterSnapshot) return false;
    if (other.selectedDenominationPaise != selectedDenominationPaise ||
        other.showTwoThousand != showTwoThousand ||
        other.hasUnreadableRows != hasUnreadableRows ||
        other.quantities.length != quantities.length) {
      return false;
    }
    for (final MapEntry<int, int> entry in quantities.entries) {
      if (other.quantities[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    selectedDenominationPaise,
    showTwoThousand,
    hasUnreadableRows,
    Object.hashAll(kAllDenominationsPaise.map((int d) => quantities[d])),
  );

  @override
  String toString() =>
      'NoteCounterSnapshot(quantities: $quantities, '
      'selectedDenominationPaise: $selectedDenominationPaise, '
      'showTwoThousand: $showTwoThousand)';
}

/// One saved count for a khata: a timestamped snapshot the user asked to keep.
///
/// Immutable like [NoteCounterSnapshot]. [savedAt] is UTC; callers render it in
/// device-local time. [snapshot] carries the quantities as they were when the
/// user saved.
final class SavedNoteCount {
  const SavedNoteCount({
    required this.id,
    required this.khataId,
    required this.savedAt,
    required this.snapshot,
  });

  final String id;
  final String khataId;

  /// When the count was saved. Stored as UTC ISO-8601.
  final DateTime savedAt;

  final NoteCounterSnapshot snapshot;

  /// Value of every counted note in paise.
  int get totalPaise => snapshot.totalPaise;
}

Map<int, int> _validatedQuantities(Map<int, int> quantities) {
  for (final MapEntry<int, int> entry in quantities.entries) {
    if (!kAllDenominationsPaise.contains(entry.key)) {
      throw ArgumentError.value(
        entry.key,
        'quantities',
        'Unknown note denomination in paise',
      );
    }
    if (entry.value < 0 || entry.value > kMaxNoteQuantity) {
      throw ArgumentError.value(
        entry.value,
        'quantities',
        'Quantity must be an integer between 0 and $kMaxNoteQuantity',
      );
    }
  }
  return <int, int>{
    for (final int denomination in kAllDenominationsPaise)
      denomination: quantities[denomination] ?? 0,
  };
}

int _validatedSelection(int denominationPaise) {
  if (!kAllDenominationsPaise.contains(denominationPaise)) {
    throw ArgumentError.value(
      denominationPaise,
      'selectedDenominationPaise',
      'Unknown note denomination in paise',
    );
  }
  return denominationPaise;
}

/// Reads and writes the note-count session of one khata.
///
/// One instance can serve the whole app. Every [save] is queued, writes never
/// overlap, and only the newest snapshot per khata is written, so a burst of
/// taps - or a khata switch in the middle of one - cannot land out of order or
/// leave an older value behind. A caller whose save was superseded still
/// completes successfully once a newer or equal write has landed: the latest
/// input wins, and no pending update is quietly dropped.
class NoteCounterStore {
  NoteCounterStore(this._ledger);

  final LocalLedger _ledger;

  /// Created once per store: an additive set of tables, no schema version
  /// change and no migration. Cleared after a failure so a retry can succeed.
  Future<void>? _schema;

  /// One id per saved session. Reuses the app's existing UUID dependency; an
  /// id collision would violate the primary key and fail loudly instead of
  /// overwriting another session.
  static const Uuid _uuid = Uuid();

  /// Newest unwritten snapshot per khata, plus the callers waiting for it.
  final Map<String, _PendingSave> _pending = <String, _PendingSave>{};

  /// The running flush, if any. Loads settle it first so a switch never reads a
  /// value the user has already replaced.
  Future<void>? _flushing;

  static final String _createQuantitiesTable =
      'CREATE TABLE IF NOT EXISTS note_counter_quantities ('
      'khata_id TEXT NOT NULL REFERENCES khatas(id) ON DELETE CASCADE, '
      'denomination_paise INTEGER NOT NULL '
      "CHECK (typeof(denomination_paise) = 'integer'), "
      'quantity INTEGER NOT NULL '
      "CHECK (typeof(quantity) = 'integer' AND quantity BETWEEN 0 AND "
      '$kMaxNoteQuantity), '
      'updated_at TEXT NOT NULL, '
      'PRIMARY KEY (khata_id, denomination_paise))';

  static const String _createStateTable =
      'CREATE TABLE IF NOT EXISTS note_counter_state ('
      'khata_id TEXT PRIMARY KEY NOT NULL '
      'REFERENCES khatas(id) ON DELETE CASCADE, '
      'selected_denomination_paise INTEGER NOT NULL '
      "CHECK (typeof(selected_denomination_paise) = 'integer'), "
      'show_two_thousand INTEGER NOT NULL '
      'CHECK (show_two_thousand IN (0, 1)), '
      'updated_at TEXT NOT NULL)';

  static const String _createSavedSessionsTable =
      'CREATE TABLE IF NOT EXISTS note_counter_saved_sessions ('
      'id TEXT PRIMARY KEY NOT NULL, '
      'khata_id TEXT NOT NULL '
      'REFERENCES khatas(id) ON DELETE CASCADE, '
      'saved_at TEXT NOT NULL, '
      'quantities_json TEXT NOT NULL, '
      'selected_denomination_paise INTEGER NOT NULL '
      "CHECK (typeof(selected_denomination_paise) = 'integer'), "
      'show_two_thousand INTEGER NOT NULL '
      'CHECK (show_two_thousand IN (0, 1)))';

  static const String _insertSession =
      'INSERT INTO note_counter_saved_sessions '
      '(id, khata_id, saved_at, quantities_json, '
      'selected_denomination_paise, show_two_thousand) '
      'VALUES (?, ?, ?, ?, ?, ?)';

  /// Newest first; `rowid` breaks same-millisecond ties deterministically.
  static const String _listSessions =
      'SELECT id, saved_at, quantities_json, '
      'selected_denomination_paise, show_two_thousand '
      'FROM note_counter_saved_sessions '
      'WHERE khata_id = ? '
      'ORDER BY saved_at DESC, rowid DESC';

  static const String _deleteSession =
      'DELETE FROM note_counter_saved_sessions '
      'WHERE khata_id = ? AND id = ?';

  static const String _upsertQuantity =
      'INSERT INTO note_counter_quantities '
      '(khata_id, denomination_paise, quantity, updated_at) '
      'VALUES (?, ?, ?, ?) '
      'ON CONFLICT(khata_id, denomination_paise) DO UPDATE SET '
      'quantity = excluded.quantity, updated_at = excluded.updated_at';

  static const String _upsertState =
      'INSERT INTO note_counter_state '
      '(khata_id, selected_denomination_paise, show_two_thousand, updated_at) '
      'VALUES (?, ?, ?, ?) '
      'ON CONFLICT(khata_id) DO UPDATE SET '
      'selected_denomination_paise = '
      'excluded.selected_denomination_paise, '
      'show_two_thousand = excluded.show_two_thousand, '
      'updated_at = excluded.updated_at';

  /// Drops rows this version can never display, for one khata only.
  ///
  /// The same transaction has just written every known denomination, so nothing
  /// readable is lost: what this removes is a denomination the UI cannot show
  /// and would otherwise warn about on every load, forever.
  static final String _deleteUnknownDenominations =
      'DELETE FROM note_counter_quantities WHERE khata_id = ? '
      'AND denomination_paise NOT IN ('
      '${kAllDenominationsPaise.join(', ')})';

  /// Reads the saved count for [khataId], or an empty count when nothing has
  /// been saved for it yet.
  ///
  /// Any save still queued for that khata is settled first, so a switch or a
  /// restart never shows a value the user has already replaced.
  ///
  /// The khata must exist. An archived khata still loads - archiving keeps its
  /// rows - but [save] rejects it. A blank or unknown id throws
  /// [KhataNotFoundException]; there is no fallback to the personal khata, so a
  /// stale id can never display one ledger's count as another's.
  Future<NoteCounterSnapshot> load(String khataId) async {
    if (khataId.trim().isEmpty) throw KhataNotFoundException(khataId);
    await _settlePendingWrites();
    await _ensureSchema();
    // One read transaction for the rows and the selection: a commit from
    // another writer cannot be split across the two queries, so what comes back
    // is a session that really existed on disk - never half of one save and
    // half of the next.
    return _ledger.transaction(() => _readSnapshot(khataId));
  }

  Future<NoteCounterSnapshot> _readSnapshot(String khataId) async {
    if (!await _khataExists(khataId)) throw KhataNotFoundException(khataId);
    final bool repaired = await _repairRetiredTwoThousand(khataId);

    final List<QueryRow> quantityRows = await _ledger
        .customSelect(
          'SELECT denomination_paise, quantity FROM note_counter_quantities '
          'WHERE khata_id = ?',
          variables: <Variable<Object>>[Variable<String>(khataId)],
        )
        .get();

    bool unreadable = repaired;
    final Map<int, int> quantities = <int, int>{};
    for (final QueryRow row in quantityRows) {
      try {
        final int denomination = row.read<int>('denomination_paise');
        final int stored = row.read<int>('quantity');
        if (!kAllDenominationsPaise.contains(denomination)) {
          unreadable = true;
          continue;
        }
        if (stored < 0 || stored > kMaxNoteQuantity) {
          // A quantity outside the documented range cannot be shown as money.
          // It is pinned to the nearest legal bound *and* reported, so the
          // caller never pretends the stored count was read as it was.
          unreadable = true;
          quantities[denomination] = stored < 0 ? 0 : kMaxNoteQuantity;
          continue;
        }
        quantities[denomination] = stored;
      } catch (_) {
        // A row whose columns are not the integers this table declares (a
        // hand-edited or foreign database) is skipped, not guessed at.
        unreadable = true;
      }
    }

    int selected = kDefaultDenominationPaise;
    bool showTwoThousand = false;
    final List<QueryRow> stateRows = await _ledger
        .customSelect(
          'SELECT selected_denomination_paise, show_two_thousand '
          'FROM note_counter_state WHERE khata_id = ?',
          variables: <Variable<Object>>[Variable<String>(khataId)],
        )
        .get();
    if (stateRows.isNotEmpty) {
      final QueryRow row = stateRows.single;
      try {
        final int storedSelection = row.read<int>(
          'selected_denomination_paise',
        );
        if (kAllDenominationsPaise.contains(storedSelection)) {
          selected = storedSelection;
        } else {
          unreadable = true;
        }
      } catch (_) {
        unreadable = true;
      }
      try {
        final int storedVisibility = row.read<int>('show_two_thousand');
        if (storedVisibility == 1) {
          showTwoThousand = true;
        } else if (storedVisibility != 0) {
          unreadable = true;
        }
      } catch (_) {
        unreadable = true;
      }
    }

    return NoteCounterSnapshot(
      quantities: quantities,
      selectedDenominationPaise: selected,
      showTwoThousand: showTwoThousand,
      hasUnreadableRows: unreadable,
    );
  }

  /// Retired ₹2,000 note: repairs away any stored quantity rows and the old
  /// `show_two_thousand` flag, for [khataId]'s current count and for its saved
  /// sessions. Runs at the start of every load (and before listing sessions),
  /// inside the same transaction, so the retired note can never resurface.
  ///
  /// This is a deliberate, active repair - never a kept value, never a silent
  /// skip: the quantities are deleted and the flags reset to 0, and saved
  /// sessions are rewritten without the ₹2,000 entry. Other denominations,
  /// quantities and timestamps are carried through unchanged. Only rows this
  /// khata owns are touched. Idempotent: a phone without ₹2,000 data writes
  /// nothing.
  /// Returns true when anything was repaired, so the caller can report it
  /// instead of pretending the stored rows were read as they were.
  Future<bool> _repairRetiredTwoThousand(String khataId) async {
    bool changed = false;
    final List<QueryRow> retiredQty = await _ledger
        .customSelect(
          'SELECT COUNT(*) AS c FROM note_counter_quantities '
          'WHERE khata_id = ? AND denomination_paise = ?',
          variables: <Variable<Object>>[
            Variable<String>(khataId),
            const Variable<int>(kRetiredTwoThousandPaise),
          ],
        )
        .get();
    changed = retiredQty.single.read<int>('c') > 0;
    final List<QueryRow> retiredState = await _ledger
        .customSelect(
          'SELECT COUNT(*) AS c FROM note_counter_state '
          'WHERE khata_id = ? AND (show_two_thousand != 0 '
          'OR selected_denomination_paise = ?)',
          variables: <Variable<Object>>[
            Variable<String>(khataId),
            const Variable<int>(kRetiredTwoThousandPaise),
          ],
        )
        .get();
    changed = changed || retiredState.single.read<int>('c') > 0;
    await _ledger.customStatement(
      'DELETE FROM note_counter_quantities '
      'WHERE khata_id = ? AND denomination_paise = ?',
      <Object>[khataId, kRetiredTwoThousandPaise],
    );
    await _ledger.customStatement(
      'UPDATE note_counter_state SET show_two_thousand = 0 '
      'WHERE khata_id = ? AND show_two_thousand != 0',
      <Object>[khataId],
    );
    await _ledger.customStatement(
      'UPDATE note_counter_state SET selected_denomination_paise = ? '
      'WHERE khata_id = ? AND selected_denomination_paise = ?',
      <Object>[kDefaultDenominationPaise, khataId, kRetiredTwoThousandPaise],
    );
    final List<QueryRow> sessions = await _ledger
        .customSelect(
          'SELECT id, quantities_json, selected_denomination_paise, '
          'show_two_thousand FROM note_counter_saved_sessions '
          'WHERE khata_id = ?',
          variables: <Variable<Object>>[Variable<String>(khataId)],
        )
        .get();
    for (final QueryRow row in sessions) {
      final String id = row.read<String>('id');
      try {
        final Object? decoded = jsonDecode(row.read<String>('quantities_json'));
        if (decoded is! Map<dynamic, dynamic>) {
          // Corrupt JSON is not decoded or rewritten here; the session-row
          // reader reports such rows as unreadable instead of guessing.
          continue;
        }
        final Map<String, int> kept = <String, int>{};
        bool dropped = false;
        bool unhandled = false;
        for (final MapEntry<dynamic, dynamic> entry in decoded.entries) {
          final String key = entry.key.toString();
          if (key == '$kRetiredTwoThousandPaise') {
            dropped = true;
            continue;
          }
          final Object? value = entry.value;
          if (value is! int) {
            // Not a value this code rewrites or invents a substitute for;
            // leave the whole row for the normal reader to report.
            unhandled = true;
            break;
          }
          kept[key] = value;
        }
        if (unhandled) continue;
        int selected = row.read<int>('selected_denomination_paise');
        int visibility = row.read<int>('show_two_thousand');
        final bool selectionRepaired = selected == kRetiredTwoThousandPaise;
        if (!dropped && !selectionRepaired && visibility == 0) continue;
        changed = true;
        if (selectionRepaired) selected = kDefaultDenominationPaise;
        if (visibility != 0) visibility = 0;
        await _ledger.customStatement(
          'UPDATE note_counter_saved_sessions '
          'SET quantities_json = ?, selected_denomination_paise = ?, '
          'show_two_thousand = ? '
          'WHERE khata_id = ? AND id = ?',
          <Object>[jsonEncode(kept), selected, visibility, khataId, id],
        );
      } catch (_) {
        // A row that cannot be read is left alone; the session-row reader
        // reports such rows as unreadable instead of guessing at them.
      }
    }
    return changed;
  }

  /// Queues [snapshot] as the newest count for [khataId].
  ///
  /// The returned future completes once a write at least as new as this
  /// snapshot has landed - so a caller whose save was superseded still sees
  /// success, and the newest value is the one on disk. A failed write fails
  /// every queued caller with its cause; success is never reported for a write
  /// that did not happen.
  ///
  /// Completes with [KhataNotFoundException] when the id is blank, unknown or
  /// archived: nothing is written and the personal khata is never substituted.
  Future<void> save(String khataId, NoteCounterSnapshot snapshot) {
    if (khataId.trim().isEmpty) {
      return Future<void>.error(KhataNotFoundException(khataId));
    }
    final Completer<void> waiter = Completer<void>();
    final _PendingSave? existing = _pending[khataId];
    if (existing == null) {
      _pending[khataId] = _PendingSave(snapshot, waiter);
    } else {
      existing.snapshot = snapshot;
      existing.waiters.add(waiter);
    }
    _startFlushing();
    return waiter.future;
  }

  /// Stores [snapshot] as a timestamped saved session for [khataId] and
  /// returns it. Saved sessions stand alone: saving one never rewrites the
  /// current count, and restoring one goes through the screen, which writes
  /// the restored values back through [save] like any other edit.
  ///
  /// Throws [ArgumentError] for an empty count (every quantity zero): a saved
  /// session exists so a real count can be restored later, and an all-zero
  /// row in the list could only confuse. Throws [KhataNotFoundException] for
  /// a blank, unknown or archived khata - a saved session is never filed
  /// under the personal khata by accident.
  Future<SavedNoteCount> saveSession(
    String khataId,
    NoteCounterSnapshot snapshot,
  ) async {
    if (khataId.trim().isEmpty) throw KhataNotFoundException(khataId);
    if (snapshot.totalPaise <= 0) {
      throw ArgumentError.value(
        snapshot,
        'snapshot',
        'Cannot save an empty count',
      );
    }
    await _ensureSchema();
    final String id = _uuid.v4();
    final String now = _utcMillisIso(DateTime.now().toUtc());
    final String quantitiesJson = jsonEncode(<String, int>{
      for (final MapEntry<int, int> entry in snapshot.quantities.entries)
        entry.key.toString(): entry.value,
    });
    // One transaction with the khata check, so an archived khata cannot gain
    // a saved session any more than it can gain count rows.
    await _ledger.transaction(() async {
      if (!await _khataIsActive(khataId)) {
        throw KhataNotFoundException(khataId);
      }
      await _ledger.customStatement(_insertSession, <Object>[
        id,
        khataId,
        now,
        quantitiesJson,
        snapshot.selectedDenominationPaise,
        snapshot.showTwoThousand ? 1 : 0,
      ]);
    });
    return SavedNoteCount(
      id: id,
      khataId: khataId,
      savedAt: DateTime.parse(now),
      snapshot: snapshot,
    );
  }

  /// Lists the saved sessions for [khataId], newest first.
  ///
  /// An archived khata's sessions stay readable - archiving keeps rows. A
  /// blank or unknown id throws [KhataNotFoundException]. A row this version
  /// cannot represent (corrupt JSON, an unknown denomination, an out-of-range
  /// value) is skipped rather than displayed with numbers this version
  /// invented; the row stays on disk until [deleteSession] removes it.
  Future<List<SavedNoteCount>> listSessions(String khataId) async {
    if (khataId.trim().isEmpty) throw KhataNotFoundException(khataId);
    await _ensureSchema();
    if (!await _khataExists(khataId)) throw KhataNotFoundException(khataId);
    // Repair before reading, so the sheet never has to render a session that
    // still carries the retired ₹2,000 note. One transaction, like a load.
    return _ledger.transaction(() async {
      await _repairRetiredTwoThousand(khataId);
      final List<QueryRow> rows = await _ledger
          .customSelect(
            _listSessions,
            variables: <Variable<Object>>[Variable<String>(khataId)],
          )
          .get();
      final List<SavedNoteCount> sessions = <SavedNoteCount>[];
      for (final QueryRow row in rows) {
        final SavedNoteCount? parsed = _parseSessionRow(row, khataId);
        if (parsed != null) sessions.add(parsed);
      }
      return sessions;
    });
  }

  /// Removes one saved session, scoped by [khataId] so one khata's sheet can
  /// never delete another's rows. Deleting a session that is already gone is
  /// a no-op, not an error. The current count is untouched.
  Future<void> deleteSession(String khataId, String sessionId) async {
    if (khataId.trim().isEmpty) throw KhataNotFoundException(khataId);
    if (sessionId.trim().isEmpty) {
      throw ArgumentError.value(sessionId, 'sessionId', 'Cannot be blank');
    }
    await _ensureSchema();
    await _ledger.customStatement(_deleteSession, <Object>[khataId, sessionId]);
  }

  /// Rebuilds a saved session from its row, or null when this version cannot
  /// represent it. Nothing is guessed: an unreadable row is skipped whole.
  SavedNoteCount? _parseSessionRow(QueryRow row, String khataId) {
    try {
      final String id = row.read<String>('id');
      final DateTime savedAt = DateTime.parse(row.read<String>('saved_at'));
      final String quantitiesJson = row.read<String>('quantities_json');
      final int selected = row.read<int>('selected_denomination_paise');
      final int visibility = row.read<int>('show_two_thousand');
      if (visibility != 0 && visibility != 1) return null;
      final Object? decoded = jsonDecode(quantitiesJson);
      if (decoded is! Map<String, dynamic>) return null;
      final Map<int, int> quantities = <int, int>{};
      for (final MapEntry<String, dynamic> entry in decoded.entries) {
        final int? denomination = int.tryParse(entry.key);
        final Object? value = entry.value;
        if (denomination == null) return null;
        if (!kAllDenominationsPaise.contains(denomination)) return null;
        if (value is! int || value < 0 || value > kMaxNoteQuantity) {
          return null;
        }
        quantities[denomination] = value;
      }
      return SavedNoteCount(
        id: id,
        khataId: khataId,
        savedAt: savedAt.toUtc(),
        snapshot: NoteCounterSnapshot(
          quantities: quantities,
          selectedDenominationPaise: selected,
          showTwoThousand: visibility == 1,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  void _startFlushing() {
    if (_flushing != null) return;
    final Future<void> run = _flush();
    _flushing = run;
    // `_flush` reports every failure to the save that caused it, so this future
    // never completes with an error; unawaited, it is still safe to drop.
    unawaited(
      run.whenComplete(() {
        if (identical(_flushing, run)) _flushing = null;
        if (_pending.isNotEmpty) _startFlushing();
      }),
    );
  }

  Future<void> _flush() async {
    try {
      while (_pending.isNotEmpty) {
        final List<String> ids = _pending.keys.toList(growable: false);
        for (final String khataId in ids) {
          final _PendingSave? pending = _pending.remove(khataId);
          if (pending == null) continue;
          await _writePending(khataId, pending);
        }
      }
    } catch (error, stack) {
      // Nothing may escape: this future has no single caller to receive it, and
      // an escaping error would surface as an unhandled async error. Saves are
      // normally failed one by one in _writePending; this only runs if the loop
      // itself breaks, and it still fails every caller instead of hanging them.
      _failAllWaiters(error, stack);
    }
  }

  /// Fails every queued caller, for the case where the flush loop itself broke.
  void _failAllWaiters(Object error, StackTrace stack) {
    final List<_PendingSave> pending = _pending.values.toList(growable: false);
    _pending.clear();
    for (final _PendingSave save in pending) {
      for (final Completer<void> waiter in save.waiters) {
        if (waiter.isCompleted) continue;
        waiter.completeError(error, stack);
      }
    }
  }

  Future<void> _writePending(String khataId, _PendingSave pending) async {
    final NoteCounterSnapshot snapshot = pending.snapshot;
    Object? failure;
    StackTrace? failureStack;
    try {
      await _write(khataId, snapshot);
    } catch (error, stack) {
      failure = error;
      failureStack = stack;
    }
    for (final Completer<void> waiter in pending.waiters) {
      if (waiter.isCompleted) continue;
      if (failure == null) {
        waiter.complete();
      } else {
        waiter.completeError(failure, failureStack);
      }
    }
  }

  Future<void> _write(String khataId, NoteCounterSnapshot snapshot) async {
    await _ensureSchema();
    // One transaction for the whole snapshot: a reader can never see a
    // half-written count, and an archived khata cannot be written at all.
    await _ledger.transaction(() async {
      if (!await _khataIsActive(khataId)) {
        throw KhataNotFoundException(khataId);
      }
      final String now = DateTime.now().toUtc().toIso8601String();
      for (final MapEntry<int, int> entry in snapshot.quantities.entries) {
        await _ledger.customStatement(_upsertQuantity, <Object>[
          khataId,
          entry.key,
          entry.value,
          now,
        ]);
      }
      // "New count" writes zeros through this same path: clearing a khata
      // persists zero quantities instead of deleting rows, so a cleared count
      // stays a stored session and no destructive sweep is needed.
      await _ledger.customStatement(_upsertState, <Object>[
        khataId,
        snapshot.selectedDenominationPaise,
        snapshot.showTwoThousand ? 1 : 0,
        now,
      ]);
      await _ledger.customStatement(_deleteUnknownDenominations, <Object>[
        khataId,
      ]);
    });
  }

  /// Fixed-width UTC ISO-8601 with milliseconds, so a lexical ordering of
  /// stored values is also a chronological one. `DateTime.toIso8601String()`
  /// drops the fraction on whole seconds, which would sort those rows before
  /// same-second rows that carry one.
  static String _utcMillisIso(DateTime utc) {
    String two(int value) => value.toString().padLeft(2, '0');
    String three(int value) => value.toString().padLeft(3, '0');
    return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-'
        '${two(utc.day)}T${two(utc.hour)}:${two(utc.minute)}:'
        '${two(utc.second)}.${three(utc.millisecond)}Z';
  }

  /// Waits for the running flush, if any. A load that races a save reads the
  /// value the user last chose instead of the one before it.
  Future<void> _settlePendingWrites() async {
    final Future<void>? flushing = _flushing;
    if (flushing == null) return;
    await flushing;
  }

  Future<void> _ensureSchema() async {
    final Future<void>? ready = _schema;
    if (ready != null) {
      await ready;
      return;
    }
    final Future<void> created = _createSchema();
    _schema = created;
    try {
      await created;
    } catch (_) {
      // A failed CREATE must not poison the store: clear it so the retry the
      // screen offers can actually run the statements again.
      if (identical(_schema, created)) _schema = null;
      rethrow;
    }
  }

  /// Creates the three note counter tables if they do not exist yet.
  ///
  /// Public for the backup restore, which must be able to land the counter
  /// section on a phone whose counter was never opened (the tables are
  /// otherwise created lazily on first use). Creates nothing else.
  Future<void> ensureTables() => _ensureSchema();

  Future<void> _createSchema() async {
    await _ledger.customStatement(_createQuantitiesTable);
    await _ledger.customStatement(_createStateTable);
    await _ledger.customStatement(_createSavedSessionsTable);
  }

  /// Any khata row, archived or not: archiving keeps the count readable.
  Future<bool> _khataExists(String khataId) async {
    final List<QueryRow> rows = await _ledger
        .customSelect(
          'SELECT id FROM khatas WHERE id = ?',
          variables: <Variable<Object>>[Variable<String>(khataId)],
        )
        .get();
    return rows.isNotEmpty;
  }

  /// An active khata only: writing to an archived one is rejected.
  Future<bool> _khataIsActive(String khataId) async {
    final List<QueryRow> rows = await _ledger
        .customSelect(
          'SELECT id FROM khatas WHERE id = ? AND deleted_at IS NULL',
          variables: <Variable<Object>>[Variable<String>(khataId)],
        )
        .get();
    return rows.isNotEmpty;
  }
}

/// One khata's newest snapshot and everyone waiting for it to land.
final class _PendingSave {
  _PendingSave(this.snapshot, Completer<void> waiter)
    : waiters = <Completer<void>>[waiter];

  NoteCounterSnapshot snapshot;
  final List<Completer<void>> waiters;
}

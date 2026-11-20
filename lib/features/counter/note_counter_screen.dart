import 'dart:async';

// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../profile/settings_screen.dart';
import 'note_counter_store.dart';
import 'saved_sessions_sheet.dart';

// The denomination constants come from the store, which is their single
// definition - this screen imports them instead of duplicating them.

/// S4 - Note Counter. See docs/spec/screens.md#s4--note-counter.
///
/// Counts physical notes by denomination: pick a denomination, enter how
/// many you hold, read the per-denomination total and the grand total. All
/// arithmetic is integer paise - no doubles anywhere - and money text goes
/// through [AppStrings].
///
/// Two modes:
///
/// * **In-memory** (the default, no [store]/[khataId]) - exactly the standalone
///   counter: nothing is persisted, nothing leaves the screen, and the
///   "nothing is saved" hint is shown.
/// * **Per-khata** (both [store] and [khataId]) - the count for that khata is
///   loaded on open and every edit (quantities, selected denomination, ₹2,000
///   visibility) is written back through the store on a coalescing write
///   queue, so a fast tap sequence is never dropped and never blocks the UI.
///   A new `khataId` reloads and never carries quantities over.
///
/// In both modes the screen never writes a ledger transaction. The optional
/// [onAddToKhata] action hands the Grand Total to its caller as integer paise
/// plus a short note - the caller opens the entry form for the user to review
/// and save, because cash already counted here may already be inside the
/// opening balance. `Save` keeps a timestamped snapshot of a non-empty count
/// as a per-khata saved session; saved sessions are listed, restored and
/// deleted from the sessions sheet. Counter data lives only in the counter
/// tables - it is **not** part of the JSON backup yet, and the screen says
/// so rather than implying it travels with one.
class NoteCounterScreen extends StatefulWidget {
  const NoteCounterScreen({
    super.key,
    this.language = AppLanguage.en,
    this.store,
    this.khataId,
    this.onAddToKhata,
  });

  /// Display language for every visible string on this screen.
  final AppLanguage language;

  /// The store for per-khata counts. Required together with [khataId].
  final NoteCounterStore? store;

  /// The khata whose count to show. Required together with [store].
  final String? khataId;

  /// When set, an "Add to khata as income" button appears once the Grand
  /// Total is above zero. Called with integer paise and a short note; this
  /// screen never writes a transaction itself.
  final void Function(int amountPaise, String note)? onAddToKhata;

  @override
  State<NoteCounterScreen> createState() => _NoteCounterScreenState();
}

/// Local en/bn pairs for counter copy the shared `AppString` set does not
/// carry. `app_strings.dart` belongs to the shared core and is not edited
/// here, so these travel with the feature like the screen does.
class _Copy {
  const _Copy(this.language);

  final AppLanguage language;

  bool get _bn => language == AppLanguage.bn;

  String get currentNote => _bn ? 'বর্তমান নোট' : 'CURRENT NOTE';

  String get chooseNote =>
      _bn ? 'নিচ থেকে নোট বেছে নিন' : 'Choose a note below';

  String get savedHint => _bn
      ? 'এই খাতার জন্য এই ডিভাইসে সংরক্ষিত — লেজার এন্ট্রি নয়, এখনো ব্যাকআপে আসে না'
      : 'Saved on this device for this khata - not a ledger entry and not in a backup yet';

  String get loading => _bn
      ? 'এই খাতার সংরক্ষিত গণনা লোড হচ্ছে…'
      : 'Loading the saved count for this khata…';

  String loadFailedReason(Object? error) => error is KhataNotFoundException
      ? (_bn ? 'খাতাটি নেই বা সংরক্ষিত (আর্কাইভ) হয়েছে' : 'this khata is missing or archived')
      : (_bn ? 'সংরক্ষিত গণনা পড়া যায়নি' : 'the saved count could not be read');

  String get loadFailedTitle => _bn
      ? 'সংরক্ষিত গণনা লোড করা যায়নি'
      : 'Could not load the saved count';

  String saveFailedReason(Object? error) => error is KhataNotFoundException
      ? (_bn ? 'খাতাটি নেই বা সংরক্ষিত (আর্কাইভ) হয়েছে' : 'this khata is missing or archived')
      : (_bn ? 'গণনা সংরক্ষণ করা যায়নি' : 'the saved count could not be stored');

  String get noChangesYet =>
      _bn ? 'এখনো সংরক্ষণের কিছু নেই' : 'No changes to save yet';

  String get saving => _bn ? 'সংরক্ষণ হচ্ছে…' : 'Saving…';

  String get savedOnDevice =>
      _bn ? 'এই ডিভাইসে সংরক্ষিত' : 'Saved on this device';

  String get notSaved => _bn ? 'সংরক্ষণ হয়নি' : 'Not saved';

  String get unreadableRows => _bn
      ? 'কিছু সংরক্ষিত নোট পড়া যায়নি, সেগুলো বাদ দেওয়া হয়েছে। পরের যেকোনো পরিবর্তনে এই খাতার গণনা আবার লেখা হবে।'
      : 'Some saved notes could not be read and were skipped. The next change rewrites this khata\'s count.';

  String get savedSessions => _bn ? 'সংরক্ষিত গণনা' : 'Saved sessions';

  String get newCountConfirmTitle => _bn
      ? 'নতুন গণনা শুরু করবেন?'
      : 'Start a new count?';

  String get newCountConfirmBody => _bn
      ? 'স্ক্রিনের বর্তমান গণনা মুছে যাবে। সংরক্ষিত গণনা তালিকায় থেকে যাবে।'
      : 'The count on screen will be cleared. Saved sessions stay in the list.';

  String get copySummary => _bn ? 'সারসংক্ষেপ কপি করুন' : 'Copy summary';

  String get summaryCopied => _bn
      ? 'সারসংক্ষেপ ক্লিপবোর্ডে কপি হয়েছে'
      : 'Summary copied to clipboard';

  String get addToKhata =>
      _bn ? 'খাতায় আয় হিসেবে যোগ করুন' : 'Add to khata as income';

  String get noteCounterWord => _bn ? 'নোট গণনা' : 'Note counter';

  String get sessionSaved => _bn ? 'গণনা সংরক্ষিত হয়েছে' : 'Count saved';

  String get sessionSaveFailed => _bn
      ? 'গণনা সংরক্ষণ করা যায়নি। আবার চেষ্টা করুন।'
      : 'Could not save the count. Try again.';

  String get sessionRestored =>
      _bn ? 'সংরক্ষিত গণনা ফিরিয়ে আনা হয়েছে' : 'Saved count restored';

  String hiddenTwoThousand(AppStrings strings, int quantity) => _bn
      ? '₹২,০০০ × ${strings.number(quantity)} নোট রয়েছে (নোটটি লুকানো)'
      : 'Includes ₹2,000 × $quantity (denomination hidden)';

  String quantityFieldLabel(AppStrings strings, int denominationPaise) => _bn
      ? '${strings.money(denominationPaise)} নোটের সংখ্যা'
      : 'Quantity of ${strings.money(denominationPaise)} notes';

  String chipNoteLabel(AppStrings strings, int denominationPaise) => _bn
      ? '${strings.money(denominationPaise)} নোট'
      : '${strings.money(denominationPaise)} note';
}

/// Which body a per-khata counter shows.
enum _CountPhase { loading, ready, failed }

/// Whether the newest edit is on disk.
enum _SavePhase { idle, saving, saved, failed }

class _NoteCounterScreenState extends State<NoteCounterScreen> {
  /// Quantity per denomination in paise. Every denomination is present, so a
  /// switch away and back always finds the previous count.
  final Map<int, int> _quantities = <int, int>{
    for (final int denomination in kAllDenominationsPaise) denomination: 0,
  };

  final TextEditingController _quantityController = TextEditingController(
    text: '0',
  );

  int _selectedDenominationPaise = kDefaultDenominationPaise;
  bool _showTwoThousand = false;

  /// Set when the last typed value was rejected (negative or decimal). The
  /// field is not rewritten, so the user sees exactly what they typed plus an
  /// explicit error instead of a silently corrected number.
  String? _inputError;

  /// True when both halves of the per-khata mode were supplied.
  bool get _persistent => widget.khataId != null && widget.store != null;

  /// Per-khata mode only: loading, ready to count, or failed to load.
  _CountPhase _phase = _CountPhase.ready;
  Object? _loadError;

  /// Per-khata mode only: the state of the newest write.
  _SavePhase _savePhase = _SavePhase.idle;
  Object? _saveError;

  /// True when the stored rows could not all be read; cleared by a save that
  /// rewrites them.
  bool _unreadableRows = false;

  /// Bumped on every load and every save, so an answer for a previous khata (or
  /// a superseded write) cannot paint over the current one.
  int _loadRequest = 0;
  int _writeRequest = 0;

  @override
  void initState() {
    super.initState();
    _validateConfig(widget.khataId, widget.store);
    if (_persistent) {
      _phase = _CountPhase.loading;
      _startLoad(notify: false);
    }
  }

  @override
  void didUpdateWidget(NoteCounterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validateConfig(widget.khataId, widget.store);
    if (oldWidget.khataId == widget.khataId &&
        identical(oldWidget.store, widget.store)) {
      return;
    }
    // A different khata - or a different database - must never inherit the
    // counts, the selection or the "saved" badge of the previous one. The
    // request counters make any answer still in flight for the old khata a
    // no-op instead of a cross-account overwrite.
    _loadRequest += 1;
    _writeRequest += 1;
    _resetSession();
    // No setState: didUpdateWidget is followed by a build of this state anyway.
    if (_persistent) {
      _phase = _CountPhase.loading;
      _startLoad(notify: false);
    }
  }

  /// Both halves of per-khata mode are required together.
  ///
  /// `NoteCounterScreen()` stays the standalone preview; `khataId` plus `store`
  /// is a counted session on that khata. Half of a pair is rejected loudly,
  /// because either guess (save nowhere, or read the wrong ledger) would
  /// report success for something that did not happen.
  void _validateConfig(String? khataId, NoteCounterStore? store) {
    if ((khataId == null) == (store == null)) return;
    throw ArgumentError(
      'NoteCounterScreen needs both khataId and store for a saved count, '
      'or neither for the in-memory session',
    );
  }

  /// Returns this screen to the empty ₹500 session.
  void _resetSession() {
    for (final int denomination in _quantities.keys.toList()) {
      _quantities[denomination] = 0;
    }
    _selectedDenominationPaise = kDefaultDenominationPaise;
    _showTwoThousand = false;
    _inputError = null;
    _phase = _CountPhase.ready;
    _loadError = null;
    _savePhase = _SavePhase.idle;
    _saveError = null;
    _unreadableRows = false;
    _syncFieldToSelection();
  }

  @override
  void dispose() {
    // A write that already failed is retried once on the way out: the store
    // owns the queue, so it still lands after this widget is gone. A write that
    // is merely queued needs nothing here - the store finishes it regardless.
    if (_persistent &&
        _phase == _CountPhase.ready &&
        _savePhase == _SavePhase.failed) {
      final NoteCounterStore? store = widget.store;
      final String? khataId = widget.khataId;
      if (store != null && khataId != null) {
        _writeRequest += 1;
        unawaited(_persist(store, khataId, _snapshot(), _writeRequest));
      }
    }
    _quantityController.dispose();
    super.dispose();
  }

  /// Denominations currently offered, largest first for the chip row.
  List<int> get _visibleDenominationsPaise => <int>[
    if (_showTwoThousand) kOptionalDenominationPaise,
    ...kStandardDenominationsPaise.reversed,
  ];

  int get _selectedQuantity => _quantities[_selectedDenominationPaise] ?? 0;

  int get _selectedTotalPaise => _selectedDenominationPaise * _selectedQuantity;

  int get _grandTotalPaise => _quantities.entries.fold<int>(
    0,
    (int sum, MapEntry<int, int> entry) => sum + entry.key * entry.value,
  );

  /// Quantity counted for a denomination that is currently hidden.
  int get _hiddenQuantity =>
      _showTwoThousand ? 0 : (_quantities[kOptionalDenominationPaise] ?? 0);

  void _selectDenomination(int denominationPaise) {
    setState(() {
      _selectedDenominationPaise = denominationPaise;
      _inputError = null;
    });
    _syncFieldToSelection();
    _schedulePersist();
  }

  void _setQuantity(int denominationPaise, int requested) {
    final int clamped = requested.clamp(0, kMaxNoteQuantity);
    setState(() {
      _quantities[denominationPaise] = clamped;
      _inputError = null;
    });
    if (denominationPaise == _selectedDenominationPaise) {
      _writeField(clamped.toString());
    }
    _schedulePersist();
  }

  void _increment() {
    _setQuantity(_selectedDenominationPaise, _selectedQuantity + 1);
  }

  void _decrement() {
    if (_selectedQuantity == 0) {
      return;
    }
    _setQuantity(_selectedDenominationPaise, _selectedQuantity - 1);
  }

  /// Validates the text field.
  ///
  /// Empty means "nothing counted yet" (zero), which is not an error. Anything
  /// that is not a non-negative whole number - `-5`, `1.5`, `abc`, `0x10` - is
  /// **rejected**: the quantity is not changed and [_inputError] explains why.
  /// Silently turning `-5` or `1.5` into some other positive count would be a
  /// lie about what the user entered.
  ///
  /// A correctly typed value above [kMaxNoteQuantity] is clamped, because the
  /// limit is a documented ceiling rather than a typo.
  void _onQuantityChanged(String raw) {
    final AppStrings strings = AppStrings(widget.language);
    // Only a genuinely empty field means "nothing counted". Whitespace is
    // *not* emptiness: `' '` is something the user typed, so it is rejected
    // like any other invalid entry rather than silently resetting the count.
    if (raw.isEmpty) {
      setState(() {
        _quantities[_selectedDenominationPaise] = 0;
        _inputError = null;
      });
      _schedulePersist();
      return;
    }

    // Validate the raw string - no trimming - so surrounding or internal
    // spaces (`' 5'`, `'5 0'`) are rejected instead of being quietly accepted
    // as a different number.
    final bool isWholeNumber = RegExp(r'^[0-9]+$').hasMatch(raw);
    final String? error = isWholeNumber
        ? null
        : raw.trimLeft().startsWith('-')
        ? strings.text(AppString.negativeQuantity)
        : strings.text(AppString.wholeNotes);
    if (!isWholeNumber) {
      setState(() => _inputError = error);
      return;
    }

    final int? parsed = int.tryParse(raw);
    if (parsed == null) {
      // A digit string longer than the platform int can hold (e.g. 30 nines)
      // parses to null. Pin the count to the documented maximum *and rewrite
      // the field*, so the visible number and the counted number agree; the
      // old `?? kMaxNoteQuantity` fallback left the field showing the huge
      // string while the count sat at the maximum.
      setState(() {
        _quantities[_selectedDenominationPaise] = kMaxNoteQuantity;
        _inputError = null;
      });
      _writeField(kMaxNoteQuantity.toString());
      _schedulePersist();
      return;
    }

    final int clamped = parsed.clamp(0, kMaxNoteQuantity);
    setState(() {
      _quantities[_selectedDenominationPaise] = clamped;
      _inputError = null;
    });
    if (clamped != parsed) {
      _writeField(clamped.toString());
    }
    _schedulePersist();
  }

  /// Direct-input values longer than five digits would otherwise keep growing;
  /// normalizing on demand keeps the visible field and the state identical.
  void _commitTypedQuantity() {
    FocusScope.of(context).unfocus();
    if (_inputError != null) {
      // "Calculate" with a bad value returns the field to the last valid count
      // rather than computing a total from a number the user did not enter.
      setState(() => _inputError = null);
    }
    _writeField(_selectedQuantity.toString());
  }

  void _toggleTwoThousand(bool value) {
    setState(() {
      _showTwoThousand = value;
      if (!value && _selectedDenominationPaise == kOptionalDenominationPaise) {
        // Never leave the selection on a hidden chip. The counted quantity is
        // kept (see _hiddenQuantity) - only the selection moves.
        _selectedDenominationPaise = kDefaultDenominationPaise;
      }
    });
    _syncFieldToSelection();
    _schedulePersist();
  }

  /// The "New count" button: resets only the current session, in both modes.
  /// Ledger entries, the balance, saved sessions and any other khata are not
  /// touched. Per-khata mode additionally stores the zeros.
  /// `New count`: reset every denomination. A non-empty count is wiped from
  /// the screen (and, per-khata, persisted as zeros), so the user confirms
  /// first; an empty count resets without a dialog. Saved sessions are kept.
  Future<void> _newCount() async {
    if (_grandTotalPaise > 0) {
      final AppStrings strings = AppStrings(widget.language);
      final _Copy copy = _Copy(widget.language);
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(copy.newCountConfirmTitle),
          content: Text(copy.newCountConfirmBody),
          actions: <Widget>[
            TextButton(
              key: const Key('note-counter-new-count-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.text(AppString.cancel)),
            ),
            FilledButton(
              key: const Key('note-counter-new-count-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(strings.text(AppString.newCount)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      for (final int denomination in _quantities.keys.toList()) {
        _quantities[denomination] = 0;
      }
      _inputError = null;
    });
    _syncFieldToSelection();
    // Per-khata mode persists the zeros for this khata only. No rows are
    // deleted, so this cannot sweep away another khata's session or any saved
    // session snapshot.
    _schedulePersist();
  }

  void _syncFieldToSelection() {
    _writeField(_selectedQuantity.toString());
  }

  /// Writes text without firing `onChanged` (setting `controller.text` does
  /// not call the field's callback) and keeps the caret at the end.
  void _writeField(String text) {
    _quantityController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  NoteCounterSnapshot _snapshot() => NoteCounterSnapshot(
    quantities: Map<int, int>.of(_quantities),
    selectedDenominationPaise: _selectedDenominationPaise,
    showTwoThousand: _showTwoThousand,
  );

  void _startLoad({required bool notify}) {
    final NoteCounterStore? store = widget.store;
    final String? khataId = widget.khataId;
    if (store == null || khataId == null) return;
    final int request = ++_loadRequest;
    if (notify) {
      setState(() {
        _phase = _CountPhase.loading;
        _loadError = null;
      });
    }
    unawaited(_load(store, khataId, request));
  }

  Future<void> _load(
    NoteCounterStore store,
    String khataId,
    int request,
  ) async {
    NoteCounterSnapshot snapshot;
    try {
      snapshot = await store.load(khataId);
    } catch (error) {
      if (!mounted || request != _loadRequest || widget.khataId != khataId) {
        return;
      }
      setState(() {
        _phase = _CountPhase.failed;
        _loadError = error;
      });
      return;
    }
    if (!mounted || request != _loadRequest || widget.khataId != khataId) {
      // The user already switched khata: showing this answer would be a
      // cross-account display of the previous khata's count.
      return;
    }
    setState(() {
      for (final int denomination in _quantities.keys.toList()) {
        _quantities[denomination] = snapshot.quantityFor(denomination);
      }
      _selectedDenominationPaise = snapshot.selectedDenominationPaise;
      _showTwoThousand = snapshot.showTwoThousand;
      _unreadableRows = snapshot.hasUnreadableRows;
      _inputError = null;
      _phase = _CountPhase.ready;
      _savePhase = _SavePhase.idle;
      _saveError = null;
    });
    _syncFieldToSelection();
  }

  /// Persists the current count for the active khata, if this is a saved counter.
  ///
  /// Every edit calls this. The store keeps only the newest snapshot per khata
  /// and writes serially, so a burst of taps - or a khata switch in the middle
  /// of one - can neither reorder the writes nor leave an older value behind.
  /// A failed write stays visible with a retry instead of being reported as
  /// saved.
  void _schedulePersist() {
    if (!_persistent || _phase != _CountPhase.ready) return;
    final NoteCounterStore? store = widget.store;
    final String? khataId = widget.khataId;
    if (store == null || khataId == null) return;
    final int request = ++_writeRequest;
    setState(() {
      _savePhase = _SavePhase.saving;
      _saveError = null;
    });
    unawaited(_persist(store, khataId, _snapshot(), request));
  }

  Future<void> _persist(
    NoteCounterStore store,
    String khataId,
    NoteCounterSnapshot snapshot,
    int request,
  ) async {
    try {
      await store.save(khataId, snapshot);
    } catch (error) {
      if (!mounted || request != _writeRequest || widget.khataId != khataId) {
        return;
      }
      setState(() {
        _savePhase = _SavePhase.failed;
        _saveError = error;
      });
      return;
    }
    if (!mounted || request != _writeRequest || widget.khataId != khataId) {
      // A newer edit (or a khata switch) already owns the status line.
      return;
    }
    setState(() {
      _savePhase = _SavePhase.saved;
      _saveError = null;
      // The save rewrote every known denomination, so rows that could not be
      // read before are now clean.
      _unreadableRows = false;
    });
  }

  /// `Save`: keep a timestamped snapshot of the current, non-empty count.
  ///
  /// Disabled at zero, so the sessions list only ever holds real counts. The
  /// current session is untouched - it keeps counting as usual.
  Future<void> _saveSession() async {
    final NoteCounterStore? store = widget.store;
    final String? khataId = widget.khataId;
    final _Copy copy = _Copy(widget.language);
    if (store == null || khataId == null) return;
    if (_grandTotalPaise <= 0) return;
    try {
      await store.saveSession(khataId, _snapshot());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copy.sessionSaved)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copy.sessionSaveFailed)),
      );
    }
  }

  /// `Copy summary`: readable plain text on the clipboard - each non-zero
  /// denomination × quantity = amount, the Grand Total and the date and time.
  Future<void> _copySummary() async {
    final AppStrings strings = AppStrings(widget.language);
    final String summary = _buildSummaryText(strings);
    await Clipboard.setData(ClipboardData(text: summary));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_Copy(widget.language).summaryCopied)),
    );
  }

  String _buildSummaryText(AppStrings strings) {
    final _Copy copy = _Copy(widget.language);
    final List<String> lines = <String>[
      '${copy.noteCounterWord} — ${strings.dateTime(DateTime.now())}',
      for (final int denomination in kAllDenominationsPaise)
        if (_quantities[denomination]! > 0)
          '${strings.money(denomination)} × '
          '${strings.number(_quantities[denomination]!)} = '
          '${strings.money(denomination * _quantities[denomination]!)}',
      '${strings.text(AppString.grandTotal)}: '
          '${strings.money(_grandTotalPaise)}',
    ];
    return lines.join('\n');
  }

  /// Opens the saved sessions sheet for the active khata. Tapping a session
  /// restores it (confirming first when the current count is not empty);
  /// sessions can also be deleted there. The screen pops the sheet itself once
  /// the restore has been applied.
  Future<void> _openSavedSessions() async {
    final NoteCounterStore? store = widget.store;
    final String? khataId = widget.khataId;
    if (store == null || khataId == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) => SavedSessionsSheet(
        store: store,
        khataId: khataId,
        currentTotalPaise: _grandTotalPaise,
        language: widget.language,
        onRestore: (SavedNoteCount session) async {
          Navigator.of(sheetContext).pop();
          _restoreSavedSession(session);
        },
      ),
    );
  }

  /// Writes the saved values into the current session (through the normal
  /// persist path) and leaves the rest of the screen alone.
  void _restoreSavedSession(SavedNoteCount session) {
    final _Copy copy = _Copy(widget.language);
    final NoteCounterSnapshot snapshot = session.snapshot;
    setState(() {
      for (final int denomination in _quantities.keys.toList()) {
        _quantities[denomination] = snapshot.quantityFor(denomination);
      }
      int selected = snapshot.selectedDenominationPaise;
      // The mirror of the load-time repair: never land the selection on a
      // chip that is hidden.
      if (!snapshot.showTwoThousand && selected == kOptionalDenominationPaise) {
        selected = kDefaultDenominationPaise;
      }
      _selectedDenominationPaise = selected;
      _showTwoThousand = snapshot.showTwoThousand;
      _unreadableRows = false;
      _inputError = null;
      _savePhase = _SavePhase.idle;
    });
    _syncFieldToSelection();
    _schedulePersist();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(copy.sessionRestored)),
    );
  }

  /// The "Add to khata as income" action: hand the Grand Total to the caller
  /// as integer paise plus a short note. This screen never writes a
  /// transaction itself - the caller opens the entry form for the user to
  /// review and save.
  void _addToKhata() {
    final void Function(int amountPaise, String note)? onAddToKhata =
        widget.onAddToKhata;
    if (onAddToKhata == null) return;
    final int total = _grandTotalPaise;
    if (total <= 0) return;
    final AppStrings strings = AppStrings(widget.language);
    final String note =
        '${_Copy(widget.language).noteCounterWord} — ${strings.dateTime(DateTime.now())}';
    onAddToKhata(total, note);
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings(widget.language);
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.payments_outlined, color: AppColors.golden, size: 22),
              const SizedBox(width: 10),
              Text(strings.text(AppString.noteCounter)),
            ],
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings),
            tooltip: strings.text(AppString.settings),
          ),
        ],
      ),
      body: _buildBody(strings),
    );
  }

  Widget _buildBody(AppStrings strings) {
    final _Copy copy = _Copy(widget.language);
    if (_persistent && _phase == _CountPhase.loading) {
      return Center(
        key: const Key('note-counter-loading'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                copy.loading,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.softText),
              ),
            ],
          ),
        ),
      );
    }
    if (_persistent && _phase == _CountPhase.failed) {
      return Center(
        child: _LoadFailure(
          strings: strings,
          error: _loadError,
          onRetry: () => _startLoad(notify: true),
        ),
      );
    }
    final bool addToKhataVisible =
        widget.onAddToKhata != null && _grandTotalPaise > 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _NoteBundle(strings: strings, denominationPaise: _selectedDenominationPaise),
          const SizedBox(height: 12),
          _DenominationPicker(
            strings: strings,
            denominationsPaise: _visibleDenominationsPaise,
            selectedPaise: _selectedDenominationPaise,
            onSelected: _selectDenomination,
          ),
          const SizedBox(height: 10),
          _TwoThousandToggle(
            strings: strings,
            value: _showTwoThousand,
            onChanged: _toggleTwoThousand,
          ),
          const SizedBox(height: 16),
          Text(
            strings.text(AppString.enterQuantity),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          _QuantityStepper(
            strings: strings,
            controller: _quantityController,
            errorText: _inputError,
            denominationPaise: _selectedDenominationPaise,
            onIncrement: _increment,
            onDecrement: _selectedQuantity == 0 ? null : _decrement,
            onChanged: _onQuantityChanged,
          ),
          const SizedBox(height: 12),
          _TotalCard(
            label: strings.text(AppString.totalAmount),
            amountPaise: _selectedTotalPaise,
            strings: strings,
            background: AppColors.warmIvory,
            border: AppColors.beige,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('note-counter-calculate'),
            onPressed: _commitTypedQuantity,
            icon: const Icon(Icons.calculate_outlined, size: 20),
            label: Text(strings.text(AppString.calculate)),
          ),
          const SizedBox(height: 12),
          _GrandTotalCard(
            strings: strings,
            amountPaise: _grandTotalPaise,
            hiddenTwoThousandQuantity: _hiddenQuantity,
          ),
          const SizedBox(height: 12),
          if (addToKhataVisible) ...<Widget>[
            FilledButton.icon(
              key: const Key('note-counter-add-to-khata'),
              onPressed: _addToKhata,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.incomeGreen,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 20,
              ),
              label: Text(
                copy.addToKhata,
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_persistent) ...<Widget>[
            _ActionButton.filled(
              buttonKey: const Key('note-counter-save'),
              onPressed: _grandTotalPaise > 0 ? _saveSession : null,
              icon: Icons.save_outlined,
              label: strings.text(AppString.save),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ActionButton.outlined(
                    buttonKey: const Key('note-counter-saved-sessions'),
                    onPressed: _openSavedSessions,
                    icon: Icons.bookmark_outline,
                    label: copy.savedSessions,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton.outlined(
                    buttonKey: const Key('note-counter-copy-summary'),
                    onPressed: _copySummary,
                    icon: Icons.content_copy,
                    label: copy.copySummary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ] else ...<Widget>[
            _ActionButton.outlined(
              buttonKey: const Key('note-counter-copy-summary'),
              onPressed: _copySummary,
              icon: Icons.content_copy,
              label: copy.copySummary,
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('note-counter-new-count'),
                  onPressed: _newCount,
                  icon: const Icon(Icons.refresh, size: 20),
                  label: Text(strings.text(AppString.newCount)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_persistent) ...<Widget>[
            const SizedBox(height: 8),
            _SaveStatus(
              strings: strings,
              phase: _savePhase,
              error: _saveError,
              onRetry: _schedulePersist,
            ),
            if (_unreadableRows) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                copy.unreadableRows,
                key: const Key('note-counter-unreadable-warning'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppColors.softText),
              ),
            ],
          ],
          const SizedBox(height: 8),
          Center(
            child: Text(
              _persistent
                  ? copy.savedHint
                  : strings.text(AppString.counterSession),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.softText),
            ),
          ),
        ],
      ),
    );
  }
}

/// A flat-friendly full-width action button that tolerates two lines of
/// label at large text scales. Never overflows: the label wraps.
class _ActionButton extends StatelessWidget {
  const _ActionButton.filled({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onPressed,
  }) : _filled = true;

  const _ActionButton.outlined({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onPressed,
  }) : _filled = false;

  /// Lands on the actual button, so a tap-test finds exactly one target.
  final Key buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool _filled;

  @override
  Widget build(BuildContext context) {
    final Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    const RoundedRectangleBorder shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    );
    if (_filled) {
      return FilledButton(
        key: buttonKey,
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: shape,
        ),
        child: child,
      );
    }
    return OutlinedButton(
      key: buttonKey,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: AppColors.primaryGreen,
        side: const BorderSide(color: AppColors.primaryGreen),
        shape: shape,
      ),
      child: child,
    );
  }
}

/// A visual cue for the selected denomination. The illustration is bundled
/// locally, so the counter stays useful without a network connection.
class _NoteBundle extends StatelessWidget {
  const _NoteBundle({required this.strings, required this.denominationPaise});

  final AppStrings strings;
  final int denominationPaise;

  @override
  Widget build(BuildContext context) {
    final _Copy copy = _Copy(strings.language);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.lightGreen,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.outline),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.darkText.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 92,
                    height: 76,
                    child: Image.asset(
                      'assets/illustrations/note_bundle.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(
                            color: AppColors.warmIvory,
                            child: Icon(
                              Icons.payments_outlined,
                              size: 42,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      copy.currentNote,
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: AppColors.softText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        strings.money(denominationPaise),
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      copy.chooseNote,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        color: AppColors.softText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip row for choosing the active denomination. Wraps instead of scrolling,
/// so a narrow phone or 200% text scale never clips a chip.
class _DenominationPicker extends StatelessWidget {
  const _DenominationPicker({
    required this.strings,
    required this.denominationsPaise,
    required this.selectedPaise,
    required this.onSelected,
  });

  final AppStrings strings;
  final List<int> denominationsPaise;
  final int selectedPaise;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final int denomination in denominationsPaise)
          _DenominationChip(
            key: Key('denomination-$denomination'),
            strings: strings,
            denominationPaise: denomination,
            selected: denomination == selectedPaise,
            onTap: () => onSelected(denomination),
          ),
      ],
    );
  }
}

class _DenominationChip extends StatelessWidget {
  const _DenominationChip({
    super.key,
    required this.strings,
    required this.denominationPaise,
    required this.selected,
    required this.onTap,
  });

  final AppStrings strings;
  final int denominationPaise;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final _Copy copy = _Copy(strings.language);
    final Color background = selected
        ? AppColors.primaryGreen
        : AppColors.warmIvory;
    final Color foreground = selected
        ? AppColors.onPrimary
        : AppColors.darkText;

    return Semantics(
      button: true,
      selected: selected,
      // `excludeSemantics` stops the child `Text` from being announced as a
      // second node, so the chip reads as one control: "₹500 note, selected".
      label: copy.chipNoteLabel(strings, denominationPaise),
      excludeSemantics: true,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            // No `alignment` here: an aligned Container in a Wrap stretches to
            // the full available width, which produced one full-width chip per
            // row. A compact box keeps the chips side by side.
            constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? AppColors.primaryGreen : AppColors.outline,
              ),
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                strings.money(denominationPaise),
                maxLines: 1,
                softWrap: false,
                // Chips must stay compact when text is huge: at 300% scale a
                // label alone was wider than the 288 dp content area, and its
                // Run height overflowed the Wrap's Row by 12 px.
                // Capping the chip label's growth keeps every chip narrow
                // enough to wrap, while the 44 dp minimum height keeps the
                // touch target legal. The label itself is unchanged, so the
                // "₹500 note" semantics stay intact.
                textScaler: TextScaler.linear(
                  MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3),
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opt-in ₹2,000 denomination (off by default).
class _TwoThousandToggle extends StatelessWidget {
  const _TwoThousandToggle({
    required this.strings,
    required this.value,
    required this.onChanged,
  });

  final AppStrings strings;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warmIvory,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  strings.text(AppString.includeTwoThousand),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.darkText,
                  ),
                ),
              ),
              Switch(
                key: const Key('note-counter-show-2000'),
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `−  10  +` with a numeric field in the middle.
class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.strings,
    required this.controller,
    required this.denominationPaise,
    required this.errorText,
    required this.onIncrement,
    required this.onDecrement,
    required this.onChanged,
  });

  final AppStrings strings;
  final TextEditingController controller;
  final int denominationPaise;

  /// Shown under the field when the last typed value was rejected.
  final String? errorText;
  final VoidCallback onIncrement;

  /// `null` disables the button, which is how "disabled at zero" is expressed.
  final VoidCallback? onDecrement;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final _Copy copy = _Copy(strings.language);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _StepperButton(
          key: const Key('note-counter-decrement'),
          icon: Icons.remove,
          semanticLabel: strings.text(AppString.decreaseQuantity),
          onPressed: onDecrement,
        ),
        const SizedBox(width: 12),
        Expanded(
          // A `TextField` gets no accessible name from a suppressed floating
          // label, and the visible "Enter Quantity" text above is a separate
          // node. This wrapper names the field itself, including the active
          // denomination, so the announced name follows the selection.
          child: Semantics(
            textField: true,
            label: copy.quantityFieldLabel(strings, denominationPaise),
            child: TextField(
              key: const Key('note-counter-quantity-field'),
              controller: controller,
              onChanged: onChanged,
              textAlign: TextAlign.center,
              textInputAction: TextInputAction.done,
              // No filtering formatters: `digitsOnly` would silently swallow
              // the `-` in `-5` and abandon the `.5` in `1.5`, leaving the user
              // with a plausible-looking count they never typed. The keyboard
              // is numeric as a convenience; _onQuantityChanged validates
              // whatever actually arrives.
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText,
              ),
              decoration: InputDecoration(
                errorText: errorText,
                errorMaxLines: 2,
                filled: true,
                fillColor: AppColors.warmIvory,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.beige),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.beige),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primaryGreen,
                    width: 1.5,
                  ),
                ),
                hintText: '0',
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _StepperButton(
          key: const Key('note-counter-increment'),
          icon: Icons.add,
          semanticLabel: strings.text(AppString.increaseQuantity),
          onPressed: onIncrement,
        ),
      ],
    );
  }
}

/// Circular green stepper button; greys out when [onPressed] is null.
class _StepperButton extends StatelessWidget {
  const _StepperButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Material(
          color: enabled ? AppColors.primaryGreen : AppColors.lightGreen,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Icon(
              icon,
              size: 24,
              color: enabled ? AppColors.onPrimary : AppColors.navigationGrey,
            ),
          ),
        ),
      ),
    );
  }
}

/// `Total Amount` / `Grand Total` card.
class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.label,
    required this.amountPaise,
    required this.strings,
    required this.background,
    required this.border,
  });

  final String label;
  final int amountPaise;
  final AppStrings strings;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.lightGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.payments_outlined,
              size: 20,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.softText,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    strings.money(amountPaise),
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grand total on `lightGreen` with the check icon from the style guide.
class _GrandTotalCard extends StatelessWidget {
  const _GrandTotalCard({
    required this.strings,
    required this.amountPaise,
    required this.hiddenTwoThousandQuantity,
  });

  final AppStrings strings;
  final int amountPaise;

  /// Non-zero when ₹2,000 notes are counted but the denomination is hidden.
  /// The card says so rather than silently including invisible money.
  final int hiddenTwoThousandQuantity;

  @override
  Widget build(BuildContext context) {
    final _Copy copy = _Copy(strings.language);
    return Container(
      key: const Key('note-counter-grand-total'),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentGreen),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.warmIvory,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 21,
                  color: AppColors.incomeGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      strings.text(AppString.grandTotal),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        strings.money(amountPaise),
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hiddenTwoThousandQuantity > 0) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              copy.hiddenTwoThousand(strings, hiddenTwoThousandQuantity),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.softText),
            ),
          ],
        ],
      ),
    );
  }
}

/// What happened to the newest edit: queued, stored, or refused.
///
/// A refusal is not silent: it keeps a retry button so the user can push the
/// same snapshot again after fixing the cause (for example, after unarchiving
/// the khata), and it never claims the count was saved.
class _SaveStatus extends StatelessWidget {
  const _SaveStatus({
    required this.strings,
    required this.phase,
    required this.error,
    required this.onRetry,
  });

  final AppStrings strings;
  final _SavePhase phase;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final _Copy copy = _Copy(strings.language);
    final bool failed = phase == _SavePhase.failed;
    final String text = switch (phase) {
      _SavePhase.idle => copy.noChangesYet,
      _SavePhase.saving => copy.saving,
      _SavePhase.saved => copy.savedOnDevice,
      _SavePhase.failed => '${copy.notSaved}: ${copy.saveFailedReason(error)}',
    };
    return Container(
      key: const Key('note-counter-save-status'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: failed ? AppColors.warmIvory : null,
        borderRadius: BorderRadius.circular(12),
        border: failed ? Border.all(color: AppColors.beige) : null,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: failed ? AppColors.darkText : AppColors.softText,
              ),
            ),
          ),
          if (failed)
            TextButton(
              key: const Key('note-counter-save-retry'),
              onPressed: onRetry,
              child: Text(strings.text(AppString.retry)),
            ),
        ],
      ),
    );
  }
}

/// Shown instead of the counter when the saved count could not be read.
///
/// The alternative - drawing a zero count - would be a fake success: the user
/// could count again and overwrite a session that was merely unreadable.
class _LoadFailure extends StatelessWidget {
  const _LoadFailure({
    required this.strings,
    required this.error,
    required this.onRetry,
  });

  final AppStrings strings;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final _Copy copy = _Copy(strings.language);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 32, color: AppColors.darkText),
          const SizedBox(height: 12),
          Text(
            '${copy.loadFailedTitle} (${copy.loadFailedReason(error)}).',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.darkText),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('note-counter-load-retry'),
            onPressed: onRetry,
            child: Text(strings.text(AppString.retry)),
          ),
        ],
      ),
    );
  }
}

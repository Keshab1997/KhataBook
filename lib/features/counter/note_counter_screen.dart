import 'dart:async';

// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../ledger/data/local_ledger.dart' show KhataNotFoundException;
import 'note_counter_store.dart';
import 'saved_sessions_sheet.dart';

// The denomination constants come from the store, which is their single
// definition - this screen imports them instead of duplicating them.

/// S4 - Note Counter. See docs/spec/screens.md#s4--note-counter.
///
/// Counts physical notes and coins: every denomination is one row on one
/// screen - ₹500, ₹200, ₹100, ₹50, ₹20, ₹10 and a final row for the total
/// value of coins in rupees - each with its illustration, a quantity field
/// and its row total, and the grand total at the bottom. All arithmetic is
/// integer paise - no doubles anywhere - and money text goes through
/// [AppStrings].
///
/// Two modes:
///
/// * **In-memory** (the default, no [store]/[khataId]) - exactly the standalone
///   counter: nothing is persisted, nothing leaves the screen, and the
///   "nothing is saved" hint is shown.
/// * **Per-khata** (both [store] and [khataId]) - the count for that khata is
///   loaded on open and every edit is written back through the store on a
///   coalescing write queue, so a fast tap sequence is never dropped and never
///   blocks the UI. A new `khataId` reloads and never carries quantities over.
///
/// In both modes the screen never writes a ledger transaction. The optional
/// [onAddToKhata] action hands the Grand Total to its caller as integer paise
/// plus a short note - the caller opens the entry form for the user to review
/// and save, because cash already counted here may already be inside the
/// opening balance. Per-khata mode is autosave: the screen writes the count on
/// every edit, keeps the status line up to date and never asks you to press a
/// save button. The sessions sheet still lists, restores and deletes snapshots
/// created before the Save button was removed, but it cannot create new ones.
/// Counter data lives only in the counter tables, and a format version 2
/// backup carries all of them - the screen says so rather than disclaiming
/// the backup.
class NoteCounterScreen extends StatefulWidget {
  const NoteCounterScreen({
    super.key,
    this.language = AppLanguage.en,
    this.store,
    this.khataId,
    this.onAddToKhata,
    this.onSettings,
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
  final VoidCallback? onSettings;

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

  String quantityFieldLabel(AppStrings strings, int denominationPaise) => _bn
      ? '${strings.money(denominationPaise)} নোটের সংখ্যা'
      : 'Quantity of ${strings.money(denominationPaise)} notes';

  String coinsAmountLabel(AppStrings strings) =>
      _bn ? 'কয়েনের মোট পরিমাণ (টাকা)' : 'Total value of coins (₹)';

  String coinsRowValue(AppStrings strings, int paise) => _bn
      ? '${strings.money(paise)} কয়েন'
      : 'Coins totalling ${strings.money(paise)}';

  String get grandTotalLabel => _bn ? 'সর্বমোট' : 'Grand Total';

  String get savedHint => _bn
      ? 'এই খাতার জন্য এই ডিভাইসে সংরক্ষিত — লেজার এন্ট্রি নয়; ব্যাকআপ ফাইলের সাথে যায়'
      : 'Saved on this device for this khata - not a ledger entry; it travels in the backup file';

  String get loading => _bn
      ? 'এই খাতার সংরক্ষিত গণনা লোড হচ্ছে…'
      : 'Loading the saved count for this khata…';

  String loadFailedReason(Object? error) => error is KhataNotFoundException
      ? (_bn
            ? 'খাতাটি নেই বা সংরক্ষিত (আর্কাইভ) হয়েছে'
            : 'this khata is missing or archived')
      : (_bn
            ? 'সংরক্ষিত গণনা পড়া যায়নি'
            : 'the saved count could not be read');

  String get loadFailedTitle =>
      _bn ? 'সংরক্ষিত গণনা লোড করা যায়নি' : 'Could not load the saved count';

  String saveFailedReason(Object? error) => error is KhataNotFoundException
      ? (_bn
            ? 'খাতাটি নেই বা সংরক্ষিত (আর্কাইভ) হয়েছে'
            : 'this khata is missing or archived')
      : (_bn
            ? 'গণনা সংরক্ষণ করা যায়নি'
            : 'the saved count could not be stored');

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

  String get newCountConfirmTitle =>
      _bn ? 'নতুন গণনা শুরু করবেন?' : 'Start a new count?';

  String get newCountConfirmBody => _bn
      ? 'স্ক্রিনের বর্তমান গণনা মুছে যাবে। সংরক্ষিত গণনা তালিকায় থেকে যাবে।'
      : 'The count on screen will be cleared. Saved sessions stay in the list.';

  String get copySummary => _bn ? 'সারসংক্ষেপ কপি করুন' : 'Copy summary';

  String get summaryCopied =>
      _bn ? 'সারসংক্ষেপ ক্লিপবোর্ডে কপি হয়েছে' : 'Summary copied to clipboard';

  String get addToKhata =>
      _bn ? 'খাতায় আয় হিসেবে যোগ করুন' : 'Add to khata as income';

  String get noteCounterWord => _bn ? 'নোট গণনা' : 'Note counter';

  String get sessionRestored =>
      _bn ? 'সংরক্ষিত গণনা ফিরিয়ে আনা হয়েছে' : 'Saved count restored';
}

/// Which body a per-khata counter shows.
enum _CountPhase { loading, ready, failed }

/// Whether the newest edit is on disk.
enum _SavePhase { idle, saving, saved, failed }

/// Vertical rhythm between the denomination rows.
const double _rowGap = 5;

class _NoteCounterScreenState extends State<NoteCounterScreen> {
  /// Quantity per denomination in paise. Every denomination is present, so a
  /// switch away and back always finds the previous count.
  final Map<int, int> _quantities = <int, int>{
    for (final int denomination in kAllDenominationsPaise) denomination: 0,
  };

  /// One controller per row: the six notes hold a number of notes,
  /// [kCoinDenominationPaise] holds the total coin amount in rupees (integer,
  /// no paise). "1 coin = ₹1" - the user types how many rupees of coins they
  /// hold, never a coin count.
  final Map<int, TextEditingController> _controllers =
      <int, TextEditingController>{
        for (final int denomination in kAllDenominationsPaise)
          denomination: TextEditingController(text: '0'),
      };

  /// Per-row error message keyed by denomination, shown as helper text.
  final Map<int, String?> _inputErrors = <int, String?>{
    for (final int denomination in kAllDenominationsPaise) denomination: null,
  };

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

  /// Returns this screen to the empty session.
  void _resetSession() {
    for (final int denomination in _quantities.keys.toList()) {
      _quantities[denomination] = 0;
      _controllers[denomination]!.text = '0';
      _inputErrors[denomination] = null;
    }
    _phase = _CountPhase.ready;
    _loadError = null;
    _savePhase = _SavePhase.idle;
    _saveError = null;
    _unreadableRows = false;
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
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Rows currently shown, largest note first; the coin row is always last.
  List<int> get _rowOrderPaise => <int>[
    ...kStandardDenominationsPaise.reversed,
    kCoinDenominationPaise,
  ];

  int get _grandTotalPaise => _quantities.entries.fold<int>(
    0,
    (int sum, MapEntry<int, int> entry) => sum + entry.key * entry.value,
  );

  /// True when every row is still at zero.
  bool get _isEmpty =>
      _quantities.values.every((int quantity) => quantity == 0);

  bool get _bn => widget.language == AppLanguage.bn;

  _Copy _copy() => _Copy(widget.language);

  /// Validates the text of [denomination]'s field.
  ///
  /// Empty means "nothing counted" (zero), which is not an error. Any digit
  /// string is a number of notes for note rows and a **total coin amount in
  /// rupees** for the coin row; both are capped at [kMaxNoteQuantity].
  /// Anything that is not a non-negative whole number is rejected: the value
  /// is not changed and the field keeps exactly what the user typed, with an
  /// explicit error. A digit string longer than an int is pinned to the
  /// documented maximum *and the field is rewritten*, so the visible number
  /// and the counted number always agree.
  void _onRowChanged(String raw, int denomination) {
    final AppStrings strings = AppStrings(widget.language);
    if (raw.isEmpty) {
      setState(() {
        _quantities[denomination] = 0;
        _inputErrors[denomination] = null;
      });
      _schedulePersist();
      return;
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(raw)) {
      setState(() {
        _inputErrors[denomination] = strings.text(AppString.wholeNotes);
      });
      return;
    }
    final int? parsed = int.tryParse(raw);
    final int clamped = parsed == null
        ? kMaxNoteQuantity
        : parsed.clamp(0, kMaxNoteQuantity);
    setState(() {
      _quantities[denomination] = clamped;
      _inputErrors[denomination] = null;
    });
    if (parsed == null || clamped != parsed) {
      _setRowText(denomination, clamped);
    }
    _schedulePersist();
  }

  /// Writes [value] (in stored units) into [denomination]'s field.
  void _setRowText(int denomination, int value) {
    final TextEditingController controller = _controllers[denomination]!;
    final String text = value.toString();
    if (controller.text == text) return;
    controller.text = text;
    controller.selection = TextSelection(
      baseOffset: text.length,
      extentOffset: text.length,
    );
  }

  Future<void> _startLoad({required bool notify}) async {
    final NoteCounterStore? store = widget.store;
    final String? khataId = widget.khataId;
    if (store == null || khataId == null) return;
    final int request = ++_loadRequest;
    if (notify && mounted) {
      setState(() {
        _phase = _CountPhase.loading;
        _loadError = null;
      });
    }
    try {
      final NoteCounterSnapshot snapshot = await store.load(khataId);
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _phase = _CountPhase.ready;
        _loadError = null;
        _applySnapshot(snapshot);
      });
    } catch (error) {
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _phase = _CountPhase.failed;
        _loadError = error;
      });
    }
  }

  /// Applies a snapshot from storage to the fields, without scheduling a
  /// write back. Writes the fields with the same integer units the store
  /// keeps.
  void _applySnapshot(NoteCounterSnapshot snapshot) {
    for (final int denomination in _quantities.keys.toList()) {
      _quantities[denomination] = snapshot.quantities[denomination] ?? 0;
      _setRowText(denomination, _quantities[denomination]!);
      _inputErrors[denomination] = null;
    }
    _unreadableRows = snapshot.hasUnreadableRows;
    _savePhase = _SavePhase.idle;
    _saveError = null;
  }

  NoteCounterSnapshot _snapshot() => NoteCounterSnapshot(
    quantities: <int, int>{
      for (final MapEntry<int, int> entry in _quantities.entries)
        entry.key: entry.value,
    },
    selectedDenominationPaise: kDefaultDenominationPaise,
    showTwoThousand: false,
  );

  void _schedulePersist() {
    if (!_persistent) return;
    final NoteCounterStore? store = widget.store;
    final String? khataId = widget.khataId;
    if (store == null || khataId == null) return;
    final int request = ++_writeRequest;
    unawaited(_persist(store, khataId, _snapshot(), request));
  }

  Future<void> _persist(
    NoteCounterStore store,
    String khataId,
    NoteCounterSnapshot snapshot,
    int request,
  ) async {
    if (mounted && request == _writeRequest) {
      setState(() {
        _savePhase = _SavePhase.saving;
        _saveError = null;
      });
    }
    try {
      await store.save(khataId, snapshot);
      if (!mounted || request != _writeRequest) return;
      setState(() {
        _savePhase = _SavePhase.saved;
        _saveError = null;
        _unreadableRows = false;
      });
    } catch (error) {
      if (!mounted || request != _writeRequest) return;
      setState(() {
        _savePhase = _SavePhase.failed;
        _saveError = error;
      });
    }
  }

  /// Every row with a non-zero count, as `500×3 = ₹1,500`-style lines.
  List<String> _summaryLines(_Copy copy) {
    final AppStrings strings = AppStrings(widget.language);
    final List<String> lines = <String>[];
    for (final int denomination in _rowOrderPaise) {
      final int quantity = _quantities[denomination] ?? 0;
      if (quantity == 0) continue;
      final int linePaise = denomination * quantity;
      final String amount = strings.money(linePaise);
      if (denomination == kCoinDenominationPaise) {
        lines.add(copy.coinsRowValue(strings, linePaise));
      } else {
        lines.add(
          '${strings.money(denomination)} × ${strings.number(quantity)} = $amount',
        );
      }
    }
    lines.add('${copy.grandTotalLabel}: ${strings.money(_grandTotalPaise)}');
    return lines;
  }

  Future<void> _copySummary() async {
    final _Copy copy = _copy();
    await Clipboard.setData(
      ClipboardData(text: _summaryLines(copy).join('\n')),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(copy.summaryCopied)));
  }

  Future<void> _confirmNewCount() async {
    if (_isEmpty) {
      setState(_resetSession);
      _schedulePersist();
      return;
    }
    final _Copy copy = _copy();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(copy.newCountConfirmTitle),
        content: Text(copy.newCountConfirmBody),
        actions: <Widget>[
          TextButton(
            key: const Key('note-counter-new-count-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            key: const Key('note-counter-new-count-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(_bn ? 'নতুন গণনা' : 'New count'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(_resetSession);
      _schedulePersist();
    }
  }

  Future<void> _showSessions() async {
    final NoteCounterStore? store = widget.store;
    final String? khataId = widget.khataId;
    if (store == null || khataId == null) return;
    final _Copy copy = _copy();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (BuildContext sheetContext) => SavedSessionsSheet(
        store: store,
        khataId: khataId,
        currentTotalPaise: _grandTotalPaise,
        language: widget.language,
        onRestore: (SavedNoteCount session) async {
          Navigator.of(sheetContext).pop();
          if (!mounted) return;
          setState(() => _applySnapshot(session.snapshot));
          _schedulePersist();
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(copy.sessionRestored)));
        },
      ),
    );
  }

  void _addToKhata() {
    final void Function(int amountPaise, String note)? callback =
        widget.onAddToKhata;
    if (callback == null) return;
    final int total = _grandTotalPaise;
    if (total <= 0) return;
    final AppStrings strings = AppStrings(widget.language);
    final _Copy copy = _copy();
    final String note =
        '${copy.noteCounterWord} — ${strings.dateTime(DateTime.now())}';
    callback(total, note);
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings(widget.language);
    final _Copy copy = _copy();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: AppColors.headerGreen,
      ),
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Image.asset(
                    'assets/illustrations/counter_footer.png',
                    fit: BoxFit.fitWidth,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
              _buildBody(strings, copy),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppStrings strings, _Copy copy) {
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
    // The whole body scrolls: at large system text scales the fixed chrome
    // below the rows (total card, buttons, hint) no longer fits on small
    // phones — a pinned column overflows instead of scrolling.
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              height: 76,
              margin: const EdgeInsets.only(bottom: 3),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[
                    AppColors.primaryGreen,
                    AppColors.headerGreen,
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(22),
                ),
                border: const Border(
                  bottom: BorderSide(color: AppColors.golden, width: 3),
                ),
              ),
              child: Row(
                children: <Widget>[
                  ClipOval(
                    child: Image.asset(
                      'assets/illustrations/counter_header_coins.png',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            strings.text(AppString.counter),
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onPrimary,
                            ),
                          ),
                          Text(
                            widget.language == AppLanguage.bn
                                ? 'গুনুন সহজে • সঞ্চয় করুন'
                                : 'Count Smart • Save More',
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('note-counter-new-count'),
                    onPressed: _confirmNewCount,
                    tooltip: strings.text(AppString.newCount),
                    color: AppColors.onPrimary,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.secondaryGreen,
                    ),
                    icon: const Icon(Icons.refresh),
                  ),
                  if (widget.onSettings != null)
                    IconButton(
                      onPressed: widget.onSettings,
                      tooltip: 'Settings',
                      color: AppColors.onPrimary,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.secondaryGreen,
                      ),
                      icon: const Icon(Icons.settings),
                    ),
                ],
              ),
            ),
            for (final int denomination in _rowOrderPaise) ...<Widget>[
              _DenominationRow(
                strings: strings,
                denominationPaise: denomination,
                isCoinRow: denomination == kCoinDenominationPaise,
                controller: _controllers[denomination]!,
                errorText: _inputErrors[denomination],
                rowTotalPaise: denomination * (_quantities[denomination] ?? 0),
                counted: (_quantities[denomination] ?? 0) > 0,
                onChanged: (String raw) => _onRowChanged(raw, denomination),
                onTapSelectAll: () {
                  final TextEditingController controller =
                      _controllers[denomination]!;
                  if (controller.text.isEmpty) return;
                  controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  );
                },
              ),
              // One gap value between every row, so the denomination list
              // reads as an even grid rather than a stack of uneven cards.
              // One step, not six: seven rows plus this gap have to share a
              // 390x770 screen with the total card and four actions.
              const SizedBox(height: _rowGap),
            ],
            const SizedBox(height: _rowGap),
            _GrandTotalCard(strings: strings, amountPaise: _grandTotalPaise),
            const SizedBox(height: 8),
            if (addToKhataVisible) ...<Widget>[
              FilledButton.icon(
                key: const Key('note-counter-add-to-khata'),
                onPressed: _addToKhata,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  minimumSize: const Size.fromHeight(44),
                  shape: const StadiumBorder(),
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
              const SizedBox(height: 5),
            ],
            if (_persistent) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _ActionButton.outlined(
                      buttonKey: const Key('note-counter-saved-sessions'),
                      onPressed: _showSessions,
                      icon: Icons.bookmark_outline,
                      label: copy.savedSessions,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton.filled(
                      buttonKey: const Key('note-counter-copy-summary'),
                      onPressed: _copySummary,
                      icon: Icons.content_copy,
                      label: copy.copySummary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
            ] else ...<Widget>[
              _ActionButton.outlined(
                buttonKey: const Key('note-counter-copy-summary'),
                onPressed: _copySummary,
                icon: Icons.content_copy,
                label: copy.copySummary,
              ),
              const SizedBox(height: 8),
            ],
            if (_persistent) ...<Widget>[
              const SizedBox(height: 2),
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
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.softText,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 2),
            Center(
              child: Text(
                _persistent
                    ? copy.savedHint
                    : strings.text(AppString.counterSession),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.1,
                  color: AppColors.softText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tier of an [_ActionButton].
enum _ActionTier {
  /// The one primary action (Copy summary): solid green.
  primary,

  /// Everything else: a plain green outline.
  outlined,
}

/// A flat-friendly action button that tolerates two lines of
/// label at large text scales. Never overflows: the label wraps.
///
/// All three tiers share one height and one stadium shape, so the row below
/// the Grand Total reads as a single control group with a plain reading order:
/// Copy summary is the loudest, Saved sessions is the named entry point.
class _ActionButton extends StatelessWidget {
  const _ActionButton.filled({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onPressed,
  }) : _tier = _ActionTier.primary;

  const _ActionButton.outlined({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onPressed,
  }) : _tier = _ActionTier.outlined;

  /// Lands on the actual button, so a tap-test finds exactly one target.
  final Key buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final _ActionTier _tier;

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
    const StadiumBorder shape = StadiumBorder();
    const EdgeInsets labelPadding = EdgeInsets.symmetric(
      horizontal: 8,
      vertical: 4,
    );
    // Every action on this screen is the same height and radius, so the stack
    // below the total reads as one control group.
    return switch (_tier) {
      _ActionTier.primary => FilledButton(
        key: buttonKey,
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.primaryGreen,
          disabledForegroundColor: AppColors.onPrimary,
          padding: labelPadding,
          shape: shape,
        ),
        child: child,
      ),
      _ActionTier.outlined => OutlinedButton(
        key: buttonKey,
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          padding: labelPadding,
          foregroundColor: AppColors.primaryGreen,
          side: const BorderSide(color: AppColors.primaryGreen),
          shape: shape,
        ),
        child: child,
      ),
    };
  }
}

/// One denomination row: its illustration, a quantity field and the row
/// total. Note rows hold how many notes; the coin row holds the **total
/// value of the coins in rupees**, never a coin count.
///
/// The quantity field is the row's stepper: it is the same fixed width in
/// every row so the seven fields line up down the screen, and the row makes
/// the state visible without moving anything - a counted row keeps a deeper
/// green edge while the row being typed into adds a brighter edge, a
/// light-green field and a soft lift.
class _DenominationRow extends StatefulWidget {
  const _DenominationRow({
    required this.strings,
    required this.denominationPaise,
    required this.isCoinRow,
    required this.controller,
    required this.errorText,
    required this.rowTotalPaise,
    required this.counted,
    required this.onChanged,
    required this.onTapSelectAll,
  });

  final AppStrings strings;
  final int denominationPaise;
  final bool isCoinRow;
  final TextEditingController controller;
  final String? errorText;
  final int rowTotalPaise;

  /// Whether this row holds a quantity: counted rows lift off the canvas so
  /// the eye finds what has already been entered.
  final bool counted;
  final ValueChanged<String> onChanged;
  final VoidCallback onTapSelectAll;

  @override
  State<_DenominationRow> createState() => _DenominationRowState();
}

class _DenominationRowState extends State<_DenominationRow> {
  /// Owns the focus of this row's quantity field, so the row itself can show
  /// that it is the one being counted.
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!mounted || _focused == _focusNode.hasFocus) return;
    setState(() => _focused = _focusNode.hasFocus);
  }

  String get _asset => widget.isCoinRow
      ? 'assets/notes/coins.png'
      : 'assets/notes/note_${widget.denominationPaise ~/ 100}.png';

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = widget.strings;
    final _Copy copy = _Copy(strings.language);
    final String title = widget.isCoinRow
        ? (strings.language == AppLanguage.bn ? 'কয়েন' : 'Coins')
        : strings.money(widget.denominationPaise);
    final String fieldLabel = widget.isCoinRow
        ? copy.coinsAmountLabel(strings)
        : copy.quantityFieldLabel(strings, widget.denominationPaise);
    return AnimatedContainer(
      key: Key('note-counter-row-${widget.denominationPaise}'),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warmIvory,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _focused
              ? AppColors.primaryGreen
              : widget.counted
              ? AppColors.secondaryGreen.withValues(alpha: 0.55)
              : AppColors.accentGreen.withValues(alpha: 0.4),
          width: _focused ? 1.6 : (widget.counted ? 1.3 : 1),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.beige.withValues(alpha: _focused ? 0.7 : 0.45),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          ExcludeSemantics(
            child: SizedBox(
              width: 100,
              height: 48,
              child: Image.asset(
                _asset,
                fit: BoxFit.contain,
                errorBuilder:
                    (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) => const ColoredBox(
                      color: AppColors.warmIvory,
                      child: Icon(
                        Icons.payments_outlined,
                        size: 28,
                        color: AppColors.primaryGreen,
                      ),
                    ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 2),
                KeyedSubtree(
                  key: Key(
                    'note-counter-row-total-${widget.denominationPaise}',
                  ),
                  child: Text(
                    strings.money(widget.rowTotalPaise),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // The quantity stepper: the same fixed width in every row, so all
          // seven fields line up down the screen.
          SizedBox(
            width: 96,
            child: Semantics(
              textField: true,
              label: fieldLabel,
              child: TextField(
                key: Key('note-counter-field-${widget.denominationPaise}'),
                controller: widget.controller,
                focusNode: _focusNode,
                onChanged: widget.onChanged,
                onTap: widget.onTapSelectAll,
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.next,
                // No filtering formatters: the controller is the single
                // source of validation, so a rejected value is shown as
                // typed with an explicit error rather than silently kept.
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.headerGreen,
                ),
                decoration: InputDecoration(
                  errorText: widget.errorText,
                  errorMaxLines: 2,
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.lightGreen,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accentGreen),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accentGreen),
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
        ],
      ),
    );
  }
}

/// The Grand Total panel.
///
/// One calm panel instead of a loud gradient: a `lightGreen` fill, a single
/// green edge and the check icon from the style guide, with the label quiet
/// and the amount the loudest thing on the screen. It keeps the shared card
/// radius, so the bottom of the counter reads as one stack.
class _GrandTotalCard extends StatelessWidget {
  const _GrandTotalCard({required this.strings, required this.amountPaise});

  final AppStrings strings;
  final int amountPaise;

  @override
  Widget build(BuildContext context) {
    final bool counting = amountPaise > 0;
    return Container(
      key: const Key('note-counter-grand-total'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(
            alpha: counting ? 0.45 : 0.20,
          ),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.warmIvory,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 20,
              color: AppColors.incomeGreen,
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 44, color: AppColors.accentGreen),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  strings.text(AppString.grandTotal),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headerGreen,
                  ),
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    strings.money(amountPaise),
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 24,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: AppColors.headerGreen,
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: failed ? AppColors.warmIvory : null,
        borderRadius: BorderRadius.circular(12),
        border: failed ? Border.all(color: AppColors.beige) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.info, size: 15, color: AppColors.primaryGreen),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
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

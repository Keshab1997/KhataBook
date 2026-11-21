// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../home/models.dart';
import '../entry/add_entry_screen.dart';
import '../entry/category_picker.dart';
import '../entry/category_store.dart';
import '../entry/transaction_editor_screen.dart';
import 'data/local_ledger.dart';

/// Geometry shared by this screen: one card radius, one 1 px rule between the
/// rows of a day, one border tone for a card that carries data and a softer one
/// for a placeholder that has nothing in it. Sizes the reference calls for - a
/// rounded calendar tile, a circular type badge, a capsule ribbon on the totals
/// card - are named here too, so the screen is one set of numbers.
const double _cardRadius = 20;
const double _cardGap = 12;
const double _groupGap = 16;
const double _labelGap = 8;
const double _separator = 1;
const double _edge = 0.85;
const double _softEdge = 0.6;

/// Row geometry: one calendar tile, one gap, then the text column.
const double _rowPadding = 12;
const double _avatarSize = 40;
const double _rowGap = 12;

/// The one type scale for this screen. Only the text a user types into the
/// search box sits outside it.
const double _labelSize = 12;
const double _rowTitleSize = 15;
const double _cardTitleSize = 16;
const double _valueSize = 20;
const double _rowAmountSize = 18;
const double _headerTitleSize = 23;

/// A caption above a figure (the totals tiles), quiet but deliberate: the same
/// 12 sp / w800 / 0.4 the entry screens' caption uses.
const TextStyle _cardLabel = TextStyle(
  fontSize: _labelSize,
  height: 1.25,
  letterSpacing: 0.4,
  fontWeight: FontWeight.w800,
);

/// The meta line under a row title: category and time, or a count.
const TextStyle _meta = TextStyle(
  fontSize: _labelSize,
  height: 1.3,
  color: AppColors.softText,
  fontWeight: FontWeight.w500,
);

/// A wrapped, slightly looser meta line for the paragraphs under a heading.
const TextStyle _metaBlock = TextStyle(
  fontSize: _labelSize,
  height: 1.45,
  color: AppColors.softText,
);

/// The 1 dp beige edge a placeholder uses: softer than a card that carries
/// data, because there is nothing in it to frame.
BorderSide get _softCardBorder =>
    BorderSide(color: AppColors.outline.withValues(alpha: _softEdge));

/// The single soft shadow from `theme.md` (blur 14, offset 0/4), kept for the
/// two cards that are the point of the screen: the design asks for depth on the
/// totals card and on the rows, and for nothing else.
List<BoxShadow> _cardShadow({double alpha = 0.05}) => <BoxShadow>[
  BoxShadow(
    color: AppColors.darkText.withValues(alpha: alpha),
    blurRadius: 14,
    offset: const Offset(0, 4),
  ),
];

/// Money text, right-aligned where it is scanned in a column. Tabular figures
/// give every digit the same width, so amounts line up down the list instead of
/// stepping with each glyph's natural advance.
TextStyle _money({
  required double size,
  required Color color,
  double letterSpacing = 0,
  double height = 1.15,
  FontWeight weight = FontWeight.w800,
}) {
  return TextStyle(
    fontSize: size,
    height: height,
    letterSpacing: letterSpacing,
    fontWeight: weight,
    color: color,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );
}

/// The device-local calendar day of [instant].
///
/// Storage keeps UTC instants (see docs/spec/data-model.md), so every date
/// comparison converts first: a 22:30 UTC entry belongs to the local day the
/// user actually saw, never to the UTC calendar day.
DateTime localDayOf(DateTime instant) {
  final DateTime local = instant.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Whether [instant] falls on one of the local calendar days in [range].
///
/// Both ends are inclusive and compare whole local days, so an entry at 23:59
/// on the end day still matches while one at 00:00 the next morning does not.
/// `null` means there is no date filter, which matches every day.
bool matchesLocalDateRange(DateTime instant, DateTimeRange? range) {
  if (range == null) {
    return true;
  }
  final DateTime day = localDayOf(instant);
  return !day.isBefore(localDayOf(range.start)) &&
      !day.isAfter(localDayOf(range.end));
}

/// [raw] with the surrounding whitespace removed and lower-cased, so matching
/// ignores case and stray spaces. Bengali has no case, so the lower-casing is
/// a no-op there and a Bengali query still matches Bengali text.
String normalizeSearchQuery(String raw) => raw.trim().toLowerCase();

/// Whether [entry] matches [rawQuery], a case-insensitive substring.
///
/// The query is tested against the title (the stored description, or the
/// category when there is no description), against the category, and against
/// the stored description. An empty or whitespace-only query matches
/// everything, which is what "no search" means.
///
/// [displayCategory] adds the category name the screen is actually showing -
/// the translated label for a built-in category, or a custom category's own
/// name. It is a *third* haystack, never a replacement: the stored token is
/// still searched, so a query behaves the same in both languages and a user
/// who types what they can see is not told their row is missing. Nothing is
/// written back; the stored id stays exactly as it was.
bool matchesSearchQuery(
  LedgerEntry entry,
  String rawQuery, {
  String? displayCategory,
}) {
  final String query = normalizeSearchQuery(rawQuery);
  if (query.isEmpty) {
    return true;
  }
  if (entry.title.toLowerCase().contains(query)) {
    return true;
  }
  if (entry.category.toLowerCase().contains(query)) {
    return true;
  }
  final String? description = entry.description;
  if (description != null && description.toLowerCase().contains(query)) {
    return true;
  }
  final String? shown = displayCategory;
  if (shown != null && shown.toLowerCase().contains(query)) {
    return true;
  }
  return false;
}

/// The screen's own copy: the decorative subtitle and footer the shared
/// dictionary does not carry, in both languages. Everything a user acts on is
/// still an [AppString], so stored values stay canonical.
class _ScreenCopy {
  const _ScreenCopy(this.bn);

  final bool bn;

  String get subtitle =>
      bn ? 'আয় ও ব্যয়ের হিসাব রাখুন' : 'Track Your Income & Expenses';
  String get footer => bn
      ? 'স্মার্ট হিসাব… সুন্দর পরিকল্পনা…'
      : 'Smart Tracking… Better Planning…';
  String get calendarTooltip => bn ? 'তারিখ বেছে নিন' : 'Pick a date';
  String get filters => bn ? 'ফিল্টার ও অনুসন্ধান' : 'Filters & search';
  String get closeFilters => bn ? 'ফিল্টার গোপন করুন' : 'Hide filters';
  String get showFilters => bn ? 'ফিল্টার দেখান' : 'Show filters';
  String get live => bn ? 'সরাসরি' : 'LIVE';
  String get backTooltip => bn ? 'পেছনে' : 'Back';

  /// The filter action's two jobs, named separately: the pill's cap opens the
  /// panels, and the chip under the search box closes them again. A control is
  /// never labelled "Hide" while it would open something.
  String get openFilters => bn ? 'ফিল্টার খুলুন' : 'Open filters';

  /// The summary of what is narrowing the list while the panels are closed, so
  /// a hidden filter is never mistaken for no filter.
  String get noActiveFilters => bn ? 'কোনো ফিল্টার নেই' : 'No filters applied';
  String get activeFilters => bn ? 'সক্রিয় ফিল্টার' : 'Filters applied';

  /// One line per active filter in the collapsed summary. The values are the
  /// same localized labels the chips show when the panels are open.
  String get searchLabel => bn ? 'খোঁজ' : 'Search';
  String get typeLabel => bn ? 'ধরন' : 'Type';
  String get categoryLabel => bn ? 'বিভাগ' : 'Category';
  String get datesLabel => bn ? 'তারিখ' : 'Dates';

  /// The two halves of a date span, with an open end spelled out rather than
  /// drawn as a dash the reader has to interpret.
  String get anyDate => bn ? 'যেকোনো তারিখ' : 'any date';
  String get dateSpanSeparator => bn ? 'থেকে' : 'to';
}

/// S2 — All Transactions. See docs/spec/screens.md#s2--all-transactions.
///
/// Reads nothing: the parent supplies an immutable [summary] and this screen
/// filters, groups and totals it for display only. Editing goes back through the
/// parent's [ledger] + [khataId] pair, and every change is re-read from storage,
/// never patched locally.
///
/// Presentation follows the illustrated reference: a branded green header with a
/// wavy golden lower edge, one ivory totals card carrying a live count ribbon,
/// a search pill, three filter panels and one ivory card per transaction, each
/// with a local-calendar tile on the left. No figure is invented: totals come
/// from the rows currently shown, and the note under them says so.
class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({
    super.key,
    required this.summary,
    this.ledger,
    this.khataId,
    this.onSummaryChanged,
    this.language = AppLanguage.en,
    this.categoryStore,
  });

  /// The khata to display. Treated as immutable, including its entry list.
  final CategoryStore? categoryStore;
  final LedgerSummary summary;
  final LocalLedger? ledger;
  final String? khataId;
  final ValueChanged<LedgerSummary>? onSummaryChanged;

  /// Copy language for this screen and the dialogs it opens. Display only.
  final AppLanguage language;

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  late LedgerSummary _summary;
  bool _refreshError = false;

  /// Copy for this screen and its subwidgets. Display only: stored values are
  /// never routed through it.
  AppStrings get _strings => AppStrings(widget.language);

  /// The screen's own decorative copy (subtitle, footer, tooltips).
  _ScreenCopy get _copy => _ScreenCopy(widget.language == AppLanguage.bn);

  /// The search box's text. Owned by the screen so the query survives a
  /// rebuild after an edit and the controller is released with the screen.
  final TextEditingController _searchController = TextEditingController();

  /// The search box's focus node, so the header's tune control can put the
  /// cursor in it instead of being decoration.
  final FocusNode _searchFocus = FocusNode();

  /// The key of the search field, so the tune control can scroll it into view
  /// before focusing it on a short screen.
  final GlobalKey _searchKey = GlobalKey();

  /// Whether the filter panels are open.
  ///
  /// Open by default, but *disclosed*: the header, the totals, the search box
  /// and the first rows were what the user came for, so the page is ordered
  /// ledgers-first (see [_buildContent]) and the panels are compact one-line
  /// groups rather than tall cards. The tune cap closes them to give the rows
  /// the whole screen, and the state strip underneath keeps every live choice
  /// visible and liftable while they are shut.
  bool _filtersOpen = true;

  /// The live query the rows are filtered by, updated on every keystroke so
  /// the list and the totals change together.
  String _query = '';

  /// The first local day to show; `null` means no lower bound.
  DateTime? _fromDay;

  /// The last local day to show; `null` means no upper bound.
  DateTime? _toDay;

  @override
  void initState() {
    super.initState();
    _summary = widget.summary;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
  }

  void _clearQuery() {
    _searchController.clear();
    setState(() => _query = '');
  }

  /// The search shortcut behind the tune control's long press: open the panels
  /// if they are closed, put the cursor in the search box, and scroll it into
  /// view. A plain press toggles the panels instead ([_toggleFilters]), because
  /// opening filters must not be the same gesture as summoning the keyboard.
  Future<void> _focusFilters() async {
    if (!_filtersOpen) {
      setState(() => _filtersOpen = true);
    }
    final BuildContext? field = _searchKey.currentContext;
    if (field != null) {
      await Scrollable.ensureVisible(
        field,
        duration: const Duration(milliseconds: 220),
        alignment: 0.1,
      );
    }
    if (mounted) {
      _searchFocus.requestFocus();
    }
  }

  void _toggleFilters() {
    setState(() => _filtersOpen = !_filtersOpen);
    if (!_filtersOpen) {
      _searchFocus.unfocus();
    }
  }

  Future<void> _refresh() async {
    final ledger = widget.ledger;
    final khataId = widget.khataId;
    final onSummaryChanged = widget.onSummaryChanged;
    if (ledger == null || khataId == null) return;
    try {
      final updated = await ledger.readSummary(khataId: khataId);
      if (mounted) {
        setState(() {
          _summary = updated;
          _refreshError = false;
        });
      }
      onSummaryChanged?.call(updated);
    } catch (_) {
      if (mounted) setState(() => _refreshError = true);
    }
  }

  Future<void> _edit(LedgerEntry entry) async {
    final ledger = widget.ledger;
    final khataId = widget.khataId;
    final entryId = entry.id;
    if (ledger == null || khataId == null || entryId == null) return;
    final AppStrings strings = _strings;
    final messenger = ScaffoldMessenger.of(context);
    final onSummaryChanged = widget.onSummaryChanged;
    // A tap is only an edit when the row carries a persisted id; a preview row
    // (id == null) has nothing to update, so it must never look tappable.
    final result = await Navigator.of(context).push<TransactionEditResult>(
      MaterialPageRoute<TransactionEditResult>(
        builder: (_) => TransactionEditorScreen(
          categoryStore: widget.categoryStore,
          language: widget.language,
          initial: EntryFormResult(
            kind: entry.type == EntryType.income
                ? EntryFormKind.income
                : EntryFormKind.expense,
            amountPaise: entry.amountPaise,
            category: entry.category,
            description: entry.description ?? '',
            occurredAt: entry.at,
          ),
          onUpdate: (value) => ledger.updateEntry(
            khataId: khataId,
            entryId: entryId,
            entry: value,
          ),
          onDelete: () =>
              ledger.softDeleteEntry(khataId: khataId, entryId: entryId),
        ),
      ),
    );
    if (result == null || !mounted) return;
    await _refresh();
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    if (result == TransactionEditResult.updated) {
      messenger.showSnackBar(
        SnackBar(content: Text(strings.text(AppString.transactionUpdated))),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(strings.text(AppString.transactionDeleted)),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: strings.text(AppString.undo),
            onPressed: () async {
              try {
                final restored = await ledger.restoreEntry(
                  khataId: khataId,
                  entryId: entryId,
                );
                if (mounted) {
                  await _refresh();
                } else {
                  final updated = await ledger.readSummary(khataId: khataId);
                  onSummaryChanged?.call(updated);
                }
                if (!messenger.mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      strings.text(
                        restored
                            ? AppString.transactionRestored
                            : AppString.transactionRestoreFailed,
                      ),
                    ),
                  ),
                );
              } catch (_) {
                if (messenger.mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        strings.text(AppString.transactionRestoreFailed),
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ),
      );
    }
  }

  /// `null` means every type, so "All" is a real state rather than a flag.
  EntryType? _typeFilter;

  /// `null` means every category.
  String? _categoryFilter;

  void _selectType(EntryType? type) {
    setState(() => _typeFilter = type);
  }

  void _selectCategory(String? category) {
    setState(() => _categoryFilter = category);
  }

  /// Every filter at once: query, both days, type and category.
  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _typeFilter = null;
      _categoryFilter = null;
      _fromDay = null;
      _toDay = null;
    });
  }

  void _clearDates() {
    setState(() {
      _fromDay = null;
      _toDay = null;
    });
  }

  /// Whether any of the four filters is narrowing the list right now. The
  /// result count and the end-of-list line use it to say what they describe:
  /// the whole khata, or the slice currently on screen.
  bool get _hasFilters =>
      normalizeSearchQuery(_query).isNotEmpty ||
      _typeFilter != null ||
      _categoryFilter != null ||
      _fromDay != null ||
      _toDay != null;

  /// The newest local day in the khata, so a picker opens near the data the
  /// user is already looking at instead of on today's month.
  DateTime? get _newestEntryDay {
    DateTime? newest;
    for (final LedgerEntry entry in _summary.entries) {
      final DateTime day = localDayOf(entry.at);
      if (newest == null || day.isAfter(newest)) {
        newest = day;
      }
    }
    return newest;
  }

  /// [intl] copy for the two date pickers. Bengali gets Bengali labels; the
  /// picker's own strings are only overridden where the app has a translation.
  Future<DateTime?> _showDayPicker({
    required DateTime initial,
    required AppString help,
  }) {
    final bool bengali = widget.language == AppLanguage.bn;
    final AppStrings strings = _strings;
    final DateTime first = DateTime(1900);
    final DateTime last = DateTime(DateTime.now().year + 100, 12, 31);
    final DateTime clamped = initial.isBefore(first)
        ? first
        : (initial.isAfter(last) ? last : initial);
    return showDatePicker(
      context: context,
      helpText: strings.text(help),
      cancelText: bengali ? strings.text(AppString.cancel) : null,
      confirmText: bengali ? 'ঠিক আছে' : null,
      fieldLabelText: bengali ? strings.text(AppString.date) : null,
      initialDate: clamped,
      firstDate: first,
      lastDate: last,
    );
  }

  DateTime get _clampedInitial {
    final DateTime now = DateTime.now();
    final DateTime first = DateTime(1900);
    final DateTime last = DateTime(now.year + 100, 12, 31);
    return now.isBefore(first) ? first : (now.isAfter(last) ? last : now);
  }

  Future<void> _pickFromDay() async {
    final DateTime proposed = _fromDay ?? _newestEntryDay ?? _clampedInitial;
    final DateTime? chosen = await _showDayPicker(
      initial: proposed,
      help: AppString.pickFromDay,
    );
    if (chosen == null || !mounted) {
      return;
    }
    final DateTime day = localDayOf(chosen);
    final DateTime? to = _toDay;
    setState(() {
      if (to != null && day.isAfter(to)) {
        // A start after the current end means the user picked the two days
        // the other way round; keep the span and let the labels follow it.
        _fromDay = to;
        _toDay = day;
      } else {
        _fromDay = day;
      }
    });
  }

  Future<void> _pickToDay() async {
    final DateTime proposed =
        _toDay ?? _fromDay ?? _newestEntryDay ?? _clampedInitial;
    final DateTime? chosen = await _showDayPicker(
      initial: proposed,
      help: AppString.pickToDay,
    );
    if (chosen == null || !mounted) {
      return;
    }
    final DateTime day = localDayOf(chosen);
    final DateTime? from = _fromDay;
    setState(() {
      if (from != null && day.isBefore(from)) {
        _fromDay = day;
        _toDay = from;
      } else {
        _toDay = day;
      }
    });
  }

  /// 48 dp clear control, shown only while there is a query to clear.
  Widget _clearSearchButton() {
    return IconButton(
      key: const Key('search-clear'),
      tooltip: _strings.text(AppString.clearSearch),
      onPressed: _clearQuery,
      icon: const Icon(Icons.close),
    );
  }

  /// Categories to offer, alphabetical on the canonical stored token. Built
  /// from every entry, not the filtered ones, so choosing a category never
  /// moves the chips under the user's finger. The selected category stays
  /// listed even when an edit removed its last entry, so such a filter still
  /// reads as selected and can be changed instead of silently disappearing.
  /// Ordering stays canonical too, so switching language relabels the chips
  /// without rearranging them under the user.
  List<String> get _categoryOptions {
    final Set<String> unique = <String>{
      for (final LedgerEntry entry in _summary.entries) entry.category,
    };
    final String? selected = _categoryFilter;
    if (selected != null) {
      unique.add(selected);
    }
    return unique.isEmpty ? const <String>[] : (unique.toList()..sort());
  }

  /// Entries matching all four filters, newest first.
  ///
  /// [categories] is the custom-category catalog, when the parent wired one, so
  /// search can also match the name the row is displaying. Without it the
  /// built-in labels are still used, which is what a screen with no store has
  /// been showing all along.
  List<LedgerEntry> _visibleEntries(List<CustomCategory>? categories) {
    final List<LedgerEntry> rows = _summary.entries
        .where((LedgerEntry entry) {
          final bool typeMatches =
              _typeFilter == null || entry.type == _typeFilter;
          final bool categoryMatches =
              _categoryFilter == null || entry.category == _categoryFilter;
          return typeMatches &&
              categoryMatches &&
              (_fromDay == null || !localDayOf(entry.at).isBefore(_fromDay!)) &&
              (_toDay == null || !localDayOf(entry.at).isAfter(_toDay!)) &&
              matchesSearchQuery(
                entry,
                _query,
                displayCategory: categories == null
                    ? _categoryLabel(_strings, entry.category)
                    : categoryDisplayName(
                        widget.language,
                        entry.category,
                        categories,
                      ),
              );
        })
        .toList(growable: false);
    return List<LedgerEntry>.from(rows)..sort(_newestFirst);
  }

  /// What is narrowing the list right now, in words, for the strip under the
  /// search box. Each non-null field is both a statement ("Type: Income") and a
  /// button that lifts that filter, so a closed panel never hides a live filter
  /// and a live filter can always be undone without opening the panels.
  _ActiveFilterSummary _activeFilterSummary(List<CustomCategory>? categories) {
    final AppStrings strings = _strings;
    final _ScreenCopy copy = _copy;
    final String query = _query.trim();
    final EntryType? type = _typeFilter;
    final String? category = _categoryFilter;
    final DateTime? from = _fromDay;
    final DateTime? to = _toDay;

    String? dates;
    if (from != null && to != null) {
      dates =
          '${strings.day(from)} ${copy.dateSpanSeparator} '
          '${strings.day(to)}';
    } else if (from != null) {
      // One open end is named as such: a single picked day must not read as a
      // span that includes days the user never chose.
      dates = strings.dateFilter(from: true, date: from);
    } else if (to != null) {
      dates = strings.dateFilter(from: false, date: to);
    }

    return _ActiveFilterSummary(
      search: query.isEmpty ? null : query,
      type: type == null
          ? null
          : strings.text(
              type == EntryType.income ? AppString.income : AppString.expense,
            ),
      category: category == null
          ? null
          : (categories == null
                ? _categoryLabel(strings, category)
                : categoryDisplayName(widget.language, category, categories)),
      dates: dates,
      labels: _ActiveFilterSummaryLabels(
        search: copy.searchLabel,
        type: copy.typeLabel,
        category: copy.categoryLabel,
        dates: copy.datesLabel,
        none: copy.noActiveFilters,
      ),
    );
  }

  /// Newest first, with a total order so equal timestamps are still stable:
  /// title, then category, then amount decide ties instead of list order.
  int _newestFirst(LedgerEntry a, LedgerEntry b) {
    final int byTime = b.at.compareTo(a.at);
    if (byTime != 0) {
      return byTime;
    }
    final int byTitle = a.title.compareTo(b.title);
    if (byTitle != 0) {
      return byTitle;
    }
    final int byCategory = a.category.compareTo(b.category);
    if (byCategory != 0) {
      return byCategory;
    }
    return a.amountPaise.compareTo(b.amountPaise);
  }

  /// Buckets already-sorted rows into months, then days, summing each month's
  /// income and expense from the rows it actually contains.
  List<_MonthGroup> _group(List<LedgerEntry> rows) {
    final List<_MonthGroup> months = <_MonthGroup>[];
    for (final LedgerEntry entry in rows) {
      final DateTime local = entry.at.toLocal();
      final DateTime month = DateTime(local.year, local.month);
      final DateTime day = DateTime(local.year, local.month, local.day);

      _MonthGroup monthGroup;
      if (months.isNotEmpty && months.last.month == month) {
        monthGroup = months.last;
      } else {
        monthGroup = _MonthGroup(month);
        months.add(monthGroup);
      }

      _DayGroup dayGroup;
      if (monthGroup.days.isNotEmpty && monthGroup.days.last.day == day) {
        dayGroup = monthGroup.days.last;
      } else {
        dayGroup = _DayGroup(day);
        monthGroup.days.add(dayGroup);
      }

      dayGroup.entries.add(entry);
      if (entry.type == EntryType.income) {
        monthGroup.incomePaise += entry.amountPaise;
      } else {
        monthGroup.expensePaise += entry.amountPaise;
      }
    }
    return months;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categoryStore == null) return _buildContent(context, null);
    return CategoryCatalog(
      store: widget.categoryStore!,
      builder: (context, categories) => _buildContent(context, categories),
    );
  }

  /// The branded header every state of this screen shares: the same green
  /// gradient and wavy golden edge as the Counter banner and the Add Entry
  /// header, a circular back action, the title and its subtitle, and the
  /// calendar action that opens the real date picker.
  Widget _header({bool calendarEnabled = true}) {
    final AppStrings strings = _strings;
    final _ScreenCopy copy = _copy;
    final bool canPop = Navigator.of(context).canPop();
    return _LedgerHeader(
      title: strings.text(AppString.allTransactions),
      subtitle: copy.subtitle,
      titleKey: const Key('all-transactions-title'),
      onBack: canPop ? () => Navigator.of(context).maybePop() : null,
      backTooltip: copy.backTooltip,
      trailing: _RoundHeaderAction(
        key: const Key('all-transactions-calendar'),
        icon: Icons.calendar_month_outlined,
        tooltip: copy.calendarTooltip,
        onPressed: calendarEnabled ? _pickFromDay : null,
      ),
    );
  }

  /// The failure state keeps the header and the back action, so a failed
  /// refresh is still a page you can leave.
  Widget _buildRefreshFailure(AppStrings strings) {
    return Scaffold(
      key: const Key('all-transactions-screen'),
      backgroundColor: AppColors.creamBackground,
      body: Column(
        children: <Widget>[
          _header(),
          Expanded(
            child: SafeArea(
              top: false,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.expenseRed,
                        size: 28,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        strings.text(AppString.refreshTransactionsFailed),
                        key: const Key('transactions-refresh-failed'),
                        textAlign: TextAlign.center,
                        style: _metaBlock,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const Key('transactions-refresh-retry'),
                        onPressed: widget.ledger == null ? null : _refresh,
                        child: Text(strings.text(AppString.retry)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<CustomCategory>? categories) {
    final AppStrings strings = _strings;
    if (_refreshError) {
      return _buildRefreshFailure(strings);
    }
    final List<LedgerEntry> allEntries = _summary.entries;
    if (allEntries.isEmpty) {
      return Scaffold(
        key: const Key('all-transactions-screen'),
        backgroundColor: AppColors.creamBackground,
        body: Column(
          children: <Widget>[
            _header(),
            Expanded(
              child: SafeArea(
                top: false,
                child: _EmptyLedger(strings: strings, copy: _copy),
              ),
            ),
          ],
        ),
      );
    }

    // One filtered list feeds the rows, the month totals and the summary card,
    // so the three can never disagree after a filter change.
    final List<LedgerEntry> visible = _visibleEntries(categories);
    final List<_MonthGroup> groups = _group(visible);

    final DateTime? fromDay = _fromDay;
    final DateTime? toDay = _toDay;
    final bool hasDates = fromDay != null || toDay != null;
    final String fromLabel = strings.dateFilter(from: true, date: fromDay);
    final String toLabel = strings.dateFilter(from: false, date: toDay);
    final String fromSemantics = strings.dateFilter(
      from: true,
      date: fromDay,
      semantic: true,
    );
    final String toSemantics = strings.dateFilter(
      from: false,
      date: toDay,
      semantic: true,
    );

    return Scaffold(
      key: const Key('all-transactions-screen'),
      backgroundColor: AppColors.creamBackground,
      body: Column(
        children: <Widget>[
          _header(),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: <Widget>[
                  _SummaryCard(
                    countText: strings.transactionCount(
                      shown: visible.length,
                      total: allEntries.length,
                    ),
                    entries: visible,
                    strings: strings,
                    copy: _copy,
                  ),
                  const SizedBox(height: _cardGap + 2),
                  _SearchPill(
                    fieldKey: _searchKey,
                    controller: _searchController,
                    focusNode: _searchFocus,
                    onChanged: _onQueryChanged,
                    clearButton: _query.isEmpty ? null : _clearSearchButton(),
                    hint: strings.text(AppString.searchHint),
                    label: strings.text(AppString.searchTransactions),
                    tuneTooltip: _filtersOpen
                        ? _copy.closeFilters
                        : _copy.openFilters,
                    filtersOpen: _filtersOpen,
                    // One press, one predictable job: open or close the
                    // panels. It never moves the cursor into the search box,
                    // so opening the filters cannot pull the keyboard up over
                    // the list the user was reading.
                    onTune: _toggleFilters,
                    // The long press keeps the old shortcut for anyone who
                    // reached for it: open the panels *and* focus search.
                    onTuneLongPress: _focusFilters,
                  ),
                  const SizedBox(height: 10),
                  _ActiveFilterStrip(
                    strings: strings,
                    copy: _copy,
                    summary: _activeFilterSummary(categories),
                    filtersOpen: _filtersOpen,
                    count: visible.length,
                    total: allEntries.length,
                    onToggle: _toggleFilters,
                    onClear: _hasFilters ? _clearFilters : null,
                    onType: _selectType,
                    onCategory: _selectCategory,
                    onDates: _clearDates,
                    onSearch: _clearQuery,
                  ),
                  const SizedBox(height: _groupGap),
                  if (groups.isEmpty)
                    _NoMatches(strings: strings, onClear: _clearFilters)
                  else ...<Widget>[
                    for (final _MonthGroup group in groups) ...<Widget>[
                      _MonthHeader(group: group, strings: strings),
                      for (final _DayGroup day in group.days) ...<Widget>[
                        _DayHeader(day: day.day, strings: strings),
                        // One card per row: a transaction is the object being
                        // scanned here, so it is the object that is framed.
                        for (final LedgerEntry entry
                            in day.entries) ...<Widget>[
                          _EntryCard(
                            entry: entry,
                            strings: strings,
                            categories: categories,
                            onTap: widget.ledger == null || entry.id == null
                                ? null
                                : _edit,
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ],
                    // The end of the list says so quietly, so "there is
                    // nothing below" is never mistaken for "the list is still
                    // there".
                    _EndOfList(strings: strings, hasFilters: _hasFilters),
                  ],
                  if (_filtersOpen) ...<Widget>[
                    const SizedBox(height: _groupGap),
                    _FilterPanelsInline(
                      strings: strings,
                      fromLabel: fromLabel,
                      toLabel: toLabel,
                      fromSemantics: fromSemantics,
                      toSemantics: toSemantics,
                      fromDay: fromDay,
                      toDay: toDay,
                      hasDates: hasDates,
                      typeFilter: _typeFilter,
                      categoryFilter: _categoryFilter,
                      categoryOptions: _categoryOptions,
                      categories: categories,
                      language: widget.language,
                      onPickFrom: _pickFromDay,
                      onPickTo: _pickToDay,
                      onClearDates: _clearDates,
                      onSelectType: _selectType,
                      onSelectCategory: _selectCategory,
                    ),
                  ],
                  _FooterArtwork(copy: _copy),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The branded header: green gradient, wavy golden lower edge, optional leaf
/// artwork on the right, a circular back action, the page title and its
/// subtitle, and one trailing round action.
///
/// It paints under the status bar itself, so the green reaches the top edge
/// while every control keeps a 48 dp hit area inside the safe area.
class _LedgerHeader extends StatelessWidget {
  const _LedgerHeader({
    required this.title,
    required this.subtitle,
    required this.titleKey,
    required this.trailing,
    this.onBack,
    this.backTooltip,
  });

  final String title;
  final String subtitle;
  final Key titleKey;
  final Widget trailing;
  final VoidCallback? onBack;
  final String? backTooltip;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double topInset = media.padding.top;
    // The subtitle is the first thing a large text scale crowds out; the title
    // alone carries the header above 145 %.
    final double scale = media.textScaler.scale(14) / 14;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: AppColors.headerGreen,
      ),
      child: ClipRect(
        key: const Key('all-transactions-header'),
        child: Stack(
          children: <Widget>[
            // The wave and its golden edge, drawn rather than shipped as an
            // image, so it scales with the header at any text size.
            Positioned.fill(
              child: CustomPaint(painter: const _HeaderWavePainter()),
            ),
            // The bundled leaf artwork, tucked into the right corner behind
            // every control and every word.
            Positioned(
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                // Below the title and subtitle rows: the leaves may brush the
                // wave, never the words.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 96,
                    maxHeight: 46,
                  ),
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.bottomRight,
                      heightFactor: 1,
                      child: Image.asset(
                        'assets/illustrations/entry_header_leaves.png',
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(8, topInset + 6, 8, 26),
              child: Row(
                children: <Widget>[
                  _RoundHeaderAction(
                    key: const Key('all-transactions-back'),
                    icon: Icons.arrow_back,
                    tooltip: backTooltip,
                    onPressed: onBack,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          key: titleKey,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: _headerTitleSize,
                            height: 1.2,
                            letterSpacing: -0.3,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onPrimary,
                          ),
                        ),
                        if (scale <= 1.45) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            key: const Key('all-transactions-subtitle'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.3,
                              fontStyle: FontStyle.italic,
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  trailing,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The header's shape: a green panel with a shallow wave along its bottom and a
/// golden ribbon following the same curve. One painter, one path, so the gold
/// never drifts away from the green.
class _HeaderWavePainter extends CustomPainter {
  const _HeaderWavePainter();

  static const double _gold = 4;

  Path _wave(Size size, double inset) {
    final double bottom = size.height - inset;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, bottom - 16)
      ..cubicTo(
        size.width * 0.72,
        bottom + 10,
        size.width * 0.34,
        bottom - 30,
        0,
        bottom - 6,
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_wave(size, 0), Paint()..color = AppColors.golden);
    canvas.drawPath(
      _wave(size, _gold),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.primaryGreen, AppColors.headerGreen],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A circular, 48 dp header action: a pale ring on the green panel, so it reads
/// as part of the banner rather than as a floating button.
class _RoundHeaderAction extends StatelessWidget {
  const _RoundHeaderAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.onPrimary.withValues(alpha: 0.16),
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.onPrimary, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        color: AppColors.onPrimary,
        iconSize: 22,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: Icon(icon),
      ),
    );
  }
}

/// The totals card: warm ivory, a green ribbon on its top edge with the live
/// count, income and expense as two columns divided by a hairline, and the
/// honest note that these totals describe only the rows shown.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.countText,
    required this.entries,
    required this.strings,
    required this.copy,
  });

  /// "Showing 2 of 8 transactions", built by the screen so the card and the
  /// active-filter strip can never state two different counts.
  final String countText;
  final List<LedgerEntry> entries;
  final AppStrings strings;
  final _ScreenCopy copy;

  @override
  Widget build(BuildContext context) {
    int incomePaise = 0;
    int expensePaise = 0;
    for (final LedgerEntry entry in entries) {
      if (entry.type == EntryType.income) {
        incomePaise += entry.amountPaise;
      } else {
        expensePaise += entry.amountPaise;
      }
    }

    final String totalsText = strings.flowTotals(
      incomePaise: incomePaise,
      expensePaise: expensePaise,
    );

    // The ribbon straddles the card's top edge. Its own height grows with the
    // text scale, so the card reserves half of it above the figures: at 200 %
    // the capsule can never sit on top of the income caption.
    final double scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final double ribbonHeight =
        MediaQuery.textScalerOf(context).scale(12) * 1.3 + 14;
    // The card is the page's preface, not the page: with the filter panels
    // closed the rows must start on the first screen of a 390x844 phone, so
    // the card's own rhythm is one step tighter than the reference file. Every
    // element stays - ribbon, two totals, rule, note, artwork.

    return Semantics(
      container: true,
      label:
          '$countText. $totalsText '
          '${strings.text(AppString.filteredTotalsExplanation)}',
      child: ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              key: const Key('transactions-summary'),
              padding: EdgeInsets.fromLTRB(16, ribbonHeight / 2 + 4, 16, 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(_cardRadius),
                border: Border.all(
                  color: AppColors.outline.withValues(alpha: _edge),
                ),
                boxShadow: _cardShadow(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Two columns at normal size, as the reference draws them.
                  // At 200 % text each caption needs the full width, so the
                  // pair stacks with a horizontal hairline in place of the
                  // vertical one - the same two figures, never squeezed into
                  // half a line each.
                  if (scale > 1.45) ...<Widget>[
                    _TotalTile(
                      label: strings.text(AppString.income),
                      value: strings.money(incomePaise),
                      color: AppColors.incomeGreen,
                      icon: Icons.trending_up_rounded,
                      income: true,
                    ),
                    const SizedBox(height: 10),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.outline.withValues(alpha: 0.8),
                    ),
                    const SizedBox(height: 10),
                    _TotalTile(
                      label: strings.text(AppString.expense),
                      value: strings.money(expensePaise),
                      color: AppColors.expenseRed,
                      icon: Icons.trending_down_rounded,
                      income: false,
                    ),
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: _TotalTile(
                            label: strings.text(AppString.income),
                            value: strings.money(incomePaise),
                            color: AppColors.incomeGreen,
                            icon: Icons.trending_up_rounded,
                            income: true,
                          ),
                        ),
                        // One hairline between the two figures, with its own
                        // breathing room on either side.
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          child: Container(
                            key: const Key('transactions-summary-rule'),
                            width: _separator,
                            height: 54,
                            color: AppColors.outline.withValues(alpha: 0.8),
                          ),
                        ),
                        Expanded(
                          child: _TotalTile(
                            label: strings.text(AppString.expense),
                            value: strings.money(expensePaise),
                            color: AppColors.expenseRed,
                            icon: Icons.trending_down_rounded,
                            income: false,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.outline.withValues(alpha: 0.55),
                  ),
                  const SizedBox(height: 8),
                  // The bundled coins sit beside the note, never over it: a
                  // decorative asset may share this row, it may not hide a
                  // word of the promise the totals rely on.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          strings.text(AppString.filteredTotalsExplanation),
                          style: _metaBlock,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ExcludeSemantics(
                        child: Opacity(
                          opacity: 0.7,
                          child: Image.asset(
                            'assets/illustrations/counter_header_coins.png',
                            key: const Key('transactions-summary-art'),
                            height: 32,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // The ribbon sits on the card's top edge: a green capsule with the
            // chart glyph and the live count.
            Positioned(
              top: -ribbonHeight / 2,
              left: 16,
              right: 16,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: _CountRibbon(label: countText, copy: copy),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The green capsule on the totals card's edge.
class _CountRibbon extends StatelessWidget {
  const _CountRibbon({required this.label, required this.copy});

  final String label;
  final _ScreenCopy copy;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('transactions-summary-ribbon'),
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.circular(999),
        boxShadow: _cardShadow(alpha: 0.10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.bar_chart_rounded,
            size: 16,
            color: AppColors.onPrimary,
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.golden,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              copy.live,
              style: const TextStyle(
                fontSize: 9.5,
                height: 1.25,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w800,
                color: AppColors.headerGreen,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: AppColors.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One column of the totals card: a tinted circular arrow badge, the caption,
/// then the figure in tabular figures so the two totals share a baseline.
class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.income,
  });

  final String label;

  /// Already formatted for the active language; this tile does no arithmetic.
  final String value;
  final Color color;
  final IconData icon;
  final bool income;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                // Two lines: at 200 % a single line of this caption would
                // ellipsize to "Inco…", which names nothing.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _cardLabel.copyWith(color: AppColors.softText),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            softWrap: false,
            style: _money(size: _valueSize, color: color, letterSpacing: -0.3),
          ),
        ),
      ],
    );
  }
}

/// The rounded search pill: leading glyph, the real controller, and the tune
/// control on a pale-green cap. The tune button simply reflects what it does -
/// while the panels are open it collapses them, and while they are closed it
/// reopens them and puts the cursor in the search box.
class _SearchPill extends StatelessWidget {
  const _SearchPill({
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.hint,
    required this.label,
    required this.clearButton,
    required this.filtersOpen,
    required this.tuneTooltip,
    required this.onTune,
    required this.onTuneLongPress,
  });

  final GlobalKey fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final String hint;
  final String label;
  final Widget? clearButton;
  final bool filtersOpen;
  final String tuneTooltip;
  final VoidCallback onTune;
  final VoidCallback onTuneLongPress;

  @override
  Widget build(BuildContext context) {
    // Two anchors, two jobs: the outer container is the pill's frame (and the
    // node the tune control scrolls to), the inner one is the field's own
    // anchor.
    return Container(
      key: const Key('search-pill'),
      padding: const EdgeInsets.fromLTRB(14, 2, 4, 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outline.withValues(alpha: _edge)),
        boxShadow: _cardShadow(alpha: 0.04),
      ),
      child: Container(
        key: fieldKey,
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: <Widget>[
            const Icon(Icons.search, size: 20, color: AppColors.softText),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const Key('search-field'),
                controller: controller,
                focusNode: focusNode,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(
                  fontSize: _rowTitleSize,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
                decoration: InputDecoration(
                  // A pill, not a framed field: the search box and the entry
                  // screens' inputs share a size and a voice, not a shape.
                  hintText: hint,
                  labelText: label,
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  hintStyle: const TextStyle(
                    fontSize: _rowTitleSize,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: AppColors.softText,
                  ),
                  suffixIcon: clearButton,
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            _TuneButton(
              filtersOpen: filtersOpen,
              tooltip: tuneTooltip,
              onPressed: onTune,
              onLongPress: onTuneLongPress,
            ),
          ],
        ),
      ),
    );
  }
}

/// The pale-green filter cap at the end of the search pill. A real button: it
/// has a tooltip, a 48 dp target and a state the user can hear.
class _TuneButton extends StatelessWidget {
  const _TuneButton({
    required this.filtersOpen,
    required this.tooltip,
    required this.onPressed,
    required this.onLongPress,
  });

  final bool filtersOpen;
  final String tooltip;
  final VoidCallback onPressed;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      onTap: onPressed,
      onLongPress: onLongPress,
      excludeSemantics: true,
      child: Material(
        key: const Key('filters-tune'),
        color: AppColors.lightGreen,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          onLongPress: onLongPress,
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(
              filtersOpen ? Icons.tune : Icons.filter_list,
              size: 20,
              color: AppColors.primaryGreen,
            ),
          ),
        ),
      ),
    );
  }
}

/// The three filter groups, rendered once, in their own compact band below the
/// ledger: date, type and category, each still its own warm panel with its own
/// heading and its own clear action.
///
/// They live behind the search box's filter cap instead of above the list, so
/// the first screen of the history is the history - while every choice the user
/// has made stays stated (and liftable) in the active-filter strip above.
class _FilterPanelsInline extends StatelessWidget {
  const _FilterPanelsInline({
    required this.strings,
    required this.fromLabel,
    required this.toLabel,
    required this.fromSemantics,
    required this.toSemantics,
    required this.fromDay,
    required this.toDay,
    required this.hasDates,
    required this.typeFilter,
    required this.categoryFilter,
    required this.categoryOptions,
    required this.categories,
    required this.language,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClearDates,
    required this.onSelectType,
    required this.onSelectCategory,
  });

  final AppStrings strings;
  final String fromLabel;
  final String toLabel;
  final String fromSemantics;
  final String toSemantics;
  final DateTime? fromDay;
  final DateTime? toDay;
  final bool hasDates;
  final EntryType? typeFilter;
  final String? categoryFilter;
  final List<String> categoryOptions;
  final List<CustomCategory>? categories;
  final AppLanguage language;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onClearDates;
  final ValueChanged<EntryType?> onSelectType;
  final ValueChanged<String?> onSelectCategory;

  /// The label a category chip shows: the stored token is the identity and the
  /// key, the label is display only.
  String _labelFor(String category) => categories == null
      ? _categoryLabel(strings, category)
      : categoryDisplayName(language, category, categories!);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _FilterPanel(
          title: strings.text(AppString.date),
          icon: Icons.event_outlined,
          action: hasDates
              ? _FilterClearAction(
                  key: const Key('date-filter-clear'),
                  label: strings.text(AppString.clearDates),
                  semanticsLabel: strings.text(AppString.clearDatesFilter),
                  onTap: onClearDates,
                )
              : null,
          children: <Widget>[
            _FilterChip(
              key: const Key('date-filter-from'),
              label: fromLabel,
              semanticLabel: fromSemantics,
              icon: Icons.calendar_today_outlined,
              selected: fromDay != null,
              onTap: onPickFrom,
            ),
            _FilterChip(
              key: const Key('date-filter-to'),
              label: toLabel,
              semanticLabel: toSemantics,
              icon: Icons.calendar_month_outlined,
              selected: toDay != null,
              onTap: onPickTo,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _FilterPanel(
          title: strings.text(AppString.type),
          icon: Icons.swap_vert,
          children: <Widget>[
            _FilterChip(
              key: const Key('type-filter-all'),
              label: strings.text(AppString.all),
              semanticLabel: strings.text(AppString.allTypesFilter),
              selected: typeFilter == null,
              onTap: () => onSelectType(null),
            ),
            _FilterChip(
              key: const Key('type-filter-income'),
              label: strings.text(AppString.income),
              semanticLabel: strings.text(AppString.incomeFilter),
              icon: Icons.trending_up_rounded,
              iconColor: AppColors.incomeGreen,
              selected: typeFilter == EntryType.income,
              onTap: () => onSelectType(EntryType.income),
            ),
            _FilterChip(
              key: const Key('type-filter-expense'),
              label: strings.text(AppString.expense),
              semanticLabel: strings.text(AppString.expenseFilter),
              icon: Icons.trending_down_rounded,
              iconColor: AppColors.expenseRed,
              selected: typeFilter == EntryType.expense,
              onTap: () => onSelectType(EntryType.expense),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _FilterPanel(
          title: strings.text(AppString.category),
          icon: Icons.sell_outlined,
          children: <Widget>[
            _FilterChip(
              key: const Key('category-filter-all'),
              label: strings.text(AppString.all),
              semanticLabel: strings.text(AppString.allCategoriesFilter),
              selected: categoryFilter == null,
              onTap: () => onSelectCategory(null),
            ),
            // The key and the filter value stay the canonical stored category;
            // only the visible label is translated, so a tapped chip still
            // matches the same rows in either language.
            for (final String category in categoryOptions)
              _FilterChip(
                key: Key('category-filter-$category'),
                label: _labelFor(category),
                customCategory: categories == null
                    ? null
                    : findCustomCategory(category, categories!),
                semanticLabel: strings.categoryLabel(
                  _labelFor(category),
                  filter: true,
                ),
                selected: categoryFilter == category,
                onTap: () => onSelectCategory(category),
              ),
          ],
        ),
      ],
    );
  }
}

/// One warm panel per filter group: a heading with its own glyph, an optional
/// clear action, and the chips.
class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.title,
    required this.icon,
    required this.children,
    this.action,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    // One warm card per group, but a compact one: the heading and the chips
    // share a tighter rhythm than a data card, because these panels sit *under*
    // the ledger now - they must cost the reader a scroll, not a screen.
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: _softEdge),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 15, color: AppColors.primaryGreen),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _cardLabel.copyWith(color: AppColors.darkText),
                ),
              ),
              if (action case final Widget clear) clear,
            ],
          ),
          const SizedBox(height: 4),
          // One gap for every chip group on the screen, the strip included.
          Wrap(
            spacing: _cardGap,
            runSpacing: _cardGap,
            children: children,
          ),
        ],
      ),
    );
  }
}

/// A quiet text action inside a filter panel heading ("Clear dates", "Show
/// filters"). 44 dp tall, so it is as tappable as a chip.
class _FilterClearAction extends StatelessWidget {
  const _FilterClearAction({
    super.key,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
  });

  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.close, size: 14, color: AppColors.softText),
              const SizedBox(width: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.softText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The localized words the active-filter strip needs: four filter names, the
/// two panel-action names and the "nothing is applied" line.
class _ActiveFilterSummaryLabels {
  const _ActiveFilterSummaryLabels({
    required this.search,
    required this.type,
    required this.category,
    required this.dates,
    required this.none,
  });

  final String search;
  final String type;
  final String category;
  final String dates;
  final String none;
}

/// What the strip states about the current filter state. A `null` field means
/// that filter is not narrowing the list; every non-null one is spoken and is
/// the button that lifts it.
class _ActiveFilterSummary {
  const _ActiveFilterSummary({
    required this.search,
    required this.type,
    required this.category,
    required this.dates,
    required this.labels,
  });

  final String? search;
  final String? type;
  final String? category;
  final String? dates;
  final _ActiveFilterSummaryLabels labels;

  bool get isEmpty =>
      search == null && type == null && category == null && dates == null;

  /// The whole state as one readable line, so a screen reader gets the same
  /// sentence a sighted user reads across the chips.
  String get sentence {
    final List<String> parts = <String>[
      if (search != null) '${labels.search}: $search',
      if (type != null) '${labels.type}: $type',
      if (category != null) '${labels.category}: $category',
      if (dates != null) '${labels.dates}: $dates',
    ];
    return parts.isEmpty ? labels.none : parts.join(', ');
  }
}

/// The one line between the search box and the ledger that states, in words,
/// what is filtering the list.
///
/// The state chip says "No filters applied" - or "Filters applied" - and its
/// tap opens or closes the panels, carrying the count so the state and the
/// number are read together. Every live filter follows as its own chip, and
/// **Clear filters** appears beside them only when there is something to clear,
/// so the action never promises a change it cannot make.
///
/// The chip is deliberately *not* a text field and never requests focus:
/// opening the panels must not force the keyboard up over the ledger.
class _ActiveFilterStrip extends StatelessWidget {
  const _ActiveFilterStrip({
    required this.strings,
    required this.copy,
    required this.summary,
    required this.filtersOpen,
    required this.count,
    required this.total,
    required this.onToggle,
    required this.onClear,
    required this.onType,
    required this.onCategory,
    required this.onDates,
    required this.onSearch,
  });

  final AppStrings strings;
  final _ScreenCopy copy;
  final _ActiveFilterSummary summary;
  final bool filtersOpen;
  final int count;
  final int total;
  final VoidCallback onToggle;
  final VoidCallback? onClear;
  final ValueChanged<EntryType?> onType;
  final ValueChanged<String?> onCategory;
  final VoidCallback onDates;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    // The count lives here too: with the panels closed the summary card is the
    // only thing above the rows, so the strip is where "2 of 8" is easiest to
    // see while scanning.
    final String toggleLabel = filtersOpen ? copy.closeFilters : copy.show;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: _cardGap,
          runSpacing: _cardGap,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            // The state chip is a real control: it opens the panels, reports
            // the state in its label, and carries the count so the two facts
            // are read together.
            _StripChip(
              key: const Key('filters-state'),
              label: summary.isEmpty
                  ? copy.noActiveFilters
                  : copy.activeFilters,
              semanticsLabel:
                  '${toggleLabel}. ${summary.sentence}. '
                  '${strings.transactionCount(shown: count, total: total)}',
              icon: filtersOpen ? Icons.tune : Icons.filter_list,
              iconColor: AppColors.primaryGreen,
              background: AppColors.lightGreen,
              foreground: AppColors.primaryGreen,
              onTap: onToggle,
            ),
            if (summary.search != null)
              _StripChip(
                key: const Key('active-filter-search'),
                label: '${copy.searchLabel}: ${summary.search}',
                semanticsLabel:
                    '${copy.searchLabel}: ${summary.search}. '
                    '${strings.text(AppString.clearSearch)}',
                icon: Icons.search,
                background: AppColors.warmIvory,
                foreground: AppColors.darkText,
                onTap: onSearch,
              ),
            if (summary.type != null)
              _StripChip(
                key: const Key('active-filter-type'),
                label: '${copy.typeLabel}: ${summary.type}',
                semanticsLabel: '${copy.typeLabel}: ${summary.type}. '
                    '${strings.text(AppString.allTypesFilter)}',
                icon: Icons.swap_vert,
                background: AppColors.warmIvory,
                foreground: AppColors.darkText,
                onTap: () => onType(null),
              ),
            if (summary.category != null)
              _StripChip(
                key: const Key('active-filter-category'),
                label: '${copy.categoryLabel}: ${summary.category}',
                semanticsLabel:
                    '${copy.categoryLabel}: ${summary.category}. '
                    '${strings.text(AppString.allCategoriesFilter)}',
                icon: Icons.sell_outlined,
                background: AppColors.warmIvory,
                foreground: AppColors.darkText,
                onTap: () => onCategory(null),
              ),
            if (summary.dates != null)
              _StripChip(
                key: const Key('active-filter-dates'),
                label: '${copy.datesLabel}: ${summary.dates}',
                semanticsLabel:
                    '${copy.datesLabel}: ${summary.dates}. '
                    '${strings.text(AppString.clearDatesFilter)}',
                icon: Icons.event_outlined,
                background: AppColors.warmIvory,
                foreground: AppColors.darkText,
                onTap: onDates,
              ),
            if (onClear != null)
              _FilterClearAction(
                key: const Key('clear-filters-inline'),
                label: strings.text(AppString.clearFilters),
                semanticsLabel: strings.text(AppString.clearFilters),
                onTap: onClear!,
              ),
          ],
        ),
      ],
    );
  }

}

/// A compact, 44 dp+ statement-and-action chip for the active-filter strip.
/// It keeps the chip language of the panels (capsule, flat fill, tinted glyph)
/// at a third of the panel's height.
class _StripChip extends StatelessWidget {
  const _StripChip({
    super.key,
    required this.label,
    required this.semanticsLabel,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.iconColor,
  });

  final String label;
  final String semanticsLabel;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color? iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: semanticsLabel,
      onTap: onTap,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Material(
            color: background,
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            shape: StadiumBorder(
              side: BorderSide(
                color: AppColors.outline.withValues(alpha: _edge),
              ),
            ),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                // The label takes the room it needs up to the strip's width,
                // then ellipsizes: with `Flexible` alone inside a `Wrap` the
                // row was asked to shrink-wrap a flexible child, which throws
                // once the text is long enough to matter.
                child: IntrinsicWidth(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(icon, size: 15, color: iconColor ?? foreground),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _cardLabel.copyWith(
                            color: foreground,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 44 dp+ pill that reports its selected state in words, colour and a check
/// mark, so selection is never carried by colour alone.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.semanticLabel,
    this.customCategory,
    this.icon,
    this.iconColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final CustomCategory? customCategory;
  final IconData? icon;
  final Color? iconColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The emphasis the entry screens already use for a chosen row: a light
    // green fill with a green edge, never a solid button. A row of solid green
    // pills would out-shout the one action on the screen.
    final Color background = selected
        ? AppColors.lightGreen
        : AppColors.warmIvory;
    final Color foreground = selected
        ? AppColors.primaryGreen
        : AppColors.darkText;
    final IconData? glyph = icon;
    final Color? glyphColor = iconColor;

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: semanticLabel,
      // The child is excluded, so the accessible tap action must live on this
      // node; otherwise a screen reader could read the chip but not press it.
      onTap: onTap,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          // Flat: selection is carried by the fill, the edge and the check
          // mark, so an elevation on the chosen chip would only add noise.
          child: Material(
            color: background,
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            shape: StadiumBorder(
              side: BorderSide(
                width: selected ? 1.2 : 1,
                color: selected
                    ? AppColors.primaryGreen
                    : AppColors.outline.withValues(alpha: _edge),
              ),
            ),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (customCategory != null) ...<Widget>[
                      Icon(
                        customCategory!.icon,
                        color: customCategory!.color,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                    ] else if (glyph != null) ...<Widget>[
                      Icon(
                        glyph,
                        size: 15,
                        color: selected
                            ? foreground
                            : (glyphColor ?? foreground),
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (selected) ...<Widget>[
                      Icon(Icons.check, size: 16, color: foreground),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 2,
                        // A chip label is the shared caption, so a chip reads
                        // the same here as a caption on any other card.
                        style: _cardLabel.copyWith(
                          color: foreground,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Month heading with that month's income and expense for the visible rows.
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.group, required this.strings});

  final _MonthGroup group;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final String label = strings.monthYear(group.month);
    final String totals = strings.flowTotals(
      incomePaise: group.incomePaise,
      expensePaise: group.expensePaise,
    );
    return Padding(
      padding: const EdgeInsets.only(top: _groupGap, bottom: _labelGap),
      child: Semantics(
        container: true,
        label: '$label. $totals',
        child: ExcludeSemantics(
          child: Container(
            key: Key(_monthKey(group.month)),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(_cardRadius),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: _edge),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: _cardTitleSize,
                    height: 1.3,
                    letterSpacing: -0.1,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                // The two figures stay on one line each, with their captions
                // in the caption size, so a month reads as a compact summary
                // rather than as a second totals card.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _MonthFigure(
                        label: strings.text(AppString.income),
                        value: strings.money(group.incomePaise),
                        color: AppColors.incomeGreen,
                        icon: Icons.trending_up_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MonthFigure(
                        label: strings.text(AppString.expense),
                        value: strings.money(group.expensePaise),
                        color: AppColors.expenseRed,
                        icon: Icons.trending_down_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One month figure: glyph, caption and value on one baseline.
class _MonthFigure extends StatelessWidget {
  const _MonthFigure({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _meta.copyWith(fontSize: 11, height: 1.2),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  softWrap: false,
                  style: _money(size: 15, color: color, letterSpacing: -0.2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Day heading inside a month: the label that owns the cards under it, set in
/// the caption size with a leading rule, so a heading is found by eye without
/// being mistaken for a row.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.strings});

  final DateTime day;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: _labelGap, bottom: 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 3,
            height: _labelSize,
            decoration: BoxDecoration(
              color: AppColors.navigationGrey,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              strings.day(day),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _cardLabel,
            ),
          ),
        ],
      ),
    );
  }
}

/// The end of the list, said once and quietly.
///
/// It is deliberately not a card: nothing here asks to be read. It only tells
/// the user the scroll has reached the bottom, and whether that bottom belongs
/// to the khata or to the filters currently applied.
class _EndOfList extends StatelessWidget {
  const _EndOfList({required this.strings, required this.hasFilters});

  final AppStrings strings;
  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    // The line names what has ended, so it never reads as a promise that more
    // rows are still on their way.
    final String message = hasFilters
        ? _copy(
            strings,
            en: 'Nothing else under these filters',
            bn: _bnFiltered,
          )
        : _copy(strings, en: 'Nothing else in this khata', bn: _bnWhole);
    return Padding(
      key: const Key('transactions-end'),
      padding: const EdgeInsets.only(top: _groupGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const Icon(
            Icons.horizontal_rule,
            size: 16,
            color: AppColors.navigationGrey,
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(message, maxLines: 2, style: _meta)),
        ],
      ),
    );
  }

  static const String _bnFiltered = 'এই ফিল্টারে আর কিছু নেই';
  static const String _bnWhole = 'এই খাতায় আর কিছু নেই';
}

/// Copy the shared [AppString] dictionary does not carry yet. As on the Wallet
/// Summary screen, a phrase nobody else needs stays private to this file
/// instead of being added to the dictionary.
String _copy(AppStrings strings, {required String en, required String bn}) =>
    strings.language == AppLanguage.bn ? bn : en;

/// One transaction as its own ivory card: a local-calendar tile on the left, a
/// tinted type arrow on it, the title and time, and the signed amount at the
/// right in tabular figures.
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.strings,
    this.categories,
    this.onTap,
  });

  final LedgerEntry entry;
  final AppStrings strings;
  final List<CustomCategory>? categories;
  final ValueChanged<LedgerEntry>? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isIncome = entry.type == EntryType.income;
    final Color amountColor = isIncome
        ? AppColors.incomeGreen
        : AppColors.expenseRed;
    final String signedAmount = strings.signedMoney(
      entry.amountPaise,
      income: isIncome,
    );

    // The stored category is translated for display only; the title is the
    // user's own text and is never touched.
    final String category = categories == null
        ? _categoryLabel(strings, entry.category)
        : categoryDisplayName(strings.language, entry.category, categories!);
    final title = categories != null && entry.title == entry.category
        ? category
        : entry.title;

    final DateTime local = entry.at.toLocal();
    // The day is the tile on the left and the day heading above, so the row's
    // own metadata carries the category and the time of day rather than
    // repeating the same date three times down one screen.
    final String rowMeta = <String>[
      category,
      _timeOf(strings, local),
    ].join(' \u00b7 ');
    final VoidCallback? tap = onTap == null || entry.id == null
        ? null
        : () => onTap!(entry);

    return Semantics(
      container: true,
      button: tap != null,
      onTap: tap,
      label: strings.transactionLabel(
        title: title,
        category: category,
        amountPaise: entry.amountPaise,
        income: isIncome,
        at: local,
        editable: tap != null,
      ),
      child: ExcludeSemantics(
        child: Container(
          // Greppable, and stable per row: the title is the user's own text,
          // which is what a reader would search for.
          // Named on the card itself: the frame is the unit a reader scans,
          // so it is the unit that carries the row's key.
          key: Key('transaction-row-${entry.title}'),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(_cardRadius),
            border: Border.all(
              color: AppColors.outline.withValues(alpha: _edge),
            ),
            boxShadow: _cardShadow(alpha: 0.03),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: entry.id == null ? null : Key('transaction-${entry.id}'),
              onTap: tap,
              child: Padding(
                padding: const EdgeInsets.all(_rowPadding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    _CalendarTile(
                      day: local,
                      income: isIncome,
                      strings: strings,
                    ),
                    const SizedBox(width: _rowGap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: _rowTitleSize,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rowMeta,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _meta.copyWith(height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // The amount is its own column at the right edge, so a
                    // column of figures can be scanned down the list.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 132),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          signedAmount,
                          maxLines: 1,
                          softWrap: false,
                          textAlign: TextAlign.right,
                          // 18 dp w800: the size Home's rows use, and the
                          // large-text size theme.md asks for before an amount
                          // may be drawn in red or green.
                          style: _money(
                            size: _rowAmountSize,
                            color: amountColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    if (tap != null) ...<Widget>[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: AppColors.softText,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The pale-green calendar tile on the left of a row: the local day number over
/// the month, with a tinted up/down arrow so the type is readable without the
/// amount's colour.
class _CalendarTile extends StatelessWidget {
  const _CalendarTile({
    required this.day,
    required this.income,
    required this.strings,
  });

  final DateTime day;
  final bool income;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    // The day number and the month come from the same localised helpers the
    // headings use, so a Bengali row is Bengali on the tile too.
    final String number = strings.number(day.day).padLeft(2, '0');
    final String month = _shortMonth(strings, day);
    final Color accent = income ? AppColors.incomeGreen : AppColors.expenseRed;
    return Container(
      key: const Key('transaction-day-tile'),
      width: _avatarSize + 6,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline.withValues(alpha: _edge)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            month,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9.5,
              height: 1.1,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryGreen,
            ),
          ),
          Text(
            number,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: AppColors.headerGreen,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Icon(
            income ? Icons.arrow_upward : Icons.arrow_downward,
            size: 12,
            color: accent,
          ),
        ],
      ),
    );
  }
}

/// The time of day in the active language: the shared `h:mm AM/PM` tail of the
/// date-time helper, without the date the row's tile and day heading carry.
String _timeOf(AppStrings strings, DateTime value) {
  final String full = strings.dateTime(value);
  final int comma = full.lastIndexOf(',');
  return comma < 0 ? full : full.substring(comma + 1).trim();
}

/// The month above a tile's day number, abbreviated to three letters so it
/// fits a 46 dp tile: the English initial letters, or the first three Bengali
/// glyphs of the month name the screen already uses everywhere else.
String _shortMonth(AppStrings strings, DateTime day) {
  final String full = strings.monthYear(day);
  final String name = full
      .substring(0, full.length - strings.number(day.year).length)
      .trim();
  if (strings.language == AppLanguage.bn) {
    return name.length <= 4 ? name : name.substring(0, 4);
  }
  return name.length <= 3 ? name : name.substring(0, 3);
}

/// Shown when the khata itself has no entries: no filters, because there is
/// nothing to filter.
class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger({required this.strings, required this.copy});

  final AppStrings strings;
  final _ScreenCopy copy;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _MessageCard(
          key: const Key('transactions-empty'),
          icon: Icons.menu_book,
          title: strings.text(AppString.noTransactions),
          message: strings.text(AppString.transactionsEmptyHelp),
        ),
        _FooterArtwork(copy: copy),
      ],
    );
  }
}

/// Shown when filters hide every entry: a different truth from an empty khata.
class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.strings, required this.onClear});

  final AppStrings strings;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _MessageCard(
      key: const Key('transactions-no-match'),
      icon: Icons.filter_list,
      title: strings.text(AppString.noMatchingTransactions),
      message: strings.text(AppString.noMatchesHelp),
      action: FilledButton(
        key: const Key('clear-filters'),
        onPressed: onClear,
        child: Text(strings.text(AppString.clearFilters)),
      ),
    );
  }
}

/// Shared card for the two empty states. Both are quiet on purpose: an empty
/// list has nothing to read, so it borrows the card language (same radius, same
/// caption/heading type) without a shadow, a gradient or a loud border.
class _MessageCard extends StatelessWidget {
  const _MessageCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_rowPadding + 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: _softCardBorder.color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.lightGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: AppColors.primaryGreen),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: _cardTitleSize,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 6),
          Text(message, style: _metaBlock),
          if (action != null) ...<Widget>[
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: action!),
          ],
        ],
      ),
    );
  }
}

/// The quiet end of the page: bundled landscape artwork with one caption pill
/// over it. It is the last child of the list, so it can never cover a row, the
/// keyboard or a scroll target.
class _FooterArtwork extends StatelessWidget {
  const _FooterArtwork({required this.copy});

  final _ScreenCopy copy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: _groupGap),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          ExcludeSemantics(
            child: Image.asset(
              'assets/illustrations/entry_footer_leaves.png',
              key: const Key('all-transactions-footer-art'),
              height: 56,
              fit: BoxFit.fitWidth,
              excludeFromSemantics: true,
            ),
          ),
          Container(
            key: const Key('all-transactions-footer'),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: _softEdge),
              ),
            ),
            child: Text(
              copy.footer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: _meta.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.headerGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A calendar month's rows and its trading totals for those rows only.
class _MonthGroup {
  _MonthGroup(this.month);

  final DateTime month;
  final List<_DayGroup> days = <_DayGroup>[];
  int incomePaise = 0;
  int expensePaise = 0;
}

/// One local calendar day inside a month.
class _DayGroup {
  _DayGroup(this.day);

  final DateTime day;
  final List<LedgerEntry> entries = <LedgerEntry>[];
}

/// Stable widget key for a month heading, e.g. `month-2026-11`.
String _monthKey(DateTime value) =>
    'month-${value.year}-${value.month.toString().padLeft(2, '0')}';

/// The editor's fixed category tokens, mapped to their dictionary keys.
///
/// A category is stored as the canonical token (`Shopping`, `Food`, ...), so
/// only this display mapping is translated; the stored value, the chip key and
/// the filter comparison keep using the token itself.
const Map<String, AppString> _categoryStrings = <String, AppString>{
  'Shopping': AppString.shopping,
  'Food': AppString.food,
  'Travel': AppString.travel,
  'Bills': AppString.bills,
  'Gifts': AppString.gifts,
};

/// [category] rendered for display. Anything the editor does not offer - an
/// imported or hand-written category - is shown verbatim, never translated.
String _categoryLabel(AppStrings strings, String category) {
  final AppString? key = _categoryStrings[category];
  return key == null ? category : strings.text(key);
}

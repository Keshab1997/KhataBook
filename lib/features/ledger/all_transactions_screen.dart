// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../home/models.dart';
import '../entry/add_entry_screen.dart';
import '../entry/category_artwork.dart';
import '../entry/category_picker.dart';
import '../entry/category_store.dart';
import '../entry/transaction_editor_screen.dart';
import 'data/local_ledger.dart';

/// Geometry shared by this screen, mirroring Home so the two ledger surfaces
/// are the same system: one card radius, one 1 px rule between rows, one
/// border tone for a card that carries data and a softer one for a placeholder
/// that has nothing in it.
const double _cardRadius = 20;
const double _cardGap = 12;
const double _groupGap = 16;
const double _labelGap = 8;
const double _separator = 1;
const double _edge = 0.85;
const double _softEdge = 0.6;

/// Row geometry: the rule between rows starts where their text starts, so it
/// never cuts under the avatars.
const double _rowPadding = 12;
const double _avatarSize = 40;
const double _rowGap = 12;
const double _rowTextInset = _rowPadding + _avatarSize + _rowGap;

/// The one type scale for this screen, matching Home's: a caption, a row
/// title, a card title, a figure inside a card and a row amount. Only the text
/// a user types into the search box sits outside it, and it keeps the size the
/// Add Entry screen uses for the same kind of box.
const double _labelSize = 12;
const double _rowTitleSize = 15;
const double _cardTitleSize = 16;
const double _valueSize = 20;
const double _rowAmountSize = 18;

/// A caption above a figure (the totals tiles), quiet but deliberate: the
/// same 12 sp / w800 / 0.4 the entry screens' caption uses, so one scale
/// covers both the form and the list.
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

/// Money text, right-aligned where it is scanned in a column. Tabular figures
/// give every digit the same width, so amounts line up at the decimal place
/// down the list instead of stepping with each glyph's natural advance.
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

/// The input frame the Add Entry screen uses, expressed as decoration so this
/// screen's search box and the entry form read as one control: warm ivory
/// fill, 1 dp beige edge, 1.5 dp green edge while focused.
const double _inputRadius = 16;

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
bool matchesSearchQuery(LedgerEntry entry, String rawQuery) {
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
  return description != null && description.toLowerCase().contains(query);
}

/// S7 - All Transactions, docs/spec/screens.md (secondary screen S7).
///
/// A view of the khata it is given: every entry, newest first,
/// grouped by local calendar day inside its calendar month. Each month heading
/// carries that month's income and expense totals, and the card at the top
/// carries the same two totals for exactly the rows currently shown.
///
/// Four filters narrow that list and always compose: a search query over the
/// description/title and the category, a "from"/"to" pair of local calendar
/// days (both inclusive), and the type and category chips. One filtered list
/// feeds the rows, the counts, the summary card and the month headings, so no
/// figure on the screen can describe a row the user cannot see. An empty
/// result is reported as "no matches", which is deliberately a different
/// message from an empty khata.
///
/// Money stays integer paise end to end ([AppStrings.money] wraps the shared
/// `formatPaise`) and dates come from [AppStrings], so nothing here can
/// disagree with Home. The opening balance is deliberately **not** part of any
/// figure on this screen - every total counts transactions only - and the card
/// says so in words, so no number can be mistaken for the remaining balance.
///
/// With a ledger and khata ID it supports editing and reversible deletion;
/// without them it remains a read-only view.
///
/// [language] localizes the copy only. Stored values - entry titles,
/// descriptions, categories and transaction ids - stay canonical, so a filter,
/// a search or an edit always acts on the data rather than on its label.
/// English remains the default, so an unwired call site reads exactly as before.
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

  /// The search box's text. Owned by the screen so the query survives a
  /// rebuild after an edit and the controller is released with the screen.
  final TextEditingController _searchController = TextEditingController();

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
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
  }

  void _clearQuery() {
    _searchController.clear();
    setState(() => _query = '');
  }

  Future<void> _refresh() async {
    final ledger = widget.ledger!;
    final khataId = widget.khataId!;
    final onSummaryChanged = widget.onSummaryChanged;
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

  Future<void> _pickFromDay() async {
    final DateTime now = DateTime.now();
    final DateTime first = DateTime(1900);
    final DateTime last = DateTime(now.year + 100, 12, 31);
    final DateTime proposed = _fromDay ?? _newestEntryDay ?? now;
    final DateTime initial = proposed.isBefore(first)
        ? first
        : (proposed.isAfter(last) ? last : proposed);
    final DateTime? chosen = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: _strings.text(AppString.pickFromDay),
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
    final DateTime now = DateTime.now();
    final DateTime first = DateTime(1900);
    final DateTime last = DateTime(now.year + 100, 12, 31);
    final DateTime proposed = _toDay ?? _fromDay ?? _newestEntryDay ?? now;
    final DateTime initial = proposed.isBefore(first)
        ? first
        : (proposed.isAfter(last) ? last : proposed);
    final DateTime? chosen = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: _strings.text(AppString.pickToDay),
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
  List<LedgerEntry> get _visibleEntries {
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
              matchesSearchQuery(entry, _query);
        })
        .toList(growable: false);
    return List<LedgerEntry>.from(rows)..sort(_newestFirst);
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

  Widget _buildContent(BuildContext context, List<CustomCategory>? categories) {
    final AppStrings strings = _strings;
    if (_refreshError) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.text(AppString.allTransactions))),
        body: Center(
          child: Padding(
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
                  textAlign: TextAlign.center,
                  style: _metaBlock,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _refresh,
                  child: Text(strings.text(AppString.retry)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final List<LedgerEntry> allEntries = _summary.entries;
    if (allEntries.isEmpty) {
      return Scaffold(
        key: const Key('all-transactions-screen'),
        appBar: AppBar(
          title: Text(
            strings.text(AppString.allTransactions),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SafeArea(top: false, child: _EmptyLedger(strings: strings)),
      );
    }

    // One filtered list feeds the rows, the month totals and the summary card,
    // so the three can never disagree after a filter change.
    final List<LedgerEntry> visible = _visibleEntries;
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
      appBar: AppBar(
        title: Text(
          strings.text(AppString.allTransactions),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            _SummaryCard(
              totalCount: allEntries.length,
              entries: visible,
              strings: strings,
            ),
            const SizedBox(height: _cardGap),
            TextField(
              key: const Key('search-field'),
              controller: _searchController,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              // The entry screen's value type, so text typed here and text
              // typed in the form read the same.
              style: const TextStyle(
                fontSize: _rowTitleSize,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
              decoration: InputDecoration(
                labelText: strings.text(AppString.searchTransactions),
                hintText: strings.text(AppString.searchHint),
                // The floated label is the shared caption; the hint mirrors the
                // type being typed, exactly as the amount field's hint mirrors
                // the amount. The frame repeats what AppTheme's
                // inputDecorationTheme defines - 16 dp corners, ivory fill, a
                // 1 dp beige edge that turns 1.5 dp green under focus - so this
                // box and every other real input in the app are one control.
                floatingLabelStyle: _cardLabel.copyWith(
                  color: AppColors.softText,
                ),
                prefixIcon: const Icon(Icons.search, color: AppColors.softText),
                suffixIcon: _query.isEmpty ? null : _clearSearchButton(),
                filled: true,
                fillColor: AppColors.surface,
                hintStyle: const TextStyle(
                  fontSize: _rowTitleSize,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.softText,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_inputRadius),
                  borderSide: BorderSide(
                    color: AppColors.beige.withValues(alpha: 0.9),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_inputRadius),
                  borderSide: BorderSide(
                    color: AppColors.beige.withValues(alpha: 0.9),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_inputRadius),
                  borderSide: const BorderSide(
                    color: AppColors.primaryGreen,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: _groupGap),
            _SectionTitle(strings.text(AppString.date)),
            const SizedBox(height: _labelGap),
            Wrap(
              spacing: _cardGap,
              runSpacing: _cardGap,
              children: <Widget>[
                _FilterChip(
                  key: const Key('date-filter-from'),
                  label: fromLabel,
                  semanticLabel: fromSemantics,
                  selected: fromDay != null,
                  onTap: _pickFromDay,
                ),
                _FilterChip(
                  key: const Key('date-filter-to'),
                  label: toLabel,
                  semanticLabel: toSemantics,
                  selected: toDay != null,
                  onTap: _pickToDay,
                ),
                if (hasDates)
                  _FilterChip(
                    key: const Key('date-filter-clear'),
                    label: strings.text(AppString.clearDates),
                    semanticLabel: strings.text(AppString.clearDatesFilter),
                    selected: false,
                    onTap: _clearDates,
                  ),
              ],
            ),
            const SizedBox(height: _groupGap),
            _SectionTitle(strings.text(AppString.type)),
            const SizedBox(height: _labelGap),
            Wrap(
              spacing: _cardGap,
              runSpacing: _cardGap,
              children: <Widget>[
                _FilterChip(
                  key: const Key('type-filter-all'),
                  label: strings.text(AppString.all),
                  semanticLabel: strings.text(AppString.allTypesFilter),
                  selected: _typeFilter == null,
                  onTap: () => _selectType(null),
                ),
                _FilterChip(
                  key: const Key('type-filter-income'),
                  label: strings.text(AppString.income),
                  semanticLabel: strings.text(AppString.incomeFilter),
                  selected: _typeFilter == EntryType.income,
                  onTap: () => _selectType(EntryType.income),
                ),
                _FilterChip(
                  key: const Key('type-filter-expense'),
                  label: strings.text(AppString.expense),
                  semanticLabel: strings.text(AppString.expenseFilter),
                  selected: _typeFilter == EntryType.expense,
                  onTap: () => _selectType(EntryType.expense),
                ),
              ],
            ),
            const SizedBox(height: _groupGap),
            _SectionTitle(strings.text(AppString.category)),
            const SizedBox(height: _labelGap),
            Wrap(
              spacing: _cardGap,
              runSpacing: _cardGap,
              children: <Widget>[
                _FilterChip(
                  key: const Key('category-filter-all'),
                  label: strings.text(AppString.all),
                  semanticLabel: strings.text(AppString.allCategoriesFilter),
                  selected: _categoryFilter == null,
                  onTap: () => _selectCategory(null),
                ),
                // The key and the filter value stay the canonical stored
                // category; only the visible label is translated, so a tapped
                // chip still matches the same rows in either language.
                for (final String category in _categoryOptions)
                  _FilterChip(
                    key: Key('category-filter-$category'),
                    label: categories == null
                        ? _categoryLabel(strings, category)
                        : categoryDisplayName(
                            widget.language,
                            category,
                            categories,
                          ),
                    customCategory: categories == null
                        ? null
                        : findCustomCategory(category, categories),
                    semanticLabel: strings.categoryLabel(
                      categories == null
                          ? _categoryLabel(strings, category)
                          : categoryDisplayName(
                              widget.language,
                              category,
                              categories,
                            ),
                      filter: true,
                    ),
                    selected: _categoryFilter == category,
                    onTap: () => _selectCategory(category),
                  ),
              ],
            ),
            const SizedBox(height: _groupGap),
            if (groups.isEmpty)
              _NoMatches(strings: strings, onClear: _clearFilters)
            else ...<Widget>[
              for (final _MonthGroup group in groups) ...<Widget>[
                _MonthHeader(group: group, strings: strings),
                for (final _DayGroup day in group.days) ...<Widget>[
                  _DayHeader(day: day.day, strings: strings),
                  // One sheet per day, rules between the rows: the day's
                  // heading and its rows form a single object to scan down.
                  _DaySheet(
                    day: day.day,
                    entries: day.entries,
                    strings: strings,
                    categories: categories,
                    onEdit: widget.ledger == null ? null : _edit,
                  ),
                ],
              ],
              // The end of the list says so quietly, so "there is nothing
              // below" is never mistaken for "the list is still there".
              _EndOfList(strings: strings, hasFilters: _hasFilters),
            ],
          ],
        ),
      ),
    );
  }
}


/// Top card: how many rows are shown and their income/expense totals, with the
/// definition of those totals spelled out underneath.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalCount,
    required this.entries,
    required this.strings,
  });

  final int totalCount;
  final List<LedgerEntry> entries;
  final AppStrings strings;

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

    final String countText = strings.transactionCount(
      shown: entries.length,
      total: totalCount,
    );
    final String totalsText = strings.flowTotals(
      incomePaise: incomePaise,
      expensePaise: expensePaise,
    );

    return Semantics(
      container: true,
      label:
          '$countText. $totalsText '
          '${strings.text(AppString.filteredTotalsExplanation)}',
      child: ExcludeSemantics(
        child: Container(
          key: const Key('transactions-summary'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[AppColors.lightGreen, AppColors.surface],
            ),
            borderRadius: BorderRadius.circular(_cardRadius),
            border: Border.all(
              color: AppColors.outline.withValues(alpha: _edge),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.darkText.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                countText,
                style: const TextStyle(
                  fontSize: _cardTitleSize,
                  height: 1.3,
                  letterSpacing: -0.1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: _cardGap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _TotalTile(
                      label: strings.text(AppString.income),
                      value: strings.money(incomePaise),
                      color: AppColors.incomeGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TotalTile(
                      label: strings.text(AppString.expense),
                      value: strings.money(expensePaise),
                      color: AppColors.expenseRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                strings.text(AppString.filteredTotalsExplanation),
                style: _metaBlock,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One half of a totals pair: the caption size, then the figure size, with
/// tabular figures so the two totals in a row line up at the decimal. 20 dp
/// w800 also keeps the red/green amounts at the "large text" size theme.md
/// requires for AA contrast on light surfaces.
class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;

  /// Already formatted for the active language; this tile does no arithmetic.
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _cardLabel.copyWith(color: AppColors.softText),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            softWrap: false,
            style: _money(
              size: _valueSize,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Heading above a filter group. Same leading rule the day headings use, one
/// step up in weight, so the three kinds of heading on this screen are
/// recognisably the same device at three sizes.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 3,
          height: _cardTitleSize,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _cardLabel.copyWith(color: AppColors.darkText),
          ),
        ),
      ],
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
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final CustomCategory? customCategory;
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
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          // Flat: selection is carried by the fill, the edge and the check
          // mark, so an elevation on the chosen chip would only add noise and
          // make the filter bar look like a stack of cards.
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
                  horizontal: 14,
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[AppColors.lightGreen, AppColors.surface],
              ),
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
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _TotalTile(
                        label: strings.text(AppString.income),
                        value: strings.money(group.incomePaise),
                        color: AppColors.incomeGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TotalTile(
                        label: strings.text(AppString.expense),
                        value: strings.money(group.expensePaise),
                        color: AppColors.expenseRed,
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

/// Day heading inside a month: the label that owns the sheet under it, set in
/// the caption size with extra letter spacing and a leading rule, so a heading
/// is found by eye without being mistaken for a row.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.strings});

  final DateTime day;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: _cardGap, bottom: _labelGap),
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

/// One day's rows on a single sheet.
///
/// The rows inside it are separated by a 1 px beige rule rather than boxed one
/// by one: a day then reads as one object, the amounts keep a single right
/// column, and only the rules tell the rows apart.
class _DaySheet extends StatelessWidget {
  const _DaySheet({
    required this.day,
    required this.entries,
    required this.strings,
    this.categories,
    this.onEdit,
  });

  /// The local calendar day this sheet belongs to, for its widget key only.
  final DateTime day;
  final List<LedgerEntry> entries;
  final AppStrings strings;
  final List<CustomCategory>? categories;

  /// Null makes every row in the sheet a plain, inert row - a read-only view
  /// of a summary has nothing to edit.
  final ValueChanged<LedgerEntry>? onEdit;

  @override
  Widget build(BuildContext context) {
    // Named outside the string so the key stays greppable.
    final String dayKey = _dayKey(day);
    return Container(
      key: Key('day-sheet-$dayKey'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: AppColors.outline.withValues(alpha: _edge)),
      ),
      // The sheet is a Material, so a row's tap ripples on the surface the
      // user is looking at instead of vanishing behind it.
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius - _separator),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int index = 0; index < entries.length; index++) ...<Widget>[
              if (index > 0) const _RowRule(),
              _EntryRow(
                entry: entries[index],
                strings: strings,
                categories: categories,
                onTap: _tapFor(entries[index]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The stored id is what makes a row editable; a row without one - or a
  /// screen without a ledger - stays inert instead of pretending to be
  /// tappable.
  VoidCallback? _tapFor(LedgerEntry entry) {
    final ValueChanged<LedgerEntry>? edit = onEdit;
    if (edit == null || entry.id == null) {
      return null;
    }
    return () => edit(entry);
  }
}

/// The 1 px rule between two rows, inset to the text column so it never cuts
/// under the avatars.
class _RowRule extends StatelessWidget {
  const _RowRule();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: _rowTextInset),
      child: SizedBox(
        height: _separator,
        child: ColoredBox(color: AppColors.beige),
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
          Expanded(
            child: Text(message, maxLines: 2, style: _meta),
          ),
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

/// One transaction: type icon, title, category and timestamp, signed amount.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.strings,
    this.categories,
    this.onTap,
  });

  final LedgerEntry entry;
  final AppStrings strings;
  final List<CustomCategory>? categories;
  final VoidCallback? onTap;

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
    final custom = categories == null
        ? null
        : findCustomCategory(entry.category, categories!);

    final title = categories != null && entry.title == entry.category
        ? category
        : entry.title;

    return Semantics(
      container: true,
      button: onTap != null,
      onTap: onTap,
      label: strings.transactionLabel(
        title: title,
        category: category,
        amountPaise: entry.amountPaise,
        income: isIncome,
        at: entry.at.toLocal(),
        editable: onTap != null,
      ),
      child: ExcludeSemantics(
        child: InkWell(
          key: entry.id == null ? null : Key('transaction-${entry.id}'),
          onTap: onTap,
          // No box of its own: the day's sheet is the surface and the rule
          // above is the divider, so a row is one line of a list rather than a
          // card that has to be framed.
          child: Padding(
            padding: const EdgeInsets.all(_rowPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // The same 40 dp leading cue Home uses: artwork when a category
                // is known, an up/down arrow in the type colour otherwise.
                Container(
                  width: _avatarSize,
                  height: _avatarSize,
                  decoration: BoxDecoration(
                    color: (categories == null
                            ? amountColor
                            : _categoryAccent(entry.category, custom))
                        .withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: categories == null
                      ? Icon(
                          isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 20,
                          color: amountColor,
                        )
                      : ClipOval(
                          child: CategoryArtwork(
                            category: entry.category,
                            size: _avatarSize,
                            fallbackColor: AppColors.navigationGrey,
                            customCategory: custom,
                          ),
                        ),
                ),
                const SizedBox(width: _rowGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        '$category · ${strings.dateTime(entry.at.toLocal())}',
                        maxLines: 2,
                        style: _meta.copyWith(height: 1.35),
                      ),
                      // The amount gets its own line, so 200% text scale never
                      // squeezes it against the title.
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            signedAmount,
                            maxLines: 1,
                            softWrap: false,
                            textAlign: TextAlign.right,
                            // 18 dp w800: the size Home's rows use, and
                            // the large-text size theme.md asks for before
                            // an amount may be drawn in red or green.
                            style: _money(
                              size: _rowAmountSize,
                              color: amountColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null) ...<Widget>[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: AppColors.softText,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The tint behind the leading cue: a custom category's own colour when it
  /// has one, otherwise the fixed category accents, so the same category is
  /// the same colour on Home and here.
  Color _categoryAccent(String category, CustomCategory? custom) {
    if (custom != null) return custom.color;
    return switch (category) {
      'Shopping' => AppColors.primaryGreen,
      'Food' => AppColors.orange,
      'Travel' => AppColors.secondaryGreen,
      'Bills' => AppColors.golden,
      'Gifts' => AppColors.expenseRed,
      _ => AppColors.navigationGrey,
    };
  }
}

/// Shown when the khata itself has no entries: no filters, because there is
/// nothing to filter.
class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger({required this.strings});

  final AppStrings strings;

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
        border: Border.all(
          color: AppColors.outline.withValues(alpha: _softEdge),
        ),
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
          Text(
            message,
            style: _metaBlock,
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: action!),
          ],
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

/// Stable widget key for a day sheet, e.g. `2026-11-19`. Same local calendar
/// day the heading above the sheet names.
String _dayKey(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

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

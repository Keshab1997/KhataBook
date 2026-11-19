// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/format/date_format.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../home/models.dart';
import '../entry/add_entry_screen.dart';
import '../entry/transaction_editor_screen.dart';
import 'data/local_ledger.dart';

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
/// Money stays integer paise end to end ([formatPaise] is the only formatter)
/// and dates come from the shared [formatEntryDate], so nothing here can
/// disagree with Home. The opening balance is deliberately **not** part of any
/// figure on this screen - every total counts transactions only - and the card
/// says so in words, so no number can be mistaken for the remaining balance.
///
/// With a ledger and khata ID it supports editing and reversible deletion;
/// without them it remains a read-only view.
class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({
    super.key,
    required this.summary,
    this.ledger,
    this.khataId,
    this.onSummaryChanged,
  });

  /// The khata to display. Treated as immutable, including its entry list.
  final LedgerSummary summary;
  final LocalLedger? ledger;
  final String? khataId;
  final ValueChanged<LedgerSummary>? onSummaryChanged;

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  late LedgerSummary _summary;
  bool _refreshError = false;

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
    final messenger = ScaffoldMessenger.of(context);
    final onSummaryChanged = widget.onSummaryChanged;
    final result = await Navigator.of(context).push<TransactionEditResult>(
      MaterialPageRoute<TransactionEditResult>(
        builder: (_) => TransactionEditorScreen(
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
        const SnackBar(content: Text('Transaction updated')),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Transaction deleted'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Undo',
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
                      restored
                          ? 'Transaction restored'
                          : 'Could not restore transaction',
                    ),
                  ),
                );
              } catch (_) {
                if (messenger.mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Could not restore transaction'),
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
      helpText: 'Show transactions from this day',
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
      helpText: 'Show transactions up to this day',
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
      tooltip: 'Clear search',
      onPressed: _clearQuery,
      icon: const Icon(Icons.close),
    );
  }

  /// Categories to offer, alphabetical. Built from every entry, not the
  /// filtered ones, so choosing a category never moves the chips under the
  /// user's finger. The selected category stays listed even when an edit
  /// removed its last entry, so such a filter still reads as selected and can
  /// be changed instead of silently disappearing.
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
    if (_refreshError) {
      return Scaffold(
        appBar: AppBar(title: const Text('All Transactions')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Could not refresh transactions.'),
              FilledButton(onPressed: _refresh, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final List<LedgerEntry> allEntries = _summary.entries;
    if (allEntries.isEmpty) {
      return Scaffold(
        key: const Key('all-transactions-screen'),
        appBar: AppBar(
          title: const Text(
            'All Transactions',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: const SafeArea(top: false, child: _EmptyLedger()),
      );
    }

    // One filtered list feeds the rows, the month totals and the summary card,
    // so the three can never disagree after a filter change.
    final List<LedgerEntry> visible = _visibleEntries;
    final List<_MonthGroup> groups = _group(visible);

    final DateTime? fromDay = _fromDay;
    final DateTime? toDay = _toDay;
    final bool hasDates = fromDay != null || toDay != null;
    final String fromLabel = fromDay == null
        ? 'From: any date'
        : 'From: ${_dateLabel(fromDay)}';
    final String toLabel = toDay == null
        ? 'To: any date'
        : 'To: ${_dateLabel(toDay)}';
    final String fromSemantics = fromDay == null
        ? 'Date filter: from any date'
        : 'Date filter: from ${_dateLabel(fromDay)}';
    final String toSemantics = toDay == null
        ? 'Date filter: to any date'
        : 'Date filter: to ${_dateLabel(toDay)}';

    return Scaffold(
      key: const Key('all-transactions-screen'),
      appBar: AppBar(
        title: const Text(
          'All Transactions',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            _SummaryCard(totalCount: allEntries.length, entries: visible),
            const SizedBox(height: 12),
            TextField(
              key: const Key('search-field'),
              controller: _searchController,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 15, color: AppColors.darkText),
              decoration: InputDecoration(
                labelText: 'Search transactions',
                hintText: 'Description or category',
                prefixIcon: const Icon(Icons.search, color: AppColors.softText),
                suffixIcon: _query.isEmpty ? null : _clearSearchButton(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primaryGreen,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const _SectionTitle('Date'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
                    label: 'Clear dates',
                    semanticLabel: 'Date filter: clear both days',
                    selected: false,
                    onTap: _clearDates,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const _SectionTitle('Type'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _FilterChip(
                  key: const Key('type-filter-all'),
                  label: 'All',
                  semanticLabel: 'Type filter: all entries',
                  selected: _typeFilter == null,
                  onTap: () => _selectType(null),
                ),
                _FilterChip(
                  key: const Key('type-filter-income'),
                  label: 'Income',
                  semanticLabel: 'Type filter: income',
                  selected: _typeFilter == EntryType.income,
                  onTap: () => _selectType(EntryType.income),
                ),
                _FilterChip(
                  key: const Key('type-filter-expense'),
                  label: 'Expense',
                  semanticLabel: 'Type filter: expense',
                  selected: _typeFilter == EntryType.expense,
                  onTap: () => _selectType(EntryType.expense),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _SectionTitle('Category'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _FilterChip(
                  key: const Key('category-filter-all'),
                  label: 'All',
                  semanticLabel: 'Category filter: all categories',
                  selected: _categoryFilter == null,
                  onTap: () => _selectCategory(null),
                ),
                for (final String category in _categoryOptions)
                  _FilterChip(
                    key: Key('category-filter-$category'),
                    label: category,
                    semanticLabel: 'Category filter: $category',
                    selected: _categoryFilter == category,
                    onTap: () => _selectCategory(category),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (groups.isEmpty)
              _NoMatches(onClear: _clearFilters)
            else
              for (final _MonthGroup group in groups) ...<Widget>[
                _MonthHeader(group: group),
                for (final _DayGroup day in group.days) ...<Widget>[
                  _DayHeader(day: day.day),
                  for (final LedgerEntry entry in day.entries)
                    _EntryRow(
                      entry: entry,
                      onTap: widget.ledger != null && entry.id != null
                          ? () => _edit(entry)
                          : null,
                    ),
                ],
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
  const _SummaryCard({required this.totalCount, required this.entries});

  final int totalCount;
  final List<LedgerEntry> entries;

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

    final String totalWord = totalCount == 1 ? 'transaction' : 'transactions';
    final String countText = entries.length == totalCount
        ? 'Showing $totalCount $totalWord'
        : 'Showing ${entries.length} of $totalCount $totalWord';

    return Semantics(
      container: true,
      label:
          '$countText. Income ${formatPaise(incomePaise)}. Expense '
          '${formatPaise(expensePaise)}. Totals count only the transactions '
          'shown and exclude the opening balance.',
      child: ExcludeSemantics(
        child: Container(
          key: const Key('transactions-summary'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.lightGreen,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                countText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _TotalTile(
                      label: 'Income',
                      paise: incomePaise,
                      color: AppColors.incomeGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TotalTile(
                      label: 'Expense',
                      paise: expensePaise,
                      color: AppColors.expenseRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Totals count only the transactions shown, so the opening '
                'balance is excluded and this is not the remaining balance.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
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

/// One half of a totals pair. 20 dp w800 keeps the red/green amounts at the
/// "large text" size theme.md requires for AA contrast on light surfaces.
class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.label,
    required this.paise,
    required this.color,
  });

  final String label;
  final int paise;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.softText),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatPaise(paise),
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Heading above the filter rows.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: AppColors.darkText,
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
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color background = selected
        ? AppColors.primaryGreen
        : AppColors.warmIvory;
    final Color foreground = selected
        ? AppColors.onPrimary
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
          child: Material(
            color: background,
            clipBehavior: Clip.antiAlias,
            shape: StadiumBorder(
              side: BorderSide(
                color: selected ? AppColors.primaryGreen : AppColors.outline,
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
                    if (selected) ...<Widget>[
                      Icon(Icons.check, size: 16, color: foreground),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: foreground,
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
  const _MonthHeader({required this.group});

  final _MonthGroup group;

  @override
  Widget build(BuildContext context) {
    final String label = _monthLabel(group.month);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Semantics(
        container: true,
        label:
            '$label. Income ${formatPaise(group.incomePaise)}, expense '
            '${formatPaise(group.expensePaise)}.',
        child: ExcludeSemantics(
          child: Container(
            key: Key(_monthKey(group.month)),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lightGreen,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _TotalTile(
                        label: 'Income',
                        paise: group.incomePaise,
                        color: AppColors.incomeGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TotalTile(
                        label: 'Expense',
                        paise: group.expensePaise,
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

/// Day heading inside a month.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(
        _dateLabel(day),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.softText,
        ),
      ),
    );
  }
}

/// One transaction: type icon, title, category and timestamp, signed amount.
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, this.onTap});

  final LedgerEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isIncome = entry.type == EntryType.income;
    final Color amountColor = isIncome
        ? AppColors.incomeGreen
        : AppColors.expenseRed;
    final String signedAmount = isIncome
        ? '+${formatPaise(entry.amountPaise)}'
        : '-${formatPaise(entry.amountPaise)}';

    return Semantics(
      container: true,
      button: onTap != null,
      onTap: onTap,
      label:
          '${entry.title}, ${entry.category}, '
          '${isIncome ? 'income' : 'expense'} $signedAmount, '
          '${formatEntryDate(entry.at.toLocal())}${onTap == null ? '' : ', tap to edit'}',
      child: ExcludeSemantics(
        child: InkWell(
          key: entry.id == null ? null : Key('transaction-${entry.id}'),
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: amountColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 20,
                    color: amountColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        entry.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entry.category} · ${formatEntryDate(entry.at.toLocal())}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.3,
                          color: AppColors.softText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // The amount gets its own line, so 200% text scale never
                      // squeezes it against the title.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          signedAmount,
                          maxLines: 1,
                          softWrap: false,
                          // 19 dp w800 matches Home's rows and keeps the red and
                          // green amounts at the large-text size theme.md asks
                          // for before they can use those colours.
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: amountColor,
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
}

/// Shown when the khata itself has no entries: no filters, because there is
/// nothing to filter.
class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const <Widget>[
        _MessageCard(
          key: Key('transactions-empty'),
          icon: Icons.menu_book,
          title: 'No transactions yet',
          message:
              'Add your first entry from Home and it will appear here, '
              'newest first.',
        ),
      ],
    );
  }
}

/// Shown when filters hide every entry: a different truth from an empty khata.
class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _MessageCard(
      key: const Key('transactions-no-match'),
      icon: Icons.filter_list,
      title: 'No transactions match these filters',
      message:
          'Try another search, type, category or date, or clear the filters '
          'to see every transaction again.',
      action: FilledButton(
        key: const Key('clear-filters'),
        onPressed: onClear,
        child: const Text('Clear filters'),
      ),
    );
  }
}

/// Shared message card for the two empty states.
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 30, color: AppColors.primaryGreen),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.softText,
            ),
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

/// `19 Nov 2026` - the date half of the shared `dd MMM yyyy, h:mm a` format.
String _dateLabel(DateTime value) => formatEntryDate(value).split(',').first;

/// `Nov 2026` - the month and year of the same shared format.
String _monthLabel(DateTime value) =>
    _dateLabel(value).split(' ').skip(1).join(' ');

/// Stable widget key for a month heading, e.g. `month-2026-11`.
String _monthKey(DateTime value) =>
    'month-${value.year}-${value.month.toString().padLeft(2, '0')}';

/// B1 uses an in-memory preview ledger. B2 replaces it with the Drift database
/// described in docs/spec/data-model.md; the totals formula stays the same.
enum EntryType { expense, income }

class LedgerEntry {
  const LedgerEntry({
    required this.title,
    required this.category,
    required this.at,
    required this.amountPaise,
    this.type = EntryType.expense,
    this.id,
    this.description,
  });

  /// Display label. For an entry read from the database this is the stored
  /// description, falling back to the category when the description is empty or
  /// null - a display-only fallback, never the stored data.
  final String title;
  final String category;
  final DateTime at;
  final int amountPaise;
  final EntryType type;

  /// The persisted transaction id, present only on rows read from the database.
  ///
  /// Edit/delete/restore act on this id. Preview and seed entries leave it
  /// null, so a preview row can never be mistaken for a stored one.
  final String? id;

  /// The stored description exactly as persisted: `null` when the row has no
  /// description, and never the category substituted in. [title] is the
  /// display fallback for this value.
  final String? description;
}

class LedgerSummary {
  const LedgerSummary({
    required this.openingBalancePaise,
    required this.entries,
  });

  final int openingBalancePaise;
  final List<LedgerEntry> entries;

  int get totalIncomePaise =>
      openingBalancePaise +
      entries
          .where((LedgerEntry e) => e.type == EntryType.income)
          .fold<int>(0, (int sum, LedgerEntry e) => sum + e.amountPaise);

  int get totalExpensePaise => entries
      .where((LedgerEntry e) => e.type == EntryType.expense)
      .fold<int>(0, (int sum, LedgerEntry e) => sum + e.amountPaise);

  int get remainingPaise => totalIncomePaise - totalExpensePaise;

  /// Home shows the newest four rows; `View All` opens the full list (D5).
  List<LedgerEntry> recent([int limit = 4]) {
    final List<LedgerEntry> sorted = List<LedgerEntry>.from(entries)
      ..sort((LedgerEntry a, LedgerEntry b) => b.at.compareTo(a.at));
    return sorted.take(limit).toList(growable: false);
  }
}

/// Seed reproduces the numbers in docs/design/ui-preview.png exactly:
/// ₹10,000 income, ₹3,580 expense, ₹6,420 remaining.
const int kSeedOpeningBalancePaise = 1000000;

final List<LedgerEntry> kSeedEntries = <LedgerEntry>[
  LedgerEntry(
    title: 'Grocery Shopping',
    category: 'Shopping',
    at: DateTime(2026, 11, 19, 20, 30),
    amountPaise: 120000,
  ),
  LedgerEntry(
    title: 'Lunch with Friends',
    category: 'Food',
    at: DateTime(2026, 11, 19, 13, 15),
    amountPaise: 58000,
  ),
  LedgerEntry(
    title: 'Mobile Recharge',
    category: 'Bills',
    at: DateTime(2026, 11, 19, 10, 20),
    amountPaise: 19900,
  ),
  LedgerEntry(
    title: 'Gift for Mom',
    category: 'Gifts',
    at: DateTime(2026, 11, 18, 19, 40),
    amountPaise: 100000,
  ),
  // Older entries account for the ₹601 that the four visible rows do not.
  LedgerEntry(
    title: 'Bus Fare',
    category: 'Travel',
    at: DateTime(2026, 11, 17, 9, 5),
    amountPaise: 30100,
  ),
  LedgerEntry(
    title: 'Tea with Team',
    category: 'Food',
    at: DateTime(2026, 11, 16, 17, 20),
    amountPaise: 30000,
  ),
];

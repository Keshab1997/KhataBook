// Design & layout gate for the reference-led All Transactions screen
// (batch account-design-b1, task all-transactions-reference).
//
// These tests own presentation only - the branded header, the totals card and
// its ribbon, the search pill and its tune control, the three filter panels,
// the ivory row cards, the quiet footer, and the small/large-text layouts - so
// the behavioural suites (all_transactions_test.dart, ledger_language_test.dart,
// transaction_edit_flow_test.dart) keep owning filtering, grouping, editing and
// the copy that goes with them.
//
// Flutter 3.50 deprecates these imports; migrate with the app's dependency
// update. The ignore is scoped to the imports, exactly as the behavioural
// suites do it, so the rest of the file stays lint-clean.
// ignore: deprecated_member_use
import 'package:drift/native.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/core/l10n/app_strings.dart' show AppLanguage;
import 'package:khatabook/core/theme/app_colors.dart';
import 'package:khatabook/core/theme/app_theme.dart';
import 'package:khatabook/features/entry/add_entry_screen.dart'
    show EntryFormKind, EntryFormResult;
import 'package:khatabook/features/home/models.dart';
import 'package:khatabook/features/ledger/data/local_ledger.dart';
import 'package:khatabook/features/ledger/all_transactions_screen.dart';

const Size _reference = Size(390, 844);
const Size _smallPhone = Size(320, 568);
const Size _tall = Size(400, 2600);
const double _largeText = 2.0;

/// ₹10,000 opening balance: it must never appear on this screen.
const int _openingPaise = 1000000;

LedgerEntry _spent(String title, String category, DateTime at, int paise) =>
    LedgerEntry(title: title, category: category, at: at, amountPaise: paise);

LedgerEntry _earned(String title, String category, DateTime at, int paise) =>
    LedgerEntry(
      title: title,
      category: category,
      at: at,
      amountPaise: paise,
      type: EntryType.income,
    );

/// The reference's own illustration - two November 2026 entries, one income
/// and one expense - plus one October row so month grouping stays visible.
LedgerSummary _summary() => LedgerSummary(
  openingBalancePaise: _openingPaise,
  entries: <LedgerEntry>[
    _earned('Salary', 'Income', DateTime(2026, 11, 19, 10, 20), 100000),
    _spent('Grocery Shopping', 'Food', DateTime(2026, 11, 19, 18, 15), 50000),
    _spent('Diwali Gift', 'Gifts', DateTime(2026, 10, 31, 18, 0), 250050),
  ],
);

Widget _screen({bool bengali = false}) => AllTransactionsScreen(
  summary: _summary(),
  language: bengali ? AppLanguage.bn : AppLanguage.en,
);

/// Pumps the screen as a pushed route, so the back action is a real one.
Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Size size = _tall,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 12);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: AppTheme.light(),
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context)
                  .push<void>(MaterialPageRoute<void>(builder: (_) => screen)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Scrolls the list until [finder] is mounted and visible.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

BoxDecoration _decorationOf(WidgetTester tester, Key key) {
  final Widget widget = tester.widget(find.byKey(key));
  if (widget is Container && widget.decoration is BoxDecoration) {
    return widget.decoration! as BoxDecoration;
  }
  final Finder inner = find
      .descendant(of: find.byKey(key), matching: find.byType(Container))
      .first;
  return tester.widget<Container>(inner).decoration! as BoxDecoration;
}

/// A ledger double whose reads always fail, so the failure state can be
/// reached the way a user reaches it: by editing a row and letting the
/// post-edit re-read fail.
class _FailingLedger extends LocalLedger {
  _FailingLedger(super.executor);

  /// Set to return a failing read; cleared to let reads succeed again.
  bool fail = false;
  int reads = 0;

  @override
  Future<LedgerSummary> readSummary({String khataId = 'personal'}) {
    reads++;
    if (fail) {
      return Future<LedgerSummary>.error(StateError('storage unavailable'));
    }
    return super.readSummary(khataId: khataId);
  }
}

void main() {
  group('branded header', () {
    for (final int year in <int>[1800, 2200]) {
      testWidgets('date controls clamp imported year $year to picker bounds', (
        tester,
      ) async {
        await _pump(
          tester,
          AllTransactionsScreen(
            summary: LedgerSummary(
              openingBalancePaise: 0,
              entries: <LedgerEntry>[
                _spent('Imported entry', 'Food', DateTime(year), 100),
              ],
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('all-transactions-calendar')));
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('date-filter-to')));
        await tester.pumpAndSettle();
        expect(find.byType(DatePickerDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'green wave with a golden edge, title, subtitle, back, calendar',
      (WidgetTester tester) async {
        await _pump(tester, _screen());

        expect(
          find.byKey(const Key('all-transactions-header')),
          findsOneWidget,
        );
        // No Material AppBar: the page owns its banner, like Home/Counter.
        expect(find.byType(AppBar), findsNothing);
        final Rect back = tester.getRect(
          find.byKey(const Key('all-transactions-back')),
        );
        final Rect titleRect = tester.getRect(
          find.byKey(const Key('all-transactions-title')),
        );
        expect(titleRect.left, greaterThan(back.right));
        expect(titleRect.top, lessThan(back.bottom));
        final Rect subtitle = tester.getRect(
          find.byKey(const Key('all-transactions-subtitle')),
        );
        final Rect banner = tester.getRect(
          find.byKey(const Key('all-transactions-header')),
        );
        expect(subtitle.bottom, lessThanOrEqualTo(banner.bottom - 20));

        final Text title = tester.widget<Text>(
          find.byKey(const Key('all-transactions-title')),
        );
        expect(title.data, 'All Transactions');
        expect(title.maxLines, 1);
        expect(title.overflow, TextOverflow.ellipsis);
        expect(title.style?.color, AppColors.onPrimary);

        expect(
          find.byKey(const Key('all-transactions-subtitle')),
          findsOneWidget,
        );

        // Both header actions are real controls with a >= 48 dp hit area.
        for (final String key in <String>[
          'all-transactions-back',
          'all-transactions-calendar',
        ]) {
          expect(find.byKey(Key(key)), findsOneWidget);
          expect(
            tester.getSize(find.byKey(Key(key))).height,
            greaterThanOrEqualTo(48),
            reason: '$key must be at least 48 dp tall',
          );
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('the header glyph actions are live, not decoration', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _screen());

      // The calendar action opens the real date picker, so it can actually
      // narrow the list instead of being a picture of a calendar.
      await tester.tap(find.byKey(const Key('all-transactions-calendar')));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the back action pops the page', (WidgetTester tester) async {
      await _pump(tester, _screen());
      await tester.tap(find.byKey(const Key('all-transactions-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('all-transactions-screen')), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  });

  group('totals card', () {
    testWidgets('ivory card with a live ribbon and two divided totals', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _screen());

      final BoxDecoration card = _decorationOf(
        tester,
        const Key('transactions-summary'),
      );
      expect(card.color, AppColors.surface);
      expect(card.borderRadius, BorderRadius.circular(20));
      expect(
        (card.border! as Border).top.color,
        AppColors.outline.withValues(alpha: 0.85),
      );
      expect(card.boxShadow, hasLength(1));

      // The green ribbon straddles the card's top edge, above the figures.
      final Finder ribbon = find.byKey(
        const Key('transactions-summary-ribbon'),
      );
      expect(ribbon, findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('Showing 3 transactions'), findsOneWidget);
      final double cardTop = tester
          .getTopLeft(find.byKey(const Key('transactions-summary')))
          .dy;
      expect(tester.getTopLeft(ribbon).dy, lessThan(cardTop));
      expect(tester.getBottomLeft(ribbon).dy, greaterThan(cardTop));

      // One vertical hairline between the two figures at normal text.
      expect(
        tester
            .getSize(find.byKey(const Key('transactions-summary-rule')))
            .width,
        1,
      );

      // Income and expense are still the real figures of the shown rows: the
      // card's own totals, not a month's subset, and never the opening balance.
      final Finder totals = find.byKey(const Key('transactions-summary'));
      expect(
        find.descendant(of: totals, matching: find.text('₹1,000')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: totals, matching: find.text('₹3,000.50')),
        findsOneWidget,
      );
      // ...and the opening balance is still nowhere on the screen.
      expect(find.textContaining('₹10,000'), findsNothing);
      expect(find.textContaining('not the remaining balance'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the coin artwork never sits over the totals note', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _screen());

      final Finder art = find.byKey(const Key('transactions-summary-art'));
      expect(art, findsOneWidget);
      final Finder note = find.textContaining('Totals count only');
      expect(note, findsOneWidget);
      // Side by side, not stacked: the decorative asset starts to the right
      // of the words it must never cover.
      expect(
        tester.getTopLeft(art).dx,
        greaterThanOrEqualTo(tester.getTopRight(note).dx - 1),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('search pill and filter panels', () {
    testWidgets(
      'rounded pill with the real controller and a pale-green tune cap',
      (WidgetTester tester) async {
        await _pump(tester, _screen());

        final BoxDecoration pill = _decorationOf(
          tester,
          const Key('search-pill'),
        );
        expect(pill.color, AppColors.surface);
        expect(pill.borderRadius, BorderRadius.circular(999));
        expect(find.byKey(const Key('search-field')), findsOneWidget);
        expect(
          tester.getSize(find.byKey(const Key('filters-tune'))).height,
          greaterThanOrEqualTo(44),
        );

        // Typing filters, and the clear control appears as a 44 dp+ action.
        await tester.enterText(find.byKey(const Key('search-field')), 'salary');
        await tester.pumpAndSettle();
        expect(find.text('Showing 1 of 3 transactions'), findsOneWidget);
        expect(
          tester.getSize(find.byKey(const Key('search-clear'))).height,
          greaterThanOrEqualTo(44),
        );
      },
    );

    testWidgets('the tune control collapses the panels and can restore them', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _screen());

      // Visible by default, as the reference shows them.
      expect(find.byKey(const Key('date-filter-from')), findsOneWidget);
      expect(find.byKey(const Key('type-filter-all')), findsOneWidget);

      await tester.tap(find.byKey(const Key('filters-tune')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('date-filter-from')), findsNothing);
      expect(find.byKey(const Key('category-filter-all')), findsNothing);
      // The rows stay: collapsing filters must never hide the data.
      expect(find.text('Salary'), findsOneWidget);

      // ...and one more press brings them back, with the cursor in search.
      await tester.tap(find.byKey(const Key('filters-tune')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('date-filter-from')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('three separate warm panels, each with its own heading', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _screen());

      for (final String key in <String>[
        'date-filter-from',
        'date-filter-to',
        'type-filter-all',
        'type-filter-income',
        'type-filter-expense',
        'category-filter-all',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: '$key is missing');
      }

      // Date above type above category, one panel each, all ivory. The panels
      // now follow the ledger instead of preceding it, so the list is what the
      // first screen shows; their own order is unchanged.
      await _reveal(tester, find.byKey(const Key('category-filter-all')));
      final double dateTop = tester
          .getTopLeft(find.byKey(const Key('date-filter-from')))
          .dy;
      final double typeTop = tester
          .getTopLeft(find.byKey(const Key('type-filter-all')))
          .dy;
      final double categoryTop = tester
          .getTopLeft(find.byKey(const Key('category-filter-all')))
          .dy;
      expect(dateTop, lessThan(typeTop));
      expect(typeTop, lessThan(categoryTop));

      // A selected chip is a green outline, a pale-green fill and a check -
      // never colour alone.
      final Material chip = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(const Key('type-filter-all')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(chip.color, AppColors.lightGreen);
      expect((chip.shape! as StadiumBorder).side.color, AppColors.primaryGreen);
      expect(
        find.descendant(
          of: find.byKey(const Key('type-filter-all')),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Bengali labels the panels and keeps canonical chip keys', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _screen(bengali: true));

      // The chip key stays the stored category token even though the label is
      // translated, so a tap still matches the same rows.
      expect(find.byKey(const Key('category-filter-Food')), findsOneWidget);
      expect(find.text('খাবার'), findsWidgets);
      expect(find.text('সব'), findsNWidgets(2));
      expect(find.byKey(const Key('filters-tune')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('rows and footer', () {
    testWidgets(
      'each transaction is a card with a calendar tile and an amount',
      (WidgetTester tester) async {
        await _pump(tester, _screen());
        await _reveal(
          tester,
          find.byKey(const Key('transaction-row-Grocery Shopping')),
        );

        final Finder row = find.byKey(
          const Key('transaction-row-Grocery Shopping'),
        );
        final BoxDecoration card = _decorationOf(
          tester,
          const Key('transaction-row-Grocery Shopping'),
        );
        expect(card.color, AppColors.surface);
        expect(card.borderRadius, BorderRadius.circular(20));
        expect(card.boxShadow, hasLength(1));

        // The local-calendar tile: day number over month, plus the type arrow.
        final Finder tile = find.descendant(
          of: row,
          matching: find.byKey(const Key('transaction-day-tile')),
        );
        expect(tile, findsOneWidget);
        expect(
          find.descendant(of: tile, matching: find.text('19')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: tile, matching: find.text('Nov')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: tile,
            matching: find.byIcon(Icons.arrow_downward),
          ),
          findsOneWidget,
        );

        // The day's real grouping and totals are still stated.
        expect(find.text('Nov 2026'), findsOneWidget);
        expect(find.text('19 Nov 2026'), findsOneWidget);

        // Income and expense rows carry their own signed amount in colour.
        final Text expense = tester.widget<Text>(find.text('-₹500'));
        expect(expense.style?.color, AppColors.expenseRed);
        expect(expense.textAlign, TextAlign.right);
        await _reveal(tester, find.text('+₹1,000'));
        expect(
          tester.widget<Text>(find.text('+₹1,000')).style?.color,
          AppColors.incomeGreen,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('the caption footer is the last thing and overlaps no row', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _screen());
      await _reveal(tester, find.byKey(const Key('all-transactions-footer')));

      expect(
        find.byKey(const Key('all-transactions-footer-art')),
        findsOneWidget,
      );
      expect(find.text('Smart Tracking… Better Planning…'), findsOneWidget);

      // It sits below the end-of-list line, so it can never cover a row.
      final double endBottom = tester
          .getBottomLeft(find.byKey(const Key('transactions-end')))
          .dy;
      expect(
        tester.getTopLeft(find.byKey(const Key('all-transactions-footer'))).dy,
        greaterThan(endBottom),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('empty, no-match and failure states', () {
    testWidgets('an empty khata is honest and quiet', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const AllTransactionsScreen(
          summary: LedgerSummary(
            openingBalancePaise: _openingPaise,
            entries: <LedgerEntry>[],
          ),
        ),
      );

      expect(find.byKey(const Key('transactions-empty')), findsOneWidget);
      expect(find.text('No transactions yet'), findsOneWidget);
      expect(find.textContaining('₹'), findsNothing);
      // The header is still there, so the page is still a page you can leave.
      expect(find.byKey(const Key('all-transactions-header')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a filter with no hits says so and can be cleared', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _screen());
      await tester.enterText(find.byKey(const Key('search-field')), 'zzz');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('transactions-no-match')), findsOneWidget);
      expect(find.text('Showing 0 of 3 transactions'), findsOneWidget);
      await tester.tap(find.byKey(const Key('clear-filters')));
      await tester.pumpAndSettle();
      expect(find.text('Showing 3 transactions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('submission and failure states', () {
    testWidgets('a preview row is not tappable; a stored row is', (
      WidgetTester tester,
    ) async {
      // Preview rows carry no id, so an editor for them could never save: the
      // row must not look editable at all.
      await _pump(tester, _screen());
      await _reveal(tester, find.text('Grocery Shopping'));
      await tester.tap(find.text('Grocery Shopping'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('editor-update-button')), findsNothing);
      expect(
        find.byKey(const Key('transaction-row-Grocery Shopping')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed refresh keeps the page and its retry really reads', (
      WidgetTester tester,
    ) async {
      // Seed real rows, so tapping one opens the real editor; then break the
      // post-edit re-read and prove the failure state is honest, keeps the
      // header and the back action, and that retry is a real read.
      final _FailingLedger ledger = _FailingLedger(NativeDatabase.memory());
      await tester.runAsync(() async {
        await ledger.initialize();
        await ledger.addEntry(
          EntryFormResult(
            kind: EntryFormKind.expense,
            amountPaise: 50000,
            category: 'Food',
            description: 'Grocery Shopping',
            occurredAt: DateTime(2026, 11, 19, 18, 15),
          ),
        );
      });
      final LedgerSummary loaded = (await tester.runAsync(
        () => ledger.readSummary(khataId: 'personal'),
      ))!;

      await _pump(
        tester,
        AllTransactionsScreen(
          summary: loaded,
          ledger: ledger,
          khataId: 'personal',
        ),
      );
      expect(find.text('Showing 1 transaction'), findsOneWidget);

      await _reveal(tester, find.text('Grocery Shopping'));
      await tester.tap(find.text('Grocery Shopping'));
      await tester.pumpAndSettle();

      // The editor is open on the stored row: break the next read now.
      ledger.fail = true;
      final Finder update = find.byKey(const Key('editor-update-button'));
      await tester.ensureVisible(update);
      await tester.pumpAndSettle();
      await tester.tap(update);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('transactions-refresh-failed')),
        findsOneWidget,
      );
      expect(find.text('Could not refresh transactions.'), findsOneWidget);
      // Still a page you can leave, with a 44 dp+ retry.
      expect(find.byKey(const Key('all-transactions-header')), findsOneWidget);
      expect(find.byKey(const Key('all-transactions-title')), findsOneWidget);
      expect(find.byKey(const Key('all-transactions-back')), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const Key('transactions-refresh-retry')))
            .height,
        greaterThanOrEqualTo(44),
      );
      // Nothing invented: no totals card, no count, no opening balance.
      expect(find.byKey(const Key('transactions-summary')), findsNothing);
      expect(find.textContaining('₹10,000'), findsNothing);
      expect(tester.takeException(), isNull);

      // A retry is a real read: it fails again while storage is broken...
      final int before = ledger.reads;
      await tester.tap(find.byKey(const Key('transactions-refresh-retry')));
      await tester.pumpAndSettle();
      expect(ledger.reads, greaterThan(before));
      expect(
        find.byKey(const Key('transactions-refresh-failed')),
        findsOneWidget,
      );

      // ...and recovers the page, with the real figure, once storage is back.
      ledger.fail = false;
      await tester.tap(find.byKey(const Key('transactions-refresh-retry')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('transactions-refresh-failed')),
        findsNothing,
      );
      expect(find.text('Showing 1 transaction'), findsOneWidget);
      expect(find.text('-₹500'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('320x568 at 200% text', () {
    Future<void> expectScrollsClean(WidgetTester tester) async {
      for (int i = 0; i < 8; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -260));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    testWidgets('English and Bengali both scroll without overflow', (
      WidgetTester tester,
    ) async {
      for (final bool bengali in <bool>[false, true]) {
        await _pump(
          tester,
          _screen(bengali: bengali),
          size: _smallPhone,
          textScale: _largeText,
        );
        // The title ellipsizes instead of pushing the header apart.
        final Text title = tester.widget<Text>(
          find.byKey(const Key('all-transactions-title')),
        );
        expect(title.overflow, TextOverflow.ellipsis);
        expect(title.maxLines, 1);
        expect(tester.takeException(), isNull);

        // A chip is still a 44 dp+ target at this scale, once scrolled to.
        await _reveal(tester, find.byKey(const Key('type-filter-all')));
        expect(
          tester.getSize(find.byKey(const Key('type-filter-all'))).height,
          greaterThanOrEqualTo(44),
        );

        await expectScrollsClean(tester);
      }
    });

    testWidgets('the totals stack rather than truncating their captions', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _screen(), size: _smallPhone, textScale: _largeText);

      // At 200 % the two columns become two rows with a horizontal rule, so
      // neither caption ellipsizes to "Inco…".
      expect(find.byKey(const Key('transactions-summary-rule')), findsNothing);
      final Text income = tester.widget<Text>(find.text('Income').first);
      expect(income.maxLines, 2);
      expect(
        find.descendant(
          of: find.byKey(const Key('transactions-summary')),
          matching: find.text('₹1,000'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('ledger first on a typical phone', () {
    testWidgets(
      'at 390x844 the search box, the filter action and a stored row are all '
      'visible without scrolling',
      (WidgetTester tester) async {
        await _pump(tester, _screen(), size: _reference);

        // Nothing here is scrolled into view: each getRect is the position the
        // first frame gave the widget, which is what "visible without
        // scrolling" means on a phone this size.
        final Finder field = find.byKey(const Key('search-field'));
        final Finder action = find.byKey(const Key('filters-state'));
        final Finder row = find.byKey(
          const Key('transaction-row-Grocery Shopping'),
        );

        expect(field, findsOneWidget);
        expect(action, findsOneWidget);
        expect(row, findsOneWidget);

        for (final Finder target in <Finder>[field, action, row]) {
          final Rect rect = tester.getRect(target);
          expect(
            rect.top,
            greaterThanOrEqualTo(0),
            reason: '$target starts above the visible screen',
          );
          expect(
            rect.bottom,
            lessThanOrEqualTo(_reference.height),
            reason: '$target ends below the visible screen',
          );
        }

        // ...and in that order: the filter action sits under the search box,
        // the ledger under both.
        expect(
          tester.getRect(field).bottom,
          lessThanOrEqualTo(tester.getRect(action).top),
        );
        expect(
          tester.getRect(action).bottom,
          lessThanOrEqualTo(tester.getRect(row).top),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('the filter action opens and closes the panels', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _screen(), size: _reference);

      // Open by default, and the strip states that nothing is narrowing the
      // list - the panels are visible rather than merely claimed open.
      expect(find.text('No filters applied'), findsOneWidget);
      expect(find.text('Filters applied'), findsNothing);
      expect(find.byKey(const Key('date-filter-from')), findsOneWidget);

      await tester.tap(find.byKey(const Key('filters-state')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('date-filter-from')), findsNothing);
      expect(find.byKey(const Key('category-filter-all')), findsNothing);
      // The rows stay put: closing filters must never hide the ledger, and the
      // search box keeps working. The newest row is the one already on screen.
      expect(
        find.byKey(const Key('transaction-row-Grocery Shopping')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('search-field')), findsOneWidget);

      // Opening again must not summon the keyboard: the action is a chip, and
      // the field it sits above is untouched.
      await tester.tap(find.byKey(const Key('filters-state')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('date-filter-from')), findsOneWidget);
      final TextField field = tester.widget<TextField>(
        find.byKey(const Key('search-field')),
      );
      expect(field.focusNode?.hasFocus, isFalse);
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('the state chip is a 44 dp+ button with a spoken state', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _screen(), size: _reference);

      expect(
        tester.getSize(find.byKey(const Key('filters-state'))).height,
        greaterThanOrEqualTo(44),
      );
      // The chip speaks its state, not just its glyph: a screen reader hears
      // "Hide filters. No filters applied. Showing 3 transactions", so a closed
      // panel can never be mistaken for an active filter.
      expect(
        find.bySemanticsLabel(RegExp(r'No filters applied')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Showing 3 transactions')),
        findsWidgets,
      );

      // A live filter is named in the strip, with the count, and is liftable
      // from there without opening anything.
      await tester.enterText(find.byKey(const Key('search-field')), 'salary');
      await tester.pumpAndSettle();
      expect(find.text('Filters applied'), findsOneWidget);
      expect(find.text('Search: salary'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'Search: salary')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Clear search')),
        findsWidgets,
      );

      await tester.tap(find.byKey(const Key('active-filter-search')));
      await tester.pumpAndSettle();
      expect(find.text('No filters applied'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Showing 3 transactions')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  });

  group('reference proportions', () {
    testWidgets('at 390x844 the header, card and pill read in order', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _screen(), size: _reference);

      final double headerBottom = tester
          .getBottomLeft(find.byKey(const Key('all-transactions-header')))
          .dy;
      final double cardTop = tester
          .getTopLeft(find.byKey(const Key('transactions-summary')))
          .dy;
      final double pillTop = tester
          .getTopLeft(find.byKey(const Key('search-pill')))
          .dy;
      final double stripTop = tester
          .getTopLeft(find.byKey(const Key('filters-state')))
          .dy;
      final double firstRowTop = tester
          .getTopLeft(find.byKey(const Key('transaction-row-Grocery Shopping')))
          .dy;

      expect(headerBottom, lessThan(cardTop));
      expect(cardTop, lessThan(pillTop));
      // Ledger-first: the state strip follows the search box, and a stored row
      // follows the strip - no filter panel stands between them any more.
      expect(pillTop, lessThan(stripTop));
      expect(stripTop, lessThan(firstRowTop));
      // The banner is a header, not a hero: it leaves the list real room.
      expect(headerBottom, lessThan(_reference.height / 4));
      expect(tester.takeException(), isNull);
    });
  });
}

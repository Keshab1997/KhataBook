// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../calculator/calculator_screen.dart';
import '../counter/note_counter_screen.dart';
import '../entry/add_entry_screen.dart';
import '../home/home_screen.dart';
import '../home/models.dart';
import '../ledger/data/local_ledger.dart';
import '../profile/profile_screen.dart';
import '../../core/format/date_format.dart';
import '../../core/format/money.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.ledger});

  /// An injected database is useful for isolated tests. The shell owns it.
  final LocalLedger? ledger;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  LocalLedger? _ledger;
  LedgerSummary? _summary;
  Object? _error;
  bool _saving = false;
  bool get _webPreview => kIsWeb && widget.ledger == null;

  @override
  void initState() {
    super.initState();
    if (!_webPreview) _open();
  }

  Future<void> _open() async {
    setState(() => _error = null);
    try {
      _ledger ??= widget.ledger ?? LocalLedger.device();
      await _ledger!.initialize();
      final LedgerSummary value = await _ledger!.readSummary();
      if (mounted) setState(() => _summary = value);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _ledger?.close();
    super.dispose();
  }

  void _addEntry() {
    final LedgerSummary? current = _summary;
    if (current == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) => AddEntryScreen(
          openingBalancePaise: current.remainingPaise,
          onSave: (EntryFormResult entry) async {
            if (_saving) return;
            _saving = true;
            try {
              await _ledger!.addEntry(entry);
            } catch (_) {
              _saving = false;
              if (routeContext.mounted) {
                ScaffoldMessenger.of(routeContext).showSnackBar(
                  const SnackBar(
                    content: Text('Could not save locally. Please try again.'),
                  ),
                );
              }
              return;
            }
            _saving = false;
            if (routeContext.mounted) Navigator.of(routeContext).pop();
            try {
              final LedgerSummary updated = await _ledger!.readSummary();
              if (mounted) setState(() => _summary = updated);
            } catch (error) {
              if (mounted) {
                setState(() {
                  _summary = null;
                  _error = error;
                });
              }
            }
          },
        ),
      ),
    );
  }

  void _viewAll() {
    final LedgerSummary? current = _summary;
    if (current == null) return;
    final List<LedgerEntry> entries = current.recent(current.entries.length);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => Scaffold(
          appBar: AppBar(title: const Text('All Transactions')),
          body: entries.isEmpty
              ? const Center(child: Text('No transactions yet.'))
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (BuildContext context, int index) {
                    final LedgerEntry e = entries[index];
                    return ListTile(
                      title: Text(e.title),
                      subtitle: Text(formatEntryDate(e.at)),
                      trailing: Text(
                        '${e.type == EntryType.income ? '+' : '-'}${formatPaise(e.amountPaise)}',
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (_webPreview) {
      home = const Column(
        children: <Widget>[
          MaterialBanner(
            content: Text(
              'Web preview only: offline storage is not available here yet.',
            ),
            actions: <Widget>[SizedBox.shrink()],
          ),
          Expanded(child: HomeScreen()),
        ],
      );
    } else if (_error != null) {
      home = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Could not open local ledger.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _open, child: const Text('Retry')),
          ],
        ),
      );
    } else if (_summary == null) {
      home = const Center(child: CircularProgressIndicator());
    } else {
      home = HomeScreen(
        summary: _summary,
        onAddEntry: _addEntry,
        onViewAll: _viewAll,
      );
    }
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          home,
          const CalculatorScreen(),
          const NoteCounterScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            label: 'Calculator',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            label: 'Counter',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

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
import '../ledger/khata_switcher.dart';
import '../ledger/all_transactions_screen.dart';
import '../ledger/wallet_summary_screen.dart';
import '../profile/profile_screen.dart';

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
  LocalKhata _activeKhata = const LocalKhata(
    id: 'personal',
    name: 'Personal Khata',
    openingBalancePaise: 0,
  );
  bool _switching = false;
  int _openRequest = 0;
  bool get _webPreview => kIsWeb && widget.ledger == null;

  @override
  void initState() {
    super.initState();
    if (!_webPreview) _open();
  }

  Future<void> _open() async {
    final int request = ++_openRequest;
    if (mounted) {
      setState(() {
        _error = null;
        _summary = null;
      });
    }
    try {
      _ledger ??= widget.ledger ?? LocalLedger.device();
      final LocalLedger ledger = _ledger!;
      await ledger.initialize();
      final String activeId = await ledger.readActiveKhataId();
      final List<LocalKhata> khatas = await ledger.listKhatas();
      final LocalKhata active = khatas.firstWhere(
        (LocalKhata khata) => khata.id == activeId,
        orElse: () => throw KhataNotFoundException(activeId),
      );
      final LedgerSummary summary = await ledger.readSummary(
        khataId: active.id,
      );
      if (mounted && request == _openRequest) {
        setState(() {
          _activeKhata = active;
          _summary = summary;
        });
      }
    } catch (error) {
      if (mounted && request == _openRequest) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _openRequest++;
    _ledger?.close();
    super.dispose();
  }

  Future<void> _switchKhata() async {
    if (_switching || _ledger == null) return;
    _switching = true;
    try {
      final List<LocalKhata> khatas = await _ledger!.listKhatas();
      if (!mounted) return;
      final LocalKhata? selected = await showKhataSwitcher(
        context,
        _ledger!,
        khatas,
        _activeKhata.id,
      );
      if (selected == null || !mounted) return;
      final LedgerSummary summary = await _ledger!.readSummary(
        khataId: selected.id,
      );
      await _ledger!.setActiveKhataId(selected.id);
      if (mounted) {
        setState(() {
          _activeKhata = selected;
          _summary = summary;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open khata. Please try again.'),
          ),
        );
      }
    } finally {
      _switching = false;
    }
  }

  void _addEntry() {
    final LedgerSummary? current = _summary;
    if (current == null) return;
    final String khataId = _activeKhata.id;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) => AddEntryScreen(
          openingBalancePaise: current.remainingPaise,
          onSave: (EntryFormResult entry) async {
            if (_saving) return;
            _saving = true;
            try {
              await _ledger!.addEntry(entry, khataId: khataId);
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
              final LedgerSummary updated = await _ledger!.readSummary(
                khataId: khataId,
              );
              if (mounted && _activeKhata.id == khataId) {
                setState(() => _summary = updated);
              }
            } catch (error) {
              if (mounted && _activeKhata.id == khataId) {
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

  Future<void> _viewAll() async {
    final LedgerSummary? current = _summary;
    if (current == null) return;
    final String khataId = _activeKhata.id;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AllTransactionsScreen(
          summary: current,
          ledger: _ledger,
          khataId: khataId,
          onSummaryChanged: (value) {
            if (mounted && _activeKhata.id == khataId) {
              setState(() => _summary = value);
            }
          },
        ),
      ),
    );
    try {
      final updated = await _ledger!.readSummary(khataId: khataId);
      if (mounted && _activeKhata.id == khataId) {
        setState(() => _summary = updated);
      }
    } catch (error) {
      if (mounted && _activeKhata.id == khataId) {
        setState(() {
          _summary = null;
          _error = error;
        });
      }
    }
  }

  void _openWallet() {
    final LocalLedger? ledger = _ledger;
    if (ledger == null || _summary == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WalletSummaryScreen(ledger: ledger),
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
        khataName: _activeKhata.name,
        onSwitchKhata: _switchKhata,
      );
    }
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          home,
          const CalculatorScreen(),
          const NoteCounterScreen(),
          ProfileScreen(
            onWalletSummary: !_webPreview && _summary != null
                ? _openWallet
                : null,
          ),
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

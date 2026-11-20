// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/language_preference.dart';
import '../calculator/calculator_screen.dart';
import '../counter/note_counter_screen.dart';
import '../counter/note_counter_store.dart';
import '../entry/add_entry_screen.dart';
import '../home/home_screen.dart';
import '../home/models.dart';
import '../ledger/data/local_ledger.dart';
import '../ledger/data/ledger_backup.dart';
import '../profile/backup_files.dart';
import '../profile/backup_screen.dart';
import '../ledger/khata_switcher.dart';
import '../ledger/khata_manage_screen.dart';
import '../ledger/all_transactions_screen.dart';
import '../ledger/wallet_summary_screen.dart';
import '../sync/cloud_backup_screen.dart';
import '../sync/cloud_sync.dart';
import '../profile/profile_screen.dart';
import '../profile/profile_store.dart';
import '../profile/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.ledger,
    this.cloudSync,
    this.initialLanguage = AppLanguage.en,
  });

  /// An injected database is useful for isolated tests. The shell owns it.
  final LocalLedger? ledger;

  /// Live cloud sync started in `main`; `null` keeps the app local-only.
  final CloudSync? cloudSync;

  /// The UI language to start in; Settings changes it through the shell, which
  /// saves it and passes it to every screen.
  final AppLanguage initialLanguage;

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
  late AppLanguage _language = widget.initialLanguage;
  ProfileStore? _profileStore;
  NoteCounterStore? _noteCounterStore;

  /// Live cloud sync (owned by `main`; never disposed here). Every local
  /// write goes through [_notifyLocalChange] so a signed-in session backs up
  /// automatically after a short debounce.
  CloudSync? get _cloudSync => widget.cloudSync;

  void _notifyLocalChange() => widget.cloudSync?.notifyLocalChange();

  AppStrings get _strings => AppStrings(_language);

  @override
  void initState() {
    super.initState();
    _open();
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
      _profileStore ??= ProfileStore(ledger);
      _noteCounterStore ??= NoteCounterStore(ledger);
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

  /// Saves the language first and only then shows it everywhere. The pushed
  /// Settings route was built with the old language, so it closes and the
  /// user lands back on Profile, already in the new language.
  Future<bool> _changeLanguage(AppLanguage language) async {
    if (!await saveLanguagePreference(language)) return false;
    if (!mounted) return true;
    setState(() => _language = language);
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    return true;
  }

  @override
  void dispose() {
    _openRequest++;
    _ledger?.close();
    super.dispose();
  }

  Future<void> _openBackup() async {
    final ledger = _ledger;
    if (ledger == null || _summary == null) return;
    final backup = LedgerBackup(ledger);
    const files = BackupFiles();
    final restored = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BackupScreen(
          language: _language,
          onExport: () async {
            final json = await backup.exportJson();
            return await files.save(json)
                ? BackupExportResult.saved
                : BackupExportResult.cancelled;
          },
          onPickBackup: () async {
            final json = await files.pick();
            if (json == null) return null;
            final counts = backup.inspect(json);
            return BackupPreview(
              payload: json,
              khataCount: counts.khataCount,
              transactionCount: counts.transactionCount,
              deletedTransactionCount: counts.deletedTransactionCount,
              profileIncluded: counts.profileIncluded,
              customCategoryCount: counts.customCategoryCount,
              khatasWithSavedCount: counts.khatasWithSavedCount,
              savedSessionCount: counts.savedSessionCount,
            );
          },
          onRestore: (preview) async {
            await backup.restoreReplacing(preview.payload);
            _notifyLocalChange();
            return true;
          },
        ),
      ),
    );
    if (restored == true && mounted) {
      await _open();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_strings.text(AppString.backupRestored))),
        );
      }
    }
  }

  Future<void> _manageKhatas() async {
    final ledger = _ledger;
    if (ledger == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => KhataManageScreen(
          language: _language,
          loadActive: ledger.listKhatas,
          loadArchived: ledger.listArchivedKhatas,
          onRename: (id, name) async {
            await ledger.renameKhata(khataId: id, name: name);
            _notifyLocalChange();
          },
          onArchive: (id) async {
            await ledger.archiveKhata(khataId: id);
            _notifyLocalChange();
          },
          onUnarchive: (id) async {
            await ledger.unarchiveKhata(khataId: id);
            _notifyLocalChange();
          },
        ),
      ),
    );
    if (changed == true && mounted) await _open();
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
        language: _language,
        onManage: _manageKhatas,
      );
      if (selected == null || !mounted) return;
      final LedgerSummary summary = await _ledger!.readSummary(
        khataId: selected.id,
      );
      await _ledger!.setActiveKhataId(selected.id);
      _notifyLocalChange();
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
          SnackBar(content: Text(_strings.text(AppString.openKhataFailed))),
        );
      }
    } finally {
      _switching = false;
    }
  }

  /// Opens the entry form for the active khata. The calculator and the note
  /// counter pass an amount (and the counter a kind and note) to prefill; the
  /// user still reviews and saves the entry, so nothing is written for them.
  void _addEntry({int? amountPaise, EntryFormKind? kind, String? description}) {
    final LedgerSummary? current = _summary;
    if (current == null) return;
    final String khataId = _activeKhata.id;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) => AddEntryScreen(
          language: _language,
          initialAmountPaise: amountPaise,
          initialKind: kind,
          initialDescription: description,
          openingBalancePaise: current.remainingPaise,
          onSave: (EntryFormResult entry) async {
            if (_saving) return;
            _saving = true;
            try {
              await _ledger!.addEntry(entry, khataId: khataId);
              _notifyLocalChange();
            } catch (_) {
              _saving = false;
              if (routeContext.mounted) {
                ScaffoldMessenger.of(routeContext).showSnackBar(
                  SnackBar(
                    content: Text(_strings.text(AppString.localSaveFailed)),
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
          language: _language,
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

  void _openCloudBackup() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            CloudBackupScreen(language: _language, cloudSync: _cloudSync),
      ),
    );
  }

  void _openWallet() {
    final LocalLedger? ledger = _ledger;
    if (ledger == null || _summary == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            WalletSummaryScreen(ledger: ledger, language: _language),
      ),
    );
  }

  /// Counted cash becomes an income entry for the user to review: it may
  /// already be inside the opening balance, so it is never saved silently.
  void _addCountedCash(int amountPaise, String note) => _addEntry(
    amountPaise: amountPaise,
    kind: EntryFormKind.income,
    description: note,
  );

  void _useCalculatorResult(int amountPaise) =>
      _addEntry(amountPaise: amountPaise);

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = _strings;
    final bool ledgerReady = _summary != null;
    final NoteCounterStore? counterStore = ledgerReady
        ? _noteCounterStore
        : null;
    final Widget home;
    if (_error != null) {
      home = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(strings.text(AppString.openLedgerFailed)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _open,
              child: Text(strings.text(AppString.retry)),
            ),
          ],
        ),
      );
    } else if (_summary == null) {
      home = const Center(child: CircularProgressIndicator());
    } else {
      home = HomeScreen(
        language: _language,
        summary: _summary,
        onAddEntry: _addEntry,
        onViewAll: _viewAll,
        khataName: _activeKhata.name,
        onSwitchKhata: _switchKhata,
        onSettings: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => SettingsScreen(
              language: _language,
              onLanguageChanged: _changeLanguage,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          home,
          CalculatorScreen(
            language: _language,
            onUseInEntry: ledgerReady ? _useCalculatorResult : null,
            onSettings: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(
                  language: _language,
                  onLanguageChanged: _changeLanguage,
                ),
              ),
            ),
          ),
          NoteCounterScreen(
            language: _language,
            store: counterStore,
            khataId: counterStore == null ? null : _activeKhata.id,
            onAddToKhata: ledgerReady ? _addCountedCash : null,
            onSettings: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(
                  language: _language,
                  onLanguageChanged: _changeLanguage,
                ),
              ),
            ),
          ),
          ProfileScreen(
            language: _language,
            onLanguageChanged: _changeLanguage,
            profileStore: _profileStore,
            onBackup:
                defaultTargetPlatform == TargetPlatform.android &&
                    _summary != null
                ? _openBackup
                : null,
            onCloudBackup: _openCloudBackup,
            onWalletSummary: _summary != null ? _openWallet : null,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: strings.text(AppString.home),
          ),
          NavigationDestination(
            icon: const Icon(Icons.calculate_outlined),
            selectedIcon: const Icon(Icons.calculate),
            label: strings.text(AppString.calculator),
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view_rounded),
            label: strings.text(AppString.counter),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: strings.text(AppString.profile),
          ),
        ],
      ),
    );
  }
}

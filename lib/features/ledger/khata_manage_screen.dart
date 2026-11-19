// Flutter material migration is tracked separately.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;

import 'data/local_ledger.dart';

/// Callback-driven screen for managing active and archived khatas.
///
/// Pops with `true` when at least one mutation (rename, archive, unarchive)
/// succeeded, or `false` when no changes were made.
class KhataManageScreen extends StatefulWidget {
  const KhataManageScreen({
    super.key,
    required this.loadActive,
    required this.loadArchived,
    required this.onRename,
    required this.onArchive,
    required this.onUnarchive,
  });

  final Future<List<LocalKhata>> Function() loadActive;
  final Future<List<LocalKhata>> Function() loadArchived;
  final Future<void> Function(String id, String name) onRename;
  final Future<void> Function(String id) onArchive;
  final Future<void> Function(String id) onUnarchive;

  @override
  State<KhataManageScreen> createState() => _KhataManageScreenState();
}

class _KhataManageScreenState extends State<KhataManageScreen> {
  static const String _personalId = 'personal';
  static const int _maxNameRunes = 40;

  List<LocalKhata> _active = const <LocalKhata>[];
  List<LocalKhata> _archived = const <LocalKhata>[];
  bool _loading = true;
  bool _mutating = false;
  bool _hasChanges = false;
  String? _loadError;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait<List<LocalKhata>>(
        <Future<List<LocalKhata>>>[widget.loadActive(), widget.loadArchived()],
      );
      if (!mounted) return;
      setState(() {
        _active = results[0];
        _archived = results[1];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load khatas. Please try again.';
      });
    }
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    if (_mutating) return;
    setState(() {
      _mutating = true;
      _actionError = null;
    });
    try {
      await action();
      if (!mounted) return;
      _hasChanges = true;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mutating = false;
        _actionError = 'Could not update khata. Please try again.';
      });
      return;
    }

    try {
      final results = await Future.wait<List<LocalKhata>>(
        <Future<List<LocalKhata>>>[widget.loadActive(), widget.loadArchived()],
      );
      if (!mounted) return;
      setState(() {
        _active = results[0];
        _archived = results[1];
        _mutating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mutating = false;
        _actionError =
            'Updated khata, but could not refresh list. Please retry.';
      });
    }
  }

  Future<void> _promptRename(LocalKhata khata) async {
    if (_mutating) return;
    final String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) =>
          _RenameKhataDialog(initialName: khata.name, maxRunes: _maxNameRunes),
    );
    if (newName == null || !mounted) return;
    await _runMutation(() => widget.onRename(khata.id, newName));
  }

  Future<void> _promptArchive(LocalKhata khata) async {
    if (_mutating || khata.id == _personalId) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Archive Khata?'),
        content: SingleChildScrollView(
          child: Text(
            'Archive "${khata.name}"? Its entries will be retained, '
            'but this khata will be hidden from the active switcher.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('cancel-archive'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-archive'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runMutation(() => widget.onArchive(khata.id));
  }

  Future<void> _promptUnarchive(LocalKhata khata) async {
    if (_mutating) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Unarchive Khata?'),
        content: SingleChildScrollView(
          child: Text('Restore "${khata.name}" to your active khatas?'),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('cancel-unarchive'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-unarchive'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unarchive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runMutation(() => widget.onUnarchive(khata.id));
  }

  void _handleBack() {
    if (_mutating) return;
    Navigator.of(context).pop(_hasChanges);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Khatas'),
          leading: IconButton(
            key: const Key('manage-khatas-back'),
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: _mutating ? null : _handleBack,
          ),
        ),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(key: Key('manage-khatas-loading')),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('manage-khatas-retry'),
                onPressed: _mutating ? null : _loadAll,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (_actionError != null) ...<Widget>[
          MaterialBanner(
            key: const Key('manage-khatas-action-error'),
            content: Text(_actionError!),
            actions: <Widget>[
              TextButton(
                onPressed: _mutating
                    ? null
                    : () => setState(() => _actionError = null),
                child: const Text('Dismiss'),
              ),
              TextButton(
                onPressed: _mutating ? null : _loadAll,
                child: const Text('Retry'),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Text('Active Khatas', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_active.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No active khatas'),
          )
        else
          for (final LocalKhata khata in _active)
            _KhataRow(
              key: Key('active-khata-${khata.id}'),
              khata: khata,
              isPersonal: khata.id == _personalId,
              isArchived: false,
              busy: _mutating,
              onRename: () => _promptRename(khata),
              onArchive: khata.id == _personalId
                  ? null
                  : () => _promptArchive(khata),
            ),
        const SizedBox(height: 24),
        Text('Archived Khatas', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_archived.isEmpty)
          const Padding(
            key: Key('empty-archived-khatas'),
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No archived khatas'),
          )
        else
          for (final LocalKhata khata in _archived)
            _KhataRow(
              key: Key('archived-khata-${khata.id}'),
              khata: khata,
              isPersonal: khata.id == _personalId,
              isArchived: true,
              busy: _mutating,
              onUnarchive: () => _promptUnarchive(khata),
            ),
      ],
    );
  }
}

class _KhataRow extends StatelessWidget {
  const _KhataRow({
    super.key,
    required this.khata,
    required this.isPersonal,
    required this.isArchived,
    required this.busy,
    this.onRename,
    this.onArchive,
    this.onUnarchive,
  });

  final LocalKhata khata;
  final bool isPersonal;
  final bool isArchived;
  final bool busy;
  final VoidCallback? onRename;
  final VoidCallback? onArchive;
  final VoidCallback? onUnarchive;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    khata.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (isPersonal)
                    Text(
                      'Default',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: <Widget>[
                if (!isArchived && onRename != null)
                  IconButton(
                    key: Key('rename-khata-${khata.id}'),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Rename ${khata.name}',
                    onPressed: busy ? null : onRename,
                  ),
                if (!isArchived && !isPersonal && onArchive != null)
                  IconButton(
                    key: Key('archive-khata-${khata.id}'),
                    icon: const Icon(Icons.archive_outlined),
                    tooltip: 'Archive ${khata.name}',
                    onPressed: busy ? null : onArchive,
                  ),
                if (isArchived && onUnarchive != null)
                  TextButton.icon(
                    key: Key('unarchive-khata-${khata.id}'),
                    icon: const Icon(Icons.unarchive_outlined),
                    label: const Text('Unarchive'),
                    onPressed: busy ? null : onUnarchive,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RenameKhataDialog extends StatefulWidget {
  const _RenameKhataDialog({required this.initialName, required this.maxRunes});

  final String initialName;
  final int maxRunes;

  @override
  State<_RenameKhataDialog> createState() => _RenameKhataDialogState();
}

class _RenameKhataDialogState extends State<_RenameKhataDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final String trimmed = (value ?? '').trim();
    if (trimmed.isEmpty || trimmed.runes.length > widget.maxRunes) {
      return 'Enter a name of 1 to ${widget.maxRunes} characters';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Khata'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: TextFormField(
            key: const Key('rename-khata-input'),
            controller: _controller,
            autofocus: true,
            maxLength: widget.maxRunes,
            maxLengthEnforcement: MaxLengthEnforcement.none,
            decoration: const InputDecoration(labelText: 'Khata name'),
            validator: _validate,
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('cancel-rename'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('save-rename'),
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

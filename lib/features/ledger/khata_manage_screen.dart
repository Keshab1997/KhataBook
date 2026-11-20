// Flutter material migration is tracked separately.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'data/local_ledger.dart';

/// Geometry shared by this screen: one card radius and one hairline border, so
/// the khata rows, the banners and the empty states line up.
const double _cardRadius = 18;
const double _edge = 0.85;
const double _softEdge = 0.6;

/// Callback-driven screen for managing active and archived khatas.
///
/// Pops with `true` when at least one mutation (rename, archive, unarchive)
/// succeeded, or `false` when no changes were made.
///
/// [language] localizes every label, warning and confirmation in this screen
/// and in its rename dialog. Khata names are user data and stay verbatim.
class KhataManageScreen extends StatefulWidget {
  const KhataManageScreen({
    super.key,
    required this.loadActive,
    required this.loadArchived,
    required this.onRename,
    required this.onArchive,
    required this.onUnarchive,
    this.language = AppLanguage.en,
  });

  final Future<List<LocalKhata>> Function() loadActive;
  final Future<List<LocalKhata>> Function() loadArchived;
  final Future<void> Function(String id, String name) onRename;
  final Future<void> Function(String id) onArchive;
  final Future<void> Function(String id) onUnarchive;

  /// Copy language for this screen and its dialogs. Display only.
  final AppLanguage language;

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

  /// Copy for this screen and its dialogs. Display only.
  AppStrings get _strings => AppStrings(widget.language);

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
        _loadError = _strings.text(AppString.loadKhatasFailed);
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
        _actionError = _strings.text(AppString.updateKhataFailed);
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
        _actionError = _strings.text(AppString.refreshKhatasFailed);
      });
    }
  }

  Future<void> _promptRename(LocalKhata khata) async {
    if (_mutating) return;
    final String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => _RenameKhataDialog(
        initialName: khata.name,
        maxRunes: _maxNameRunes,
        language: widget.language,
      ),
    );
    if (newName == null || !mounted) return;
    await _runMutation(() => widget.onRename(khata.id, newName));
  }

  Future<void> _promptArchive(LocalKhata khata) async {
    if (_mutating || khata.id == _personalId) return;
    final AppStrings strings = _strings;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(strings.text(AppString.archiveQuestion)),
        content: SingleChildScrollView(
          child: Text(strings.archiveConfirmation(khata.name)),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('cancel-archive'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.text(AppString.cancel)),
          ),
          FilledButton(
            key: const Key('confirm-archive'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.text(AppString.archive)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runMutation(() => widget.onArchive(khata.id));
  }

  Future<void> _promptUnarchive(LocalKhata khata) async {
    if (_mutating) return;
    final AppStrings strings = _strings;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(strings.text(AppString.unarchiveQuestion)),
        content: SingleChildScrollView(
          child: Text(strings.unarchiveConfirmation(khata.name)),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('cancel-unarchive'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.text(AppString.cancel)),
          ),
          FilledButton(
            key: const Key('confirm-unarchive'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.text(AppString.unarchive)),
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
    final AppStrings strings = _strings;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.text(AppString.manageKhatas)),
          leading: IconButton(
            key: const Key('manage-khatas-back'),
            icon: const Icon(Icons.arrow_back),
            tooltip: strings.text(AppString.back),
            onPressed: _mutating ? null : _handleBack,
          ),
        ),
        body: _buildBody(strings),
      ),
    );
  }

  Widget _buildBody(AppStrings strings) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(key: Key('manage-khatas-loading')),
        ),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(_cardRadius),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: _edge),
              ),
            ),
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
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: AppColors.softText,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('manage-khatas-retry'),
                  onPressed: _mutating ? null : _loadAll,
                  child: Text(strings.text(AppString.retry)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (_actionError != null) ...<Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(_cardRadius),
            child: MaterialBanner(
              key: const Key('manage-khatas-action-error'),
              backgroundColor: AppColors.lightGreen,
              elevation: 0,
              content: Text(
                _actionError!,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.darkText,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: _mutating
                      ? null
                      : () => setState(() => _actionError = null),
                  child: Text(strings.text(AppString.dismiss)),
                ),
                TextButton(
                  onPressed: _mutating ? null : _loadAll,
                  child: Text(strings.text(AppString.retry)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          strings.text(AppString.activeKhatas),
          style: const TextStyle(
            fontSize: 13,
            height: 1.2,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(height: 10),
        if (_active.isEmpty)
          _EmptyGroup(
            key: const Key('empty-active-khatas'),
            message: strings.text(AppString.noActiveKhatas),
          )
        else
          for (final LocalKhata khata in _active)
            _KhataRow(
              key: Key('active-khata-${khata.id}'),
              khata: khata,
              strings: strings,
              isPersonal: khata.id == _personalId,
              isArchived: false,
              busy: _mutating,
              onRename: () => _promptRename(khata),
              onArchive: khata.id == _personalId
                  ? null
                  : () => _promptArchive(khata),
            ),
        const SizedBox(height: 28),
        Text(
          strings.text(AppString.archivedKhatas),
          style: const TextStyle(
            fontSize: 13,
            height: 1.2,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(height: 10),
        if (_archived.isEmpty)
          _EmptyGroup(
            key: const Key('empty-archived-khatas'),
            message: strings.text(AppString.noArchivedKhatas),
          )
        else
          for (final LocalKhata khata in _archived)
            _KhataRow(
              key: Key('archived-khata-${khata.id}'),
              khata: khata,
              strings: strings,
              isPersonal: khata.id == _personalId,
              isArchived: true,
              busy: _mutating,
              onUnarchive: () => _promptUnarchive(khata),
            ),
      ],
    );
  }
}

/// The placeholder shown for an empty group of khatas: a quiet, bordered card
/// so an empty section still reads as part of the screen.
class _EmptyGroup extends StatelessWidget {
  const _EmptyGroup({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: _softEdge),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.inbox_outlined,
            color: AppColors.navigationGrey,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.softText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KhataRow extends StatelessWidget {
  const _KhataRow({
    super.key,
    required this.khata,
    required this.strings,
    required this.isPersonal,
    required this.isArchived,
    required this.busy,
    this.onRename,
    this.onArchive,
    this.onUnarchive,
  });

  final LocalKhata khata;
  final AppStrings strings;
  final bool isPersonal;
  final bool isArchived;
  final bool busy;
  final VoidCallback? onRename;
  final VoidCallback? onArchive;
  final VoidCallback? onUnarchive;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
        side: BorderSide(color: AppColors.outline.withValues(alpha: _edge)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.25,
                      letterSpacing: -0.1,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                  if (isPersonal) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      strings.text(AppString.defaultKhata),
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: AppColors.softText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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
                    tooltip: strings.renameLabel(khata.name),
                    onPressed: busy ? null : onRename,
                  ),
                if (!isArchived && !isPersonal && onArchive != null)
                  IconButton(
                    key: Key('archive-khata-${khata.id}'),
                    icon: const Icon(Icons.archive_outlined),
                    tooltip: strings.archiveLabel(khata.name),
                    onPressed: busy ? null : onArchive,
                  ),
                if (isArchived && onUnarchive != null)
                  TextButton.icon(
                    key: Key('unarchive-khata-${khata.id}'),
                    icon: const Icon(Icons.unarchive_outlined),
                    label: Text(strings.text(AppString.unarchive)),
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
  const _RenameKhataDialog({
    required this.initialName,
    required this.maxRunes,
    required this.language,
  });

  final String initialName;
  final int maxRunes;
  final AppLanguage language;

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
      return AppStrings(widget.language).nameLength(widget.maxRunes);
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings(widget.language);
    return AlertDialog(
      title: Text(strings.text(AppString.renameKhata)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: TextFormField(
            key: const Key('rename-khata-input'),
            controller: _controller,
            autofocus: true,
            maxLength: widget.maxRunes,
            maxLengthEnforcement: MaxLengthEnforcement.none,
            decoration: InputDecoration(
              labelText: strings.text(AppString.khataName),
            ),
            validator: _validate,
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('cancel-rename'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.text(AppString.cancel)),
        ),
        FilledButton(
          key: const Key('save-rename'),
          onPressed: _submit,
          child: Text(strings.text(AppString.save)),
        ),
      ],
    );
  }
}

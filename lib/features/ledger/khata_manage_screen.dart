// Flutter material migration is tracked separately.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MaxLengthEnforcement;

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'data/local_ledger.dart';

/// Geometry — one card radius and one hairline border so the khata rows,
/// the banners and the empty states line up as one system.
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
            icon: const Icon(Icons.arrow_back_rounded),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  key: const Key('manage-khatas-loading'),
                  strokeWidth: 3,
                  color: AppColors.primaryGreen,
                  backgroundColor: AppColors.lightGreen,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Loading khatas…',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.softText,
                ),
              ),
            ],
          ),
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
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.darkText.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.lightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.expenseRed,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: AppColors.softText,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('manage-khatas-retry'),
                  onPressed: _mutating ? null : _loadAll,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(strings.text(AppString.retry)),
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
          Container(
            key: const Key('manage-khatas-action-error'),
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            decoration: BoxDecoration(
              color: AppColors.lightGreen,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _actionError!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.darkText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      onPressed: _mutating
                          ? null
                          : () => setState(() => _actionError = null),
                      child: Text(strings.text(AppString.dismiss)),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      onPressed: _mutating ? null : _loadAll,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 36),
                      ),
                      child: Text(strings.text(AppString.retry)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        _SectionHeader(
          icon: Icons.folder_open_rounded,
          label: strings.text(AppString.activeKhatas),
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
        const SizedBox(height: 24),
        _SectionHeader(
          icon: Icons.archive_outlined,
          label: strings.text(AppString.archivedKhatas),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: AppColors.primaryGreen),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            height: 1.2,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryGreen,
          ),
        ),
      ],
    );
  }
}

/// Placeholder shown for an empty group — quiet bordered card.
class _EmptyGroup extends StatelessWidget {
  const _EmptyGroup({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: _softEdge),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.creamBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.inbox_outlined,
              color: AppColors.navigationGrey,
              size: 16,
            ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: AppColors.outline.withValues(alpha: _edge)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.darkText.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isArchived
                    ? AppColors.navigationGrey.withValues(alpha: 0.12)
                    : AppColors.lightGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isArchived
                    ? Icons.archive_rounded
                    : isPersonal
                    ? Icons.star_rounded
                    : Icons.book_rounded,
                size: 18,
                color: isArchived
                    ? AppColors.navigationGrey
                    : AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    khata.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.25,
                      letterSpacing: -0.1,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                    ),
                  ),
                  if (isPersonal) ...<Widget>[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightGreen,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        strings.text(AppString.defaultKhata),
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.2,
                          letterSpacing: 0.4,
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!isArchived && onRename != null)
              IconButton(
                key: Key('rename-khata-${khata.id}'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: strings.renameLabel(khata.name),
                color: AppColors.softText,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.creamBackground,
                  minimumSize: const Size(36, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: busy ? null : onRename,
              ),
            if (!isArchived && !isPersonal && onArchive != null) ...<Widget>[
              const SizedBox(width: 4),
              IconButton(
                key: Key('archive-khata-${khata.id}'),
                icon: const Icon(Icons.archive_outlined, size: 18),
                tooltip: strings.archiveLabel(khata.name),
                color: AppColors.softText,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.creamBackground,
                  minimumSize: const Size(36, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: busy ? null : onArchive,
              ),
            ],
            if (isArchived && onUnarchive != null)
              FilledButton.icon(
                key: Key('unarchive-khata-${khata.id}'),
                icon: const Icon(Icons.unarchive_outlined, size: 16),
                label: Text(
                  strings.text(AppString.unarchive),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: busy ? null : onUnarchive,
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
              filled: true,
              fillColor: AppColors.surface,
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

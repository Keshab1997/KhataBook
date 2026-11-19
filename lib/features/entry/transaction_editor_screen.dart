// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'add_entry_screen.dart';

/// What the caller should do once the editor has closed.
enum TransactionEditResult { updated, deleted }

/// Edits (or deletes) one existing entry without owning navigation, storage or
/// undo. S2/S7 follow-on in docs/spec/screens.md.
///
/// The caller supplies the original [initial] values and two callbacks:
/// [onUpdate] receives the edited entry, [onDelete] takes no arguments (the
/// caller already knows which entry it is). Both return `true` only when the
/// change really landed. This screen never touches a ledger, so it cannot fake
/// a save:
///   * `true` pops with [TransactionEditResult.updated] or `.deleted`;
///   * `false` or a thrown error shows an inline message, re-enables the
///     actions and leaves the form exactly as it was;
///   * a cancelled delete confirmation calls nothing at all.
///
/// Money stays integer paise: the amount is parsed from the field into paise
/// and nothing here uses `double`. The untouched date keeps the original
/// [EntryFormResult.occurredAt] *exactly*, time and all; a date the user picks
/// is stored as that local calendar day at midnight, matching Add Entry.
class TransactionEditorScreen extends StatefulWidget {
  const TransactionEditorScreen({
    super.key,
    this.language = AppLanguage.en,
    required this.initial,
    required this.onUpdate,
    required this.onDelete,
  });

  final AppLanguage language;

  /// The entry being edited, shown prefilled and never mutated.
  final EntryFormResult initial;

  /// Persists the edited entry; `true` means it landed.
  final Future<bool> Function(EntryFormResult) onUpdate;

  /// Removes the entry; `true` means it landed.
  final Future<bool> Function() onDelete;

  @override
  State<TransactionEditorScreen> createState() =>
      _TransactionEditorScreenState();
}

class _TransactionEditorScreenState extends State<TransactionEditorScreen> {
  AppStrings get _strings => AppStrings(widget.language);

  /// Add Entry's own category set, in the same order, so the two screens agree.
  static const List<String> _standardCategories = <String>[
    'Shopping',
    'Food',
    'Travel',
    'Bills',
    'Gifts',
  ];

  static final RegExp _amountPattern = RegExp(r'^\d{1,9}(?:\.\d{1,2})?$');

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _description;

  late EntryFormKind _kind;
  late String _category;
  late DateTime _date;
  bool _showCategoryError = false;

  /// Non-null while a callback is in flight; also names which action is
  /// running, so both buttons can be disabled and the user can see why.
  AppString? _pendingLabel;

  /// Last honest failure message; cleared on the next attempt.
  AppString? _error;

  bool get _busy => _pendingLabel != null;

  @override
  void initState() {
    super.initState();
    final EntryFormResult initial = widget.initial;
    _kind = initial.kind;
    _category = initial.category;
    _amount = TextEditingController(text: _amountText(initial.amountPaise));
    _description = TextEditingController(text: initial.description);
    _date = DateTime(
      initial.occurredAt.year,
      initial.occurredAt.month,
      initial.occurredAt.day,
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  /// Exact paise as an editable decimal string: 120000 becomes `1200.00`.
  String _amountText(int paise) {
    final int rupees = paise ~/ 100;
    final int fraction = paise % 100;
    return '$rupees.${fraction.toString().padLeft(2, '0')}';
  }

  /// Rejects anything that is not rupees with at most two decimals, and zero.
  int? _parseAmountPaise(String input) {
    final String text = _amountDigits(input);
    if (!_amountPattern.hasMatch(text)) {
      return null;
    }
    final List<String> parts = text.split('.');
    final int rupees = int.parse(parts[0]);
    final int paise = parts.length == 1
        ? 0
        : int.parse(parts[1].padRight(2, '0'));
    final int amount = rupees * 100 + paise;
    return amount > 0 ? amount : null;
  }

  bool get _dateUnchanged {
    final DateTime original = widget.initial.occurredAt;
    return _date.year == original.year &&
        _date.month == original.month &&
        _date.day == original.day;
  }

  /// The original category is always offered, even when it is not one of Add
  /// Entry's five, so editing can never silently drop it.
  List<String> get _categoryChoices {
    final List<String> choices = <String>[];
    final String original = widget.initial.category;
    if (original.trim().isNotEmpty && !_standardCategories.contains(original)) {
      choices.add(original);
    }
    choices.addAll(_standardCategories);
    return choices;
  }

  String _amountDigits(String text) => widget.language == AppLanguage.bn
      ? text.replaceAllMapped(
          RegExp('[০-৯]'),
          (match) => '০১২৩৪৫৬৭৮৯'.indexOf(match[0]!).toString(),
        )
      : text;

  Future<void> _pickDate() async {
    if (_busy) {
      return;
    }
    final DateTime now = DateTime.now();
    final bool bengali = widget.language == AppLanguage.bn;
    final DateTime? chosen = await showDatePicker(
      context: context,
      helpText: bengali ? _DatePickerCopy.help.text(widget.language) : null,
      cancelText: bengali ? _strings.text(AppString.cancel) : null,
      confirmText: bengali
          ? _DatePickerCopy.confirm.text(widget.language)
          : null,
      fieldLabelText: bengali ? _strings.text(AppString.date) : null,
      errorFormatText: bengali
          ? _DatePickerCopy.invalidFormat.text(widget.language)
          : null,
      errorInvalidText: bengali
          ? _DatePickerCopy.outOfRange.text(widget.language)
          : null,
      barrierLabel: bengali ? _strings.text(AppString.cancel) : null,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 100, 12, 31),
    );
    if (chosen == null || !mounted) {
      return;
    }
    setState(() => _date = DateTime(chosen.year, chosen.month, chosen.day));
  }

  /// Runs a caller-owned callback and never lets its failure escape.
  Future<bool> _attempt(Future<bool> Function() action) async {
    try {
      return await action();
    } catch (_) {
      return false;
    }
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    final FormState? form = _formKey.currentState;
    final bool fieldsValid = form?.validate() ?? false;
    final bool categoryValid = _category.trim().isNotEmpty;
    setState(() => _showCategoryError = !categoryValid);
    if (!fieldsValid || !categoryValid) {
      return;
    }
    final int? amountPaise = _parseAmountPaise(_amount.text);
    if (amountPaise == null) {
      return;
    }

    final EntryFormResult edited = EntryFormResult(
      kind: _kind,
      amountPaise: amountPaise,
      category: _category,
      description: _description.text,
      occurredAt: _dateUnchanged ? widget.initial.occurredAt : _date,
    );

    setState(() {
      _error = null;
      _pendingLabel = AppString.updating;
    });
    final bool updated = await _attempt(() => widget.onUpdate(edited));
    if (!mounted) {
      return;
    }
    if (updated) {
      setState(() => _pendingLabel = null);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.of(context).pop(TransactionEditResult.updated);
      return;
    }
    setState(() {
      _pendingLabel = null;
      _error = AppString.editSaveFailed;
    });
  }

  Future<void> _delete() async {
    if (_busy) {
      return;
    }
    final bool confirmed = await _confirmDelete();
    if (!confirmed || !mounted) {
      return;
    }
    setState(() {
      _error = null;
      _pendingLabel = AppString.deleting;
    });
    final bool deleted = await _attempt(widget.onDelete);
    if (!mounted) {
      return;
    }
    if (deleted) {
      setState(() => _pendingLabel = null);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.of(context).pop(TransactionEditResult.deleted);
      return;
    }
    setState(() {
      _pendingLabel = null;
      _error = AppString.deleteFailed;
    });
  }

  /// Explicit confirmation; anything but "Delete" must not reach the caller.
  Future<bool> _confirmDelete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          key: const Key('delete-confirm-dialog'),
          title: Text(_strings.text(AppString.deleteQuestion)),
          content: Text(_strings.text(AppString.deleteExplanation)),
          actions: <Widget>[
            TextButton(
              key: const Key('cancel-delete-button'),
              style: TextButton.styleFrom(
                minimumSize: const Size(64, 48),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_strings.text(AppString.cancel)),
            ),
            FilledButton(
              key: const Key('confirm-delete-button'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.warmIvory,
                foregroundColor: AppColors.expenseRed,
                minimumSize: const Size(88, 48),
                side: const BorderSide(color: AppColors.expenseRed),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                _strings.text(AppString.delete),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  void _selectKind(EntryFormKind kind) {
    if (_busy) {
      return;
    }
    setState(() => _kind = kind);
  }

  void _selectCategory(String category) {
    if (_busy) {
      return;
    }
    setState(() {
      _category = category;
      _showCategoryError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final bool future = _date.isAfter(DateTime(now.year, now.month, now.day));

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        key: const Key('transaction-editor-screen'),
        backgroundColor: AppColors.creamBackground,
        appBar: AppBar(
          leading:
              widget.language == AppLanguage.bn &&
                  (ModalRoute.of(context)?.impliesAppBarDismissal ?? false)
              ? IconButton(
                  icon: const BackButtonIcon(),
                  tooltip: _strings.text(AppString.back),
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              : null,
          title: Text(
            _strings.text(AppString.editTransaction),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _kindSelector(),
                  const SizedBox(height: 20),
                  _SectionLabel(_strings.text(AppString.amount)),
                  const SizedBox(height: 6),
                  _amountField(),
                  const SizedBox(height: 16),
                  _SectionLabel(_strings.text(AppString.date)),
                  const SizedBox(height: 6),
                  _dateField(),
                  if (future) _inlineNote(_strings.text(AppString.futureDate)),
                  const SizedBox(height: 16),
                  _SectionLabel(_strings.text(AppString.category)),
                  const SizedBox(height: 10),
                  _categoryChips(),
                  if (_showCategoryError)
                    _inlineWarning(_strings.text(AppString.pickCategory)),
                  const SizedBox(height: 16),
                  _SectionLabel(_strings.text(AppString.description)),
                  const SizedBox(height: 6),
                  _descriptionField(),
                  const SizedBox(height: 20),
                  if (_pendingLabel != null)
                    _pendingCard(_strings.text(_pendingLabel!)),
                  if (_error != null) _errorCard(_strings.text(_error!)),
                  FilledButton.icon(
                    key: const Key('editor-update-button'),
                    onPressed: _busy ? null : _submit,
                    icon: const Icon(Icons.check),
                    label: Text(_strings.text(AppString.updateTransaction)),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const Key('editor-delete-button'),
                    onPressed: _busy ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      // Red text at this size would fall under AA on the cream
                      // canvas (theme.md), so the label stays darkText and the
                      // red is carried by the icon and the border.
                      foregroundColor: AppColors.darkText,
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: AppColors.expenseRed),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.expenseRed,
                    ),
                    label: Text(_strings.text(AppString.deleteTransaction)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Expense | Income as the two-segment pill used by Add Entry.
  Widget _kindSelector() {
    return Material(
      color: AppColors.lightGreen,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _kindSegment(
                EntryFormKind.expense,
                const Key('editor-kind-expense'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _kindSegment(
                EntryFormKind.income,
                const Key('editor-kind-income'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kindSegment(EntryFormKind kind, Key key) {
    final bool selected = _kind == kind;
    final bool income = kind == EntryFormKind.income;
    final String name = _strings.text(
      income ? AppString.income : AppString.expense,
    );
    final Color textColor = selected ? AppColors.onPrimary : AppColors.darkText;
    final Color iconColor = selected
        ? AppColors.onPrimary
        : (income ? AppColors.incomeGreen : AppColors.expenseRed);
    return Semantics(
      key: key,
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: name,
      excludeSemantics: true,
      onTap: () => _selectKind(kind),
      child: Material(
        color: selected ? AppColors.primaryGreen : AppColors.lightGreen,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _selectKind(kind),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    income ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 16,
                    color: iconColor,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Warm-ivory framed input row, matching Add Entry's fields.
  Widget _framed({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.warmIvory,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.beige, width: 1.4),
      ),
      child: child,
    );
  }

  Widget _amountField() {
    return _framed(
      child: Semantics(
        label: _strings.text(AppString.amount),
        child: TextFormField(
          key: const Key('editor-amount-field'),
          controller: _amount,
          enabled: !_busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
          ),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            prefixText: '₹ ',
            prefixStyle: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGreen,
            ),
            hintText: widget.language == AppLanguage.bn ? '০.০০' : '0.00',
            hintStyle: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: AppColors.softText,
            ),
            errorMaxLines: 4,
            errorStyle: const TextStyle(
              fontSize: 12,
              color: AppColors.expenseRed,
            ),
          ),
          validator: (String? value) {
            final String text = _amountDigits(value ?? '');
            if (!_amountPattern.hasMatch(text)) {
              return _strings.text(AppString.amountPrecision);
            }
            if (_parseAmountPaise(text) == null) {
              return _strings.text(AppString.positiveAmount);
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _dateField() {
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    final String label = widget.language == AppLanguage.bn
        ? _strings.day(_date)
        : localizations.formatMediumDate(_date);
    return InkWell(
      key: const Key('editor-date-field'),
      borderRadius: BorderRadius.circular(16),
      onTap: _pickDate,
      child: _framed(
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.calendar_today,
              size: 18,
              color: AppColors.primaryGreen,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.softText),
          ],
        ),
      ),
    );
  }

  Widget _categoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final String category in _categoryChoices) _categoryChip(category),
      ],
    );
  }

  Widget _categoryChip(String category) {
    final bool selected = _category == category;
    final Color background = selected
        ? AppColors.primaryGreen
        : AppColors.lightGreen;
    final Color foreground = selected
        ? AppColors.onPrimary
        : AppColors.primaryGreen;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: _strings.categoryLabel(_categoryLabel(_strings, category)),
      onTap: () => _selectCategory(category),
      child: ExcludeSemantics(
        child: Material(
          color: background,
          clipBehavior: Clip.antiAlias,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? AppColors.primaryGreen : AppColors.beige,
              width: 1.4,
            ),
          ),
          child: InkWell(
            key: Key('editor-category-$category'),
            onTap: () => _selectCategory(category),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
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
                        _categoryLabel(_strings, category),
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

  Widget _descriptionField() {
    return _framed(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.edit, size: 18, color: AppColors.softText),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              label: _strings.text(AppString.description),
              child: TextFormField(
                key: const Key('editor-description-field'),
                controller: _description,
                enabled: !_busy,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 15, color: AppColors.darkText),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: _strings.text(AppString.descriptionHint),
                  hintStyle: const TextStyle(
                    fontSize: 15,
                    color: AppColors.softText,
                  ),
                  helperText: _strings.text(AppString.descriptionOptional),
                  helperStyle: const TextStyle(
                    fontSize: 11,
                    color: AppColors.softText,
                  ),
                  errorMaxLines: 4,
                  errorStyle: const TextStyle(
                    fontSize: 12,
                    color: AppColors.expenseRed,
                  ),
                ),
                validator: (String? value) =>
                    (value ?? '').trim().runes.length > 120
                    ? _strings.text(AppString.descriptionTooLong)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingCard(String label) {
    return Semantics(
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: Container(
          key: const Key('editor-busy'),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.lightGreen,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.sync, size: 16, color: AppColors.primaryGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      key: const Key('editor-error'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warmIvory,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.expenseRed),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline, size: 18, color: AppColors.expenseRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineWarning(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: <Widget>[
          const Icon(Icons.info_outline, size: 16, color: AppColors.expenseRed),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineNote(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: <Widget>[
          const Icon(Icons.info_outline, size: 16, color: AppColors.softText),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.softText),
            ),
          ),
        ],
      ),
    );
  }
}

/// The small bold caption the design puts above every field.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: AppColors.darkText,
      ),
    );
  }
}

String _categoryLabel(AppStrings strings, String category) {
  final AppString? key = switch (category) {
    'Shopping' => AppString.shopping,
    'Food' => AppString.food,
    'Travel' => AppString.travel,
    'Bills' => AppString.bills,
    'Gifts' => AppString.gifts,
    'Income' => AppString.income,
    'Expense' => AppString.expense,
    _ => null,
  };
  return key == null ? category : strings.text(key);
}

enum _DatePickerCopy {
  help('Select date', 'তারিখ বেছে নিন'),
  confirm('OK', 'ঠিক আছে'),
  invalidFormat('Invalid format.', 'তারিখের বিন্যাস সঠিক নয়।'),
  outOfRange('Out of range.', 'তারিখটি অনুমোদিত সীমার বাইরে।');

  const _DatePickerCopy(this.en, this.bn);

  final String en;
  final String bn;

  String text(AppLanguage language) => language == AppLanguage.bn ? bn : en;
}

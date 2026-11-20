// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';

enum EntryFormKind { expense, income }

class EntryFormResult {
  const EntryFormResult({
    required this.kind,
    required this.amountPaise,
    required this.category,
    required this.description,
    required this.occurredAt,
  });

  final EntryFormKind kind;
  final int amountPaise;
  final String category;
  final String description;
  final DateTime occurredAt;
}

/// One choice in the expense category row: the stored ID, display label and icon.
class _CategoryOption {
  const _CategoryOption(this.id, this.label, this.icon);

  final String id;
  final AppString label;
  final IconData icon;
}

/// The small bold caption the design puts above every framed field
/// (`Amount`, `Date`, `Category`, `Description`).
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

/// Collects an entry without owning navigation or persistence.
///
/// S2 in docs/spec/screens.md, styled after the "Add Expense" phone in
/// docs/design/ui-preview.png: cream canvas, green header and action, framed
/// amount/date/description rows, icon category chips and the notebook
/// illustration under the form.
class AddEntryScreen extends StatefulWidget {
  const AddEntryScreen({
    super.key,
    this.language = AppLanguage.en,
    required this.openingBalancePaise,
    required this.onSave,
  });

  final AppLanguage language;

  final int openingBalancePaise;
  final ValueChanged<EntryFormResult> onSave;

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  AppStrings get _strings => AppStrings(widget.language);

  static const List<_CategoryOption> _categories = <_CategoryOption>[
    _CategoryOption('Shopping', AppString.shopping, Icons.shopping_cart),
    _CategoryOption('Food', AppString.food, Icons.restaurant),
    _CategoryOption('Travel', AppString.travel, Icons.directions_car),
    _CategoryOption('Bills', AppString.bills, Icons.home),
    _CategoryOption('Gifts', AppString.gifts, Icons.card_giftcard),
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _description = TextEditingController();
  EntryFormKind _kind = EntryFormKind.expense;
  String? _category;
  bool _showCategoryError = false;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  int? _parseAmount(String input) {
    final String text = _amountDigits(input);
    if (!RegExp(r'^\d{1,9}(?:\.\d{1,2})?$').hasMatch(text)) {
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

  String _amountDigits(String text) => widget.language == AppLanguage.bn
      ? text.replaceAllMapped(
          RegExp('[০-৯]'),
          (match) => '০১২৩৪৫৬৭৮৯'.indexOf(match[0]!).toString(),
        )
      : text;

  Future<void> _pickDate() async {
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
      lastDate: DateTime(DateTime.now().year + 100, 12, 31),
    );
    if (chosen != null && mounted) {
      setState(() => _date = DateTime(chosen.year, chosen.month, chosen.day));
    }
  }

  void _save() {
    final bool validFields = _formKey.currentState!.validate();
    final bool validCategory =
        _kind == EntryFormKind.income || _category != null;
    setState(() => _showCategoryError = !validCategory);
    if (!validFields || !validCategory) return;
    widget.onSave(
      EntryFormResult(
        kind: _kind,
        amountPaise: _parseAmount(_amount.text)!,
        category: _kind == EntryFormKind.income ? 'Income' : _category!,
        description: _description.text,
        occurredAt: _date,
      ),
    );
  }

  void _selectKind(EntryFormKind kind) {
    setState(() {
      _kind = kind;
      _showCategoryError = false;
    });
  }

  void _selectCategory(String category) {
    setState(() {
      _category = category;
      _showCategoryError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final int? amount = _parseAmount(_amount.text);
    final int? afterSave = amount == null
        ? null
        : widget.openingBalancePaise +
              (_kind == EntryFormKind.income ? amount : -amount);
    final DateTime now = DateTime.now();
    final bool future = _date.isAfter(DateTime(now.year, now.month, now.day));

    return Scaffold(
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
          _strings.text(AppString.addEntry),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _save,
            tooltip: _strings.text(AppString.save),
            icon: const Icon(Icons.save),
          ),
          const SizedBox(width: 8),
        ],
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
                if (future) _inlineWarning(_strings.text(AppString.futureDate)),
                const SizedBox(height: 16),
                _SectionLabel(_strings.text(AppString.category)),
                const SizedBox(height: 10),
                if (_kind == EntryFormKind.expense) ...<Widget>[
                  _categoryChips(),
                  if (_showCategoryError)
                    _inlineWarning(_strings.text(AppString.pickCategory)),
                ] else
                  _incomeCategoryPill(),
                const SizedBox(height: 16),
                _SectionLabel(_strings.text(AppString.description)),
                const SizedBox(height: 6),
                _descriptionField(),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: Text(_strings.text(AppString.saveEntry)),
                ),
                const SizedBox(height: 12),
                _afterSavePreview(afterSave),
                const SizedBox(height: 8),
                _illustration(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Expense | Income as the two-segment pill under the header.
  Widget _kindSelector() {
    return Material(
      color: AppColors.lightGreen,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          children: <Widget>[
            Expanded(child: _kindSegment(EntryFormKind.expense)),
            const SizedBox(width: 6),
            Expanded(child: _kindSegment(EntryFormKind.income)),
          ],
        ),
      ),
    );
  }

  Widget _kindSegment(EntryFormKind kind) {
    final bool selected = _kind == kind;
    final bool income = kind == EntryFormKind.income;
    final Color background = selected
        ? AppColors.primaryGreen
        : AppColors.lightGreen;
    final Color foreground = selected
        ? AppColors.onPrimary
        : (income ? AppColors.incomeGreen : AppColors.expenseRed);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: _strings.text(income ? AppString.income : AppString.expense),
      excludeSemantics: true,
      onTap: () => _selectKind(kind),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _selectKind(kind),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  income ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 16,
                  color: foreground,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _strings.text(
                      income ? AppString.income : AppString.expense,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
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
    );
  }

  /// The cream input card used for amount, date and description: warm ivory
  /// fill, beige frame, rounded corners.
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
      // The caption above the frame is its own Text, so the field carries its
      // own accessible name rather than being an unlabeled text field.
      child: Semantics(
        label: _strings.text(AppString.amount),
        child: TextFormField(
          key: const Key('amount-field'),
          controller: _amount,
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
              color: AppColors.navigationGrey,
            ),
            errorMaxLines: 4,
            errorStyle: const TextStyle(
              fontSize: 12,
              color: AppColors.expenseRed,
            ),
          ),
          onChanged: (_) => setState(() {}),
          validator: (String? value) => _parseAmount(value ?? '') == null
              ? _strings.text(AppString.validAmount)
              : null,
        ),
      ),
    );
  }

  Widget _dateField() {
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    return InkWell(
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
                widget.language == AppLanguage.bn
                    ? _strings.day(_date)
                    : localizations.formatMediumDate(_date),
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
      spacing: 10,
      runSpacing: 12,
      children: _categories.map(_categoryTile).toList(),
    );
  }

  Widget _categoryTile(_CategoryOption option) {
    final bool selected = _category == option.id;
    final Color accent = _categoryAccent(option.id);
    final bool warmAccent =
        accent == AppColors.orange || accent == AppColors.golden;
    final Color selectedIconColor = warmAccent
        ? AppColors.darkText
        : AppColors.onPrimary;
    // One semantic control announces both category and selected state.
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: _strings.text(option.label),
      excludeSemantics: true,
      onTap: () => _selectCategory(option.id),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _selectCategory(option.id),
        child: SizedBox(
          width: 62,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: selected ? accent : accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: selected ? accent : AppColors.outline,
                    width: selected ? 1.5 : 1,
                  ),
                  boxShadow: selected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: accent.withValues(alpha: 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  option.icon,
                  size: 22,
                  color: selected ? selectedIconColor : accent,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _strings.text(option.label),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppColors.primaryGreen
                        : AppColors.softText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _categoryAccent(String category) {
    switch (category) {
      case 'Food':
        return AppColors.orange;
      case 'Travel':
        return AppColors.secondaryGreen;
      case 'Bills':
        return AppColors.golden;
      case 'Gifts':
        return AppColors.expenseRed;
      default:
        return AppColors.primaryGreen;
    }
  }

  Widget _incomeCategoryPill() {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.lightGreen,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _strings.text(AppString.categoryIncome),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryGreen,
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
            // Same reason as the amount field: the caption is a separate Text,
            // so the field itself carries the accessible name.
            child: Semantics(
              label: _strings.text(AppString.description),
              child: TextFormField(
                key: const Key('description-field'),
                controller: _description,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 15, color: AppColors.darkText),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: _strings.text(AppString.descriptionHint),
                  hintStyle: const TextStyle(
                    fontSize: 15,
                    color: AppColors.navigationGrey,
                  ),
                  helperText: _strings.text(AppString.descriptionLimit),
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
                    (value ?? '').characters.length > 120
                    ? _strings.text(AppString.descriptionTooLong)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Small red note under a field, used for the future-date flag and the
  /// missing-category error.
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
              style: const TextStyle(color: AppColors.expenseRed),
            ),
          ),
        ],
      ),
    );
  }

  Widget _afterSavePreview(int? afterSave) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 18,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _strings.afterSave(afterSave),
              maxLines: 2,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _illustration() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _strings.text(AppString.everyExpenseCounts),
                    style: const TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _strings.text(AppString.oneEntryAtATime),
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      color: AppColors.softText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 132,
              height: 98,
              child: Image.asset(
                'assets/illustrations/entry_notebook.png',
                fit: BoxFit.cover,
                semanticLabel: _strings.text(AppString.notebookIllustration),
                errorBuilder: _illustrationError,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The picture is decorative: when the asset is missing (an unregistered
  /// bundle, a stripped build) the screen shows a drawn notebook instead of
  /// the framework's red error box.
  Widget _illustrationError(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.warmIvory,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.beige),
        ),
        child: const Icon(
          Icons.menu_book,
          size: 56,
          color: AppColors.primaryGreen,
        ),
      ),
    );
  }
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

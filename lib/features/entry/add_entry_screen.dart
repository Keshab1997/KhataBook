// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import 'category_picker.dart';
import 'category_store.dart';

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

/// One choice in the expense category row: the stored ID and display label.
class _CategoryOption {
  const _CategoryOption(this.id, this.label);

  final String id;
  final AppString label;
}

/// The small bold caption the design puts above every framed field
/// (`Amount`, `Date`, `Category`, `Description`).
///
/// It sits a step quieter than the value it names: the field below is the
/// thing to read, the caption is the label for it.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.icon);

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: AppColors.primaryGreen, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.headerGreen,
            ),
          ),
        ),
      ],
    );
  }
}

/// Collects an entry without owning navigation or persistence.
///
/// S2 in docs/spec/screens.md, styled after the "Add Expense" phone in
/// docs/design/ui-preview.png: cream canvas, green header and action, framed
/// amount/date/description rows, AI-illustrated category chips and a save action at the end of the form.
class AddEntryScreen extends StatefulWidget {
  const AddEntryScreen({
    super.key,
    this.language = AppLanguage.en,
    this.categoryStore,
    this.initialAmountPaise,
    this.initialKind,
    this.initialDescription,
    required this.openingBalancePaise,
    required this.onSave,
  });

  final AppLanguage language;

  final CategoryStore? categoryStore;
  final int? initialAmountPaise;
  final EntryFormKind? initialKind;
  final String? initialDescription;
  final int openingBalancePaise;
  final ValueChanged<EntryFormResult> onSave;

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  AppStrings get _strings => AppStrings(widget.language);

  // Keep the whole form visible on ordinary-height phones. Large accessibility
  // text and the keyboard retain the naturally scrollable layout.
  bool get _compact =>
      (MediaQuery.sizeOf(context).height -
              MediaQuery.viewPaddingOf(context).vertical) <
          800 &&
      MediaQuery.textScalerOf(context).scale(1) <= 1.2;

  static const List<_CategoryOption> _categories = <_CategoryOption>[
    _CategoryOption('Shopping', AppString.shopping),
    _CategoryOption('Food', AppString.food),
    _CategoryOption('Travel', AppString.travel),
    _CategoryOption('Bills', AppString.bills),
    _CategoryOption('Gifts', AppString.gifts),
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _description = TextEditingController();

  /// Focus is owned here rather than left to the fields, because the frame
  /// that turns green is the *card around* the field, not the field itself.
  final FocusNode _amountFocus = FocusNode();
  final FocusNode _descriptionFocus = FocusNode();
  EntryFormKind _kind = EntryFormKind.expense;
  String? _category;
  bool _showCategoryError = false;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final amount = widget.initialAmountPaise;
    if (amount != null && amount > 0) {
      _amount.text =
          '${amount ~/ 100}.${(amount % 100).toString().padLeft(2, '0')}';
    }
    _kind = widget.initialKind ?? EntryFormKind.expense;
    _description.text = widget.initialDescription ?? '';
    final DateTime now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _amountFocus.addListener(_handleFocusChange);
    _descriptionFocus.addListener(_handleFocusChange);
  }

  /// Repaints the frame of whichever field gained or lost focus.
  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountFocus.dispose();
    _descriptionFocus.dispose();
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
    HapticFeedback.mediumImpact();
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
    HapticFeedback.lightImpact();
    setState(() {
      _kind = kind;
      _showCategoryError = false;
    });
  }

  void _selectCategory(String category) {
    HapticFeedback.lightImpact();
    setState(() {
      _category = category;
      _showCategoryError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final bool future = _date.isAfter(DateTime(now.year, now.month, now.day));

    return Hero(tag: 'add-entry-fab', child: Scaffold(
      backgroundColor: AppColors.creamBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        toolbarHeight: _compact ? 56 : 76,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_compact ? 8 : 14),
          child: SizedBox(height: _compact ? 8 : 14),
        ),
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const CustomPaint(painter: _EntryHeaderPainter()),
            Positioned(
              right: 0,
              bottom: 0,
              child: Image.asset(
                'assets/illustrations/entry_header_leaves.png',
                height: 48,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: _strings.text(AppString.back),
          onPressed: () => Navigator.of(context).maybePop(),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: AppColors.onPrimary,
          ),
        ),
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/illustrations/entry_header_notebook.png',
                width: 42,
                height: 42,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _strings.text(AppString.addEntry),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    widget.language == AppLanguage.bn
                        ? 'হিসাব রাখুন নিয়মিত'
                        : 'Keep Your Account Updated',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _save,
            tooltip: _strings.text(AppString.save),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.onPrimary,
            ),
            icon: const Icon(Icons.save),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Image.asset(
                'assets/illustrations/entry_footer_leaves.png',
                fit: BoxFit.fitWidth,
                excludeFromSemantics: true,
              ),
            ),
          ),
          SafeArea(
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  _compact ? 4 : 12,
                  20,
                  _compact ? 1 : 28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _kindSelector(),
                    SizedBox(height: _compact ? 4 : 14),
                    _SectionLabel(
                      _strings.text(AppString.amount),
                      Icons.account_balance_wallet,
                    ),
                    SizedBox(height: _compact ? 3 : 8),
                    _amountField(),
                    SizedBox(height: _compact ? 4 : 12),
                    _SectionLabel(_strings.text(AppString.date), Icons.event),
                    SizedBox(height: _compact ? 3 : 8),
                    _dateField(),
                    if (future)
                      _inlineWarning(_strings.text(AppString.futureDate)),
                    SizedBox(height: _compact ? 4 : 12),
                    _SectionLabel(
                      _strings.text(AppString.category),
                      Icons.sell,
                    ),
                    SizedBox(height: _compact ? 4 : 12),
                    if (_kind == EntryFormKind.expense) ...<Widget>[
                      _categoryChips(),
                      if (_showCategoryError)
                        _inlineWarning(_strings.text(AppString.pickCategory)),
                    ] else
                      _incomeCategoryPill(),
                    SizedBox(height: _compact ? 4 : 12),
                    _SectionLabel(
                      _strings.text(AppString.description),
                      Icons.edit_note,
                    ),
                    SizedBox(height: _compact ? 3 : 8),
                    _descriptionField(),
                    SizedBox(height: _compact ? 6 : 16),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: AppColors.onPrimary,
                          width: 3,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.golden.withValues(alpha: 0.4),
                            blurRadius: 9,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: FilledButton.icon(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          shape: const StadiumBorder(),
                          minimumSize: Size.fromHeight(_compact ? 48 : 58),
                          backgroundColor: AppColors.primaryGreen,
                        ),
                        icon: const Icon(Icons.save),
                        label: Text(_strings.text(AppString.saveEntry)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  /// Expense | Income as the two-segment pill under the header.
  Widget _kindSelector() {
    return Material(
      color: AppColors.lightGreen,
      borderRadius: BorderRadius.circular(32),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(_compact ? 2 : 5),
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
        : AppColors.warmIvory;
    // Unselected keeps the label in body ink and lets the arrow carry the
    // income/expense colour; selected inverts the pair. That is the same
    // treatment the editor uses, so the two forms read as one screen family.
    final Color textColor = selected ? AppColors.onPrimary : AppColors.darkText;
    final Color iconColor = selected
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
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(32)),
          side: BorderSide(
            color: selected ? AppColors.primaryGreen : AppColors.beige,
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _selectKind(kind),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: _compact ? 9 : 11,
            ),
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
                    _strings.text(
                      income ? AppString.income : AppString.expense,
                    ),
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
    );
  }

  /// The ivory input card used for amount, date and description: warm ivory
  /// fill, beige frame, rounded corners.
  ///
  /// The card holding focus turns green and lifts very slightly, so the row
  /// being edited is obvious without moving any of the other rows.
  Widget _framed({required Widget child, bool focused = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      constraints: const BoxConstraints(minHeight: 44),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: _compact ? 4 : 14,
      ),
      decoration: BoxDecoration(
        color: focused ? AppColors.lightGreen : AppColors.warmIvory,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: focused
              ? AppColors.primaryGreen
              : AppColors.accentGreen.withValues(alpha: 0.5),
          width: focused ? 1.6 : 1.4,
        ),
        boxShadow: focused
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.primaryGreen.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  Widget _amountField() {
    return _framed(
      focused: _amountFocus.hasFocus,
      // The caption above the frame is its own Text, so the field carries its
      // own accessible name rather than being an unlabeled text field.
      child: Semantics(
        label: _strings.text(AppString.amount),
        child: TextFormField(
          key: const Key('amount-field'),
          controller: _amount,
          focusNode: _amountFocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AppColors.darkText,
          ),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
            prefixIcon: Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: const BoxDecoration(
                color: AppColors.lightGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.currency_rupee,
                color: AppColors.primaryGreen,
                size: 26,
              ),
            ),
            hintText: widget.language == AppLanguage.bn ? '০.০০' : '0.00',
            hintStyle: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.4,
              color: AppColors.headerGreen,
            ),
            suffixIcon: IconButton(
              tooltip: _strings.text(AppString.amount),
              onPressed: () => _amountFocus.requestFocus(),
              icon: const Icon(
                Icons.grid_view_rounded,
                color: AppColors.primaryGreen,
              ),
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
    final String mediumDate = localizations.formatMediumDate(_date);
    final String englishDate = mediumDate.contains('${_date.year}')
        ? mediumDate
        : '$mediumDate, ${_date.year}';
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
                    : englishDate,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final double tileWidth = (constraints.maxWidth - 36) / 4;
        return Wrap(
          spacing: 12,
          runSpacing: _compact ? 5 : 12,
          children: <Widget>[
            ..._categories.map((option) => _categoryTile(option, tileWidth)),
            if (widget.categoryStore != null)
              CustomCategoryChoices(
                store: widget.categoryStore!,
                language: widget.language,
                selected: _category,
                onSelected: _selectCategory,
              ),
          ],
        );
      },
    );
  }

  Widget _categoryTile(_CategoryOption option, double width) {
    final bool selected = _category == option.id;
    final Color accent = _categoryAccent(option.id);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: _strings.text(option.label),
      excludeSemantics: true,
      onTap: () => _selectCategory(option.id),
      child: Material(
        color: selected ? AppColors.lightGreen : AppColors.warmIvory,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _selectCategory(option.id),
          child: Container(
            width: width,
            padding: EdgeInsets.symmetric(
              vertical: _compact ? 4 : 8,
              horizontal: 4,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? accent : AppColors.beige,
                width: selected ? 1.8 : 1.1,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.headerGreen.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/illustrations/entry_category_${option.id.toLowerCase()}.png',
                    key: Key('category-artwork-${option.id}'),
                    width: _compact ? 28 : 48,
                    height: _compact ? 28 : 48,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                ),
                SizedBox(height: _compact ? 2 : 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _strings.text(option.label),
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.headerGreen,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.lightGreen,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accentGreen),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.south_west_rounded,
              size: 16,
              color: AppColors.incomeGreen,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _strings.text(AppString.categoryIncome),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _descriptionField() {
    return _framed(
      focused: _descriptionFocus.hasFocus,
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
                focusNode: _descriptionFocus,
                onChanged: (_) => setState(() {}),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 15, color: AppColors.darkText),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  hintText: _strings.text(AppString.descriptionHint),
                  hintStyle: const TextStyle(
                    fontSize: 15,
                    color: AppColors.navigationGrey,
                  ),
                  helperText: _strings.text(AppString.descriptionLimit),
                  counterText: '${_description.text.characters.length} / 120',
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
}

/// Decorative curved header; all controls remain live AppBar widgets.
class _EntryHeaderPainter extends CustomPainter {
  const _EntryHeaderPainter();

  Path _wave(Size size, double bottom) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height - bottom + 8)
    ..cubicTo(
      size.width * .78,
      size.height - bottom - 24,
      size.width * .35,
      size.height - bottom + 20,
      0,
      size.height - bottom - 10,
    )
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_wave(size, 0), Paint()..color = AppColors.golden);
    canvas.drawPath(
      _wave(size, 4),
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[AppColors.primaryGreen, AppColors.headerGreen],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

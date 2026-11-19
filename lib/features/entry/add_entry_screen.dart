// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/format/money.dart';
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

/// One choice in the expense category row: the tile label and its icon.
class _CategoryOption {
  const _CategoryOption(this.name, this.icon);

  final String name;
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
    required this.openingBalancePaise,
    required this.onSave,
  });

  final int openingBalancePaise;
  final ValueChanged<EntryFormResult> onSave;

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  static const List<_CategoryOption> _categories = <_CategoryOption>[
    _CategoryOption('Shopping', Icons.shopping_cart),
    _CategoryOption('Food', Icons.restaurant),
    _CategoryOption('Travel', Icons.directions_car),
    _CategoryOption('Bills', Icons.home),
    _CategoryOption('Gifts', Icons.card_giftcard),
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

  int? _parseAmount(String text) {
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

  Future<void> _pickDate() async {
    final DateTime? chosen = await showDatePicker(
      context: context,
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
        title: const Text(
          'Add Entry',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _save,
            tooltip: 'Save',
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
                const _SectionLabel('Amount'),
                const SizedBox(height: 6),
                _amountField(),
                const SizedBox(height: 16),
                const _SectionLabel('Date'),
                const SizedBox(height: 6),
                _dateField(),
                if (future) _inlineWarning('This date is in the future.'),
                const SizedBox(height: 16),
                const _SectionLabel('Category'),
                const SizedBox(height: 10),
                if (_kind == EntryFormKind.expense) ...<Widget>[
                  _categoryChips(),
                  if (_showCategoryError) _inlineWarning('Pick a category'),
                ] else
                  _incomeCategoryPill(),
                const SizedBox(height: 16),
                const _SectionLabel('Description'),
                const SizedBox(height: 6),
                _descriptionField(),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Entry'),
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
      label: income ? 'Income' : 'Expense',
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
                    income ? 'Income' : 'Expense',
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
        label: 'Amount',
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
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            prefixText: '₹ ',
            prefixStyle: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGreen,
            ),
            hintText: '0.00',
            hintStyle: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: AppColors.navigationGrey,
            ),
            errorStyle: TextStyle(fontSize: 12, color: AppColors.expenseRed),
          ),
          onChanged: (_) => setState(() {}),
          validator: (String? value) =>
              _parseAmount(value ?? '') == null ? 'Enter a valid amount' : null,
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
                localizations.formatMediumDate(_date),
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
    final bool selected = _category == option.name;
    final Color tileColor = selected
        ? AppColors.primaryGreen
        : AppColors.lightGreen;
    // The tile is one control: an explicit container node carries its name and
    // its selected state, so a screen reader announces "Food, selected"
    // instead of "Food" with the state lost on a child node.
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: option.name,
      excludeSemantics: true,
      onTap: () => _selectCategory(option.name),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _selectCategory(option.name),
        child: SizedBox(
          width: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? AppColors.primaryGreen : AppColors.beige,
                    width: 1.4,
                  ),
                ),
                child: Icon(
                  option.icon,
                  size: 22,
                  color: selected
                      ? AppColors.onPrimary
                      : AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 6),
              // Scaling the label down keeps a long category name inside its
              // tile even at 200% text scale.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  option.name,
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

  Widget _incomeCategoryPill() {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.lightGreen,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Category: Income',
          style: TextStyle(
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
              label: 'Description',
              child: TextFormField(
                key: const Key('description-field'),
                controller: _description,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 15, color: AppColors.darkText),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'What was it for?',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: AppColors.navigationGrey,
                  ),
                  helperText: 'Up to 120 characters',
                  helperStyle: TextStyle(
                    fontSize: 11,
                    color: AppColors.softText,
                  ),
                  errorStyle: TextStyle(
                    fontSize: 12,
                    color: AppColors.expenseRed,
                  ),
                ),
                validator: (String? value) =>
                    (value ?? '').characters.length > 120
                    ? 'Description must be 120 characters or fewer'
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
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.lightGreen,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          afterSave == null
              ? 'After saving: —'
              : 'After saving: ${formatPaise(afterSave)}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryGreen,
          ),
        ),
      ),
    );
  }

  Widget _illustration() {
    return Column(
      children: <Widget>[
        SizedBox(
          height: 168,
          width: double.infinity,
          child: Image.asset(
            'assets/illustrations/entry_notebook.png',
            fit: BoxFit.contain,
            semanticLabel: 'Open ledger notebook and pen',
            errorBuilder: _illustrationError,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Every expense counts…',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: AppColors.softText,
          ),
        ),
      ],
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

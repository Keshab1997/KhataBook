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

/// Collects an entry without owning navigation or persistence.
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
  static const List<String> _categories = <String>[
    'Shopping',
    'Food',
    'Travel',
    'Bills',
    'Gifts',
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
      appBar: AppBar(title: const Text('Add Entry')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SegmentedButton<EntryFormKind>(
                  segments: const <ButtonSegment<EntryFormKind>>[
                    ButtonSegment<EntryFormKind>(
                      value: EntryFormKind.expense,
                      label: Text('Expense'),
                      icon: Icon(Icons.arrow_upward),
                    ),
                    ButtonSegment<EntryFormKind>(
                      value: EntryFormKind.income,
                      label: Text('Income'),
                      icon: Icon(Icons.arrow_downward),
                    ),
                  ],
                  selected: <EntryFormKind>{_kind},
                  onSelectionChanged: (Set<EntryFormKind> selection) {
                    setState(() {
                      _kind = selection.single;
                      _showCategoryError = false;
                    });
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                    hintText: '0.00',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (String? value) =>
                      _parseAmount(value ?? '') == null
                      ? 'Enter a valid amount'
                      : null,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    'Date: ${MaterialLocalizations.of(context).formatMediumDate(_date)}',
                  ),
                ),
                if (future)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'This date is in the future.',
                      style: TextStyle(color: AppColors.expenseRed),
                    ),
                  ),
                const SizedBox(height: 16),
                if (_kind == EntryFormKind.expense) ...<Widget>[
                  const Text('Category'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _categories.map((String category) {
                      return ChoiceChip(
                        label: Text(category),
                        selected: _category == category,
                        onSelected: (_) => setState(() {
                          _category = category;
                          _showCategoryError = false;
                        }),
                      );
                    }).toList(),
                  ),
                  if (_showCategoryError)
                    const Text(
                      'Pick a category',
                      style: TextStyle(color: AppColors.expenseRed),
                    ),
                  const SizedBox(height: 16),
                ] else ...<Widget>[
                  const Text('Category: Income'),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _description,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                    helperText: 'Up to 120 characters',
                  ),
                  validator: (String? value) =>
                      (value ?? '').characters.length > 120
                      ? 'Description must be 120 characters or fewer'
                      : null,
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: _save, child: const Text('Save Entry')),
                const SizedBox(height: 12),
                Text(
                  'After saving: ${afterSave == null ? '—' : formatPaise(afterSave)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../profile/settings_screen.dart';

/// S4 - Note Counter. See docs/spec/screens.md#s4--note-counter.
///
/// Counts physical notes by denomination: pick a denomination, enter how
/// many you hold, read the per-denomination total and the grand total. All
/// arithmetic is integer paise with [formatPaise] - no doubles anywhere.
///
/// Scope, stated plainly: this is an in-memory session. Nothing is persisted,
/// nothing leaves the screen, and no ledger transaction is created. Switching
/// khata does not affect it because it does not read a khata at all. The
/// "Add to khata as income" action in the spec is *not* implemented - it is
/// still marked NEEDS CONFIRMATION there, since it would double-count cash
/// already inside the opening balance.
///
/// ₹2,000 notes are hidden until the toggle is switched on. Turning the
/// toggle off never discards counted notes: the quantity stays in the grand
/// total and the total card says so.
class NoteCounterScreen extends StatefulWidget {
  const NoteCounterScreen({super.key});

  @override
  State<NoteCounterScreen> createState() => _NoteCounterScreenState();
}

/// Largest quantity a single denomination accepts (docs/spec/data-model.md).
const int kMaxNoteQuantity = 99999;

/// Denominations always offered, in paise, smallest first.
const List<int> kStandardDenominationsPaise = <int>[
  1000, // ₹10
  2000, // ₹20
  5000, // ₹50
  10000, // ₹100
  20000, // ₹200
  50000, // ₹500
];

/// The optional denomination, hidden until the user opts in (D3/Q3).
const int kOptionalDenominationPaise = 200000; // ₹2,000

/// Shorthand used by the rupee labels, e.g. `₹2,000` for 200000 paise.
String _rupeeLabel(int paise) => formatPaise(paise);

class _NoteCounterScreenState extends State<NoteCounterScreen> {
  /// Quantity per denomination in paise. Every denomination is present, so a
  /// switch away and back always finds the previous count.
  final Map<int, int> _quantities = <int, int>{
    for (final int denomination in <int>[
      ...kStandardDenominationsPaise,
      kOptionalDenominationPaise,
    ])
      denomination: 0,
  };

  final TextEditingController _quantityController = TextEditingController(
    text: '0',
  );

  int _selectedDenominationPaise = 50000; // ₹500, as in the mockup.
  bool _showTwoThousand = false;

  /// Set when the last typed value was rejected (negative or decimal). The
  /// field is not rewritten, so the user sees exactly what they typed plus an
  /// explicit error instead of a silently corrected number.
  String? _inputError;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  /// Denominations currently offered, largest first for the chip row.
  List<int> get _visibleDenominationsPaise => <int>[
    if (_showTwoThousand) kOptionalDenominationPaise,
    ...kStandardDenominationsPaise.reversed,
  ];

  int get _selectedQuantity => _quantities[_selectedDenominationPaise] ?? 0;

  int get _selectedTotalPaise => _selectedDenominationPaise * _selectedQuantity;

  int get _grandTotalPaise => _quantities.entries.fold<int>(
    0,
    (int sum, MapEntry<int, int> entry) => sum + entry.key * entry.value,
  );

  /// Quantity counted for a denomination that is currently hidden.
  int get _hiddenQuantity =>
      _showTwoThousand ? 0 : (_quantities[kOptionalDenominationPaise] ?? 0);

  void _selectDenomination(int denominationPaise) {
    setState(() {
      _selectedDenominationPaise = denominationPaise;
      _inputError = null;
    });
    _syncFieldToSelection();
  }

  void _setQuantity(int denominationPaise, int requested) {
    final int clamped = requested.clamp(0, kMaxNoteQuantity);
    setState(() {
      _quantities[denominationPaise] = clamped;
      _inputError = null;
    });
    if (denominationPaise == _selectedDenominationPaise) {
      _writeField(clamped.toString());
    }
  }

  void _increment() {
    _setQuantity(_selectedDenominationPaise, _selectedQuantity + 1);
  }

  void _decrement() {
    if (_selectedQuantity == 0) {
      return;
    }
    _setQuantity(_selectedDenominationPaise, _selectedQuantity - 1);
  }

  /// Validates the text field.
  ///
  /// Empty means "nothing counted yet" (zero), which is not an error. Anything
  /// that is not a non-negative whole number - `-5`, `1.5`, `abc`, `0x10` - is
  /// **rejected**: the quantity is not changed and [_inputError] explains why.
  /// Silently turning `-5` or `1.5` into some other positive count would be a
  /// lie about what the user entered.
  ///
  /// A correctly typed value above [kMaxNoteQuantity] is clamped, because the
  /// limit is a documented ceiling rather than a typo.
  void _onQuantityChanged(String raw) {
    // Only a genuinely empty field means "nothing counted". Whitespace is
    // *not* emptiness: `' '` is something the user typed, so it is rejected
    // like any other invalid entry rather than silently resetting the count.
    if (raw.isEmpty) {
      setState(() {
        _quantities[_selectedDenominationPaise] = 0;
        _inputError = null;
      });
      return;
    }

    // Validate the raw string - no trimming - so surrounding or internal
    // spaces (`' 5'`, `'5 0'`) are rejected instead of being quietly accepted
    // as a different number.
    final bool isWholeNumber = RegExp(r'^[0-9]+$').hasMatch(raw);
    final String? error = isWholeNumber
        ? null
        : raw.trimLeft().startsWith('-')
        ? 'Quantity cannot be negative'
        : 'Enter a whole number of notes';
    if (!isWholeNumber) {
      setState(() => _inputError = error);
      return;
    }

    final int? parsed = int.tryParse(raw);
    if (parsed == null) {
      // A digit string longer than the platform int can hold (e.g. 30 nines)
      // parses to null. Pin the count to the documented maximum *and rewrite
      // the field*, so the visible number and the counted number agree; the
      // old `?? kMaxNoteQuantity` fallback left the field showing the huge
      // string while the count sat at the maximum.
      setState(() {
        _quantities[_selectedDenominationPaise] = kMaxNoteQuantity;
        _inputError = null;
      });
      _writeField(kMaxNoteQuantity.toString());
      return;
    }

    final int clamped = parsed.clamp(0, kMaxNoteQuantity);
    setState(() {
      _quantities[_selectedDenominationPaise] = clamped;
      _inputError = null;
    });
    if (clamped != parsed) {
      _writeField(clamped.toString());
    }
  }

  /// Direct-input values longer than five digits would otherwise keep growing;
  /// normalizing on demand keeps the visible field and the state identical.
  void _commitTypedQuantity() {
    FocusScope.of(context).unfocus();
    if (_inputError != null) {
      // "Calculate" with a bad value returns the field to the last valid count
      // rather than computing a total from a number the user did not enter.
      setState(() => _inputError = null);
    }
    _writeField(_selectedQuantity.toString());
  }

  void _toggleTwoThousand(bool value) {
    setState(() {
      _showTwoThousand = value;
      if (!value && _selectedDenominationPaise == kOptionalDenominationPaise) {
        // Never leave the selection on a hidden chip. The counted quantity is
        // kept (see _hiddenQuantity) - only the selection moves.
        _selectedDenominationPaise = 50000;
      }
    });
    _syncFieldToSelection();
  }

  void _newCount() {
    setState(() {
      for (final int denomination in _quantities.keys.toList()) {
        _quantities[denomination] = 0;
      }
      _inputError = null;
    });
    _syncFieldToSelection();
  }

  void _syncFieldToSelection() {
    _writeField(_selectedQuantity.toString());
  }

  /// Writes text without firing `onChanged` (setting `controller.text` does
  /// not call the field's callback) and keeps the caret at the end.
  void _writeField(String text) {
    _quantityController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.payments_outlined, color: AppColors.golden, size: 22),
              SizedBox(width: 10),
              Text('Note Counter'),
            ],
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _NoteBundle(denominationPaise: _selectedDenominationPaise),
            const SizedBox(height: 12),
            _DenominationPicker(
              denominationsPaise: _visibleDenominationsPaise,
              selectedPaise: _selectedDenominationPaise,
              onSelected: _selectDenomination,
            ),
            const SizedBox(height: 10),
            _TwoThousandToggle(
              value: _showTwoThousand,
              onChanged: _toggleTwoThousand,
            ),
            const SizedBox(height: 16),
            Text(
              'Enter Quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 8),
            _QuantityStepper(
              controller: _quantityController,
              errorText: _inputError,
              denominationPaise: _selectedDenominationPaise,
              onIncrement: _increment,
              onDecrement: _selectedQuantity == 0 ? null : _decrement,
              onChanged: _onQuantityChanged,
            ),
            const SizedBox(height: 12),
            _TotalCard(
              label: 'Total Amount',
              amountPaise: _selectedTotalPaise,
              background: AppColors.warmIvory,
              border: AppColors.beige,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('note-counter-calculate'),
              onPressed: _commitTypedQuantity,
              icon: const Icon(Icons.calculate_outlined, size: 20),
              label: const Text('Calculate'),
            ),
            const SizedBox(height: 12),
            _GrandTotalCard(
              amountPaise: _grandTotalPaise,
              hiddenTwoThousandQuantity: _hiddenQuantity,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('note-counter-new-count'),
                    onPressed: _newCount,
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text('New count'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(color: AppColors.primaryGreen),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'In-memory session - nothing is saved or added to a khata',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.softText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A visual cue for the selected denomination. The illustration is bundled
/// locally, so the counter stays useful without a network connection.
class _NoteBundle extends StatelessWidget {
  const _NoteBundle({required this.denominationPaise});

  final int denominationPaise;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.lightGreen,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.outline),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.darkText.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 92,
                    height: 76,
                    child: Image.asset(
                      'assets/illustrations/note_bundle.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(
                            color: AppColors.warmIvory,
                            child: Icon(
                              Icons.payments_outlined,
                              size: 42,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'CURRENT NOTE',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: AppColors.softText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _rupeeLabel(denominationPaise),
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Choose a note below',
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        color: AppColors.softText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip row for choosing the active denomination. Wraps instead of scrolling,
/// so a narrow phone or 200% text scale never clips a chip.
class _DenominationPicker extends StatelessWidget {
  const _DenominationPicker({
    required this.denominationsPaise,
    required this.selectedPaise,
    required this.onSelected,
  });

  final List<int> denominationsPaise;
  final int selectedPaise;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final int denomination in denominationsPaise)
          _DenominationChip(
            key: Key('denomination-$denomination'),
            denominationPaise: denomination,
            selected: denomination == selectedPaise,
            onTap: () => onSelected(denomination),
          ),
      ],
    );
  }
}

class _DenominationChip extends StatelessWidget {
  const _DenominationChip({
    super.key,
    required this.denominationPaise,
    required this.selected,
    required this.onTap,
  });

  final int denominationPaise;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color background = selected
        ? AppColors.primaryGreen
        : AppColors.warmIvory;
    final Color foreground = selected
        ? AppColors.onPrimary
        : AppColors.darkText;

    return Semantics(
      button: true,
      selected: selected,
      // `excludeSemantics` stops the child `Text` from being announced as a
      // second node, so the chip reads as one control: "₹500 note, selected".
      label: '${_rupeeLabel(denominationPaise)} note',
      excludeSemantics: true,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            // No `alignment` here: an aligned Container in a Wrap stretches to
            // the full available width, which produced one full-width chip per
            // row. A compact box keeps the chips side by side.
            constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? AppColors.primaryGreen : AppColors.outline,
              ),
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                _rupeeLabel(denominationPaise),
                maxLines: 1,
                softWrap: false,
                // Chips must stay compact when text is huge: at 300% scale a
                // label alone was wider than the 288 dp content area, and its
                // Run height overflowed the Wrap's Row by 12 px.
                // Capping the chip label's growth keeps every chip narrow
                // enough to wrap, while the 44 dp minimum height keeps the
                // touch target legal. The label itself is unchanged, so the
                // "₹500 note" semantics stay intact.
                textScaler: TextScaler.linear(
                  MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3),
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opt-in ₹2,000 denomination (off by default).
class _TwoThousandToggle extends StatelessWidget {
  const _TwoThousandToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warmIvory,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Include ₹2,000 notes',
                  style: TextStyle(fontSize: 13, color: AppColors.darkText),
                ),
              ),
              Switch(
                key: const Key('note-counter-show-2000'),
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `−  10  +` with a numeric field in the middle.
class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.controller,
    required this.denominationPaise,
    required this.errorText,
    required this.onIncrement,
    required this.onDecrement,
    required this.onChanged,
  });

  final TextEditingController controller;
  final int denominationPaise;

  /// Shown under the field when the last typed value was rejected.
  final String? errorText;
  final VoidCallback onIncrement;

  /// `null` disables the button, which is how "disabled at zero" is expressed.
  final VoidCallback? onDecrement;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _StepperButton(
          key: const Key('note-counter-decrement'),
          icon: Icons.remove,
          semanticLabel: 'Decrease quantity',
          onPressed: onDecrement,
        ),
        const SizedBox(width: 12),
        Expanded(
          // A `TextField` gets no accessible name from a suppressed floating
          // label, and the visible "Enter Quantity" text above is a separate
          // node. This wrapper names the field itself, including the active
          // denomination, so the announced name follows the selection.
          child: Semantics(
            textField: true,
            label: 'Quantity of ${_rupeeLabel(denominationPaise)} notes',
            child: TextField(
              key: const Key('note-counter-quantity-field'),
              controller: controller,
              onChanged: onChanged,
              textAlign: TextAlign.center,
              textInputAction: TextInputAction.done,
              // No filtering formatters: `digitsOnly` would silently swallow
              // the `-` in `-5` and abandon the `.5` in `1.5`, leaving the user
              // with a plausible-looking count they never typed. The keyboard
              // is numeric as a convenience; _onQuantityChanged validates
              // whatever actually arrives.
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText,
              ),
              decoration: InputDecoration(
                errorText: errorText,
                errorMaxLines: 2,
                filled: true,
                fillColor: AppColors.warmIvory,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.beige),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.beige),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primaryGreen,
                    width: 1.5,
                  ),
                ),
                hintText: '0',
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _StepperButton(
          key: const Key('note-counter-increment'),
          icon: Icons.add,
          semanticLabel: 'Increase quantity',
          onPressed: onIncrement,
        ),
      ],
    );
  }
}

/// Circular green stepper button; greys out when [onPressed] is null.
class _StepperButton extends StatelessWidget {
  const _StepperButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Material(
          color: enabled ? AppColors.primaryGreen : AppColors.lightGreen,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Icon(
              icon,
              size: 24,
              color: enabled ? AppColors.onPrimary : AppColors.navigationGrey,
            ),
          ),
        ),
      ),
    );
  }
}

/// `Total Amount` / `Grand Total` card.
class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.label,
    required this.amountPaise,
    required this.background,
    required this.border,
  });

  final String label;
  final int amountPaise;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.lightGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.payments_outlined,
              size: 20,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.softText,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatPaise(amountPaise),
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grand total on `lightGreen` with the check icon from the style guide.
class _GrandTotalCard extends StatelessWidget {
  const _GrandTotalCard({
    required this.amountPaise,
    required this.hiddenTwoThousandQuantity,
  });

  final int amountPaise;

  /// Non-zero when ₹2,000 notes are counted but the denomination is hidden.
  /// The card says so rather than silently including invisible money.
  final int hiddenTwoThousandQuantity;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('note-counter-grand-total'),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accentGreen),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.warmIvory,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 21,
                  color: AppColors.incomeGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      'Grand Total',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatPaise(amountPaise),
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hiddenTwoThousandQuantity > 0) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Includes ₹2,000 × $hiddenTwoThousandQuantity (denomination '
              'hidden)',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.softText),
            ),
          ],
        ],
      ),
    );
  }
}

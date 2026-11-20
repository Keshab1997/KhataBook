// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/format/money.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// Operator glyphs are kept distinct from the ASCII '-' used inside a
/// negative number token, so a leading minus can be edited like a digit.
const List<String> _calculatorOperators = <String>['÷', '×', '−', '+'];

/// Bounds keep a long key run from producing Infinity, NaN or runaway work.
/// Results beyond one lakh crore are treated as malformed, never as a crash.
const int _maxExpressionLength = 64;
const int _maxOperandLength = 40;
const double _maxCalculatorValue = 1000000000000;

/// Parses an operand that may still be mid-keystroke (`0.`, `-.`).
double? _parseNumber(String token) {
  if (token.isEmpty || token == '-' || token == '.') return null;
  String text = token;
  if (text.startsWith('.')) text = '0$text';
  if (text.startsWith('-.')) text = '-0${text.substring(1)}';
  if (text.endsWith('.')) text = '${text}0';
  return double.tryParse(text);
}

/// Expands Dart's shortest round-trip string into plain decimal notation.
/// An exponent must never survive into a token: appending a digit to `1e-8`
/// yields `1e-82`, which silently changes the value being edited.
String _plainDecimal(double value) {
  final String shortest = value.toString();
  final int exponentAt = shortest.indexOf('e');
  if (exponentAt < 0) return shortest;

  final String mantissa = shortest.substring(0, exponentAt);
  final int exponent = int.parse(shortest.substring(exponentAt + 1));
  final bool negative = mantissa.startsWith('-');
  final String unsigned = negative ? mantissa.substring(1) : mantissa;
  final List<String> parts = unsigned.split('.');
  final String leading = parts.first;
  final String trailing = parts.length > 1 ? parts.last : '';
  final String digits = '$leading$trailing';
  final int point = leading.length + exponent;

  final String expanded;
  if (point <= 0) {
    final String zeros = ''.padLeft(-point, '0');
    expanded = '0.$zeros$digits';
  } else if (point >= digits.length) {
    final String zeros = ''.padLeft(point - digits.length, '0');
    expanded = '$digits$zeros';
  } else {
    expanded = '${digits.substring(0, point)}.${digits.substring(point)}';
  }

  final String trimmed = expanded.replaceFirst(RegExp(r'0+$'), '');
  final String plain = !expanded.contains('.')
      ? expanded
      : trimmed.endsWith('.')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
  return negative ? '-$plain' : plain;
}

/// A user-facing reason why the current expression has no trustworthy value.
/// Keeping it typed lets the display say *why* instead of showing a fake zero.
class _EvaluationIssue implements Exception {
  const _EvaluationIssue(this.message);

  final AppString message;
}

/// S3 - Calculator. See docs/spec/screens.md#s3--calculator.
///
/// A fully offline keypad: the expression is a small token list evaluated by
/// [_ExpressionParser] with ordinary precedence. Nothing here uses `eval`,
/// flows through the network, writes storage or navigates; the parent shell
/// owns those concerns.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key, this.language = AppLanguage.en});

  final AppLanguage language;

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final List<String> _tokens = <String>[];
  String _result = '0';
  AppString? _error;
  final _CalcHistory _history = _CalcHistory();

  String get _expression => _tokens.join(' ');

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(widget.language);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxHeight < 640;
            final double keyGap = compact ? 10 : 14;
            final double verticalPadding = compact ? 12 : 16;
            final double minDisplayHeight = compact ? 100 : 150;
            final double maxKeySize = compact ? 110 : 140;
            final double keySizeByWidth =
                (constraints.maxWidth - 32 - keyGap * 3) / 4;
            final double keySizeByHeight =
                (constraints.maxHeight -
                    verticalPadding * 2 -
                    minDisplayHeight -
                    keyGap * 5) /
                5;
            final double availableKeySize = keySizeByWidth < keySizeByHeight
                ? keySizeByWidth
                : keySizeByHeight;
            final double minimumKeySize = availableKeySize < 44
                ? 44
                : availableKeySize;
            final double keySize = minimumKeySize < maxKeySize
                ? minimumKeySize
                : maxKeySize;
            final double keypadHeight = keySize * 5 + keyGap * 4;
            final double minContentHeight =
                minDisplayHeight + keyGap + keypadHeight;
            final double availableHeight =
                constraints.maxHeight - verticalPadding * 2;
            final double textScale = MediaQuery.of(context).textScaler
                .scale(1.0);
            // Fill the screen when there is room at normal text scale; at
            // larger scales the rendered content can exceed the estimate, so
            // keep scrolling available instead.
            final bool fillKeypad =
                availableHeight >= minContentHeight && textScale == 1.0;

            Widget columnContent = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _CalculatorDisplay(
                  strings: strings,
                  compact: compact,
                  expression: _expression,
                  result: _result,
                  error: _error == null ? null : strings.text(_error!),
                ),
                SizedBox(height: keyGap),
                if (fillKeypad)
                  Expanded(
                    child: _Keypad(
                      strings: strings,
                      keySize: keySize,
                      gap: keyGap,
                      fillHeight: true,
                      onDigit: _onDigit,
                      onDecimal: _onDecimal,
                      onOperator: _onOperator,
                      onPercent: _onPercent,
                      onBackspace: _onBackspace,
                      onClear: _onClear,
                      onEquals: _onEquals,
                      onHistoryPressed: _showHistory,
                    ),
                  )
                else
                  _Keypad(
                    strings: strings,
                    keySize: keySize,
                    gap: keyGap,
                    fillHeight: false,
                    onDigit: _onDigit,
                    onDecimal: _onDecimal,
                    onOperator: _onOperator,
                    onPercent: _onPercent,
                    onBackspace: _onBackspace,
                    onClear: _onClear,
                    onEquals: _onEquals,
                    onHistoryPressed: _showHistory,
                  ),
              ],
            );

            if (fillKeypad) {
              return SizedBox(height: availableHeight, child: columnContent);
            }
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: verticalPadding,
              ),
              child: columnContent,
            );
          },
        ),
      ),
    );
  }

  void _onDigit(String digit) {
    if (_expression.length >= _maxExpressionLength) return;
    setState(() {
      if (_tokens.isEmpty || _calculatorOperators.contains(_tokens.last)) {
        _tokens.add(digit);
      } else {
        _tokens[_tokens.length - 1] += digit;
      }
      _evaluate();
    });
  }

  void _onDecimal() {
    if (_expression.length >= _maxExpressionLength) return;
    setState(() {
      if (_tokens.isEmpty || _calculatorOperators.contains(_tokens.last)) {
        _tokens.add('0.');
      } else if (!_tokens.last.contains('.')) {
        _tokens[_tokens.length - 1] += '.';
      }
      _evaluate();
    });
  }

  void _onOperator(String operator) {
    if (_expression.length >= _maxExpressionLength) return;
    setState(() {
      if (_tokens.isEmpty) {
        // A leading mathematical minus is part of the first number. Any other
        // leading operator is kept so the parser can name the problem rather
        // than leaving a valid-looking zero on screen.
        _tokens.add(operator == '−' ? '-' : operator);
      } else if (_tokens.last == '-' ||
          _calculatorOperators.contains(_tokens.last)) {
        _tokens[_tokens.length - 1] = operator;
      } else {
        _tokens.add(operator);
      }
      _evaluate();
    });
  }

  void _onPercent() {
    setState(() {
      if (_tokens.isEmpty || _calculatorOperators.contains(_tokens.last)) {
        _error = AppString.invalidExpression;
        return;
      }
      final double? value = _parseNumber(_tokens.last);
      if (value == null) {
        _error = AppString.invalidExpression;
        return;
      }
      final double percent = value / 100;
      if (!percent.isFinite || percent.abs() > _maxCalculatorValue) {
        _error = AppString.valueTooLarge;
        return;
      }
      if (percent == 0 && value != 0) {
        _error = AppString.valueTooSmall;
        return;
      }
      // Keep full precision without exponent notation: `0.1 % × 1000` stays
      // 1, and a later digit on `0.00000001` cannot corrupt an exponent.
      final String operand = _operandText(percent);
      final int index = _tokens.length - 1;
      if (operand.length > _maxOperandLength) {
        _error = AppString.valueTooSmall;
        return;
      }
      final List<String> candidate = List<String>.from(_tokens);
      candidate[index] = operand;
      if (candidate.join(' ').length > _maxExpressionLength) {
        _error = AppString.expressionTooLong;
        return;
      }
      _tokens[index] = operand;
      _evaluate();
    });
  }

  void _onBackspace() {
    if (_tokens.isEmpty) return;
    setState(() {
      final String last = _tokens.last;
      if (last.length > 1) {
        _tokens[_tokens.length - 1] = last.substring(0, last.length - 1);
      } else {
        _tokens.removeLast();
      }
      _evaluate();
    });
  }

  void _onClear() {
    setState(() {
      _tokens.clear();
      _evaluate();
    });
  }

  /// The expression stays on screen and editable; the result is always a
  /// live preview, so `=` simply re-evaluates without locking the input.
  /// A completed calculation is persisted to history so nothing is lost
  /// when the user navigates away and comes back.
  void _onEquals() {
    setState(_evaluate);
    _history.save(_expression, _result);
  }

  /// Shows the persisted calculation history. Tapping an entry restores its
  /// expression and result to the display.
  Future<void> _showHistory() async {
    final strings = AppStrings(widget.language);
    final entries = await _history.load();
    if (!mounted) return;
    final String? picked = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(strings.text(AppString.calculatorHistory)),
          content: entries.isEmpty
              ? Text(
                  strings.text(AppString.calculatorHistoryEmpty),
                  style: TextStyle(color: AppColors.softText),
                )
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    itemBuilder: (BuildContext context, int index) {
                      final entry = entries[index];
                      return ListTile(
                        title: Text(entry['expression'] ?? ''),
                        subtitle: Text(
                          entry['result'] ?? '',
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () =>
                            Navigator.of(dialogContext).pop(index.toString()),
                      );
                    },
                  ),
                ),
          actions: <Widget>[
            if (entries.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop('clear'),
                child: Text(
                  strings.text(AppString.clearHistory),
                  style: TextStyle(color: AppColors.expenseRed),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.text(AppString.close)),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (picked == 'clear') {
      await _history.clear();
      return;
    }
    if (picked == null) return;
    final int index = int.tryParse(picked) ?? -1;
    if (index < 0 || index >= entries.length) return;
    final entry = entries[index];
    setState(() {
      _tokens.clear();
      _tokens.addAll(entry['expression']!.split(' '));
      _result = entry['result'] ?? '0';
      _error = null;
    });
  }

  /// Recomputes from the token list. A genuinely unfinished expression (a
  /// trailing operator) still previews the value typed so far; anything
  /// malformed, divide-by-zero or out of range gets an explicit reason, never
  /// a quiet `0`. The token list stays editable either way.
  void _evaluate() {
    if (_tokens.isEmpty) {
      _result = '0';
      _error = null;
      return;
    }
    try {
      _result = _formatResult(_ExpressionParser().parse(_tokens));
      _error = null;
    } on _EvaluationIssue catch (issue) {
      _result = '0';
      _error = issue.message;
    }
  }

  /// Indian grouping with at most two decimals, but no cosmetic trailing
  /// zeros: `0.5` stays `0.5` and `1,000.00` shows as `1,000`.
  String _formatResult(double value) {
    final String grouped = formatPaise((value * 100).round())
        .replaceFirst('₹', '');
    if (!grouped.contains('.')) return grouped;
    final String trimmed = grouped.replaceFirst(RegExp(r'0+$'), '');
    return trimmed.endsWith('.')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  /// Grouping-free, exponent-free operand text with full double precision.
  /// Rounding belongs to display only; doing it here corrupts later
  /// arithmetic after `%`, and an exponent would corrupt later editing.
  String _operandText(double value) {
    final String plain = _plainDecimal(value);
    if (plain.endsWith('.0')) return plain.substring(0, plain.length - 2);
    return plain;
  }
}

/// Token parser for `+ - × ÷` with normal precedence and no code execution.
///
/// A trailing operator is ignored so the live preview stays useful while a
/// new number is being typed. Anything unparseable, divide-by-zero or out of
/// range throws [_EvaluationIssue] with text the display can show.
class _ExpressionParser {
  int _index = 0;
  List<String> _tokens = const <String>[];

  double parse(List<String> tokens) {
    _tokens = tokens;
    _index = 0;
    final double value = _parseExpression();
    if (_index != _tokens.length) {
      throw const _EvaluationIssue(AppString.invalidExpression);
    }
    return value;
  }

  double _parseExpression() {
    double value = _parseTerm();
    while (_index < _tokens.length &&
        (_tokens[_index] == '+' || _tokens[_index] == '−')) {
      final String operator = _tokens[_index];
      _index++;
      if (_index >= _tokens.length) break;
      final double right = _parseTerm();
      value = operator == '+' ? value + right : value - right;
      _check(value);
    }
    return value;
  }

  double _parseTerm() {
    double value = _parseFactor();
    while (_index < _tokens.length &&
        (_tokens[_index] == '×' || _tokens[_index] == '÷')) {
      final String operator = _tokens[_index];
      _index++;
      if (_index >= _tokens.length) break;
      final double right = _parseFactor();
      if (operator == '÷') {
        if (right == 0) {
          throw const _EvaluationIssue(AppString.divideByZero);
        }
        value /= right;
      } else {
        value *= right;
      }
      _check(value);
    }
    return value;
  }

  double _parseFactor() {
    if (_index >= _tokens.length) {
      throw const _EvaluationIssue(AppString.invalidExpression);
    }
    final double? value = _parseNumber(_tokens[_index++]);
    if (value == null) {
      throw const _EvaluationIssue(AppString.invalidExpression);
    }
    _check(value);
    return value;
  }

  void _check(double value) {
    if (!value.isFinite || value.abs() > _maxCalculatorValue) {
      throw const _EvaluationIssue(AppString.valueTooLarge);
    }
  }
}

/// Persisted calculation history, kept as a JSON list under a single key.
/// Entries are newest-first, capped at 50.
class _CalcHistory {
  static const _key = 'calculator_history';
  static const _maxEntries = 50;
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Saves a completed calculation. Silently no-ops when there is nothing
  /// worth keeping (empty expression or a plain zero result).
  Future<void> save(String expression, String result) async {
    if (expression.isEmpty || result == '0') return;
    final prefs = await _getPrefs();
    final List<String> existing = prefs.getStringList(_key) ?? <String>[];
    final entry = jsonEncode(<String, String>{
      'expression': expression,
      'result': result,
    });
    existing.insert(0, entry);
    if (existing.length > _maxEntries) existing.length = _maxEntries;
    await prefs.setStringList(_key, existing);
  }

  Future<List<Map<String, String>>> load() async {
    final prefs = await _getPrefs();
    final List<String> raw = prefs.getStringList(_key) ?? <String>[];
    return raw
        .map((e) {
          try {
            final Map<String, dynamic> decoded = jsonDecode(e);
            return <String, String>{
              'expression': decoded['expression'] as String,
              'result': decoded['result'] as String,
            };
          } catch (_) {
            return null;
          }
        })
        .whereType<Map<String, String>>()
        .toList();
  }

  Future<void> clear() async {
    final prefs = await _getPrefs();
    await prefs.remove(_key);
  }
}

/// A spacious, unobstructed display, with the expression above the result.
///
/// Uses fixed font sizes with `TextOverflow.fade` so the layout never jumps
/// when digits are added or removed - only the text fades at the left edge
/// when it exceeds the available width.
class _CalculatorDisplay extends StatelessWidget {
  const _CalculatorDisplay({
    required this.strings,
    required this.compact,
    required this.expression,
    required this.result,
    required this.error,
  });

  final AppStrings strings;
  final bool compact;
  final String expression;
  final String result;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Expression line - fixed height, never resizes.
          _ExpressionLine(
            strings: strings,
            compact: compact,
            expression: expression,
            isEmpty: expression.isEmpty,
          ),
          if (expression.isNotEmpty) SizedBox(height: compact ? 6 : 10),
          // Result line - fixed height, larger font.
          _ResultLine(
            compact: compact,
            result: error ?? result,
            isError: error != null,
          ),
        ],
      ),
    );
  }
}

/// Expression preview line: fixed font size, fades at the left edge when
/// too long instead of resizing or wrapping.
class _ExpressionLine extends StatelessWidget {
  const _ExpressionLine({
    required this.strings,
    required this.compact,
    required this.expression,
    required this.isEmpty,
  });

  final AppStrings strings;
  final bool compact;
  final String expression;
  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: compact ? 26 : 32,
        child: Text(
          isEmpty
              ? strings.text(AppString.calculatorExpressionHint)
              : expression,
          key: const Key('calculator-expression'),
          textAlign: TextAlign.right,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
          style: TextStyle(
            color: isEmpty
                ? AppColors.softText.withValues(alpha: 0.6)
                : AppColors.softText,
            fontSize: compact ? 16 : 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Result line: fixed font size, fades at the left edge when too long.
/// Shows error text in red when there's an evaluation issue.
class _ResultLine extends StatelessWidget {
  const _ResultLine({
    required this.compact,
    required this.result,
    required this.isError,
  });

  final bool compact;
  final String result;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: compact ? 56 : 72,
        child: Text(
          result,
          key: const Key('calculator-result'),
          textAlign: TextAlign.right,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
          style: TextStyle(
            color: isError ? AppColors.expenseRed : AppColors.darkText,
            fontSize: compact ? 44 : 60,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

/// The five rows of round keys from the calculator reference.
class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.strings,
    required this.keySize,
    required this.gap,
    required this.onDigit,
    required this.onDecimal,
    required this.onOperator,
    required this.onPercent,
    required this.onBackspace,
    required this.onClear,
    required this.onEquals,
    required this.onHistoryPressed,
    this.fillHeight = false,
  });

  final AppStrings strings;
  final double keySize;
  final double gap;
  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final ValueChanged<String> onOperator;
  final VoidCallback onPercent;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onEquals;
  final VoidCallback onHistoryPressed;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: fillHeight
          ? MainAxisAlignment.spaceEvenly
          : MainAxisAlignment.start,
      children: <Widget>[
        _row(<Widget>[
          _clearKey(),
          _historyKey(),
          _greenKey('%', onPercent),
          _backspaceKey(),
          _greenKey('÷', () => onOperator('÷')),
        ]),
        _row(<Widget>[
          _numberKey('7'),
          _numberKey('8'),
          _numberKey('9'),
          _greenKey('×', () => onOperator('×')),
        ]),
        _row(<Widget>[
          _numberKey('4'),
          _numberKey('5'),
          _numberKey('6'),
          _greenKey('−', () => onOperator('−')),
        ]),
        _row(<Widget>[
          _numberKey('1'),
          _numberKey('2'),
          _numberKey('3'),
          _greenKey('+', () => onOperator('+')),
        ]),
        _row(<Widget>[
          _numberKey('00'),
          _numberKey('0'),
          _numberKey('.'),
          _equalsKey(),
        ], bottomGap: false),
      ],
    );
  }

  Widget _row(List<Widget> keys, {bool bottomGap = true}) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap ? gap : 0),
      child: Row(
        children: <Widget>[
          for (int index = 0; index < keys.length; index++) ...<Widget>[
            if (index > 0) SizedBox(width: gap),
            Expanded(child: Center(child: keys[index])),
          ],
        ],
      ),
    );
  }

  Widget _numberKey(String label) {
    return _CalcKey(
      key: Key('calc-key-$label'),
      size: keySize,
      onPressed: label == '.' ? onDecimal : () => onDigit(label),
      background: AppColors.warmIvory,
      foreground: AppColors.darkText,
      outline: AppColors.outline,
      child: Text(
        label,
        style: TextStyle(
          fontSize: label.length > 1 ? 23 : 29,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _clearKey() {
    return _CalcKey(
      key: const Key('calc-key-C'),
      size: keySize,
      onPressed: onClear,
      tooltip: strings.text(AppString.clearCalculation),
      background: AppColors.lightGreen,
      foreground: AppColors.primaryGreen,
      outline: AppColors.lightGreen,
      child: const Text(
        'AC',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _historyKey() {
    return _CalcKey(
      key: const Key('calc-key-history'),
      size: keySize,
      onPressed: onHistoryPressed,
      tooltip: strings.text(AppString.calculatorHistory),
      background: AppColors.lightGreen,
      foreground: AppColors.primaryGreen,
      outline: AppColors.lightGreen,
      child: const Icon(Icons.history, size: 25),
    );
  }

  Widget _greenKey(String label, VoidCallback onPressed) {
    return _CalcKey(
      key: Key('calc-key-$label'),
      size: keySize,
      onPressed: onPressed,
      background: AppColors.lightGreen,
      foreground: AppColors.primaryGreen,
      outline: AppColors.lightGreen,
      child: Text(
        label,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _backspaceKey() {
    return _CalcKey(
      key: const Key('calc-key-backspace'),
      size: keySize,
      onPressed: onBackspace,
      background: AppColors.lightGreen,
      foreground: AppColors.primaryGreen,
      outline: AppColors.lightGreen,
      tooltip: strings.text(AppString.backspace),
      child: const Icon(Icons.backspace_outlined, size: 25),
    );
  }

  Widget _equalsKey() {
    return _CalcKey(
      key: const Key('calc-key-='),
      size: keySize,
      onPressed: onEquals,
      background: AppColors.orange,
      foreground: AppColors.onPrimary,
      outline: AppColors.orange,
      tooltip: strings.text(AppString.equals),
      child: const Text(
        '=',
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// One circular key with a soft shadow. FittedBox keeps glyphs bounded at
/// larger text scales; tooltips label icon-only actions for accessibility.
class _CalcKey extends StatelessWidget {
  const _CalcKey({
    super.key,
    required this.size,
    required this.child,
    required this.onPressed,
    required this.background,
    required this.foreground,
    required this.outline,
    this.tooltip,
  });

  final double size;
  final Widget child;
  final VoidCallback onPressed;
  final Color background;
  final Color foreground;
  final Color outline;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Widget button = SizedBox.square(
      dimension: size,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(color: outline),
          elevation: 2,
          shadowColor: AppColors.primaryGreen.withValues(alpha: 0.12),
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const CircleBorder(),
        ),
        child: FittedBox(fit: BoxFit.scaleDown, child: child),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

// Flutter 3.50 deprecates this import; migrate to material_ui in a dedicated dependency update.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/format/money.dart';
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

  final String message;
}

/// S3 - Calculator. See docs/spec/screens.md#s3--calculator.
///
/// A fully offline keypad: the expression is a small token list evaluated by
/// [_ExpressionParser] with ordinary precedence. Nothing here uses `eval`,
/// flows through the network, writes storage or navigates; the parent shell
/// owns those concerns.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final List<String> _tokens = <String>[];
  String _result = '0';
  String? _error;

  String get _expression => _tokens.join(' ');

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
              Icon(Icons.calculate_outlined, size: 22),
              SizedBox(width: 12),
              Text('Calculator'),
            ],
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // 200% text and a 320 px phone scroll instead of overflowing; every
          // key keeps its own bounded, fitted label.
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _CalculatorDisplay(
                expression: _expression,
                result: _result,
                error: _error,
              ),
              const SizedBox(height: 12),
              _Keypad(
                onDigit: _onDigit,
                onDecimal: _onDecimal,
                onOperator: _onOperator,
                onPercent: _onPercent,
                onBackspace: _onBackspace,
                onClear: _onClear,
                onEquals: _onEquals,
              ),
            ],
          ),
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
        _error = 'Invalid expression';
        return;
      }
      final double? value = _parseNumber(_tokens.last);
      if (value == null) {
        _error = 'Invalid expression';
        return;
      }
      final double percent = value / 100;
      if (!percent.isFinite || percent.abs() > _maxCalculatorValue) {
        _error = 'Value too large';
        return;
      }
      if (percent == 0 && value != 0) {
        _error = 'Value too small';
        return;
      }
      // Keep full precision without exponent notation: `0.1 % × 1000` stays
      // 1, and a later digit on `0.00000001` cannot corrupt an exponent.
      final String operand = _operandText(percent);
      final int index = _tokens.length - 1;
      if (operand.length > _maxOperandLength) {
        _error = 'Value too small';
        return;
      }
      final List<String> candidate = List<String>.from(_tokens);
      candidate[index] = operand;
      if (candidate.join(' ').length > _maxExpressionLength) {
        _error = 'Expression too long';
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
  void _onEquals() {
    setState(_evaluate);
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
      throw const _EvaluationIssue('Invalid expression');
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
          throw const _EvaluationIssue('Cannot divide by zero');
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
      throw const _EvaluationIssue('Invalid expression');
    }
    final double? value = _parseNumber(_tokens[_index++]);
    if (value == null) throw const _EvaluationIssue('Invalid expression');
    _check(value);
    return value;
  }

  void _check(double value) {
    if (!value.isFinite || value.abs() > _maxCalculatorValue) {
      throw const _EvaluationIssue('Value too large');
    }
  }
}

/// Expression above, large result below; both shrink to fit at 200% text.
class _CalculatorDisplay extends StatelessWidget {
  const _CalculatorDisplay({
    required this.expression,
    required this.result,
    required this.error,
  });

  final String expression;
  final String result;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warmIvory,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      // A minimum, not a fixed, height: at 200% text the two fitted lines
      // may grow and the enclosing scroll view carries the extra pixels.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                key: const Key('calculator-expression'),
                expression,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  color: AppColors.softText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                key: const Key('calculator-result'),
                error ?? result,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: error == null
                      ? AppColors.darkText
                      : AppColors.expenseRed,
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The five keypad rows from docs/spec/screens.md#s3--calculator.
class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onDecimal,
    required this.onOperator,
    required this.onPercent,
    required this.onBackspace,
    required this.onClear,
    required this.onEquals,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final ValueChanged<String> onOperator;
  final VoidCallback onPercent;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onEquals;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _row(<Widget>[
          _greenKey('C', onClear),
          _backspaceKey(),
          _greenKey('%', onPercent),
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
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: <Widget>[
              Expanded(flex: 2, child: _numberKey('0')),
              const SizedBox(width: 8),
              Expanded(child: _numberKey('.')),
              const SizedBox(width: 8),
              Expanded(child: _equalsKey()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(List<Widget> keys) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          for (int index = 0; index < keys.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: 8),
            Expanded(child: keys[index]),
          ],
        ],
      ),
    );
  }

  Widget _numberKey(String label) {
    return _CalcKey(
      key: Key('calc-key-$label'),
      onPressed: label == '.' ? onDecimal : () => onDigit(label),
      background: AppColors.creamBackground,
      foreground: AppColors.darkText,
      outline: AppColors.outline,
      child: Text(
        label,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _greenKey(String label, VoidCallback onPressed) {
    return _CalcKey(
      key: Key('calc-key-$label'),
      onPressed: onPressed,
      background: AppColors.buttonGreen,
      foreground: AppColors.onPrimary,
      outline: Colors.transparent,
      child: Text(
        label,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _backspaceKey() {
    return _CalcKey(
      key: const Key('calc-key-backspace'),
      onPressed: onBackspace,
      background: AppColors.buttonGreen,
      foreground: AppColors.onPrimary,
      outline: Colors.transparent,
      tooltip: 'Backspace',
      child: const Icon(Icons.backspace_outlined, size: 22),
    );
  }

  Widget _equalsKey() {
    return _CalcKey(
      key: const Key('calc-key-='),
      onPressed: onEquals,
      background: AppColors.orange,
      foreground: AppColors.onPrimary,
      outline: Colors.transparent,
      tooltip: 'Equals',
      child: const Text(
        '=',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// One fixed-height key. FittedBox keeps glyphs readable and bounded when the
/// ambient text scale doubles, and the tooltip supplies a semantic label for
/// icon-only keys.
class _CalcKey extends StatelessWidget {
  const _CalcKey({
    super.key,
    required this.child,
    required this.onPressed,
    required this.background,
    required this.foreground,
    required this.outline,
    this.tooltip,
  });

  final Widget child;
  final VoidCallback onPressed;
  final Color background;
  final Color foreground;
  final Color outline;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Widget button = SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(color: outline),
          elevation: 1,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: FittedBox(fit: BoxFit.scaleDown, child: child),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

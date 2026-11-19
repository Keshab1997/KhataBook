/// Money lives in the database as **integer paise**. This is the only layer
/// that turns it into text, using Indian digit grouping (₹1,00,000) and the
/// rupee symbol. No `double`, no `intl` locale data, no network.
String formatPaise(int paise) {
  final int absolute = paise.abs();
  final int rupees = absolute ~/ 100;
  final int fraction = absolute % 100;
  final String fractionText = fraction == 0
      ? ''
      : '.${fraction.toString().padLeft(2, '0')}';
  final String sign = paise < 0 ? '-' : '';
  final String grouped = _groupIndian(rupees.toString());
  return '$sign₹$grouped$fractionText';
}

/// Indian grouping: the last three digits, then pairs (1,00,000 not 100,000).
String _groupIndian(String digits) {
  if (digits.length <= 3) {
    return digits;
  }
  final String lastThree = digits.substring(digits.length - 3);
  String rest = digits.substring(0, digits.length - 3);
  final List<String> groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) {
    groups.insert(0, rest);
  }
  return '${groups.join(',')},$lastThree';
}

import 'package:flutter/services.dart';

const _digits = [
  'không',
  'một',
  'hai',
  'ba',
  'bốn',
  'năm',
  'sáu',
  'bảy',
  'tám',
  'chín',
];

/// Reads a three-digit group. [full] forces "không trăm"/"linh" when a higher
/// group exists (e.g. 1.005.000 → "một triệu không trăm linh năm nghìn").
String _group(int value, {required bool full}) {
  final hundreds = value ~/ 100;
  final tens = (value % 100) ~/ 10;
  final units = value % 10;
  final words = <String>[];
  if (hundreds > 0 || full) {
    words.add('${_digits[hundreds]} trăm');
  }
  if (tens == 0) {
    if (units > 0) {
      if (hundreds > 0 || full) words.add('linh');
      words.add(_digits[units]);
    }
  } else {
    words.add(tens == 1 ? 'mười' : '${_digits[tens]} mươi');
    if (units == 1) {
      words.add(tens == 1 ? 'một' : 'mốt');
    } else if (units == 4) {
      words.add(tens == 1 ? 'bốn' : 'tư');
    } else if (units == 5) {
      words.add('lăm');
    } else if (units > 0) {
      words.add(_digits[units]);
    }
  }
  return words.join(' ');
}

/// Vietnamese reading of a non-negative whole number, e.g. 1.500.000 →
/// "một triệu năm trăm nghìn". Amounts of a thousand billion or more are read
/// with "tỷ" once ("chín nghìn chín trăm tỷ"), as in Vietnamese contracts.
String numberToVietnameseWords(int value) {
  if (value < 0) throw ArgumentError.value(value, 'value', 'must be >= 0');
  if (value == 0) return 'không';
  return _words(value, full: false);
}

const _billion = 1000000000;

String _words(int value, {required bool full}) {
  if (value >= _billion) {
    final high = value ~/ _billion;
    final low = value % _billion;
    final head = '${_words(high, full: full)} tỷ';
    return low == 0 ? head : '$head ${_belowBillion(low, full: true)}';
  }
  return _belowBillion(value, full: full);
}

String _belowBillion(int value, {required bool full}) {
  const scales = ['', 'nghìn', 'triệu'];
  final groups = <int>[];
  for (var rest = value; rest > 0; rest ~/= 1000) {
    groups.add(rest % 1000);
  }
  final parts = <String>[];
  for (var i = groups.length - 1; i >= 0; i--) {
    final group = groups[i];
    if (group == 0) continue;
    final text = _group(group, full: full || i < groups.length - 1);
    parts.add(scales[i].isEmpty ? text : '$text ${scales[i]}');
  }
  return parts.join(' ');
}

/// "Năm mươi triệu đồng" — capitalised, as written in Vietnamese contracts.
String vndInWords(int value) {
  final words = numberToVietnameseWords(value);
  return '${words[0].toUpperCase()}${words.substring(1)} đồng';
}

/// Digits only, grouped with "." while typing (50000000 → 50.000.000).
class VndInputFormatter extends TextInputFormatter {
  const VndInputFormatter({this.maxDigits = 13});
  final int maxDigits;

  static String format(String digits) {
    final clean = digits.replaceAll(RegExp(r'\D'), '');
    if (clean.isEmpty) return '';
    final normalized = clean.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < normalized.length; i++) {
      if (i > 0 && (normalized.length - i) % 3 == 0) buffer.write('.');
      buffer.write(normalized[i]);
    }
    return buffer.toString();
  }

  static String digitsOf(String text) => text.replaceAll(RegExp(r'\D'), '');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = digitsOf(newValue.text);
    if (digits.length > maxDigits) return oldValue;
    final formatted = format(digits);
    // Keep the caret after the same number of digits it followed before.
    final digitsBeforeCaret = digitsOf(
      newValue.text.substring(
        0,
        newValue.selection.end.clamp(0, newValue.text.length),
      ),
    ).length;
    var offset = 0;
    for (var seen = 0; offset < formatted.length && seen < digitsBeforeCaret;) {
      if (formatted[offset] != '.') seen++;
      offset++;
    }
    digits = formatted;
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// Percentage with up to two decimals using a Vietnamese decimal comma.
class PercentInputFormatter extends TextInputFormatter {
  const PercentInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('.', ',');
    if (text.isEmpty || RegExp(r'^\d{0,3}(,\d{0,2})?$').hasMatch(text)) {
      return newValue.copyWith(text: text);
    }
    return oldValue;
  }
}

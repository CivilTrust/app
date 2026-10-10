class DisplayFormatters {
  const DisplayFormatters._();

  static String vnd(int value) {
    final digits = value.abs().toString();
    final groups = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      final start = (end - 3).clamp(0, end);
      groups.add(digits.substring(start, end));
    }
    final formatted = groups.reversed.join('.');
    return '${value < 0 ? '-' : ''}$formatted VNĐ';
  }

  static String dateTime(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)} '
        '${two(local.day)}/${two(local.month)}/${local.year}';
  }
}

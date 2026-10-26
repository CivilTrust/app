class VietQrService {
  const VietQrService();

  static const maxAmount = 9999999999999; // 13 digits, safe on Web.
  static bool isBankBin(String value) => RegExp(r'^\d{6}$').hasMatch(value);
  static bool isAccountNumber(String value) =>
      RegExp(r'^[A-Za-z0-9]{4,19}$').hasMatch(value);

  String build({
    required String bankBin,
    required String accountNumber,
    required int amount,
    required String purpose,
  }) {
    if (!isBankBin(bankBin)) {
      throw ArgumentError('BIN phải gồm 6 chữ số');
    }
    if (!isAccountNumber(accountNumber)) {
      throw ArgumentError('Số tài khoản phải gồm 4–19 ký tự chữ hoặc số.');
    }
    if (amount <= 0 || amount > maxAmount) {
      throw ArgumentError('Số tiền phải dương và không quá 13 chữ số.');
    }
    // Never silently alter a reviewed reference. ASCII makes TLV byte
    // lengths unambiguous for this account-transfer profile.
    if (!RegExp(r'^[A-Za-z0-9 ]{1,25}$').hasMatch(purpose) ||
        purpose.trim().isEmpty) {
      throw ArgumentError(
        'Nội dung QR cần 1–25 ký tự chữ/số không dấu hoặc khoảng trắng.',
      );
    }
    final bankAccount = _field('00', bankBin) + _field('01', accountNumber);
    final merchant =
        _field('00', 'A000000727') +
        _field('01', bankAccount) +
        _field('02', 'QRIBFTTA');
    final body =
        '000201'
        '010212'
        '${_field('38', merchant)}'
        '5303704'
        '${_field('54', amount.toString())}'
        '5802VN'
        '${_field('62', _field('08', purpose))}'
        '6304';
    return '$body${_crc16(body)}';
  }

  String _field(String id, String value) {
    if (value.isEmpty || value.length > 99) {
      throw ArgumentError('Độ dài trường QR không hợp lệ.');
    }
    return '$id${value.length.toString().padLeft(2, '0')}$value';
  }

  String _crc16(String value) {
    var crc = 0xffff;
    for (final byte in value.codeUnits) {
      crc ^= byte << 8;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 0x8000) != 0
            ? ((crc << 1) ^ 0x1021) & 0xffff
            : (crc << 1) & 0xffff;
      }
    }
    return crc.toRadixString(16).padLeft(4, '0').toUpperCase();
  }
}

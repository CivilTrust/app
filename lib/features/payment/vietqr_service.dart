class VietQrService {
  const VietQrService();

  String build({
    required String bankBin,
    required String accountNumber,
    required int amount,
    required String purpose,
  }) {
    if (!RegExp(r'^\d{6}$').hasMatch(bankBin)) {
      throw ArgumentError.value(bankBin, 'bankBin', 'BIN phải gồm 6 chữ số');
    }
    if (!RegExp(r'^[A-Za-z0-9]{4,30}$').hasMatch(accountNumber)) {
      throw ArgumentError.value(
        accountNumber,
        'accountNumber',
        'Số tài khoản phải gồm 4-30 ký tự chữ hoặc số',
      );
    }
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Số tiền phải lớn hơn 0');
    }
    final bankAccount = _field('00', bankBin) + _field('01', accountNumber);
    final merchant = _field('00', 'A000000727') + _field('01', bankAccount);
    final normalizedPurpose = purpose
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), '')
        .trim();
    final sanitizedPurpose = normalizedPurpose.length > 50
        ? normalizedPurpose.substring(0, 50)
        : normalizedPurpose;
    final body =
        '000201'
        '010212'
        '${_field('38', merchant)}'
        '5303704'
        '${_field('54', amount.toString())}'
        '5802VN'
        '${_field('62', _field('08', sanitizedPurpose))}'
        '6304';
    return '$body${_crc16(body)}';
  }

  String _field(String id, String value) =>
      '$id${value.length.toString().padLeft(2, '0')}$value';

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

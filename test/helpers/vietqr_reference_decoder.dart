/// Test-only TLV decoder and nibble-table CRC independent of the builder's
/// byte/bit-loop serializer. No app payment code is imported here.
Map<String, String> readTlv(String encoded) {
  final result = <String, String>{};
  var offset = 0;
  while (offset < encoded.length) {
    if (offset + 4 > encoded.length ||
        !RegExp(r'^\d{4}$').hasMatch(encoded.substring(offset, offset + 4))) {
      throw const FormatException('Bad TLV header');
    }
    final id = encoded.substring(offset, offset + 2);
    final size = int.parse(encoded.substring(offset + 2, offset + 4));
    offset += 4;
    if (size == 0 || offset + size > encoded.length || result.containsKey(id)) {
      throw const FormatException('Bad TLV length or duplicate');
    }
    result[id] = encoded.substring(offset, offset + size);
    offset += size;
  }
  return result;
}

String referenceCrc(String value) {
  const table = [
    0x0000,
    0x1021,
    0x2042,
    0x3063,
    0x4084,
    0x50a5,
    0x60c6,
    0x70e7,
    0x8108,
    0x9129,
    0xa14a,
    0xb16b,
    0xc18c,
    0xd1ad,
    0xe1ce,
    0xf1ef,
  ];
  var crc = 0xffff;
  for (final value in value.codeUnits) {
    crc = ((crc << 4) ^ table[((crc >> 12) ^ (value >> 4)) & 15]) & 0xffff;
    crc = ((crc << 4) ^ table[((crc >> 12) ^ value) & 15]) & 0xffff;
  }
  return crc.toRadixString(16).padLeft(4, '0').toUpperCase();
}

Map<String, String> decodeAccountQr(String payload) {
  if (payload.codeUnits.any((value) => value > 127) ||
      payload.length < 8 ||
      payload.substring(payload.length - 8, payload.length - 4) != '6304' ||
      referenceCrc(payload.substring(0, payload.length - 4)) !=
          payload.substring(payload.length - 4)) {
    throw const FormatException('Bad CRC/profile');
  }
  final top = readTlv(payload);
  final merchant = readTlv(top['38']!);
  final account = readTlv(merchant['01']!);
  final additional = readTlv(top['62']!);
  if (top['00'] != '01' ||
      top['01'] != '12' ||
      top['53'] != '704' ||
      top['58'] != 'VN' ||
      merchant['00'] != 'A000000727' ||
      merchant['02'] != 'QRIBFTTA') {
    throw const FormatException('Unsupported account-transfer fields');
  }
  return {
    'bankBin': account['00']!,
    'accountNumber': account['01']!,
    'amount': top['54']!,
    'purpose': additional['08']!,
  };
}

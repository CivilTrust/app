import 'dart:convert';
import 'dart:typed_data';

String bytesToHex(List<int> bytes, {bool include0x = true}) {
  final buffer = StringBuffer(include0x ? '0x' : '');
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

Uint8List hexToBytes(String value) {
  final normalized = value.startsWith('0x') ? value.substring(2) : value;
  if (normalized.length.isOdd ||
      !RegExp(r'^[0-9a-fA-F]*$').hasMatch(normalized)) {
    throw const FormatException('Invalid hexadecimal value');
  }
  return Uint8List.fromList([
    for (var index = 0; index < normalized.length; index += 2)
      int.parse(normalized.substring(index, index + 2), radix: 16),
  ]);
}

String base64UrlNoPadding(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

Uint8List base64UrlDecodeNoPadding(String value) {
  final padding = '=' * ((4 - value.length % 4) % 4);
  return Uint8List.fromList(base64Url.decode('$value$padding'));
}

Uint8List uint256Bytes(BigInt value) {
  if (value.isNegative) {
    throw const FormatException('uint256 cannot be negative');
  }
  final bytes = Uint8List(32);
  var current = value;
  for (var index = 31; index >= 0; index--) {
    bytes[index] = (current & BigInt.from(0xff)).toInt();
    current >>= 8;
  }
  if (current != BigInt.zero) {
    throw const FormatException('uint256 overflow');
  }
  return bytes;
}

String canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is Iterable) return value.map(_canonicalize).toList();
  return value;
}

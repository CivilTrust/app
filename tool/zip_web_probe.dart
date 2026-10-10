import 'dart:convert';

import 'package:archive/archive.dart';

void main() {
  final pdf = ArchiveFile.bytes('agreement.pdf', utf8.encode('pdf'))
    ..compression = CompressionType.none;
  final evidence = ArchiveFile.bytes(
    'evidence.civiltrust.json',
    utf8.encode('{"schema":"civiltrust-evidence/1.0"}'),
  )..compression = CompressionType.none;
  final bytes = ZipEncoder().encodeBytes(
    Archive()
      ..addFile(pdf)
      ..addFile(evidence),
  );

  if (!_contains(bytes, const [0x50, 0x4b, 0x01, 0x02]) ||
      !_contains(bytes, const [0x50, 0x4b, 0x05, 0x06])) {
    throw StateError('ZIP central directory has invalid byte order.');
  }
  final decoded = ZipDecoder().decodeBytes(bytes);
  if (decoded.findFile('agreement.pdf') == null ||
      decoded.findFile('evidence.civiltrust.json') == null) {
    throw StateError('ZIP entries are missing.');
  }
  // ignore: avoid_print
  print('WEB_ZIP_OK entries=${decoded.length} bytes=${bytes.length}');
  // ignore: avoid_print
  print('WEB_ZIP_BASE64=${base64Encode(bytes)}');
}

bool _contains(List<int> bytes, List<int> pattern) {
  for (var offset = 0; offset <= bytes.length - pattern.length; offset++) {
    var matches = true;
    for (var index = 0; index < pattern.length; index++) {
      if (bytes[offset + index] != pattern[index]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}

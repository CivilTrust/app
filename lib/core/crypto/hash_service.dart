import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/digests/keccak.dart';

import '../encoding/encoding_utils.dart';

class HashService {
  const HashService();

  Uint8List keccakBytes(List<int> bytes) =>
      KeccakDigest(256).process(Uint8List.fromList(bytes));

  String keccakHex(List<int> bytes) => bytesToHex(keccakBytes(bytes));

  String canonicalObjectHash(Map<String, Object?> value) =>
      keccakHex(utf8.encode(canonicalJson(value)));
}

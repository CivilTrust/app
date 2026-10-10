import 'dart:math';

/// Generates an opaque local agreement id without relying on 32-bit shifts.
///
/// Dart compiled to JavaScript applies JavaScript's 32-bit shift semantics, so
/// `1 << 32` becomes zero and cannot be passed to [Random.nextInt].
String createAgreementId({Random? random, DateTime? now}) {
  final source = random ?? Random.secure();
  final timestamp = (now ?? DateTime.now()).toUtc().microsecondsSinceEpoch;
  final first = source.nextInt(0x7fffffff).toRadixString(16).padLeft(8, '0');
  final second = source.nextInt(0x7fffffff).toRadixString(16).padLeft(8, '0');
  return '$timestamp-$first$second';
}

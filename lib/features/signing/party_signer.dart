import 'dart:typed_data';

import '../../core/models/identity_evidence.dart';
import '../../core/models/party_signature.dart';
import 'signing_context.dart';

abstract interface class PartySigner {
  Future<PartySignature> sign({
    required String role,
    required Uint8List digest,
    required IdentityEvidence identity,
    SigningContext? context,
  });

  Future<bool> verify(PartySignature signature);
}

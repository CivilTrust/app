import 'dart:convert';

import '../../core/crypto/hash_service.dart';
import '../../core/models/identity_evidence.dart';
import 'identity_reader.dart';

class MockIdentityReader implements IdentityReader {
  MockIdentityReader({this._hashService = const HashService()});

  final HashService _hashService;
  bool _cancelled = false;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<IdentityEvidence> read({required String role}) async {
    _cancelled = false;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (_cancelled) throw const IdentityReaderException('Đã hủy đọc CCCD');
    final normalizedRole = role.toLowerCase() == 'partyb' ? 'B' : 'A';
    final fullNumber = normalizedRole == 'A' ? '001099000001' : '001099000002';
    final name = normalizedRole == 'A' ? 'NGUYEN VAN AN' : 'TRAN THI BINH';
    final commitment = _hashService.keccakHex(
      utf8.encode('$fullNumber|$name|mock-civiltrust-v1'),
    );
    return IdentityEvidence(
      source: 'mock',
      displayName: name,
      documentNumberMasked:
          '********${fullNumber.substring(fullNumber.length - 4)}',
      readAt: DateTime.now().toUtc(),
      chipAuthentication: 'mock',
      identityCommitment: commitment,
      attributes: {
        'fullName': name,
        'dateOfBirth': normalizedRole == 'A' ? '15/08/1995' : '22/03/1997',
        'documentNumber': fullNumber,
        'issuedDate': '01/07/2021',
        'issuedBy': 'Cục Cảnh sát QLHC về TTXH',
        'permanentAddress': normalizedRole == 'A'
            ? 'Cầu Giấy, Hà Nội'
            : 'Nam Từ Liêm, Hà Nội',
        'currentAddress': normalizedRole == 'A'
            ? 'Cầu Giấy, Hà Nội'
            : 'Nam Từ Liêm, Hà Nội',
      },
    );
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
  }
}

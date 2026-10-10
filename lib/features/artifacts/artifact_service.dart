import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/crypto/hash_service.dart';
import '../../core/encoding/encoding_utils.dart';
import '../../core/formatting/display_formatters.dart';
import '../../core/models/agreement.dart';
import 'evidence_manifest.dart';

class ArtifactBundle {
  const ArtifactBundle({
    required this.pdf,
    required this.evidence,
    required this.zip,
  });
  final Uint8List pdf;
  final EvidenceManifest evidence;
  final Uint8List zip;
}

class ArtifactService {
  ArtifactService(
    this._hash, {
    Future<pw.Font> Function()? regularFont,
    Future<pw.Font> Function()? boldFont,
  }) : _regularFont = regularFont ?? PdfGoogleFonts.notoSansRegular,
       _boldFont = boldFont ?? PdfGoogleFonts.notoSansBold;
  final HashService _hash;
  final Future<pw.Font> Function() _regularFont;
  final Future<pw.Font> Function() _boldFont;

  Future<ArtifactBundle> build(SigningSession session) async {
    if (session.partyA == null ||
        session.partyB == null ||
        session.payment == null) {
      throw StateError('Cần đủ hai chữ ký và xác nhận thanh toán.');
    }
    final evidenceHash = _hash.keccakHex(
      utf8.encode(canonicalJson(session.toJson())),
    );
    final pdf = await _buildPdf(session, evidenceHash);
    final documentHash = _hash.keccakHex(pdf);
    final evidence = EvidenceManifest(
      documentHash: documentHash,
      evidenceHash: evidenceHash,
      session: session.copyWith(state: AgreementState.committedPendingAnchor),
    );
    final evidenceBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(evidence.toJson()),
    );
    final archive = Archive()
      ..addFile(_storedFile('agreement.pdf', pdf))
      ..addFile(_storedFile('evidence.civiltrust.json', evidenceBytes));
    return ArtifactBundle(
      pdf: pdf,
      evidence: evidence,
      zip: Uint8List.fromList(ZipEncoder().encodeBytes(archive)),
    );
  }

  ArtifactBundle attachNotary(ArtifactBundle bundle, Map<String, dynamic> sct) {
    final evidence = EvidenceManifest(
      documentHash: bundle.evidence.documentHash,
      evidenceHash: bundle.evidence.evidenceHash,
      session: bundle.evidence.session,
      signedCommitment: sct,
      merkleProof: bundle.evidence.merkleProof,
    );
    final bytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(evidence.toJson()),
    );
    final archive = Archive()
      ..addFile(_storedFile('agreement.pdf', bundle.pdf))
      ..addFile(_storedFile('evidence.civiltrust.json', bytes));
    return ArtifactBundle(
      pdf: bundle.pdf,
      evidence: evidence,
      zip: Uint8List.fromList(ZipEncoder().encodeBytes(archive)),
    );
  }

  Future<Uint8List> _buildPdf(
    SigningSession session,
    String evidenceHash,
  ) async {
    final regular = await _regularFont();
    final bold = await _boldFont();
    final doc = pw.Document();
    final d = session.draft;
    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Header(level: 0, child: pw.Text('THỎA THUẬN ĐIỆN TỬ CIVILTRUST')),
          pw.Text(d.title, style: pw.TextStyle(font: bold, fontSize: 16)),
          pw.Text(
            'Mẫu dữ liệu: ${d.templateId}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),
          pw.Text(d.terms),
          pw.SizedBox(height: 12),
          pw.Text('Giá trị giao dịch: ${DisplayFormatters.vnd(d.amountVnd)}'),
          pw.Divider(),
          _signatureBlock(
            'Bên A',
            session.partyA!.identity,
            session.partyA!.signedAt,
          ),
          _signatureBlock(
            'Bên B',
            session.partyB!.identity,
            session.partyB!.signedAt,
          ),
          pw.Text('Thanh toán/nhận tiền: ${session.payment!.reference}'),
          pw.Text(
            'Xác nhận lúc: ${session.payment!.confirmedAt.toUtc().toIso8601String()}',
          ),
          pw.Divider(),
          pw.Text('Mã nội dung đã ký: ${session.frozenDigest}'),
          pw.Text('Mã evidence trước khi gửi Notary: $evidenceHash'),
          pw.SizedBox(height: 8),
          pw.Text(
            'Bản PDF này là hiện vật bất biến. SCT và Merkle proof được lưu trong '
            'evidence.civiltrust.json để tránh vòng lặp hash. Chữ ký A/B xác thực '
            'digest nội dung đã khóa; xác nhận nhận tiền là ghi nhận riêng của Bên A.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _signatureBlock(
    String label,
    Map<String, dynamic> identity,
    DateTime at,
  ) {
    final attributes = identity['attributes'] is Map
        ? Map<String, dynamic>.from(identity['attributes'] as Map)
        : const <String, dynamic>{};
    String value(String key) => attributes[key]?.toString() ?? '';

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '$label: ${identity['displayName'] ?? 'Chưa rõ'}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          if (value('dateOfBirth').isNotEmpty)
            pw.Text('Ngày sinh: ${value('dateOfBirth')}'),
          if (value('documentNumber').isNotEmpty)
            pw.Text('Số CCCD: ${value('documentNumber')}'),
          if (value('issuedDate').isNotEmpty || value('issuedBy').isNotEmpty)
            pw.Text(
              'Cấp ngày: ${value('issuedDate')} · Nơi cấp: ${value('issuedBy')}',
            ),
          if (value('permanentAddress').isNotEmpty)
            pw.Text('Thường trú: ${value('permanentAddress')}'),
          if (value('currentAddress').isNotEmpty)
            pw.Text('Nơi ở hiện tại: ${value('currentAddress')}'),
          pw.Text('CCCD commitment: ${identity['identityCommitment'] ?? ''}'),
          pw.Text('Ký lúc: ${at.toUtc().toIso8601String()}'),
        ],
      ),
    );
  }

  EvidenceManifest importZip(Uint8List bytes) {
    if (!_containsBytes(bytes, const [0x50, 0x4b, 0x05, 0x06])) {
      throw const FormatException(
        'ZIP bị hỏng hoặc là gói cũ tạo từ Flutter Web. Hãy hoàn tất lại '
        'thỏa thuận để tải gói ZIP mới.',
      );
    }
    final archive = ZipDecoder().decodeBytes(bytes);
    final pdfFile = _findFile(archive, 'agreement.pdf');
    final evidenceFile = _findFile(archive, 'evidence.civiltrust.json');
    if (pdfFile == null || evidenceFile == null) {
      throw const FormatException(
        'ZIP thiếu agreement.pdf hoặc evidence.civiltrust.json',
      );
    }
    final manifest = EvidenceManifest.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(utf8.decode(evidenceFile.content as List<int>)) as Map,
      ),
    );
    final actual = _hash.keccakHex(pdfFile.content as List<int>);
    if (actual != manifest.documentHash) {
      throw const FormatException('Hash agreement.pdf không khớp evidence.');
    }
    final actualEvidence = _hash.keccakHex(
      utf8.encode(
        canonicalJson(
          manifest.session
              .copyWith(state: AgreementState.paymentConfirmed)
              .toJson(),
        ),
      ),
    );
    if (actualEvidence != manifest.evidenceHash) {
      throw const FormatException('Evidence đã bị thay đổi.');
    }
    return manifest;
  }

  /// Store mode avoids an archive 4.4.0 Web deflate byte-order bug that
  /// corrupts the ZIP central directory. PDF bytes are already compressed.
  ArchiveFile _storedFile(String name, List<int> bytes) =>
      ArchiveFile.bytes(name, bytes)..compression = CompressionType.none;

  ArchiveFile? _findFile(Archive archive, String expectedName) {
    final exact = archive.findFile(expectedName);
    if (exact != null) return exact;
    final matches = archive.files.where((file) {
      final normalized = file.name.replaceAll('\\', '/');
      return file.isFile && normalized.split('/').last == expectedName;
    }).toList();
    return matches.length == 1 ? matches.single : null;
  }

  bool _containsBytes(List<int> bytes, List<int> pattern) {
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
}

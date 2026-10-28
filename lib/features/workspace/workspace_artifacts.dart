import 'dart:typed_data';

import '../../core/config/app_config.dart';
import '../../core/crypto/hash_service.dart';
import '../../core/encoding/encoding_utils.dart';
import '../../core/models/agreement.dart';
import '../artifacts/artifact_service.dart';
import '../notary/notary_client.dart';
import '../notary/sct_verifier.dart';
import 'workspace_service.dart';

class WorkspaceArtifacts {
  WorkspaceArtifacts(this.workspace, this.config, {ArtifactService? artifacts})
    : artifacts = artifacts ?? ArtifactService(const HashService());
  final WorkspaceService workspace;
  final AppConfig config;
  final ArtifactService artifacts;

  Future<ArtifactBundle> _checked(
    String id,
    Map<String, dynamic> archive,
  ) async {
    final bytes = base64UrlDecodeNoPadding(archive['zip'] as String);
    final bundle = artifacts.restoreBundle(Uint8List.fromList(bytes));
    await workspace.validator.validate(
      bundle.evidence.session,
      requirePartyB: true,
    );
    final current = workspace.session(workspace.record(id));
    if (bundle.evidence.documentHash != archive['documentHash'] ||
        canonicalJson(
              bundle.evidence.session
                  .copyWith(state: AgreementState.paymentConfirmed)
                  .toJson(),
            ) !=
            canonicalJson(
              current.copyWith(state: AgreementState.paymentConfirmed).toJson(),
            )) {
      throw const FormatException(
        'ZIP không khớp đúng phiên đã ký và xác nhận.',
      );
    }
    return bundle;
  }

  Future<ArtifactBundle> local(String id) => _checked(
    id,
    Map<String, dynamic>.from(workspace.record(id)['archive'] as Map),
  );

  Future<ArtifactBundle> finalize(String id) async {
    var record = workspace.record(id);
    if (record['role'] != 'partyA') {
      throw StateError('Chỉ bên nhận A tạo hồ sơ cuối.');
    }
    final current = workspace.session(record);
    if (current.state != AgreementState.paymentConfirmed) {
      throw StateError('A chưa xác nhận nhận tiền.');
    }
    await workspace.validator.validate(current, requirePartyB: true);
    var bundle = record['archive'] == null
        ? await artifacts.build(current)
        : await local(id);
    // This write completes BEFORE notary or remote finalization. Never regenerate
    // PDF bytes after a network error once the original exists in the vault.
    var archive = <String, dynamic>{
      'zip': base64UrlNoPadding(bundle.zip),
      'documentHash': bundle.evidence.documentHash,
      'note': config.notaryEnabled
          ? 'Chưa nhận SCT'
          : 'Notary đã tắt; ZIP offline, không có SCT.',
    };
    await workspace.vault.put(id, {...record, 'archive': archive});
    if (config.notaryEnabled && bundle.evidence.signedCommitment == null) {
      try {
        final sct = await NotaryClient(config.notaryBaseUrl)
            .submit(bundle.evidence.documentHash);
        final result = const SctVerifier().verify(
          sct,
          documentHash: bundle.evidence.documentHash,
          policy: config.sctTrustPolicy,
        );
        if (result.status == SctVerificationStatus.invalid ||
            result.status == SctVerificationStatus.unsupported) {
          throw const FormatException('SCT không hợp lệ hoặc chưa hỗ trợ');
        }
        bundle = artifacts.attachNotary(bundle, sct.toJson());
        archive = {
          ...archive,
          'zip': base64UrlNoPadding(bundle.zip),
          'note': result.status == SctVerificationStatus.valid
              ? 'SCT hợp lệ theo trust policy'
              : 'Có SCT; chưa cấu hình trust policy để kết luận hợp lệ.',
        };
      } catch (_) {
        archive = {
          ...archive,
          'note': 'Chưa có SCT kiểm chứng được; giữ nguyên PDF/ZIP offline. Không khẳng định đã neo.',
        };
      }
      await workspace.vault.put(id, {
        ...workspace.record(id),
        'archive': archive,
      });
    }
    record = workspace.record(id);
    if (record['finalized'] != true) await workspace.publish(id, archive);
    return bundle;
  }

  Future<ArtifactBundle> fetch(String id) async {
    final record = workspace.record(id);
    final archive = await workspace.repository.artifact(record);
    final bundle = await _checked(id, archive);
    await workspace.vault.put(id, {
      ...workspace.record(id),
      'archive': archive,
    });
    return bundle;
  }
}

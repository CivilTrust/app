import 'dart:typed_data';

import '../../core/config/app_config.dart';
import '../../core/crypto/hash_service.dart';
import '../../core/encoding/encoding_utils.dart';
import '../../core/models/agreement.dart';
import '../artifacts/artifact_service.dart';
import '../notary/notary_client.dart';
import '../notary/sct_verifier.dart';
import 'workspace_service.dart';
import 'workflow_rules.dart';
import 'payer_proposal.dart';

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
    if (WorkflowRules.isPayerProposal(current.draft)) {
      final archived = bundle.evidence.session;
      if (bundle.evidence.documentHash != archive['documentHash'] ||
          bundle.evidence.signedSnapshotHash !=
              const HashService().canonicalObjectHash(
                signedSnapshot(current).toJson(),
              ) ||
          archived.events.length > current.events.length ||
          canonicalJson(archived.events) !=
              canonicalJson(
                current.events.take(archived.events.length).toList(),
              )) {
        throw const FormatException('ZIP không khớp lịch sử hợp đồng này.');
      }
      return bundle;
    }
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
    if (record['finalized'] == true) {
      if (WorkflowRules.isPayerProposal(workspace.session(record).draft)) {
        return record['archiveFinalized'] == true ? local(id) : fetch(id);
      }
      return record['archive'] == null ? fetch(id) : local(id);
    }
    if (WorkflowRules.isPayerProposal(workspace.session(record).draft)) {
      return _finalizePayer(id);
    }
    if (record['pending'] != null) {
      throw StateError(
        'Hãy làm mới để kiểm tra kết quả công bố trước khi thử lại.',
      );
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

  Map<String, dynamic> _archive(ArtifactBundle bundle, String note) => {
    'zip': base64UrlNoPadding(bundle.zip),
    'documentHash': bundle.evidence.documentHash,
    'note': note,
  };

  /// B persists the original before publish. Both roles derive later evidence
  /// snapshots from these same PDF bytes, never from a second PDF render.
  Future<ArtifactBundle> savePayerStage(String id) async {
    var record = workspace.record(id);
    if (record['finalized'] == true) {
      return record['archiveFinalized'] == true ? local(id) : fetch(id);
    }
    final current = workspace.session(record);
    if (!WorkflowRules.isPayerProposal(current.draft) ||
        current.partyA == null ||
        current.partyB == null) {
      throw StateError('Chưa đủ hai chữ ký.');
    }
    await workspace.validator.validate(current, requirePartyB: true);
    ArtifactBundle original;
    if (record['signedArchive'] != null) {
      original = await _checked(
        id,
        Map<String, dynamic>.from(record['signedArchive'] as Map),
      );
    } else if (record['signedArtifactReady'] == true ||
        record['finalized'] == true) {
      workspace.ensureEndpoint(record);
      original = await _checked(
        id,
        await workspace.repository.artifact(record),
      );
    } else {
      if (record['role'] != 'partyB') {
        throw StateError(
          'Chờ B lưu bản PDF nguyên gốc; không tạo bản PDF khác trên thiết bị A.',
        );
      }
      original = await artifacts.build(signedSnapshot(current));
    }
    final base = _archive(
      original,
      'PDF hợp đồng đã ký nguyên bản; không phải xác nhận thanh toán.',
    );
    await workspace.vault.put(id, {
      ...workspace.record(id),
      'signedArchive': base,
    });
    if (record['signedArtifactReady'] != true && record['role'] == 'partyB') {
      await workspace.publishSigned(id, Map<String, Object?>.from(base));
    }
    record = workspace.record(id);
    final result = artifacts.updatePayerEvidence(
      original,
      workspace.session(record),
    );
    await workspace.vault.put(id, {
      ...record,
      'archive': _archive(
        result,
        'Gói bằng chứng tại trạng thái hiện tại; PDF không đổi. Chứng từ B và xác nhận A là tự khai. Chưa có SCT/proof nếu không đính kèm.',
      ),
    });
    return result;
  }

  Future<ArtifactBundle> _finalizePayer(String id) async {
    final record = workspace.record(id);
    if (workspace.session(record).state != AgreementState.paymentConfirmed ||
        record['pending'] != null) {
      throw StateError(
        'Cần A xác nhận nhận đủ và làm mới trước khi công bố cuối.',
      );
    }
    var result = await savePayerStage(id);
    String note =
        'PDF nguyên bản; A tự xác nhận nhận tiền. Notary đã tắt, không có SCT.';
    if (config.notaryEnabled) {
      try {
        final sct = await NotaryClient(config.notaryBaseUrl)
            .submit(result.evidence.documentHash);
        final status = const SctVerifier()
            .verify(
              sct,
              documentHash: result.evidence.documentHash,
              policy: config.sctTrustPolicy,
            )
            .status;
        if (status == SctVerificationStatus.invalid ||
            status == SctVerificationStatus.unsupported) {
          throw const FormatException('SCT không hợp lệ.');
        }
        result = artifacts.attachNotary(result, sct.toJson());
        note = status == SctVerificationStatus.valid
            ? 'SCT hợp lệ theo trust policy; thanh toán do A xác nhận.'
            : 'Có SCT, chưa cấu hình trust policy; không khẳng định đã neo.';
      } catch (_) {
        note = 'Chưa có SCT kiểm chứng được; giữ hồ sơ offline, không khẳng định đã neo.';
      }
    }
    final archive = _archive(result, note);
    await workspace.vault.put(id, {
      ...workspace.record(id),
      'archive': archive,
    });
    await workspace.publish(id, Map<String, Object?>.from(archive));
    await workspace.vault.put(id, {
      ...workspace.record(id),
      'archiveFinalized': true,
    });
    return result;
  }

  Future<ArtifactBundle> fetch(String id) async {
    final record = workspace.record(id);
    workspace.ensureEndpoint(record);
    final archive = await workspace.repository.artifact(record);
    final bundle = await _checked(id, archive);
    if (WorkflowRules.isPayerProposal(bundle.evidence.session.draft) &&
        record['finalized'] == true &&
        canonicalJson(bundle.evidence.session.toJson()) !=
            canonicalJson(workspace.session(record).toJson())) {
      throw const FormatException(
        'Gói cuối chưa khớp trạng thái xác nhận nhận tiền.',
      );
    }
    await workspace.vault.put(id, {
      ...workspace.record(id),
      'archive': archive,
      'archiveFinalized': record['finalized'] == true,
    });
    return bundle;
  }
}

import '../../core/crypto/hash_service.dart';
import '../../core/encoding/encoding_utils.dart';
import '../../core/models/agreement.dart';
import '../../core/models/identity_evidence.dart';
import '../../core/models/party_role.dart';
import '../../core/models/party_signature.dart';
import '../identity/identity_context.dart';
import '../identity/identity_service.dart';
import '../sessions/session_models.dart';
import '../signing/mock_party_signer.dart';
import '../signing/session_validator.dart';
import '../signing/signing_context.dart';
import 'agreement_vault.dart';
import 'workflow_engine.dart';
import 'workflow_event.dart';
import 'workflow_rules.dart';
import 'workspace_repository.dart';

class WorkspaceService {
  WorkspaceService(this.vault, this.repository);
  final AgreementVault vault;
  final WorkspaceRepository repository;
  final validator = SessionValidator(const HashService(), MockPartySigner());

  Map<String, dynamic> record(String localId) => vault.records.firstWhere(
    (r) => r['localId'] == localId,
    orElse: () => throw StateError('Không có hồ sơ trong kho đã mở.'),
  );
  SigningSession session(Map<String, dynamic> record) =>
      SigningSession.fromJson(
        Map<String, dynamic>.from(record['session'] as Map),
      );

  Future<Map<String, dynamic>> create(AgreementDraft draft) async {
    if (!vault.unlocked) throw StateError('Mở kho trước khi tạo phiên.');
    final role = WorkflowRules.creator(draft);
    final state = SigningSession(draft: draft, state: AgreementState.draft);
    await validator.validate(state);
    final id = createIdentityNonce(), actionKey = await WorkflowKey.create();
    final saved = <String, dynamic>{
      'localId': '$id:${role.name}',
      'sessionId': id,
      'role': role.name,
      'isOwner': true,
      'token': createIdentityNonce(),
      'participantToken': createIdentityNonce(),
      'key': createIdentityNonce(),
      'actionSeed': base64UrlNoPadding(actionKey.seed),
      'version': 0,
      'session': state.toJson(),
      'finalized': false,
      'endpoint': repository.baseUrl,
    };
    await vault.put(saved['localId'] as String, saved);
    await repository.create(saved);
    return sync(saved['localId'] as String);
  }

  Future<Map<String, dynamic>> resumeCreation(String id) async {
    final saved = record(id);
    if (saved['version'] != 0 || saved['isOwner'] != true) {
      throw StateError('Không phải yêu cầu tạo đang chờ.');
    }
    await repository.create(saved);
    return sync(id);
  }

  Future<Map<String, dynamic>> join(SessionCapabilities invitation) async {
    if (!vault.unlocked) throw StateError('Mở kho trước khi tham gia.');
    if (invitation.isOwner ||
        invitation.workflowProfile != WorkflowRules.profile) {
      throw const FormatException('Không phải lời mời workflow mới.');
    }
    final key = await WorkflowKey.create();
    final candidate = <String, dynamic>{
      'sessionId': invitation.sessionId,
      'token': invitation.token,
      'key': base64UrlNoPadding(invitation.encryptionKey),
      'isOwner': false,
      'actionSeed': base64UrlNoPadding(key.seed),
    };
    final snapshot = await repository.read(candidate);
    await validator.validate(snapshot.session);
    final id = '${invitation.sessionId}:${snapshot.role.name}';
    final existing = vault.records.where((r) => r['localId'] == id).firstOrNull;
    if (existing != null) return sync(id);
    final saved = {
      ...candidate,
      'localId': id,
      'role': snapshot.role.name,
      'endpoint': repository.baseUrl,
    };
    await _saveSnapshot(saved, snapshot);
    return record(id);
  }

  Future<void> _saveSnapshot(
    Map<String, dynamic> local,
    WorkspaceSnapshot snapshot,
  ) async {
    final key = WorkflowKey(
      base64UrlDecodeNoPadding(local['actionSeed'] as String),
    );
    final registered = snapshot.keys[snapshot.role.name];
    await vault.put(local['localId'] as String, {
      ...local,
      'role': snapshot.role.name,
      'session': snapshot.session.toJson(),
      'version': snapshot.version,
      'expiresAt': snapshot.expiresAt.toIso8601String(),
      'lastSyncedAt': DateTime.now().toUtc().toIso8601String(),
      'finalized': snapshot.finalized,
      'pending': null,
      'registeredKeys': snapshot.keys,
      'readOnly': registered != null && registered != await key.publicKey,
    });
  }

  Future<Map<String, dynamic>> sync(String id) async {
    final local = record(id);
    _checkEndpoint(local);
    final snapshot = await repository.read(local);
    await validator.validate(snapshot.session);
    if (snapshot.version < (local['version'] as int) ||
        snapshot.role.name != local['role']) {
      throw const FormatException(
        'Server trả snapshot cũ hoặc sai vai trò; giữ nguyên bản cục bộ.',
      );
    }
    await _saveSnapshot(local, snapshot);
    return record(id);
  }

  void _checkEndpoint(Map<String, dynamic> record) {
    if (record['endpoint'] != repository.baseUrl) {
      throw StateError(
        'Hồ sơ thuộc coordinator khác. Không gửi capability tới URL khác; cần xác nhận cấu hình/migration với nhóm.',
      );
    }
  }

  String invite(Map<String, dynamic> local) {
    if (local['isOwner'] != true) {
      throw StateError('Chỉ người tạo có lời mời đối tác.');
    }
    return SessionCapabilities(
      sessionId: local['sessionId'] as String,
      token: local['participantToken'] as String,
      encryptionKey: base64UrlDecodeNoPadding(local['key'] as String),
      isOwner: false,
      workflowProfile: WorkflowRules.profile,
    ).toInviteFragment();
  }

  Future<Map<String, dynamic>> act(
    String id,
    WorkflowAction action, {
    IdentityService? identityService,
    bool consent = false,
    Map<String, String>? bankFields,
    String? paymentReference,
  }) async {
    final local = record(id);
    _checkEndpoint(local);
    if (local['readOnly'] == true) {
      throw StateError(
        'Thiếu khóa hành động gốc. Nhập gói khôi phục từ thiết bị đã thao tác; vẫn có thể xem hồ sơ.',
      );
    }
    if (local['pending'] != null) {
      throw StateError(
        'Có thao tác chưa xác nhận. Hãy làm mới để kiểm trạng thái trước.',
      );
    }
    if (local['version'] == 0 || local['finalized'] == true) {
      throw StateError('Phiên chưa được tạo hoặc đã đóng.');
    }
    var current = session(local);
    final role = PartyRole.values.byName(local['role'] as String);
    WorkflowRules.next(
      current.state,
      role,
      WorkflowRules.creator(current.draft),
      action,
    );
    final key = WorkflowKey(
      base64UrlDecodeNoPadding(local['actionSeed'] as String),
    );
    if (action == WorkflowAction.approve && bankFields != null) {
      final draft = current.draft;
      current = SigningSession(
        state: AgreementState.draft,
        draft: AgreementDraft(
          id: draft.id,
          title: draft.title,
          terms: draft.terms,
          amountVnd: draft.amountVnd,
          createdAt: draft.createdAt,
          templateId: draft.templateId,
          fields: {
            ...draft.fields,
            for (final name in ['bankBin', 'accountNumber', 'accountName'])
              name: bankFields[name] ?? draft.fields[name] ?? '',
          },
        ),
      );
    }
    await validator.validate(current);
    PartySignature? signature;
    if (action == WorkflowAction.sign) {
      if (!consent || identityService == null) {
        throw StateError(
          'Cần đồng ý đọc danh tính và ký đúng nội dung đang hiển thị.',
        );
      }
      final identity = await identityService.identify(
        context: IdentityContext.create(
          ceremonyId: current.draft.fields['identityCeremonyId']!,
          role: role.name,
        ),
        consent: consent,
      );
      final json = Map<String, dynamic>.from(identity.toJson());
      json['attributes'] = {
        ...identity.attributes,
        'workspaceActionKey': await key.publicKey,
      };
      if (role == WorkflowRules.creator(current.draft) &&
          current.draft.fields['creatorIdentityCommitment'] !=
              identity.identityCommitment) {
        throw const FormatException(
          'Danh tính người tạo thay đổi. Cần tạo đề xuất mới, không ký lên thông tin cũ.',
        );
      }
      signature = await MockPartySigner().sign(
        role: role.name,
        digest: hexToBytes(
          const HashService().canonicalObjectHash(current.draft.toJson()),
        ),
        identity: IdentityEvidence.fromJson(json),
        context: SigningContext.fromDraft(current.draft),
      );
    }
    final next = await WorkflowEngine.apply(
      current,
      role,
      key,
      action,
      signature: signature,
      paymentReference: paymentReference,
    );
    await validator.validate(next);
    await _mutate(local, next, action.name);
    return record(id);
  }

  Future<void> _mutate(
    Map<String, dynamic> local,
    SigningSession next,
    String action, {
    Map<String, Object?>? artifact,
  }) async {
    final id = local['localId'] as String;
    // Persist the exact signed intent before network I/O. On ambiguous failure
    // require explicit refresh/review, never automatically re-sign.
    await vault.put(id, {
      ...local,
      'pending': {'action': action, 'session': next.toJson()},
    });
    await repository.apply(local, next, action, encryptedArtifact: artifact);
    await sync(id);
  }

  Future<void> publish(String id, Map<String, Object?> archive) async {
    final local = record(id);
    _checkEndpoint(local);
    final current = session(local);
    if (local['role'] != 'partyA' ||
        current.state != AgreementState.paymentConfirmed ||
        local['readOnly'] == true) {
      throw StateError('Chỉ A được xuất hồ sơ sau khi xác nhận nhận tiền.');
    }
    await validator.validate(current, requirePartyB: true);
    final box = await repository.cipher.encrypt(
      archive,
      base64UrlDecodeNoPadding(local['key'] as String),
    );
    await _mutate(local, current, 'publishArtifact', artifact: box.toJson());
  }
}

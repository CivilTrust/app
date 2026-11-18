import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/agreement.dart';
import 'workspace_overview.dart';
import 'workspace_service.dart';

/// In-app notification about a remote change to one agreement.
class AppNotification {
  AppNotification({
    required this.localId,
    required this.title,
    required this.message,
    required this.at,
    required this.needsAction,
  });
  final String localId;
  final String title;
  final String message;
  final DateTime at;
  final bool needsAction;
  bool read = false;
}

/// Periodically checks open agreements for changes made by the other party.
///
/// Read-only by design: it decrypts and verifies the remote snapshot exactly
/// like a refresh, but never writes to the vault. The detail page performs
/// the real sync when the user opens the record, so polling cannot race with
/// an action the user is taking.
///
/// Only records bound to the configured coordinator are polled, so bearer
/// capabilities are never sent to another endpoint. Notifications live in
/// memory and are cleared when the vault locks.
class WorkspaceWatcher extends ChangeNotifier {
  WorkspaceWatcher(
    this.service, {
    this.interval = const Duration(seconds: 45),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    service.vault.addListener(_vaultChanged);
    _vaultChanged();
  }

  final WorkspaceService service;
  final Duration interval;
  final DateTime Function() _clock;
  final List<AppNotification> _items = [];
  final Map<String, int> _seen = {};
  final Set<String> _updated = {};
  Timer? _timer;
  bool _checking = false;
  bool _active = true;
  bool _disposed = false;
  bool _wasUnlocked = false;

  List<AppNotification> get notifications => List.unmodifiable(_items);
  int get unread => _items.where((n) => !n.read).length;

  /// Records whose remote version is newer than the stored copy.
  bool hasUpdate(String localId) => _updated.contains(localId);

  /// Call when the app goes to background/foreground.
  void setActive(bool active) {
    if (active == _active) return;
    _active = active;
    _schedule();
    if (active) unawaited(checkNow());
  }

  /// Vault notifies on every write; only lock/unlock transitions matter here,
  /// otherwise frequent draft autosaves would keep postponing the timer.
  void _vaultChanged() {
    final unlocked = service.vault.unlocked;
    if (unlocked == _wasUnlocked) return;
    _wasUnlocked = unlocked;
    if (!unlocked) {
      _items.clear();
      _seen.clear();
      _updated.clear();
      if (!_disposed) notifyListeners();
    }
    _schedule();
    // Catch up on changes made while the vault was locked or the app closed.
    if (unlocked) unawaited(checkNow());
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (_disposed || !_active || !service.vault.unlocked) return;
    _timer = Timer.periodic(interval, (_) => checkNow());
  }

  bool _eligible(Map<String, dynamic> record) =>
      record['kind'] != 'form' &&
      record['submittedSession'] == null &&
      record['finalized'] != true &&
      record['pending'] == null &&
      record['version'] is int &&
      (record['version'] as int) > 0 &&
      record['endpoint'] == service.repository.baseUrl;

  /// The stored record was synced (e.g. the user opened it).
  void markSeen(String localId) {
    _updated.remove(localId);
    for (final item in _items.where((n) => n.localId == localId)) {
      item.read = true;
    }
    if (!_disposed) notifyListeners();
  }

  void markAllRead() {
    for (final item in _items) {
      item.read = true;
    }
    notifyListeners();
  }

  Future<void> checkNow() async {
    if (_checking || _disposed || !service.vault.unlocked) return;
    _checking = true;
    var changed = false;
    try {
      for (final record in service.vault.records.where(_eligible).toList()) {
        if (!service.vault.unlocked) break;
        final id = record['localId'] as String;
        final stored = record['version'] as int;
        final known = _seen[id] ?? stored;
        try {
          final snapshot = await service.repository.read(record);
          if (snapshot.version <= known) {
            if (snapshot.version <= stored) _updated.remove(id);
            continue;
          }
          await service.validator.validate(snapshot.session);
          _seen[id] = snapshot.version;
          _updated.add(id);
          final overview = overviewOf({
            ...record,
            'version': snapshot.version,
            'finalized': snapshot.finalized,
            'pending': null,
          }, snapshot.session);
          _items.insert(
            0,
            AppNotification(
              localId: id,
              title:
                  '${snapshot.session.draft.title} · ${agreementCode(snapshot.session.draft.id)}',
              message: _describe(snapshot.session, overview),
              at: _clock(),
              needsAction: overview.bucket == RecordBucket.action,
            ),
          );
          if (_items.length > 50) _items.removeRange(50, _items.length);
          changed = true;
        } catch (_) {
          // Network/validation errors are surfaced when the user opens the
          // record; polling stays silent to avoid noisy repeated alerts.
        }
      }
    } finally {
      _checking = false;
    }
    if (changed && !_disposed) notifyListeners();
  }

  String _describe(SigningSession session, RecordOverview overview) {
    final event = session.events.isEmpty
        ? null
        : Map<String, dynamic>.from(session.events.last['body'] as Map);
    final who = event?['role'] == 'partyA' ? 'Bên A' : 'Bên B';
    final what = switch (event?['action']) {
      'approve' => '$who đã khóa nội dung',
      'sign' => '$who đã ký',
      'reportTransfer' => '$who báo đã chuyển khoản',
      'confirmReceived' => '$who xác nhận đã nhận tiền',
      'requestChanges' => '$who đề nghị chỉnh sửa',
      'decline' => '$who đã từ chối đề xuất',
      'reportIssue' => '$who báo chưa thấy tiền',
      _ => 'Hợp đồng có cập nhật',
    };
    if (overview.bucket == RecordBucket.done &&
        overview.headline == 'Đã hoàn tất') {
      return '$what. Gói hồ sơ hoàn tất đã sẵn sàng để tải.';
    }
    return overview.bucket == RecordBucket.action
        ? '$what. Bạn cần: ${overview.headline.toLowerCase()}.'
        : '$what.';
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    service.vault.removeListener(_vaultChanged);
    super.dispose();
  }
}

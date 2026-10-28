import 'session_models.dart';

/// Paste works in a native app without relying on Uri.base/deep-link setup.
/// Decode locally; never navigate/fetch a host supplied by an invitation.
SessionCapabilities parseParticipantInvite(String input) {
  try {
    var value = input.trim();
    if (value.isEmpty || value.length > 8192) throw const FormatException();
    if (value.contains('://')) {
      final uri = Uri.parse(value);
      if (!{'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          !uri.fragment.startsWith('join=')) {
        throw const FormatException();
      }
      value = uri.fragment.substring(5);
    } else if (value.startsWith('join=')) {
      value = value.substring(5);
    }
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
      throw const FormatException();
    }
    final capability = SessionCapabilities.fromInviteFragment(value);
    if (capability.isOwner ||
        capability.encryptionKey.length != 32 ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(capability.sessionId) ||
        !RegExp(r'^[A-Za-z0-9_-]{16,256}$').hasMatch(capability.token)) {
      throw const FormatException();
    }
    return capability;
  } catch (_) {
    // Never interpolate the input, parser exception or capability in errors.
    throw const FormatException(
      'Mã mời không hợp lệ hoặc không phải quyền Bên B.',
    );
  }
}

/// Invite capabilities belong in the fragment, never in HTTP query strings.
/// Do not retain tracking queries or a previous invite when sharing a new one.
String buildInviteUrl(Uri pageUri, String fragment) => Uri(
  scheme: pageUri.scheme,
  host: pageUri.host,
  port: pageUri.hasPort ? pageUri.port : null,
  path: pageUri.path,
  fragment: 'join=$fragment',
).toString();

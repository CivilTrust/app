/// Invite capabilities belong in the fragment, never in HTTP query strings.
/// Do not retain tracking queries or a previous invite when sharing a new one.
String buildInviteUrl(Uri pageUri, String fragment) => Uri(
  scheme: pageUri.scheme,
  host: pageUri.host,
  port: pageUri.hasPort ? pageUri.port : null,
  path: pageUri.path,
  fragment: 'join=$fragment',
).toString();

import 'dart:convert';

class IapPrincipal {
  const IapPrincipal(
      {required this.subject,
      required this.issuer,
      required this.audience,
      required this.roles,
      required this.permissions,
      this.email,
      this.name});

  final String subject;
  final String issuer;
  final List<String> audience;
  final String? email;
  final String? name;
  final List<String> roles;
  final List<String> permissions;

  bool hasRole(String role) => roles.contains(role);
  bool hasAnyRole(Iterable<String> values) => values.any(hasRole);
  bool hasPermission(String permission) => permissions.contains(permission);
  bool hasAnyPermission(Iterable<String> values) => values.any(hasPermission);

  /// Decodes claims for UI visibility only. Signature and authorization must be
  /// enforced by the backend; a browser can modify its own UI state.
  factory IapPrincipal.fromAccessToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw const FormatException('invalid JWT');
    }
    final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('invalid JWT payload');
    }
    final ext = payload['ext'] is Map<String, dynamic>
        ? payload['ext'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final subject = payload['sub'];
    final issuer = payload['iss'];
    if (subject is! String || issuer is! String) {
      throw const FormatException('JWT is missing sub or iss');
    }
    return IapPrincipal(
      subject: subject,
      issuer: issuer,
      audience: _strings(payload['aud']),
      email: _string(payload['email']) ?? _string(ext['email']),
      name: _string(payload['name']) ?? _string(ext['name']),
      roles: _strings(ext['roles']),
      permissions: _strings(ext['permissions']),
    );
  }
}

String? _string(Object? value) => value is String ? value : null;
List<String> _strings(Object? value) {
  if (value is String) return [value];
  if (value is List) return value.whereType<String>().toList(growable: false);
  return const [];
}

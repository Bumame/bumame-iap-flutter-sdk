import 'dart:convert';

class IapPrincipal {
  const IapPrincipal(
      {required this.subject,
      required this.issuer,
      required this.audience,
      required this.roles,
      required this.permissions,
      this.resourceScopes = const {},
      this.email,
      this.name,
      this.picture});

  final String subject;
  final String issuer;
  final List<String> audience;
  final String? email;
  final String? name;
  final String? picture;
  final List<String> roles;
  final List<String> permissions;
  final Map<String, IapResourceScope> resourceScopes;

  bool hasRole(String role) => roles.contains(role);
  bool hasAnyRole(Iterable<String> values) => values.any(hasRole);
  bool hasPermission(String permission) => permissions.contains(permission);
  bool hasAnyPermission(Iterable<String> values) => values.any(hasPermission);
  bool hasResource(String type, String id) {
    final scope = resourceScopes[type];
    return scope != null &&
        (scope.mode == 'all' ||
            (scope.mode == 'selected' && scope.ids.contains(id)));
  }

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
      picture: _string(payload['picture']) ?? _string(ext['picture']),
      roles: _strings(ext['roles']),
      permissions: _strings(ext['permissions']),
      resourceScopes: _resourceScopes(
        ext['resource_scopes'] ?? payload['resource_scopes'],
      ),
    );
  }
}

class IapResourceScope {
  const IapResourceScope({required this.mode, required this.ids});

  final String mode;
  final List<String> ids;
}

String? _string(Object? value) => value is String ? value : null;
List<String> _strings(Object? value) {
  if (value is String) return [value];
  if (value is List) return value.whereType<String>().toList(growable: false);
  return const [];
}

Map<String, IapResourceScope> _resourceScopes(Object? value) {
  if (value is! Map) return const {};
  final result = <String, IapResourceScope>{};
  for (final entry in value.entries) {
    final raw = entry.value;
    if (entry.key is! String || raw is! Map) continue;
    final mode = _string(raw['mode']);
    if (mode != 'all' && mode != 'selected') continue;
    result[entry.key as String] = IapResourceScope(
      mode: mode!,
      ids: _strings(raw['ids']),
    );
  }
  return Map.unmodifiable(result);
}

/// Declares the permission requirement for one application route.
class IapPermissionRouteRule {
  final String path;
  final Set<String> permissions;
  final bool prefix;
  final bool requireAll;

  const IapPermissionRouteRule.exact(
    this.path,
    this.permissions, {
    this.requireAll = false,
  }) : prefix = false;

  const IapPermissionRouteRule.prefix(
    this.path,
    this.permissions, {
    this.requireAll = false,
  }) : prefix = true;

  bool matches(String candidate) {
    if (!prefix) return candidate == path;
    return candidate == path || candidate.startsWith('$path/');
  }

  bool allows(Set<String> grantedPermissions) {
    if (requireAll) return grantedPermissions.containsAll(permissions);
    return permissions.any(grantedPermissions.contains);
  }
}

/// Matches a route against its most-specific rule and evaluates permissions.
///
/// Routes without a rule are allowed so applications can keep public and
/// authentication-only pages outside their feature permission map. Backend
/// permission middleware remains the security boundary.
class IapPermissionRouteGuard {
  const IapPermissionRouteGuard(this.rules);

  final List<IapPermissionRouteRule> rules;

  bool canAccess(String path, Iterable<String> grantedPermissions) {
    final rule = _mostSpecificRule(path);
    if (rule == null) return true;
    return rule.allows(grantedPermissions.toSet());
  }

  IapPermissionRouteRule? _mostSpecificRule(String path) {
    IapPermissionRouteRule? result;
    for (final rule in rules) {
      if (!rule.matches(path)) continue;
      if (result == null || rule.path.length > result.path.length) {
        result = rule;
      }
    }
    return result;
  }
}

class IapConfig {
  IapConfig({
    required String issuer,
    required this.clientId,
    required this.audience,
    required this.redirectUri,
    this.postLogoutRedirectUri,
    this.scopes = const [
      'openid',
      'profile',
      'email',
      'roles',
      'offline_access'
    ],
  }) : issuer = issuer.trim().replaceFirst(RegExp(r'/$'), '') {
    if (this.issuer.isEmpty ||
        clientId.isEmpty ||
        audience.isEmpty ||
        redirectUri.isEmpty) {
      throw ArgumentError(
          'issuer, clientId, audience, and redirectUri are required');
    }
  }

  final String issuer;
  final String clientId;
  final String audience;
  final String redirectUri;
  final String? postLogoutRedirectUri;
  final List<String> scopes;
}

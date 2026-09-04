import 'auth_client.dart';
import 'principal.dart';
import 'token_store.dart';

/// The app-facing IAP session API. Apps use this instead of handling access
/// token storage, refresh-token rotation, or profile persistence themselves.
class IapSession {
  IapSession({required this.client, required this.tokenStore});

  final IapAuthClient client;
  final IapTokenStore tokenStore;

  Future<TokenSet?> tokens() => tokenStore.read();

  Future<IapPrincipal?> principal() async {
    final token = await accessToken(refreshIfNeeded: false);
    if (token == null) return null;
    try {
      return IapPrincipal.fromAccessToken(token);
    } on FormatException {
      await clear();
      return null;
    }
  }

  Future<String?> accessToken({
    bool refreshIfNeeded = true,
    Duration minimumValidity = const Duration(seconds: 30),
  }) async {
    final current = await tokenStore.read();
    if (current == null) return null;
    if (!refreshIfNeeded || !_needsRefresh(current, minimumValidity)) {
      return current.accessToken;
    }
    if (current.refreshToken == null || current.refreshToken!.isEmpty) {
      await clear();
      return null;
    }
    return (await client.refresh()).accessToken;
  }

  Future<String> refresh() async => (await client.refresh()).accessToken;

  Future<void> save(TokenSet tokens) => tokenStore.write(tokens);
  Future<void> clear() => tokenStore.clear();

  bool _needsRefresh(TokenSet tokens, Duration minimumValidity) {
    final expiresAt = tokens.expiresAt;
    if (expiresAt == null) return false;
    return !expiresAt.isAfter(DateTime.now().toUtc().add(minimumValidity));
  }
}

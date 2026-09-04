import 'auth_client.dart';
import 'principal.dart';
import 'token_store.dart';

/// The app-facing IAP session API. Apps use this instead of handling access
/// token storage, refresh-token rotation, or profile persistence themselves.
class IapSession {
  IapSession({required this.client, required this.tokenStore});

  final IapAuthClient client;
  final IapTokenStore tokenStore;
  Future<String>? _refreshing;

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
    return refresh();
  }

  Future<String> refresh() {
    final active = _refreshing;
    if (active != null) return active;
    final operation = client.refresh().then((tokens) => tokens.accessToken);
    _refreshing = operation;
    return operation.whenComplete(() => _refreshing = null);
  }

  Future<void> save(TokenSet tokens) => tokenStore.write(tokens);
  Future<void> clear() => tokenStore.clear();

  bool _needsRefresh(TokenSet tokens, Duration minimumValidity) {
    final expiresAt = tokens.expiresAt;
    if (expiresAt == null) return false;
    return !expiresAt.isAfter(DateTime.now().toUtc().add(minimumValidity));
  }
}

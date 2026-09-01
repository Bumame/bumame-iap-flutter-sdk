import 'auth_client.dart';

abstract interface class IapTokenStore {
  Future<TokenSet?> read();
  Future<void> write(TokenSet tokens);
  Future<void> clear();
}

/// Safe default for Flutter web: tokens disappear on refresh and are not placed
/// in localStorage. Applications that persist tokens should use a BFF with an
/// HttpOnly cookie instead of browser-readable storage.
class MemoryTokenStore implements IapTokenStore {
  TokenSet? _tokens;

  @override
  Future<TokenSet?> read() async => _tokens;
  @override
  Future<void> write(TokenSet tokens) async => _tokens = tokens;
  @override
  Future<void> clear() async => _tokens = null;
}

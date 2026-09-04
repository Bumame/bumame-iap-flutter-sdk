import 'auth_client.dart';

abstract interface class IapTokenStore {
  Future<TokenSet?> read();
  Future<void> write(TokenSet tokens);
  Future<void> clear();
}

/// In-memory default. Applications that persist tokens should use the SDK web
/// session store or, for stronger XSS isolation, a BFF with an HttpOnly cookie.
class MemoryTokenStore implements IapTokenStore {
  TokenSet? _tokens;

  @override
  Future<TokenSet?> read() async => _tokens;
  @override
  Future<void> write(TokenSet tokens) async => _tokens = tokens;
  @override
  Future<void> clear() async => _tokens = null;
}

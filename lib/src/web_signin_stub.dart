import 'auth_client.dart';
import 'config.dart';
import 'session.dart';
import 'token_store.dart';
import 'resource_context.dart';

/// Web-only. Importing the SDK in an Android/iOS build remains supported, but
/// browser redirect login must use a platform-specific sign-in flow.
class IapWebSignIn {
  factory IapWebSignIn({
    required IapConfig config,
    String storagePrefix = 'bumame_iap',
  }) {
    final store = MemoryTokenStore();
    return IapWebSignIn._(
      IapSession(
          client: IapAuthClient(config, tokenStore: store), tokenStore: store),
      IapResourceContext(),
    );
  }

  IapWebSignIn._(this.session, this.resourceContext);

  final IapSession session;
  final IapResourceContext resourceContext;
  bool get isCallback => false;
  Future<void> start() =>
      throw UnsupportedError('IapWebSignIn is only available on Flutter web');
  Future<TokenSet> complete() =>
      throw UnsupportedError('IapWebSignIn is only available on Flutter web');
  Future<void> reset() async {
    await session.clear();
    resourceContext.clear();
  }
}

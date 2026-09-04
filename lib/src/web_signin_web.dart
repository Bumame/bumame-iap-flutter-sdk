// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

import 'auth_client.dart';
import 'config.dart';
import 'session.dart';
import 'token_store.dart';
import 'resource_context.dart';

/// Browser redirect/PKCE flow. OAuth transaction state and token data are
/// isolated in sessionStorage, never localStorage. IAP's own secure cookie is
/// what provides SSO when a new browser session starts.
class IapWebSignIn {
  factory IapWebSignIn({
    required IapConfig config,
    String storagePrefix = 'bumame_iap',
  }) {
    final store = _WebSessionTokenStore('$storagePrefix.tokens');
    final client = IapAuthClient(config, tokenStore: store);
    final resourceKey = '$storagePrefix.resources';
    final resourceContext = IapResourceContext(
      initialHeaders: _readResourceHeaders(resourceKey),
      onChanged: (headers) =>
          html.window.sessionStorage[resourceKey] = jsonEncode(headers),
    );
    return IapWebSignIn._(
      storagePrefix: storagePrefix,
      store: store,
      session: IapSession(client: client, tokenStore: store),
      resourceContext: resourceContext,
    );
  }

  IapWebSignIn._({
    required this.storagePrefix,
    required _WebSessionTokenStore store,
    required this.session,
    required this.resourceContext,
  }) : _store = store;

  final String storagePrefix;
  final _WebSessionTokenStore _store;
  final IapSession session;
  final IapResourceContext resourceContext;

  bool get isCallback =>
      Uri.base.queryParameters.containsKey('code') ||
      Uri.base.queryParameters.containsKey('error');

  String get _transactionKey => '$storagePrefix.transaction';

  Future<void> start() async {
    final request = await session.client.createAuthorizationRequest();
    html.window.sessionStorage[_transactionKey] = jsonEncode({
      'uri': request.uri.toString(),
      'state': request.state,
      'nonce': request.nonce,
      'code_verifier': request.codeVerifier,
    });
    html.window.location.assign(request.uri.toString());
  }

  Future<TokenSet> complete() async {
    final callbackUri = Uri.base;
    final oauthError = callbackUri.queryParameters['error'];
    if (oauthError != null) {
      throw IapException(
        callbackUri.queryParameters['error_description'] ?? oauthError,
      );
    }
    final raw = html.window.sessionStorage[_transactionKey];
    if (raw == null) {
      throw const IapException('missing_authorization_transaction');
    }
    final transaction = jsonDecode(raw);
    if (transaction is! Map<String, dynamic>) {
      throw const IapException('invalid_authorization_transaction');
    }
    final tokens = await session.client.exchangeCode(
      callbackUri: callbackUri,
      request: AuthorizationRequest(
        uri: Uri.parse(transaction['uri'] as String),
        state: transaction['state'] as String,
        nonce: transaction['nonce'] as String,
        codeVerifier: transaction['code_verifier'] as String,
      ),
    );
    html.window.sessionStorage.remove(_transactionKey);
    html.window.history.replaceState(null, '', Uri.base.path);
    return tokens;
  }

  Future<void> reset() async {
    html.window.sessionStorage.remove(_transactionKey);
    await _store.clear();
    await session.clear();
    resourceContext.clear();
  }
}

Map<String, Object?> _readResourceHeaders(String key) {
  final raw = html.window.sessionStorage[key];
  if (raw == null || raw.isEmpty) return const {};
  try {
    final value = jsonDecode(raw);
    return value is Map<String, dynamic> ? value : const {};
  } catch (_) {
    return const {};
  }
}

class _WebSessionTokenStore implements IapTokenStore {
  _WebSessionTokenStore(this.key);
  final String key;

  @override
  Future<TokenSet?> read() async {
    final raw = html.window.sessionStorage[key];
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? TokenSet.fromJson(decoded)
          : null;
    } catch (_) {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(TokenSet tokens) async {
    html.window.sessionStorage[key] = jsonEncode(tokens.toJson());
  }

  @override
  Future<void> clear() async => html.window.sessionStorage.remove(key);
}

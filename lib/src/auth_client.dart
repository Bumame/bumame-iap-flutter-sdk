import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'token_store.dart';

class AuthorizationRequest {
  const AuthorizationRequest(
      {required this.uri,
      required this.state,
      required this.nonce,
      required this.codeVerifier});
  final Uri uri;
  final String state;
  final String nonce;
  final String codeVerifier;
}

class TokenSet {
  const TokenSet(
      {required this.accessToken,
      required this.tokenType,
      required this.expiresIn,
      this.refreshToken,
      this.idToken,
      this.scope,
      this.expiresAt});
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final String? refreshToken;
  final String? idToken;
  final String? scope;

  /// UTC expiry calculated when the token response is received. This is kept
  /// with the token store so an application can refresh before an API call.
  final DateTime? expiresAt;

  factory TokenSet.fromJson(Map<String, dynamic> json) {
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 0;
    final rawExpiresAt = json['expires_at'];
    final expiresAt = rawExpiresAt is String
        ? DateTime.tryParse(rawExpiresAt)?.toUtc()
        : DateTime.now().toUtc().add(Duration(seconds: expiresIn));
    return TokenSet(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiresIn: expiresIn,
      refreshToken: json['refresh_token'] as String?,
      idToken: json['id_token'] as String?,
      scope: json['scope'] as String?,
      expiresAt: expiresAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'token_type': tokenType,
        'expires_in': expiresIn,
        if (refreshToken != null) 'refresh_token': refreshToken,
        if (idToken != null) 'id_token': idToken,
        if (scope != null) 'scope': scope,
        if (expiresAt != null)
          'expires_at': expiresAt!.toUtc().toIso8601String(),
      };
}

class IapAuthClient {
  IapAuthClient(this.config,
      {http.Client? httpClient, IapTokenStore? tokenStore})
      : _http = httpClient ?? http.Client(),
        _store = tokenStore ?? MemoryTokenStore();

  final IapConfig config;
  final http.Client _http;
  final IapTokenStore _store;
  Map<String, dynamic>? _discovery;

  Future<Map<String, dynamic>> discover() async {
    if (_discovery != null) {
      return _discovery!;
    }
    final response = await _http
        .get(Uri.parse('${config.issuer}/.well-known/openid-configuration'));
    if (response.statusCode != 200) {
      throw IapException('discovery_failed', response.statusCode);
    }
    final value = jsonDecode(response.body);
    if (value is! Map<String, dynamic> ||
        value['issuer'] != config.issuer ||
        value['authorization_endpoint'] is! String ||
        value['token_endpoint'] is! String) {
      throw const FormatException('invalid IAP discovery document');
    }
    return _discovery = value;
  }

  Future<AuthorizationRequest> createAuthorizationRequest() async {
    final discovery = await discover();
    final state = _random(32);
    final nonce = _random(32);
    final verifier = _random(64);
    final challenge = base64Url
        .encode(sha256.convert(ascii.encode(verifier)).bytes)
        .replaceAll('=', '');
    final uri = Uri.parse(discovery['authorization_endpoint'] as String)
        .replace(queryParameters: {
      'response_type': 'code',
      'client_id': config.clientId,
      'redirect_uri': config.redirectUri,
      'scope': config.scopes.join(' '),
      'state': state,
      'nonce': nonce,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'audience': config.audience,
    });
    return AuthorizationRequest(
        uri: uri, state: state, nonce: nonce, codeVerifier: verifier);
  }

  Future<TokenSet> exchangeCode(
      {required Uri callbackUri, required AuthorizationRequest request}) async {
    if (callbackUri.queryParameters['state'] != request.state) {
      throw const IapException('invalid_state');
    }
    final code = callbackUri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const IapException('missing_code');
    }
    final tokens = await _tokenRequest({
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': config.redirectUri,
      'code_verifier': request.codeVerifier,
      'client_id': config.clientId
    });
    await _store.write(tokens);
    return tokens;
  }

  Future<TokenSet> refresh() async {
    final current = await _store.read();
    if (current?.refreshToken == null) {
      throw const IapException('missing_refresh_token');
    }
    final updated = await _tokenRequest({
      'grant_type': 'refresh_token',
      'refresh_token': current!.refreshToken!,
      'client_id': config.clientId
    });
    final tokens = TokenSet(
        accessToken: updated.accessToken,
        tokenType: updated.tokenType,
        expiresIn: updated.expiresIn,
        refreshToken: updated.refreshToken ?? current.refreshToken,
        idToken: updated.idToken ?? current.idToken,
        scope: updated.scope,
        expiresAt: updated.expiresAt);
    await _store.write(tokens);
    return tokens;
  }

  Future<TokenSet?> tokens() => _store.read();
  Future<void> clearLocalSession() => _store.clear();

  Future<TokenSet> _tokenRequest(Map<String, String> body) async {
    final discovery = await discover();
    final response = await _http.post(
        Uri.parse(discovery['token_endpoint'] as String),
        headers: {'content-type': 'application/x-www-form-urlencoded'},
        body: body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw IapException('token_exchange_failed', response.statusCode);
    }
    final value = jsonDecode(response.body);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('invalid token response');
    }
    return TokenSet.fromJson(value);
  }
}

class IapException implements Exception {
  const IapException(this.code, [this.statusCode]);
  final String code;
  final int? statusCode;
  @override
  String toString() => statusCode == null ? code : '$code ($statusCode)';
}

String _random(int length) {
  final random = Random.secure();
  final bytes = List<int>.generate(length, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

import 'package:bumame_iap_flutter/bumame_iap_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('builds RP-initiated logout request from OIDC discovery', () async {
    final client = IapAuthClient(
      IapConfig(
        issuer: 'https://auth.example.test',
        clientId: 'example-web',
        audience: 'urn:example',
        redirectUri: 'https://app.example.test/login',
        postLogoutRedirectUri: 'https://app.example.test/login',
      ),
      httpClient: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://auth.example.test/.well-known/openid-configuration',
        );
        return http.Response(
          '''{
            "issuer": "https://auth.example.test",
            "authorization_endpoint": "https://auth.example.test/oauth2/auth",
            "token_endpoint": "https://auth.example.test/oauth2/token",
            "end_session_endpoint": "https://auth.example.test/oauth2/sessions/logout"
          }''',
          200,
        );
      }),
    );

    final uri = await client.createLogoutRequest(idTokenHint: 'id-token');

    expect(uri.path, '/oauth2/sessions/logout');
    expect(uri.queryParameters['id_token_hint'], 'id-token');
    expect(uri.queryParameters['client_id'], 'example-web');
    expect(
      uri.queryParameters['post_logout_redirect_uri'],
      'https://app.example.test/login',
    );
  });

  test('rejects providers without an end-session endpoint', () async {
    final client = IapAuthClient(
      IapConfig(
        issuer: 'https://auth.example.test',
        clientId: 'example-web',
        audience: 'urn:example',
        redirectUri: 'https://app.example.test/login',
      ),
      httpClient: MockClient(
        (_) async => http.Response(
          '''{
            "issuer": "https://auth.example.test",
            "authorization_endpoint": "https://auth.example.test/oauth2/auth",
            "token_endpoint": "https://auth.example.test/oauth2/token"
          }''',
          200,
        ),
      ),
    );

    await expectLater(
      client.createLogoutRequest(),
      throwsA(
        isA<IapException>().having(
          (error) => error.code,
          'code',
          'end_session_endpoint_missing',
        ),
      ),
    );
  });

  test('does not send a post-logout redirect without an ID token hint',
      () async {
    final client = IapAuthClient(
      IapConfig(
        issuer: 'https://auth.example.test',
        clientId: 'example-web',
        audience: 'urn:example',
        redirectUri: 'https://app.example.test/login',
        postLogoutRedirectUri: 'https://app.example.test/login',
      ),
      httpClient: MockClient(
        (_) async => http.Response(
          '''{
            "issuer": "https://auth.example.test",
            "authorization_endpoint": "https://auth.example.test/oauth2/auth",
            "token_endpoint": "https://auth.example.test/oauth2/token",
            "end_session_endpoint": "https://auth.example.test/oauth2/sessions/logout"
          }''',
          200,
        ),
      ),
    );

    final uri = await client.createLogoutRequest();

    expect(uri.queryParameters['client_id'], 'example-web');
    expect(uri.queryParameters.containsKey('id_token_hint'), isFalse);
    expect(
      uri.queryParameters.containsKey('post_logout_redirect_uri'),
      isFalse,
    );
  });
}

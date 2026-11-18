import 'dart:async';
import 'dart:typed_data';

import 'package:bumame_iap_flutter/bumame_iap_flutter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final proactive in [true, false]) {
    final stage = proactive ? 'before request' : 'after API 401';
    test(
      'invalid_grant $stage clears the session and notifies the app',
      () async {
        final fixture = await _fixture(
          expired: proactive,
          refresh: () async => http.Response('{"error":"invalid_grant"}', 400),
        );

        await expectLater(
          fixture.dio.get('/cms'),
          throwsA(isA<DioException>()),
        );
        expect(await fixture.session.tokens(), isNull);
        expect(fixture.expirations, 1);
        expect(fixture.adapter.requests.length, proactive ? 0 : 1);
      },
    );

    for (final kind in ['timeout', 'server error', 'non-OAuth 400']) {
      test('$kind $stage preserves the session and allows Retry', () async {
        var fail = true;
        final fixture = await _fixture(
          expired: proactive,
          refresh: () async {
            if (!fail) return _validRefresh();
            if (kind == 'timeout') throw TimeoutException('IAP unavailable');
            return kind == 'server error'
                ? http.Response('{"error":"server_error"}', 503)
                : http.Response('Bad request', 400);
          },
        );

        await expectLater(
          fixture.dio.get('/cms'),
          throwsA(isA<DioException>()),
        );
        expect((await fixture.session.tokens())?.refreshToken, 'old-refresh');
        expect(fixture.expirations, 0);

        fail = false;
        expect((await fixture.dio.get('/cms')).statusCode, 200);
        expect((await fixture.session.tokens())?.refreshToken, 'new-refresh');
        expect(fixture.expirations, 0);
      });
    }
  }

  test('an expired token without a refresh token requires login', () async {
    final fixture = await _fixture(expired: true, refreshToken: null);
    await expectLater(fixture.dio.get('/cms'), throwsA(isA<DioException>()));
    expect(fixture.expirations, 1);
    expect(await fixture.session.tokens(), isNull);
    expect(fixture.adapter.requests, isEmpty);
  });

  for (final status in [401, 503]) {
    test(
      'retry returning $status completes without clearing refreshed tokens',
      () async {
        final fixture = await _fixture(expired: false, retryStatus: status);
        await expectLater(
          fixture.dio.get('/cms').timeout(const Duration(seconds: 2)),
          throwsA(
            isA<DioException>().having(
              (error) => error.response?.statusCode,
              'status',
              status,
            ),
          ),
        );
        expect(fixture.adapter.requests, [
          'Bearer old-access',
          'Bearer new-access',
        ]);
        expect(fixture.expirations, 0);
        expect((await fixture.session.tokens())?.refreshToken, 'new-refresh');
      },
    );
  }

  test('public 401 does not refresh or clear CMS auth', () async {
    final fixture = await _fixture(
      expired: true,
      refresh: () async => throw StateError('public request must not refresh'),
    );
    await expectLater(
      fixture.dio.get('/public', options: Options(extra: {'iapAuth': false})),
      throwsA(isA<DioException>()),
    );
    expect(fixture.adapter.requests, [null]);
    expect(fixture.expirations, 0);
    expect((await fixture.session.tokens())?.refreshToken, 'old-refresh');
  });
}

http.Response _validRefresh() => http.Response(
      '{"access_token":"new-access","refresh_token":"new-refresh","expires_in":3600}',
      200,
    );

Future<_Fixture> _fixture({
  required bool expired,
  String? refreshToken = 'old-refresh',
  Future<http.Response> Function()? refresh,
  int retryStatus = 200,
}) async {
  final store = MemoryTokenStore();
  final client = IapAuthClient(
    IapConfig(
      issuer: 'https://auth.example.test',
      clientId: 'cms',
      audience: 'urn:cms',
      redirectUri: 'https://cms.example.test/login',
    ),
    tokenStore: store,
    httpClient: MockClient((request) {
      if (request.method == 'GET') {
        return Future.value(
          http.Response(
            '{"issuer":"https://auth.example.test",'
            '"authorization_endpoint":"https://auth.example.test/authorize",'
            '"token_endpoint":"https://auth.example.test/token"}',
            200,
          ),
        );
      }
      expect(request.bodyFields['grant_type'], 'refresh_token');
      return refresh?.call() ?? Future.value(_validRefresh());
    }),
  );
  final session = IapSession(client: client, tokenStore: store);
  await session.save(
    TokenSet(
      accessToken: 'old-access',
      refreshToken: refreshToken,
      tokenType: 'Bearer',
      expiresIn: 3600,
      expiresAt: DateTime.now().add(Duration(hours: expired ? -1 : 1)),
    ),
  );
  final fixture = _Fixture(session, _ApiAdapter(retryStatus));
  fixture.dio.interceptors.add(
    IapDioInterceptor(
      dio: fixture.dio,
      session: session,
      invalidateOnlyOnRejectedRefresh: true,
      onUnauthorized: () async => fixture.expirations++,
    ),
  );
  addTearDown(() => fixture.dio.close());
  return fixture;
}

class _Fixture {
  _Fixture(this.session, this.adapter) {
    dio.httpClientAdapter = adapter;
  }

  final IapSession session;
  final _ApiAdapter adapter;
  final dio = Dio(BaseOptions(baseUrl: 'https://cms.example.test'));
  int expirations = 0;
}

class _ApiAdapter implements HttpClientAdapter {
  _ApiAdapter(this.retryStatus);

  final int retryStatus;
  final requests = <Object?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final authorization = options.headers['Authorization'];
    requests.add(authorization);
    return ResponseBody.fromString(
      '{}',
      authorization == 'Bearer new-access' ? retryStatus : 401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

import 'package:dio/dio.dart';

import 'session.dart';

typedef IapUnauthorizedCallback = Future<void> Function();
typedef IapRequestHeaders = Map<String, Object?> Function();

/// Adds a current IAP access token to Dio requests and performs one safe retry
/// after refresh. Set `requestOptions.extra['iapAuth'] = false` for a public
/// request that must not carry credentials.
class IapDioInterceptor extends QueuedInterceptor {
  IapDioInterceptor({
    required this.dio,
    required this.session,
    this.onUnauthorized,
    this.requestHeaders,
  });

  final Dio dio;
  final IapSession session;
  final IapUnauthorizedCallback? onUnauthorized;
  final IapRequestHeaders? requestHeaders;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['iapAuth'] == false ||
        options.headers.containsKey('Authorization')) {
      return handler.next(options);
    }
    try {
      final token = await session.accessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      final contextual = requestHeaders?.call();
      if (contextual != null) options.headers.addAll(contextual);
      handler.next(options);
    } catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
          message: 'IAP session refresh failed',
        ),
      );
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        request.extra['iapAuth'] == false ||
        request.extra['iapRetried'] == true) {
      if (err.response?.statusCode == 401) await _invalidate();
      return handler.next(err);
    }

    try {
      final token = await session.refresh();
      final response = await dio.fetch<dynamic>(
        request.copyWith(
          headers: {...request.headers, 'Authorization': 'Bearer $token'},
          extra: {...request.extra, 'iapRetried': true},
        ),
      );
      handler.resolve(response);
    } catch (_) {
      await _invalidate();
      handler.next(err);
    }
  }

  Future<void> _invalidate() async {
    await session.clear();
    await onUnauthorized?.call();
  }
}

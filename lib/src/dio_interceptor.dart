import 'package:dio/dio.dart';

import 'auth_client.dart';
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
    this.invalidateOnlyOnRejectedRefresh = false,
  });

  final Dio dio;
  final IapSession session;
  final IapUnauthorizedCallback? onUnauthorized;
  final IapRequestHeaders? requestHeaders;
  final bool invalidateOnlyOnRejectedRefresh;

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
      if (token == null && invalidateOnlyOnRejectedRefresh) {
        throw const IapException('missing_refresh_token');
      }
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      final contextual = requestHeaders?.call();
      if (contextual != null) options.headers.addAll(contextual);
      handler.next(options);
    } catch (error, stackTrace) {
      if (invalidateOnlyOnRejectedRefresh) {
        await _handleRejectedRefresh(error);
      }
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
    if (invalidateOnlyOnRejectedRefresh) {
      if (err.response?.statusCode != 401 ||
          request.extra['iapAuth'] == false) {
        return handler.next(err);
      }
      return _retryAfterRefresh(err, handler);
    }
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

  Future<void> _retryAfterRefresh(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    String token;
    try {
      final current = await session.tokens();
      if (current == null) return handler.next(error);
      token =
          request.headers['Authorization'] == 'Bearer ${current.accessToken}'
              ? await session.refresh()
              : (await session.accessToken()) ??
                  (throw const IapException('missing_refresh_token'));
    } catch (cause, stackTrace) {
      await _handleRejectedRefresh(cause);
      return handler.next(
        DioException(
          requestOptions: request,
          error: cause,
          stackTrace: stackTrace,
          message: 'IAP session refresh failed',
        ),
      );
    }

    // Do not re-enter this queued error interceptor if the retry fails.
    final retryClient = dio.clone()..interceptors.remove(this);
    try {
      final response = await retryClient.fetch<dynamic>(
        request.copyWith(
          headers: {...request.headers, 'Authorization': 'Bearer $token'},
        ),
      );
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<void> _handleRejectedRefresh(Object error) async {
    if (error is IapException && error.isRefreshRejected) {
      await _invalidate();
    }
  }

  Future<void> _invalidate() async {
    await session.clear();
    await onUnauthorized?.call();
  }
}

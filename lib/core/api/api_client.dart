// Talks to PassVaultapi exactly the way passvault-client's src/lib/api.js
// does: the server always answers HTTP 200 with the real outcome in the
// body -- {success, status, result} on success, {success:false, error} on
// failure -- so this unwraps that into normal Future resolve/reject
// (ApiException) behavior for callers, and keeps the Bearer JWT in sync.
import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Base URL for PassVaultapi. Overridable per build via
/// `--dart-define=API_BASE_URL=https://...`; defaults to port 5896 (same as
/// passvault-client's .env.local) via 10.0.2.2, the Android emulator's alias
/// for the host machine's localhost -- "localhost" from inside the emulator
/// means the emulator itself, not the host running PassVaultapi.
const String _defaultApiBaseUrl = 'http://10.0.2.2:5896';
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: _defaultApiBaseUrl);

class ApiClient {
  // X-Client-Platform tells the backend to use this row's *Mobile-suffixed
  // Google/reCAPTCHA columns (see PassVaultapi's isMobilePlatform in
  // services/vaultAuth.js) instead of the web ones -- this app has no
  // Origin/Referer header for the backend to otherwise detect it by.
  ApiClient(this._tokenStorage)
    : dio = Dio(BaseOptions(baseUrl: apiBaseUrl, headers: {'Content-Type': 'application/json', 'X-Client-Platform': 'mobile'})) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.read();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          final data = response.data;
          if (data is Map && data['success'] == false) {
            handler.reject(_rejection(response.requestOptions, data));
            return;
          }
          final token = (data is Map ? data['result'] : null) is Map ? data['result']['token'] as String? : null;
          if (token != null) {
            await _tokenStorage.write(token);
          }
          // Callers only ever want the envelope's `result` -- same as
          // axiosInstance's response interceptor returning `data` (the
          // already-unwrapped body) instead of the raw AxiosResponse.
          handler.resolve(
            Response(requestOptions: response.requestOptions, data: data is Map ? data['result'] : data, statusCode: response.statusCode),
          );
        },
        onError: (error, handler) {
          final data = error.response?.data;
          final nestedError = data is Map ? data['error'] : null;
          final message = ((nestedError is Map ? nestedError['message'] : null) ?? (data is Map ? data['message'] : null)) as String? ??
              'Unable to reach the server. Please try again.';
          final title = (data is Map ? data['title'] : null) as String?;
          handler.reject(
            DioException(requestOptions: error.requestOptions, error: ApiException(message, title: title), type: error.type),
          );
        },
      ),
    );
  }

  final Dio dio;
  final TokenStorage _tokenStorage;

  DioException _rejection(RequestOptions options, Map data) {
    final message = (data['error']?['message'] ?? data['message'] ?? 'Something went wrong.') as String;
    final title = data['title'] as String?;
    return DioException(requestOptions: options, error: ApiException(message, title: title));
  }

  /// Unwraps a DioException down to the [ApiException] every onError/onResponse
  /// rejection above attaches, so callers can `catch (e)` without knowing dio.
  static ApiException toApiException(Object error) {
    if (error is DioException && error.error is ApiException) {
      return error.error as ApiException;
    }
    return const ApiException('Something went wrong.');
  }
}

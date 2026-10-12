/// Normalized failure shape for every call through [ApiClient] -- mirrors
/// the {message, title} rejection shape passvault-client's axios
/// interceptor (src/lib/api.js) produces, so UI error handling reads the
/// same way regardless of whether PassVaultapi answered
/// {success:false, error} or the request never reached it at all.
class ApiException implements Exception {
  final String message;
  final String? title;

  const ApiException(this.message, {this.title});

  @override
  String toString() => message;
}

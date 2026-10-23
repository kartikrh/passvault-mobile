/// Normalized failure shape for every call through [ApiClient] -- mirrors
/// the {message, title} rejection shape passvault-client's axios
/// interceptor (src/lib/api.js) produces, so UI error handling reads the
/// same way regardless of whether PassVaultapi answered
/// {success:false, error} or the request never reached it at all.
class ApiException implements Exception {
  final String message;
  final String? title;

  /// PassVaultapi's machine-readable error code (error.code), e.g.
  /// DRIVE_REAUTH_REQUIRED or QUOTA_EXCEEDED -- null when the request never
  /// reached the server.
  final String? code;

  const ApiException(this.message, {this.title, this.code});

  @override
  String toString() => message;
}

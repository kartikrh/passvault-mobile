import '../../../core/api/api_client.dart';

class StepUpResult {
  final bool verified;
  final String? lastViewedAt;
  const StepUpResult(this.verified, this.lastViewedAt);
}

/// POST /vault/auth/2fa/verify -- on-demand re-verification for an
/// already-signed-in session (see verifyStepUpOtpService in
/// services/vaultAuth.js), used to gate revealing a saved account's
/// password. Distinct from /vault/auth/verifyOtp (login/enrollment only).
/// When [client.otpEnabled] is false, the server satisfies this
/// automatically -- callers should skip prompting for a code entirely in
/// that case (see verifyOwnTotpCode's early return) rather than showing a
/// code field that isn't needed.
class StepUpRepository {
  StepUpRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<StepUpResult> verify({
    String? code,
    String? entryId,
    String? entryName,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _apiClient.dio.post('/vault/auth/2fa/verify', data: {
      'code': code,
      'entryId': entryId,
      'entryName': entryName,
      'latitude': latitude,
      'longitude': longitude,
    });
    final data = response.data as Map<String, dynamic>;
    return StepUpResult(data['verified'] == true, data['lastViewedAt'] as String?);
  }

  /// POST /vault/auth/activity/passwordViewed -- audit log for a reveal that
  /// was confirmed with biometrics on the device instead of a 2FA code.
  Future<void> logPasswordViewed({
    required String entryId,
    String? entryName,
    double? latitude,
    double? longitude,
  }) async {
    await _apiClient.dio.post('/vault/auth/activity/passwordViewed', data: {
      'entryId': entryId,
      'entryName': entryName,
      'latitude': latitude,
      'longitude': longitude,
    });
  }
}

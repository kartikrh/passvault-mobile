import 'client.dart';

/// Every PassVaultapi call that can complete a sign-in (login, google,
/// verifyOtp) either finishes immediately or hands back a 2FA challenge --
/// see beginTwoFactorChallenge in services/vaultAuth.js. Modeled as a sealed
/// type so the UI has to handle both branches explicitly rather than
/// guessing which fields are present on a plain map.
sealed class AuthOutcome {
  const AuthOutcome();

  factory AuthOutcome.fromJson(Map<String, dynamic> json) {
    if (json['otpRequired'] == true) {
      return TwoFactorRequired(
        otpType: json['otpType'] as int,
        pendingToken: json['pendingToken'] as String,
        qrCode: json['qrCode'] as String?,
      );
    }
    return AuthSuccess(
      token: json['token'] as String,
      client: Client.fromJson(json['client'] as Map<String, dynamic>),
    );
  }
}

class AuthSuccess extends AuthOutcome {
  final String token;
  final Client client;
  const AuthSuccess({required this.token, required this.client});
}

/// otpType is OTPType.GOOGLE_AUTHENTICATOR (1) or OTPType.MAIL (2) -- see
/// PassVaultapi's utilities/otpConstants.js. qrCode (a data: URL) is only
/// present the first time a Google Authenticator secret is issued --
/// beginTwoFactorChallenge's "no secret yet" branch.
class TwoFactorRequired extends AuthOutcome {
  final int otpType;
  final String pendingToken;
  final String? qrCode;
  const TwoFactorRequired({required this.otpType, required this.pendingToken, this.qrCode});
}

/// OTPType from PassVaultapi's utilities/otpConstants.js -- keys can't start
/// with a digit in JS, kept as-is here for a 1:1 name/value mapping.
abstract class OtpType {
  static const int googleAuthenticator = 1;
  static const int mail = 2;
}

/// Mirrors PassVaultapi's MINIMAL_PROFILE_FIELDS / FULL_PROFILE_FIELDS
/// (services/vaultAuth.js) -- mobileNo/address are only ever populated from
/// GET /vault/auth/profile/full, null otherwise.
class Client {
  final String? name;
  final String? username;
  final String email;
  final bool hasPassword;
  final bool otpEnabled;
  final int? otpType; // OTPType.GOOGLE_AUTHENTICATOR = 1, OTPType.MAIL = 2
  final bool hasOtpSecret;
  final bool driveConnected;
  final String? mobileNo;
  final String? address;
  final int popupIntervalSeconds;

  const Client({
    required this.name,
    required this.username,
    required this.email,
    required this.hasPassword,
    required this.otpEnabled,
    required this.otpType,
    required this.hasOtpSecret,
    required this.driveConnected,
    this.mobileNo,
    this.address,
    this.popupIntervalSeconds = 10,
  });

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        name: json['name'] as String?,
        username: json['username'] as String?,
        email: json['email'] as String,
        hasPassword: json['hasPassword'] as bool? ?? false,
        otpEnabled: json['otpEnabled'] as bool? ?? false,
        otpType: json['otpType'] as int?,
        hasOtpSecret: json['hasOtpSecret'] as bool? ?? false,
        driveConnected: json['driveConnected'] as bool? ?? false,
        mobileNo: json['mobileNo'] as String?,
        address: json['address'] as String?,
        popupIntervalSeconds: json['popupIntervalSeconds'] as int? ?? 10,
      );
}

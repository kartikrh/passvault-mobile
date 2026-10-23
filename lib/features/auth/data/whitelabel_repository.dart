// POST /vault/whitelabel/ -- public, unauthenticated (see PassVaultapi's
// controller/vault/whitelabel.js / services/whitelabel.js's
// publicWhitelabelsService). Unlike passvault-client, which picks by
// matching the browser's own origin against each row's `domain` (no origin
// concept on mobile), this app has no per-domain identity to match against,
// so it always uses whichever entry has isDefault:true (falling back to the
// first active one) -- the same fallback passvault-client's pickWhitelabel
// uses when no origin match is found.
//
// Reads the *Mobile-suffixed fields (googleKeyMobile, not googleKey) -- the
// mobile app registers its own Google OAuth client, separate from the web
// one, and the backend verifies the ID token against that same column (see
// isMobilePlatform / X-Client-Platform in PassVaultapi's vaultAuth.js).
// Only googleClientId matters here -- this app is Google-only, so
// isRecatchEnableMobile/recatchKeyMobile (relevant to the email/password
// login form this app doesn't have) aren't modeled.
import '../../../core/api/api_client.dart';

class WhitelabelConfig {
  final String? googleClientId;

  /// Brand logo URL set in the panel's White Label screen (shown on the
  /// login and dashboard screens); null/empty when not configured.
  final String? logoUrl;

  const WhitelabelConfig({required this.googleClientId, this.logoUrl});

  factory WhitelabelConfig.fromJson(Map<String, dynamic> json) => WhitelabelConfig(
        googleClientId: json['googleKeyMobile'] as String?,
        logoUrl: (json['logo'] as String?)?.trim().isNotEmpty == true ? json['logo'] as String : null,
      );

  static const none = WhitelabelConfig(googleClientId: null);
}

class WhitelabelRepository {
  WhitelabelRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<WhitelabelConfig> fetch() async {
    // Dio always sends the api_client's default Content-Type: application/json
    // header, and Fastify's JSON body parser rejects an empty body when that
    // header is present ("Body cannot be empty when content-type is set to
    // 'application/json'") -- so this needs an explicit (even if empty) body.
    final response = await _apiClient.dio.post('/vault/whitelabel/', data: <String, dynamic>{});
    final list = response.data as List<dynamic>;
    if (list.isEmpty) return WhitelabelConfig.none;
    final entries = list.cast<Map<String, dynamic>>();
    final picked = entries.firstWhere(
      (item) => item['isDefault'] == true,
      orElse: () => entries.first,
    );
    return WhitelabelConfig.fromJson(picked);
  }
}

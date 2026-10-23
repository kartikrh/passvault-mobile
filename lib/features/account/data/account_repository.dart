// Signed-in account management -- profile, passwords, 2FA, suspend/delete,
// activity and the mid-session VPN check. Mirrors passvault-client's
// src/lib/profile.js, activity.js, useVpnGuard.js, TwoFactorSettings.js and
// AccountDangerZone.js; contracts are PassVaultapi's services/vaultAuth.js,
// vaultActivity.js and vaultAccountLifecycle.js.
import '../../../core/api/api_client.dart';
import '../../auth/domain/auth_outcome.dart';
import '../../auth/domain/client.dart';
import '../domain/account_models.dart';

class AccountRepository {
  AccountRepository(this._apiClient);

  final ApiClient _apiClient;

  // Fastify rejects a bodyless JSON POST -- see whitelabel_repository.dart.
  static const _emptyBody = <String, dynamic>{};

  /// GET /vault/auth/profile/full -- adds mobileNo/address.
  Future<Client> fetchFullProfile() async {
    final response = await _apiClient.dio.get('/vault/auth/profile/full');
    return Client.fromJson((response.data as Map<String, dynamic>)['client'] as Map<String, dynamic>);
  }

  /// GET /vault/auth/profile/package -- null when no plan is assigned.
  Future<ClientPackage?> fetchPackage() async {
    final response = await _apiClient.dio.get('/vault/auth/profile/package');
    final pkg = (response.data as Map<String, dynamic>)['package'];
    return pkg is Map<String, dynamic> ? ClientPackage.fromJson(pkg) : null;
  }

  /// PUT /vault/auth/profile -- pass only what changed. A username can only
  /// be set once (server-enforced).
  Future<Client> updateProfile({String? name, String? username, String? mobileNo, String? address}) async {
    final response = await _apiClient.dio.put('/vault/auth/profile', data: {
      'name': ?name,
      'username': ?username,
      'mobileNo': ?mobileNo,
      'address': ?address,
    });
    return Client.fromJson((response.data as Map<String, dynamic>)['client'] as Map<String, dynamic>);
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _apiClient.dio.post('/vault/auth/changePassword', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  /// For an account that has never had a password (Google sign-up).
  Future<void> setPassword(String newPassword) async {
    await _apiClient.dio.post('/vault/auth/setPassword', data: {'newPassword': newPassword});
  }

  /// POST /vault/auth/forgotPassword -- emails a reset link. Always reports
  /// success (the server doesn't reveal whether the email exists).
  Future<void> forgotPassword(String email) async {
    await _apiClient.dio.post('/vault/auth/forgotPassword', data: {'email': email});
  }

  /// POST /vault/auth/2fa/setup -- starts Google Authenticator enrollment.
  /// Returns the QR + pendingToken, confirmed via /vault/auth/verifyOtp on
  /// the existing TwoFactorScreen.
  Future<TwoFactorRequired> beginTwoFactorSetup() async {
    final response = await _apiClient.dio.post('/vault/auth/2fa/setup', data: _emptyBody);
    final outcome = AuthOutcome.fromJson(response.data as Map<String, dynamic>);
    if (outcome is! TwoFactorRequired) throw StateError('Unexpected 2FA setup response');
    return outcome;
  }

  /// POST /vault/auth/2fa/reset -- clears the authenticator secret; the
  /// caller immediately re-enrolls (same as TwoFactorSettings' Reset).
  Future<void> resetTwoFactor() async {
    await _apiClient.dio.post('/vault/auth/2fa/reset', data: _emptyBody);
  }

  Future<void> suspendAccount({String? code}) async {
    await _apiClient.dio.post('/vault/auth/suspendAccount', data: {'code': code});
  }

  Future<void> deleteAccount({String? code, required String reason}) async {
    await _apiClient.dio.post('/vault/auth/deleteAccount', data: {'code': code, 'reason': reason});
  }

  Future<ActivityPage> fetchActivity({int page = 1, int pageSize = 25}) async {
    final response = await _apiClient.dio.get(
      '/vault/auth/activity',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    final data = response.data as Map<String, dynamic>;
    final items = (data['activity'] as List<dynamic>? ?? [])
        .map((row) => ActivityItem.fromJson(row as Map<String, dynamic>))
        .toList();
    return ActivityPage(
      items,
      (data['page'] as num?)?.toInt() ?? page,
      (data['totalPages'] as num?)?.toInt() ?? 0,
      (data['total'] as num?)?.toInt() ?? 0,
    );
  }

  /// GET /vault/auth/vpnStatus -- true when the server sees a VPN/proxy.
  Future<bool> vpnDetected() async {
    final response = await _apiClient.dio.get('/vault/auth/vpnStatus');
    return (response.data as Map<String, dynamic>)['vpnDetected'] == true;
  }
}

/// Upgrade Plan -- mirrors passvault-client's src/lib/plan.js.
class PlanRepository {
  PlanRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Plan>> fetchPlans() async {
    final response = await _apiClient.dio.get('/vault/plan/packages');
    return (response.data as List<dynamic>? ?? []).map((p) => Plan.fromJson(p as Map<String, dynamic>)).toList();
  }

  Future<PaymentMethod> fetchPaymentMethod() async {
    final response = await _apiClient.dio.get('/vault/plan/paymentMethod');
    return PaymentMethod.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> submitUpgrade({required int packageId, required String transferCode}) async {
    await _apiClient.dio.post('/vault/plan/upgradeRequest', data: {
      'packageId': packageId,
      'transferCode': transferCode,
    });
  }

  /// Null when the client has never requested an upgrade.
  Future<UpgradeRequest?> fetchMyRequest() async {
    final response = await _apiClient.dio.get('/vault/plan/upgradeRequest/mine');
    final request = (response.data as Map<String, dynamic>?)?['request'];
    return request is Map<String, dynamic> ? UpgradeRequest.fromJson(request) : null;
  }
}

/// CMS pages (POST /vault/page, public).
class PagesRepository {
  PagesRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<CmsPage>> fetchPages() async {
    final response = await _apiClient.dio.post('/vault/page', data: <String, dynamic>{});
    final list = response.data is List ? response.data as List<dynamic> : const [];
    return list.map((p) => CmsPage.fromJson(p as Map<String, dynamic>)).toList();
  }
}

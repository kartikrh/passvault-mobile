// Calls PassVaultapi's /vault/auth/* endpoints exactly as
// passvault-client's src/lib pages do -- see PassVaultapi's routes/vault/auth
// and services/vaultAuth.js for the request/response contracts this mirrors.
import '../../../core/api/api_client.dart';
import '../../../core/location/location_service.dart';
import '../domain/auth_outcome.dart';
import '../domain/client.dart';

class AuthRepository {
  AuthRepository(this._apiClient, this._locationService);

  final ApiClient _apiClient;
  final LocationService _locationService;

  Future<Map<String, dynamic>> _geoBody() async {
    final coords = await _locationService.requireCurrentLocation();
    return {'latitude': coords.latitude, 'longitude': coords.longitude};
  }

  /// POST /vault/auth/login -- email/username + password (loginService).
  /// Matches passvault-client's LoginForm. No reCAPTCHA token is sent --
  /// this app has no reCAPTCHA widget built yet (see whitelabel_repository's
  /// isRecatchEnableMobile note); if an operator has that on for this White
  /// Label, the server rejects with "Please complete the reCAPTCHA
  /// challenge" until one exists.
  Future<AuthOutcome> login({required String identifier, required String password}) async {
    final body = {'identifier': identifier, 'password': password, ...await _geoBody()};
    final response = await _apiClient.dio.post('/vault/auth/login', data: body);
    return AuthOutcome.fromJson(response.data as Map<String, dynamic>);
  }

  /// POST /vault/auth/google -- idToken from google_sign_in. Finds or
  /// creates the client (googleSignInService) -- covers both sign-up and
  /// sign-in with one call.
  Future<AuthOutcome> googleSignIn(String idToken) async {
    final body = {'idToken': idToken, ...await _geoBody()};
    final response = await _apiClient.dio.post('/vault/auth/google', data: body);
    return AuthOutcome.fromJson(response.data as Map<String, dynamic>);
  }

  /// POST /vault/auth/verifyOtp -- completes a 2FA-gated Google sign-in.
  /// No auth header needed -- pendingToken itself proves step one already
  /// passed.
  Future<AuthOutcome> verifyOtp({required String pendingToken, required String code}) async {
    final response = await _apiClient.dio.post('/vault/auth/verifyOtp', data: {'pendingToken': pendingToken, 'code': code});
    return AuthOutcome.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /vault/auth/profile -- authenticated. Minimal field set (see
  /// getProfileService); used to restore session state on app start.
  Future<Client> fetchProfile() async {
    final response = await _apiClient.dio.get('/vault/auth/profile');
    final data = response.data as Map<String, dynamic>;
    return Client.fromJson(data['client'] as Map<String, dynamic>);
  }

  /// POST /vault/auth/logout -- stateless JWT session, so this is purely
  /// advisory server-side (logoutService); the real logout is discarding
  /// the local token, done by the caller after this returns.
  Future<void> logout() async {
    // Needs an explicit body -- see whitelabel_repository.dart's fetch()
    // comment on why a bodyless POST fails Fastify's JSON body parser.
    await _apiClient.dio.post('/vault/auth/logout', data: <String, dynamic>{});
  }
}

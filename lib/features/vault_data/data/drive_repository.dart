// POST /vault/auth/drive/connect, GET /vault/auth/drive/status -- see
// PassVaultapi's services/vaultDrive.js.
import '../../../core/api/api_client.dart';

class DriveRepository {
  DriveRepository(this._apiClient);

  final ApiClient _apiClient;

  /// [code] is the one-time serverAuthCode from
  /// GoogleDriveConnectService.requestServerAuthCode(). redirectUri: '' --
  /// see utilities/googleDrive.js's DEFAULT_REDIRECT_URI comment: a native
  /// app's serverAuthCode is obtained under Google's native-app flow, which
  /// expects no redirect_uri on exchange (the web client instead omits this
  /// field to fall back to "postmessage", its own popup flow's value).
  Future<bool> connect(String code) async {
    final response = await _apiClient.dio.post('/vault/auth/drive/connect', data: {'code': code, 'redirectUri': ''});
    final data = response.data as Map<String, dynamic>;
    return data['driveConnected'] == true;
  }

  Future<bool> status() async {
    final response = await _apiClient.dio.get('/vault/auth/drive/status');
    final data = response.data as Map<String, dynamic>;
    return data['driveConnected'] == true;
  }
}
